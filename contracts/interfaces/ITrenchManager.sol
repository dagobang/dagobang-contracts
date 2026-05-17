// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface ITrenchManagerV2 {
  function buy(uint256 amountIn, uint256 amountOutMin, address token, address to, uint256 deadline)
    external
    payable
    returns (uint256 amountOut);

  function sell(uint256 amountIn, uint256 amountOutMin, address token, address to, uint256 deadline)
    external
    returns (uint256 amountOut);
}
