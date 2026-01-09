// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IPancakeInfinityVault} from "../interfaces/IPancakeInfinityVault.sol";

interface IInfinityLockAcquired {
  function lockAcquired(bytes calldata data) external returns (bytes memory);
}

contract MockPancakeInfinityVault is IPancakeInfinityVault {
  using SafeERC20 for IERC20;

  mapping(address => mapping(address => int256)) public deltas;

  receive() external payable {}

  function lock(bytes memory data) external returns (bytes memory result) {
    return IInfinityLockAcquired(msg.sender).lockAcquired(data);
  }

  function currencyDelta(address settler, address currency) external view returns (int256) {
    return deltas[settler][currency];
  }

  function sync(address) external {}

  function take(address currency, address to, uint256 amount) external {
    if (currency == address(0)) {
      (bool ok, ) = to.call{value: amount}("");
      require(ok, "TAKE_NATIVE_FAILED");
      return;
    }
    IERC20(currency).safeTransfer(to, amount);
  }

  function settle() external payable returns (uint256) {
    return msg.value;
  }

  function setDelta(address settler, address currency, int256 delta) external {
    deltas[settler][currency] = delta;
  }
}

