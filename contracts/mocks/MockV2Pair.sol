// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MockV2Pair {
  using SafeERC20 for IERC20;

  address public immutable token0;
  address public immutable token1;

  uint112 private _reserve0;
  uint112 private _reserve1;

  constructor(address tokenA, address tokenB, uint112 reserve0_, uint112 reserve1_) {
    require(tokenA != tokenB, "SAME_TOKEN");
    (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    _reserve0 = reserve0_;
    _reserve1 = reserve1_;
  }

  function setReserves(uint112 reserve0_, uint112 reserve1_) external {
    _reserve0 = reserve0_;
    _reserve1 = reserve1_;
  }

  function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) {
    return (_reserve0, _reserve1, 0);
  }

  function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata) external {
    if (amount0Out > 0) IERC20(token0).safeTransfer(to, amount0Out);
    if (amount1Out > 0) IERC20(token1).safeTransfer(to, amount1Out);
  }
}

