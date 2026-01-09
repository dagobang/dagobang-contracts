// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./FourERC20.sol";

contract MockBinanceLife is FourERC20, Ownable {
    uint public constant MODE_NORMAL = 0;
    uint public constant MODE_TRANSFER_RESTRICTED = 1;
    uint public constant MODE_TRANSFER_CONTROLLED = 2;
    uint public _mode;

    bool private _initialized;

    constructor(address initialOwner) Ownable(initialOwner) {}

    function init(
        string memory name,
        string memory symbol,
        uint256 totalSupply) public onlyOwner {
        require(!_initialized, "Token: initialized");
        _initialized = true;
        _init(name, symbol);
        _mint(owner(), totalSupply);
        _mode = MODE_NORMAL;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);
        if (_mode == MODE_TRANSFER_RESTRICTED) {
            revert("Token: Transfer is restricted");
        }
        if (_mode == MODE_TRANSFER_CONTROLLED) {
            require(from == owner() || to == owner(), "Token: Invalid transfer");
        }
    }

    function setMode(uint256 v) public onlyOwner {
        if (_mode != MODE_NORMAL) {
            _mode = v;
        }
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}