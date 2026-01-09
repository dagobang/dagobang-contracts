// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

library SafeCast {
  function toUint128(int128 value) internal pure returns (uint128) {
    require(value >= 0, "SAFECAST_U128");
    return uint128(uint256(int256(value)));
  }
}

