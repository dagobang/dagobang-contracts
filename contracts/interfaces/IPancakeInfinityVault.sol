// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IPancakeInfinityVault {
  function lock(bytes memory data) external returns (bytes memory result);
  function currencyDelta(address settler, address currency) external view returns (int256);
  function sync(address currency) external;
  function take(address currency, address to, uint256 amount) external;
  function settle() external payable returns (uint256);
}

