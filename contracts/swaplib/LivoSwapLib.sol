// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ILivoLaunchpad} from "../interfaces/ILivoLaunchpad.sol";
import {IWNative} from "../interfaces/IWNative.sol";

library LivoSwapLib {
  using SafeERC20 for IERC20;

  function swap(address wNative, address launchpad, address tokenIn, address tokenOut, uint256 amountIn, address recipient)
    internal
    returns (uint256 amountOut)
  {
    require(launchpad != address(0), "LIVO_ADDR_0");
    require(tokenIn != tokenOut, "LIVO_SAME_TOKEN");
    require(amountIn > 0, "ZI");

    if (tokenIn == address(0)) {
      require(tokenOut != address(0), "LIVO_NATIVE_TO_NATIVE");
      _ensureNativeBalance(wNative, amountIn);
      uint256 tokenBefore = IERC20(tokenOut).balanceOf(address(this));
      ILivoLaunchpad(launchpad).buyTokensWithExactEth{value: amountIn}(tokenOut, 0, block.timestamp);
      amountOut = IERC20(tokenOut).balanceOf(address(this)) - tokenBefore;
      if (amountOut > 0) IERC20(tokenOut).safeTransfer(recipient, amountOut);
      return amountOut;
    }

    require(tokenOut == address(0), "LIVO_UNSUPPORTED_PAIR");
    IERC20(tokenIn).forceApprove(launchpad, amountIn);
    uint256 nativeBefore = address(this).balance;
    ILivoLaunchpad(launchpad).sellExactTokens(tokenIn, amountIn, 0, block.timestamp);
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
