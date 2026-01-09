// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IV4Router {
  struct PathKey {
    address intermediateCurrency;
    uint24 fee;
    int24 tickSpacing;
    address hooks;
    bytes hookData;
  }

  struct ExactInputParams {
    address currencyIn;
    address currencyOut;
    PathKey[] path;
    uint128 amountIn;
    uint128 amountOutMinimum;
  }
}

