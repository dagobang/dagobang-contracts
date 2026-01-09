// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";

contract DagobangProxy is ERC1967Proxy {
  error ProxyDeniedAdminAccess();
  error NotAdmin();

  receive() external payable {}

  constructor(address implementation_, address admin_, bytes memory data)
    payable
    ERC1967Proxy(implementation_, data)
  {
    ERC1967Utils.changeAdmin(admin_);
  }

  function admin() external view returns (address) {
    return ERC1967Utils.getAdmin();
  }

  function implementation() external view returns (address) {
    return ERC1967Utils.getImplementation();
  }

  function upgradeToAndCall(address newImplementation, bytes calldata data) external payable {
    if (msg.sender != ERC1967Utils.getAdmin()) revert NotAdmin();
    ERC1967Utils.upgradeToAndCall(newImplementation, data);
  }

  function changeAdmin(address newAdmin) external {
    if (msg.sender != ERC1967Utils.getAdmin()) revert NotAdmin();
    ERC1967Utils.changeAdmin(newAdmin);
  }

  function _fallback() internal virtual override {
    if (msg.sender == ERC1967Utils.getAdmin()) revert ProxyDeniedAdminAccess();
    super._fallback();
  }
}
