// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IPancakeCLPool} from "./IPancakeCLPool.sol";

interface IPancakeBinPool {
  struct BinSwapExactInputSingleParams {
    IPancakeCLPool.PoolKey poolKey;
    bool swapForY;
    uint128 amountIn;
    uint128 amountOutMinimum;
    bytes hookData;
  }

  function swap(IPancakeCLPool.PoolKey memory key, bool swapForY, int128 amountSpecified, bytes memory hookData)
    external
    returns (int256 delta);
}

