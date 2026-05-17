// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IHyperZap {
  function buy(address tokenAddress, uint256 usdcAmount, uint256 minTokensOut, address referrer)
    external
    returns (uint256 tokensOut);

  function sell(address tokenAddress, uint256 tokenAmount, uint256 minUsdcOut) external returns (uint256 usdcOut);
}
