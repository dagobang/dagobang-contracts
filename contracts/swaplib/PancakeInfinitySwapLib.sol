// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IWNative} from "../interfaces/IWNative.sol";
import {IPancakeInfinityVault} from "../interfaces/IPancakeInfinityVault.sol";
import {IPancakeCLPool} from "../interfaces/IPancakeCLPool.sol";
import {ICLPoolManager} from "../interfaces/IPancakeCLPool.sol";
import {IPancakeBinPool} from "../interfaces/IPancakeBinPool.sol";
import {BalanceDelta} from "./BalanceDelta.sol";
import {BalanceDeltaLibrary} from "./BalanceDelta.sol";
import {Locker} from "./Locker.sol";
import {SafeCast} from "./SafeCast.sol";

library PancakeInfinitySwapLib {
  using SafeERC20 for IERC20;
  using BalanceDeltaLibrary for BalanceDelta;
  using SafeCast for int128;

  enum CMD {
    SWAP_PANCAKE_INFINITY_EXACT_IN,
    SWAP_PANCAKE_INFINITY_BIN_EXACT_IN
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
    address vault,
    address clPoolManager,
    address binPoolManager,
    address payer,
    address payerOrigin,
    uint256 amountIn,
    address tokenIn,
    address tokenOut,
    address hooks,
    address poolManager,
    uint24 fee,
    bytes32 parameters,
    bytes memory hookData,
    address recipient
  ) internal returns (uint256 amountOut) {
    address currency0 = tokenIn < tokenOut ? tokenIn : tokenOut;
    address currency1 = tokenIn < tokenOut ? tokenOut : tokenIn;
    if (poolManager == clPoolManager) {
      (, amountOut) = swapCLExactIn(
        vault,
        IPancakeCLPool.CLSwapExactInputSingleParams({
          poolKey: IPancakeCLPool.PoolKey(currency0, currency1, hooks, poolManager, fee, parameters),
          zeroForOne: tokenIn < tokenOut,
          amountIn: uint128(amountIn),
          amountOutMinimum: 0,
          hookData: hookData
        }),
        recipient,
        payerOrigin,
        payer
      );
      return amountOut;
    }
    if (poolManager == binPoolManager) {
      (, amountOut) = swapBinExactIn(
        vault,
        IPancakeBinPool.BinSwapExactInputSingleParams({
          poolKey: IPancakeCLPool.PoolKey(currency0, currency1, hooks, poolManager, fee, parameters),
          swapForY: tokenIn < tokenOut,
          amountIn: uint128(amountIn),
          amountOutMinimum: 0,
          hookData: hookData
        }),
        recipient,
        payerOrigin,
        payer
      );
      return amountOut;
    }
    revert("INFINITY_PM");
  }

  function swapCLExactIn(
    address vault,
    IPancakeCLPool.CLSwapExactInputSingleParams memory params,
    address recipient,
    address payerOrigin,
    address payer
  ) internal isNotLocked(payer) returns (uint256 amountIn, uint256 amountOut) {
    bytes memory data = abi.encode(CMD.SWAP_PANCAKE_INFINITY_EXACT_IN, abi.encode(params, recipient, payerOrigin));
    bytes memory result = IPancakeInfinityVault(vault).lock(data);
    return abi.decode(result, (uint256, uint256));
  }

  function swapBinExactIn(
    address vault,
    IPancakeBinPool.BinSwapExactInputSingleParams memory params,
    address recipient,
    address payerOrigin,
    address payer
  ) internal isNotLocked(payer) returns (uint256 amountIn, uint256 amountOut) {
    bytes memory data = abi.encode(CMD.SWAP_PANCAKE_INFINITY_BIN_EXACT_IN, abi.encode(params, recipient, payerOrigin));
    bytes memory result = IPancakeInfinityVault(vault).lock(data);
    return abi.decode(result, (uint256, uint256));
  }

  function lockAcquired(
    address vault,
    address wNative,
    address clPoolManager,
    address binPoolManager,
    bytes memory data
  ) internal returns (bytes memory) {
    (CMD cmd, bytes memory params) = abi.decode(data, (CMD, bytes));
    if (cmd == CMD.SWAP_PANCAKE_INFINITY_EXACT_IN) {
      (IPancakeCLPool.CLSwapExactInputSingleParams memory swapParams, address recipient, address payerOrigin) =
        abi.decode(params, (IPancakeCLPool.CLSwapExactInputSingleParams, address, address));
      _swapCLExactIn(clPoolManager, swapParams);
      address currencyOut = swapParams.zeroForOne ? swapParams.poolKey.currency1 : swapParams.poolKey.currency0;
      address currencyIn = swapParams.zeroForOne ? swapParams.poolKey.currency0 : swapParams.poolKey.currency1;
      uint256 amountOut = _getFullCredit(vault, currencyOut);
      _take(vault, wNative, currencyOut, recipient, amountOut);
      uint256 amountIn = _getFullDebt(vault, currencyIn);
      _settle(vault, wNative, currencyIn, _msgSender(), amountIn);
      _refund(currencyIn, payerOrigin, _getBalance(currencyIn));
      return abi.encode(amountIn, amountOut);
    }
    if (cmd == CMD.SWAP_PANCAKE_INFINITY_BIN_EXACT_IN) {
      (IPancakeBinPool.BinSwapExactInputSingleParams memory swapParams, address recipient, address payerOrigin) =
        abi.decode(params, (IPancakeBinPool.BinSwapExactInputSingleParams, address, address));
      _swapBinExactIn(binPoolManager, swapParams);
      address currencyOut = swapParams.swapForY ? swapParams.poolKey.currency1 : swapParams.poolKey.currency0;
      address currencyIn = swapParams.swapForY ? swapParams.poolKey.currency0 : swapParams.poolKey.currency1;
      uint256 amountOut = _getFullCredit(vault, currencyOut);
      _take(vault, wNative, currencyOut, recipient, amountOut);
      uint256 amountIn = _getFullDebt(vault, currencyIn);
      _settle(vault, wNative, currencyIn, _msgSender(), amountIn);
      _refund(currencyIn, payerOrigin, _getBalance(currencyIn));
      return abi.encode(amountIn, amountOut);
    }
    revert("INFINITY_NO_CMD");
  }

  function _swapCLExactIn(address clPoolManager, IPancakeCLPool.CLSwapExactInputSingleParams memory params) private {
    uint128 amountIn = params.amountIn;
    uint128 amountOut = _swapCLExactPrivate(clPoolManager, params.poolKey, params.zeroForOne, -int256(uint256(amountIn)), params.hookData).toUint128();
    require(amountOut >= params.amountOutMinimum, "INFINITY_MIN_OUT");
  }

  function _swapCLExactPrivate(
    address clPoolManager,
    IPancakeCLPool.PoolKey memory poolKey,
    bool zeroForOne,
    int256 amountSpecified,
    bytes memory hookData
  ) private returns (int128 reciprocalAmount) {
    int256 deltaRaw = IPancakeCLPool(clPoolManager).swap(
      poolKey,
      ICLPoolManager.SwapParams(zeroForOne, amountSpecified, zeroForOne ? _minSqrtRatio() : _maxSqrtRatio()),
      hookData
    );
    BalanceDelta delta = BalanceDeltaLibrary.wrap(deltaRaw);
    reciprocalAmount = (zeroForOne == amountSpecified < 0) ? delta.amount1() : delta.amount0();
  }

  function _swapBinExactIn(address binPoolManager, IPancakeBinPool.BinSwapExactInputSingleParams memory params) private {
    uint128 amountIn = params.amountIn;
    uint128 amountOut = _swapBinExactPrivate(binPoolManager, params.poolKey, params.swapForY, -int256(uint256(amountIn)), params.hookData).toUint128();
    require(amountOut >= params.amountOutMinimum, "INFINITY_MIN_OUT");
  }

  function _swapBinExactPrivate(
    address binPoolManager,
    IPancakeCLPool.PoolKey memory poolKey,
    bool swapForY,
    int256 amountSpecified,
    bytes memory hookData
  ) private returns (int128 reciprocalAmount) {
    int256 deltaRaw = IPancakeBinPool(binPoolManager).swap(poolKey, swapForY, int128(amountSpecified), hookData);
    BalanceDelta delta = BalanceDeltaLibrary.wrap(deltaRaw);
    reciprocalAmount = (swapForY == amountSpecified < 0) ? delta.amount1() : delta.amount0();
  }

  function _minSqrtRatio() private pure returns (uint160) {
    return 4295128739 + 1;
  }

  function _maxSqrtRatio() private pure returns (uint160) {
    return 1461446703485210103287273052203988822378723970342 - 1;
  }

  function _getFullDebt(address vault, address currency) private view returns (uint256 amount) {
    int256 _amount = IPancakeInfinityVault(vault).currencyDelta(address(this), currency);
    require(_amount <= 0, "INFINITY_DEBT_SIGN");
    amount = uint256(-_amount);
  }

  function _getFullCredit(address vault, address currency) private view returns (uint256 amount) {
    int256 _amount = IPancakeInfinityVault(vault).currencyDelta(address(this), currency);
    require(_amount >= 0, "INFINITY_CREDIT_SIGN");
    amount = uint256(_amount);
  }

  function _settle(address vault, address wNative, address currency, address payer, uint256 amount) private {
    IPancakeInfinityVault(vault).sync(currency);
    if (currency == address(0)) {
      _ensureNative(wNative, amount);
      IPancakeInfinityVault(vault).settle{value: amount}();
    } else {
      _pay(vault, currency, payer, amount);
      IPancakeInfinityVault(vault).settle();
    }
  }

  function _refund(address currency, address receiver, uint256 amount) private {
    if (amount == 0) return;
    if (currency == address(0)) {
      (bool success, ) = receiver.call{value: amount}("");
      require(success, "INFINITY_REFUND_FAILED");
    } else {
      IERC20(currency).safeTransfer(receiver, amount);
    }
  }

  function _pay(address vault, address currency, address payer, uint256 amount) private {
    if (amount == 0) return;
    if (payer == address(this)) {
      IERC20(currency).safeTransfer(vault, amount);
    } else {
      IERC20(currency).safeTransferFrom(payer, vault, amount);
    }
  }

  function _take(address vault, address wNative, address currency, address recipient, uint256 amount) private {
    if (amount == 0) return;
    IPancakeInfinityVault(vault).take(currency, address(this), amount);
    if (currency == address(0)) {
      IWNative(wNative).deposit{value: amount}();
      if (recipient != address(this)) {
        IERC20(wNative).safeTransfer(recipient, amount);
      }
    } else if (recipient != address(this)) {
      IERC20(currency).safeTransfer(recipient, amount);
    }
  }

  function _getBalance(address currency) private view returns (uint256) {
    if (currency == address(0)) return address(this).balance;
    return IERC20(currency).balanceOf(address(this));
  }

  function _ensureNative(address wNative, uint256 amount) private {
    uint256 bal = address(this).balance;
    if (bal >= amount) return;
    IWNative(wNative).withdraw(amount - bal);
  }
}

