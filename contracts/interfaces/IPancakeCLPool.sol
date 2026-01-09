// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface ICLPoolManager {
  struct SwapParams {
    bool zeroForOne;
    int256 amountSpecified;
    uint160 sqrtPriceLimitX96;
  }
}

interface IPancakeCLPool {
  struct PoolKey {
    address currency0;
    address currency1;
    address hooks;
    address poolManager;
    uint24 fee;
    bytes32 parameters;
  }

  struct CLSwapExactInputSingleParams {
    PoolKey poolKey;
    bool zeroForOne;
    uint128 amountIn;
    uint128 amountOutMinimum;
    bytes hookData;
  }

  function swap(PoolKey memory key, ICLPoolManager.SwapParams memory params, bytes memory hookData)
    external
    returns (int256 delta);
}

