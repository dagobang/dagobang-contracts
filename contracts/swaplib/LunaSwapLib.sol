// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ILunaLaunchPad} from "../interfaces/ILunaLaunchPad.sol";
import {IWNative} from "../interfaces/IWNative.sol";

library LunaSwapLib {
  using SafeERC20 for IERC20;

  function buy(address launchpad, address router, address wNative, address tokenOut, uint256 amountIn)
    internal
    returns (uint256 amountOut)
  {
    IWNative(wNative).deposit{value: amountIn}();
    IERC20(wNative).forceApprove(router, amountIn);

    uint256 outBefore = IERC20(tokenOut).balanceOf(address(this));
    bool ok = ILunaLaunchPad(launchpad).buy(amountIn, tokenOut, 0, type(uint256).max);
    require(ok, "LUNA_BUY_FAILED");
    uint256 outAfter = IERC20(tokenOut).balanceOf(address(this));
    amountOut = outAfter - outBefore;
  }

  function sell(address launchpad, address router, address wNative, address tokenIn, uint256 amountIn)
    internal
    returns (uint256 amountOutWNative)
  {
    IERC20(tokenIn).forceApprove(router, amountIn);
    uint256 wBefore = IERC20(wNative).balanceOf(address(this));
    bool ok = ILunaLaunchPad(launchpad).sell(amountIn, tokenIn, 0, type(uint256).max);
    require(ok, "LUNA_SELL_FAILED");
    uint256 wAfter = IERC20(wNative).balanceOf(address(this));
    amountOutWNative = wAfter - wBefore;
  }
}
