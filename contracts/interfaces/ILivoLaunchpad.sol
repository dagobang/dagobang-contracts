// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface ILivoLaunchpad {
  function buyTokensWithExactEth(address token, uint256 minTokenAmount, uint256 deadline)
    external
    payable
    returns (uint256 receivedTokens);

  function sellExactTokens(address token, uint256 tokenAmount, uint256 minEthAmount, uint256 deadline)
    external
    returns (uint256 receivedEth);
}
