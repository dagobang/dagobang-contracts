// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {BalanceDelta} from "../swaplib/BalanceDelta.sol";

interface IV4PoolManager {
  struct SwapParams {
    bool zeroForOne;
    int256 amountSpecified;
    uint160 sqrtPriceLimitX96;
  }

  struct PoolKey {
    address currency0;
    address currency1;
    uint24 fee;
    int24 tickSpacing;
    address hooks;
  }

  function exttload(bytes32 slot) external view returns (bytes32 value);
  function unlock(bytes calldata data) external returns (bytes memory);
  function swap(PoolKey memory key, SwapParams memory params, bytes calldata hookData) external returns (BalanceDelta);
  function sync(address currency) external;
  function take(address currency, address to, uint256 amount) external;
  function settle() external payable returns (uint256);
}

