// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IUniswapV2Pair} from "../interfaces/IUniswapV2Pair.sol";

library V2SwapLib {
  using SafeERC20 for IERC20;

  function exactIn(
    address pair,
    address tokenIn,
    address tokenOut,
    uint24 feeBps,
    uint256 amountIn,
    address recipient
  ) internal returns (uint256 amountOut) {
    require(pair != address(0), "V2_INVALID_PAIR");
    require(amountIn > 0, "V2_ZERO_IN");

    uint256 fee = feeBps == 0 ? 25 : uint256(feeBps);
    require(fee < 10_000, "V2_INVALID_FEE");

    (uint112 r0, uint112 r1, ) = IUniswapV2Pair(pair).getReserves();

    bool zeroForOne = tokenIn < tokenOut;
    (uint256 reserveIn, uint256 reserveOut) = zeroForOne ? (uint256(r0), uint256(r1)) : (uint256(r1), uint256(r0));

    uint256 recipientBefore = IERC20(tokenOut).balanceOf(recipient);

    IERC20(tokenIn).safeTransfer(pair, amountIn);

    uint256 balanceIn = IERC20(tokenIn).balanceOf(pair);
    uint256 amountDelta = balanceIn - reserveIn;

    uint256 amountOutQuoted = _getAmountOut(amountDelta, reserveIn, reserveOut, fee);
    (uint256 amount0Out, uint256 amount1Out) = zeroForOne ? (uint256(0), amountOutQuoted) : (amountOutQuoted, uint256(0));
    IUniswapV2Pair(pair).swap(amount0Out, amount1Out, recipient, "");

    uint256 recipientAfter = IERC20(tokenOut).balanceOf(recipient);
    amountOut = recipientAfter - recipientBefore;
  }

  function _getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut, uint256 fee)
    private
    pure
    returns (uint256)
  {
    uint256 amountInWithFee = amountIn * (10_000 - fee);
    uint256 numerator = amountInWithFee * reserveOut;
    uint256 denominator = reserveIn * 10_000 + amountInWithFee;
    return numerator / denominator;
  }
}

