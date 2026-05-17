// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IMintableERC20 is IERC20 {
  function mint(address to, uint256 amount) external;
}

contract MockPrintrTrading {
  using SafeERC20 for IERC20;

  uint256 public constant RATE = 2;

  receive() external payable {}

  function seed() external payable {}

  function spend(address token, address recipient, uint256 baseAmount, uint256) external payable returns (bytes memory) {
    require(msg.value == baseAmount, "INVALID_VALUE");
    IMintableERC20(token).mint(recipient, baseAmount * RATE);
    return "";
  }

  function sell(address token, address recipient, uint256 amount, uint256) external returns (bytes memory) {
    IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
    uint256 ethOut = amount / RATE;
    (bool ok,) = recipient.call{value: ethOut}("");
    require(ok, "NATIVE_TRANSFER_FAILED");
    return "";
  }
}
