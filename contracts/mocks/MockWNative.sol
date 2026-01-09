// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockWNative is ERC20 {
  constructor() ERC20("Wrapped Native", "WNATIVE") {}

  receive() external payable {}

  function deposit() external payable {
    _mint(msg.sender, msg.value);
  }

  function withdraw(uint256 wad) external {
    _burn(msg.sender, wad);
    (bool ok, ) = msg.sender.call{ value: wad }("");
    require(ok, "NATIVE_TRANSFER_FAILED");
  }
}

