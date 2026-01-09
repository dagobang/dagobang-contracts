// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IUniswapV3Factory} from "../interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "../interfaces/IUniswapV3Pool.sol";

library V3SwapLib {
  uint160 internal constant MIN_SQRT_RATIO = 4295128739;
  uint160 internal constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;

  function exactIn(
    address v3Factory,
    address tokenIn,
    address tokenOut,
    uint24 fee,
    address poolOverride,
    uint256 amountIn,
    address recipient
  ) internal returns (uint256 amountOut) {
    address pool = IUniswapV3Factory(v3Factory).getPool(tokenIn, tokenOut, fee);
    require(pool != address(0), "POOL_NOT_FOUND");
    if (poolOverride != address(0)) {
      require(poolOverride == pool, "POOL_MISMATCH");
    }

    bool zeroForOne = tokenIn < tokenOut;
    uint160 sqrtPriceLimitX96 = zeroForOne ? MIN_SQRT_RATIO + 1 : MAX_SQRT_RATIO - 1;

    (int256 amount0, int256 amount1) = IUniswapV3Pool(pool).swap(
      recipient,
      zeroForOne,
      int256(amountIn),
      sqrtPriceLimitX96,
      abi.encode(tokenIn, tokenOut, fee, address(this))
    );

    int256 amountOutSigned = zeroForOne ? amount1 : amount0;
    amountOut = uint256(-amountOutSigned);
  }
}

