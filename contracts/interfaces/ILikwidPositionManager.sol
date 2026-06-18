// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface ILikwidPositionManager {
    struct SwapInputParams {
        bytes32 poolId;
        bool zeroForOne;
        address to;
        uint256 amountIn;
        uint256 amountOutMin;
        uint256 deadline;
    }

    function exactInput(SwapInputParams calldata params)
        external
        payable
        returns (uint24 swapFee, uint256 feeAmount, uint256 amountOut);
}
