// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IHyperBonding {
  function creatorOf(address token_) external view returns (address);
  function ltOf(address token_) external view returns (address);
  function isGraduating(address token_) external view returns (bool);
  function isGraduated(address token_) external view returns (bool);
  function graduatedPair(address token_) external view returns (address);
}
