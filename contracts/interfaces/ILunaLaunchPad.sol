// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface ILunaLaunchPad {
  function buy(uint256 amountIn, address tokenAddress, uint256 amountOutMin, uint256 deadline) external returns (bool);
  function sell(uint256 amountIn, address tokenAddress, uint256 amountOutMin, uint256 deadline) external returns (bool);
}

