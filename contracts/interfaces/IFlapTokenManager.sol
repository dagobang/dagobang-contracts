// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IFlapTokenManager {
  struct ExactInputParams {
    address inputToken;
    address outputToken;
    uint256 inputAmount;
    uint256 minOutputAmount;
    bytes permitData;
  }

  function swapExactInput(ExactInputParams calldata params) external payable returns (uint256 outputAmount);
}

