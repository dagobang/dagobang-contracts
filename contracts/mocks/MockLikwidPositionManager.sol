// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MockLikwidPositionManager {
    using SafeERC20 for IERC20;

    address public immutable tokenIn;

    struct SwapInputParams {
        bytes32 poolId;
        bool zeroForOne;
        address to;
        uint256 amountIn;
        uint256 amountOutMin;
        uint256 deadline;
    }

    constructor(address tokenIn_) {
        tokenIn = tokenIn_;
    }

    receive() external payable {}

    function seed() external payable {}

    function exactInput(SwapInputParams calldata params)
        external
        payable
        returns (uint24 swapFee, uint256 feeAmount, uint256 amountOut)
    {
        if (msg.value == 0 && tokenIn != address(0)) {
            IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), params.amountIn);
        }

        amountOut = params.amountIn;
        require(amountOut >= params.amountOutMin, "MIN_OUT");
        (bool ok, ) = params.to.call{value: amountOut}("");
        require(ok, "NATIVE_TRANSFER_FAILED");
        return (0, 0, amountOut);
    }
}
