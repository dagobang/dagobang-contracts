// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IMockOpenFourMintable is IERC20 {
    function mint(address to, uint256 amount) external;
}

contract MockOpenFourCore {
    using SafeERC20 for IERC20;

    uint256 public constant RATE = 2;

    receive() external payable {}

    function seed() external payable {}

    function buyByBudget(address token, uint256 maxQuotePayAmount, uint256 minAmountOut, uint256, bytes calldata)
        external
        payable
    {
        require(msg.value == maxQuotePayAmount, "INVALID_VALUE");
        uint256 amountOut = maxQuotePayAmount * RATE;
        require(amountOut >= minAmountOut, "MIN_OUT");
        IMockOpenFourMintable(token).mint(msg.sender, amountOut);
    }

    function sell(address token, uint256 amount, uint256 minQuoteReceive, uint256, bytes calldata) external {
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        uint256 nativeOut = amount / RATE;
        require(nativeOut >= minQuoteReceive, "MIN_OUT");
        (bool ok, ) = msg.sender.call{value: nativeOut}("");
        require(ok, "NATIVE_TRANSFER_FAILED");
    }
}
