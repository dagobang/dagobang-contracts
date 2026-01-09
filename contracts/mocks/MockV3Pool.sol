// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IUniswapV3SwapCallback} from "../interfaces/IUniswapV3SwapCallback.sol";

contract MockV3Pool {
  using SafeERC20 for IERC20;

  address public immutable token0;
  address public immutable token1;

  constructor(address token0_, address token1_) {
    require(token0_ != token1_, "SAME_TOKEN");
    (token0, token1) = token0_ < token1_ ? (token0_, token1_) : (token1_, token0_);
  }

  function swap(
    address recipient,
    bool zeroForOne,
    int256 amountSpecified,
    uint160,
    bytes calldata data
  ) external returns (int256 amount0, int256 amount1) {
    require(amountSpecified > 0, "ONLY_EXACT_INPUT");

    uint256 amountIn = uint256(amountSpecified);
    uint256 amountOut = amountIn;

    if (zeroForOne) {
      amount0 = int256(amountIn);
      amount1 = -int256(amountOut);
      IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(amount0, amount1, data);
      IERC20(token1).safeTransfer(recipient, amountOut);
    } else {
      amount0 = -int256(amountOut);
      amount1 = int256(amountIn);
      IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(amount0, amount1, data);
      IERC20(token0).safeTransfer(recipient, amountOut);
    }
  }
}
