// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

type BalanceDelta is int256;

library BalanceDeltaLibrary {
  function amount0(BalanceDelta delta) internal pure returns (int128) {
    int256 _delta = BalanceDelta.unwrap(delta);
    return int128((_delta << 128) >> 128);
  }

  function amount1(BalanceDelta delta) internal pure returns (int128) {
    int256 _delta = BalanceDelta.unwrap(delta);
    return int128(_delta >> 128);
  }

  function wrap(int256 delta) internal pure returns (BalanceDelta) {
    return BalanceDelta.wrap(delta);
  }

  function from(int128 a0, int128 a1) internal pure returns (BalanceDelta) {
    uint256 packed = uint256(uint128(uint256(int256(a0)))) | (uint256(uint128(uint256(int256(a1)))) << 128);
    return BalanceDelta.wrap(int256(packed));
  }
}
