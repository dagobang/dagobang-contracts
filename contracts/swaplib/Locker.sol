// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

library Locker {
  bytes32 internal constant LOCKER_SLOT = 0xc5011edf2a3b0b6188f232acbdd9a3c76c9d6ae49cf41063586b9f8030da24dc;

  function get() internal view returns (address locker) {
    assembly ("memory-safe") {
      locker := sload(LOCKER_SLOT)
    }
  }

  function set(address locker) internal {
    assembly ("memory-safe") {
      sstore(LOCKER_SLOT, locker)
    }
  }
}
