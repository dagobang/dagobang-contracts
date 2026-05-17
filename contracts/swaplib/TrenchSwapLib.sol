// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ITrenchManagerV2} from "../interfaces/ITrenchManager.sol";
import {IWNative} from "../interfaces/IWNative.sol";

library TrenchSwapLib {
  using SafeERC20 for IERC20;

  function swap(address wNative, address trenchManager, address tokenIn, address tokenOut, uint256 amountIn, address recipient)
    internal
    returns (uint256 amountOut)
  {
    require(trenchManager != address(0), "TRENCH_ADDR_0");
    require(amountIn > 0, "ZI");

    if (tokenIn == address(0)) {
      require(tokenOut != address(0), "TRENCH_NATIVE_TO_NATIVE");
      _ensureNativeBalance(wNative, amountIn);
      uint256 beforeBal = IERC20(tokenOut).balanceOf(address(this));
      ITrenchManagerV2(trenchManager).buy{value: amountIn}(amountIn, 0, tokenOut, address(this), block.timestamp);
      amountOut = IERC20(tokenOut).balanceOf(address(this)) - beforeBal;
      if (amountOut > 0) IERC20(tokenOut).safeTransfer(recipient, amountOut);
      return amountOut;
    }

    require(tokenOut == address(0), "TRENCH_UNSUPPORTED_PAIR");
    IERC20(tokenIn).forceApprove(trenchManager, amountIn);
    uint256 nativeBefore = address(this).balance;
    ITrenchManagerV2(trenchManager).sell(amountIn, 0, tokenIn, address(this), block.timestamp);
    uint256 nativeDelta = address(this).balance - nativeBefore;
    IWNative(wNative).deposit{value: nativeDelta}();
    IERC20(wNative).safeTransfer(recipient, nativeDelta);
    return nativeDelta;
  }

  function _ensureNativeBalance(address wNative, uint256 need) private {
    uint256 nativeBal = address(this).balance;
    if (nativeBal >= need) return;
    IWNative(wNative).withdraw(need - nativeBal);
  }
}
