// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IWNative} from "../interfaces/IWNative.sol";
import {IV4PoolManager} from "../interfaces/IV4PoolManager.sol";
import {IV4Router} from "../interfaces/IV4Router.sol";
import {BalanceDelta} from "./BalanceDelta.sol";
import {BalanceDeltaLibrary} from "./BalanceDelta.sol";
import {Locker} from "./Locker.sol";
import {SafeCast} from "./SafeCast.sol";

library V4SwapLib {
  using SafeERC20 for IERC20;
  using BalanceDeltaLibrary for BalanceDelta;
  using SafeCast for int128;

  enum CMD {
    SWAP_V4_EXACT_IN
  }

  error ContractLocked();

  modifier isNotLocked(address payer) {
    if (Locker.get() != address(0)) revert ContractLocked();
    Locker.set(payer);
    _;
    Locker.set(address(0));
  }

  function _msgSender() internal view returns (address) {
    return Locker.get();
  }

  function swapExactIn(
    address poolManager,
    address wNative,
    address payer,
    address payerOrigin,
    uint256 amountIn,
    address tokenIn,
    address tokenOut,
    uint24 fee,
    int24 tickSpacing,
    address hooks,
    bytes memory hookData,
    address recipient
  ) internal returns (uint256 amountOut) {
    IV4Router.PathKey[] memory path = new IV4Router.PathKey[](1);
    path[0] = IV4Router.PathKey(tokenOut, fee, tickSpacing, hooks, hookData);
    (, amountOut) = swapV4ExactIn(
      poolManager,
      IV4Router.ExactInputParams({currencyIn: tokenIn, currencyOut: tokenOut, path: path, amountIn: uint128(amountIn), amountOutMinimum: 0}),
      recipient,
      payerOrigin,
      payer
    );
  }

  function swapV4ExactIn(
    address poolManager,
    IV4Router.ExactInputParams memory params,
    address recipient,
    address payerOrigin,
    address payer
  ) internal isNotLocked(payer) returns (uint256 amountIn, uint256 amountOut) {
    bytes memory data = abi.encode(CMD.SWAP_V4_EXACT_IN, abi.encode(params, recipient, payerOrigin));
    bytes memory result = IV4PoolManager(poolManager).unlock(data);
    return abi.decode(result, (uint256, uint256));
  }

  function unlockCallback(address poolManager, address wNative, bytes memory data) internal returns (bytes memory) {
    (CMD cmd, bytes memory params) = abi.decode(data, (CMD, bytes));
    if (cmd == CMD.SWAP_V4_EXACT_IN) {
      (IV4Router.ExactInputParams memory swapParams, address recipient, address payerOrigin) =
        abi.decode(params, (IV4Router.ExactInputParams, address, address));
      _swapV4ExactIn(poolManager, swapParams);
      address currencyOut = swapParams.path[swapParams.path.length - 1].intermediateCurrency;
      uint256 amountOut = _getFullCredit(poolManager, currencyOut);
      _take(poolManager, wNative, currencyOut, recipient, amountOut);
      uint256 amountIn = _getFullDebt(poolManager, swapParams.currencyIn);
      _settle(poolManager, wNative, swapParams.currencyIn, _msgSender(), amountIn);
      _refund(wNative, swapParams.currencyIn, payerOrigin, _getBalance(wNative, swapParams.currencyIn));
      return abi.encode(amountIn, amountOut);
    }
    revert("V4_NO_CMD");
  }

  function _swapV4ExactIn(address poolManager, IV4Router.ExactInputParams memory params) private {
    unchecked {
      uint256 pathLength = params.path.length;
      uint128 amountOut;
      address currencyIn = params.currencyIn;
      uint128 amountIn = params.amountIn;
      IV4Router.PathKey memory pathKey;

      for (uint256 i = 0; i < pathLength; i++) {
        pathKey = params.path[i];
        (IV4PoolManager.PoolKey memory poolKey, bool zeroForOne) = _getPoolAndSwapDirection(pathKey, currencyIn);
        amountOut = _swap(poolManager, poolKey, zeroForOne, -int256(uint256(amountIn)), pathKey.hookData).toUint128();
        amountIn = amountOut;
        currencyIn = pathKey.intermediateCurrency;
      }
    }
  }

  function _swap(address poolManager, IV4PoolManager.PoolKey memory poolKey, bool zeroForOne, int256 amountSpecified, bytes memory hookData)
    private
    returns (int128 reciprocalAmount)
  {
    unchecked {
      BalanceDelta delta = IV4PoolManager(poolManager).swap(
        poolKey,
        IV4PoolManager.SwapParams(zeroForOne, amountSpecified, zeroForOne ? _minSqrtRatio() : _maxSqrtRatio()),
        hookData
      );
      reciprocalAmount = (zeroForOne == amountSpecified < 0) ? delta.amount1() : delta.amount0();
    }
  }

  function _minSqrtRatio() private pure returns (uint160) {
    return 4295128739 + 1;
  }

  function _maxSqrtRatio() private pure returns (uint160) {
    return 1461446703485210103287273052203988822378723970342 - 1;
  }

  function _computeSlot(address target, address currency) private pure returns (bytes32 hashSlot) {
    assembly ("memory-safe") {
      mstore(0, and(target, 0xffffffffffffffffffffffffffffffffffffffff))
      mstore(32, and(currency, 0xffffffffffffffffffffffffffffffffffffffff))
      hashSlot := keccak256(0, 64)
    }
  }

  function _getFullDebt(address poolManager, address currency) private view returns (uint256 amount) {
    bytes32 slot = _computeSlot(address(this), currency);
    int256 _amount = int256(uint256(IV4PoolManager(poolManager).exttload(slot)));
    require(_amount <= 0, "V4_DEBT_SIGN");
    amount = uint256(-_amount);
  }

  function _getFullCredit(address poolManager, address currency) private view returns (uint256 amount) {
    bytes32 slot = _computeSlot(address(this), currency);
    int256 _amount = int256(uint256(IV4PoolManager(poolManager).exttload(slot)));
    require(_amount >= 0, "V4_CREDIT_SIGN");
    amount = uint256(_amount);
  }

  function _settle(address poolManager, address wNative, address currency, address payer, uint256 amount) private {
    IV4PoolManager(poolManager).sync(currency);
    if (currency == address(0)) {
      _ensureNative(wNative, amount);
      IV4PoolManager(poolManager).settle{value: amount}();
    } else {
      _pay(poolManager, currency, payer, amount);
      IV4PoolManager(poolManager).settle();
    }
  }

  function _refund(address wNative, address currency, address receiver, uint256 amount) private {
    if (amount == 0) return;
    if (currency == address(0)) {
      (bool success, ) = receiver.call{value: amount}("");
      require(success, "V4_REFUND_FAILED");
    } else {
      IERC20(currency).safeTransfer(receiver, amount);
    }
  }

  function _pay(address poolManager, address currency, address payer, uint256 amount) private {
    if (amount == 0) return;
    if (payer == address(this)) {
      IERC20(currency).safeTransfer(poolManager, amount);
    } else {
      IERC20(currency).safeTransferFrom(payer, poolManager, amount);
    }
  }

  function _take(address poolManager, address wNative, address currency, address recipient, uint256 amount) private {
    if (amount == 0) return;
    IV4PoolManager(poolManager).take(currency, address(this), amount);
    if (currency == address(0)) {
      IWNative(wNative).deposit{value: amount}();
      if (recipient != address(this)) {
        IERC20(wNative).safeTransfer(recipient, amount);
      }
    } else if (recipient != address(this)) {
      IERC20(currency).safeTransfer(recipient, amount);
    }
  }

  function _getPoolAndSwapDirection(IV4Router.PathKey memory params, address currencyIn)
    private
    pure
    returns (IV4PoolManager.PoolKey memory poolKey, bool zeroForOne)
  {
    address currencyOut = params.intermediateCurrency;
    (address currency0, address currency1) = currencyIn < currencyOut ? (currencyIn, currencyOut) : (currencyOut, currencyIn);
    zeroForOne = currencyIn == currency0;
    poolKey = IV4PoolManager.PoolKey(currency0, currency1, params.fee, params.tickSpacing, params.hooks);
  }

  function _getBalance(address wNative, address currency) private view returns (uint256) {
    if (currency == address(0)) return address(this).balance;
    return IERC20(currency).balanceOf(address(this));
  }

  function _ensureNative(address wNative, uint256 amount) private {
    uint256 bal = address(this).balance;
    if (bal >= amount) return;
    IWNative(wNative).withdraw(amount - bal);
  }
}

