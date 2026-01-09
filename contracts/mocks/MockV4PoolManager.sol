// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IV4PoolManager} from "../interfaces/IV4PoolManager.sol";
import {BalanceDelta} from "../swaplib/BalanceDelta.sol";
import {BalanceDeltaLibrary} from "../swaplib/BalanceDelta.sol";

interface IV4UnlockCallback {
  function unlockCallback(bytes calldata data) external returns (bytes memory);
}

contract MockV4PoolManager is IV4PoolManager {
  using SafeERC20 for IERC20;
  using BalanceDeltaLibrary for int128;

  mapping(bytes32 => int256) public deltas;

  receive() external payable {}

  function exttload(bytes32 slot) external view returns (bytes32 value) {
    return bytes32(uint256(deltas[slot]));
  }

  function unlock(bytes calldata data) external returns (bytes memory) {
    return IV4UnlockCallback(msg.sender).unlockCallback(data);
  }

  function swap(PoolKey memory key, SwapParams memory params, bytes calldata) external returns (BalanceDelta swapDelta) {
    require(params.amountSpecified < 0, "ONLY_EXACT_IN");
    uint256 amountIn = uint256(-params.amountSpecified);
    uint256 amountOut = amountIn;

    address currencyIn = params.zeroForOne ? key.currency0 : key.currency1;
    address currencyOut = params.zeroForOne ? key.currency1 : key.currency0;

    bytes32 slotIn = _computeSlot(msg.sender, currencyIn);
    bytes32 slotOut = _computeSlot(msg.sender, currencyOut);
    deltas[slotIn] = -int256(amountIn);
    deltas[slotOut] = int256(amountOut);

    int128 a0 = params.zeroForOne ? -int128(int256(amountIn)) : int128(int256(amountOut));
    int128 a1 = params.zeroForOne ? int128(int256(amountOut)) : -int128(int256(amountIn));
    swapDelta = BalanceDeltaLibrary.from(a0, a1);
  }

  function sync(address) external {}

  function take(address currency, address to, uint256 amount) external {
    if (currency == address(0)) {
      (bool ok, ) = to.call{value: amount}("");
      require(ok, "TAKE_NATIVE_FAILED");
      return;
    }
    IERC20(currency).safeTransfer(to, amount);
  }

  function settle() external payable returns (uint256) {
    return msg.value;
  }

  function _computeSlot(address target, address currency) internal pure returns (bytes32 hashSlot) {
    assembly ("memory-safe") {
      mstore(0, and(target, 0xffffffffffffffffffffffffffffffffffffffff))
      mstore(32, and(currency, 0xffffffffffffffffffffffffffffffffffffffff))
      hashSlot := keccak256(0, 64)
    }
  }
}
