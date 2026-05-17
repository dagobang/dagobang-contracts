// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IPrintrTrading {
  function spend(address token, address recipient, uint256 baseAmount, uint256 maxPrice)
    external
    payable
    returns (bytes memory);

  function sell(address token, address recipient, uint256 amount, uint256 minPrice)
    external
    returns (bytes memory);
}
