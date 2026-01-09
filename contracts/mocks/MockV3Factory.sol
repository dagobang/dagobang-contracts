// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract MockV3Factory {
  mapping(bytes32 => address) private _pools;

  function setPool(address tokenA, address tokenB, uint24 fee, address pool) external {
    _pools[_key(tokenA, tokenB, fee)] = pool;
    _pools[_key(tokenB, tokenA, fee)] = pool;
  }

  function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address) {
    return _pools[_key(tokenA, tokenB, fee)];
  }

  function _key(address tokenA, address tokenB, uint24 fee) private pure returns (bytes32) {
    return keccak256(abi.encodePacked(tokenA, tokenB, fee));
  }
}

