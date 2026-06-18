// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IPrintrTrading} from "../interfaces/IPrintrTrading.sol";
import {IWNative} from "../interfaces/IWNative.sol";

library PrintrSwapLib {
  using SafeERC20 for IERC20;

  function swap(address wNative, address printrTrading, address tokenIn, address tokenOut, uint256 amountIn, address recipient)
    external
    returns (uint256 amountOut)
  {
    require(printrTrading != address(0), "PRINTR_ADDR_0");
    require(tokenIn != tokenOut, "PRINTR_SAME_TOKEN");
    require(amountIn > 0, "ZI");

    if (tokenIn == address(0)) {
      require(tokenOut != address(0), "PRINTR_NATIVE_TO_NATIVE");
      _ensureNativeBalance(wNative, amountIn);
      uint256 tokenBefore = IERC20(tokenOut).balanceOf(address(this));
      IPrintrTrading(printrTrading).spend{value: amountIn}(tokenOut, address(this), amountIn, 0);
      amountOut = IERC20(tokenOut).balanceOf(address(this)) - tokenBefore;
      if (amountOut > 0) IERC20(tokenOut).safeTransfer(recipient, amountOut);
      return amountOut;
    }

    require(tokenOut == address(0), "PRINTR_UNSUPPORTED_PAIR");
    IERC20(tokenIn).forceApprove(printrTrading, amountIn);
    uint256 nativeBefore = address(this).balance;
    IPrintrTrading(printrTrading).sell(tokenIn, address(this), amountIn, 0);
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
