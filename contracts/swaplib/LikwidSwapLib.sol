// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ILikwidPositionManager} from "../interfaces/ILikwidPositionManager.sol";
import {IWNative} from "../interfaces/IWNative.sol";

library LikwidSwapLib {
    using SafeERC20 for IERC20;

    address internal constant DEFAULT_LIKWID_POSITION_MANAGER = 0xB397FE16BE79B082f17F1CD96e6489df19E07BCD;

    function swap(
        address wNative,
        address positionManagerOverride,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint24 fee,
        int24 tickSpacing,
        address payerOrigin
    ) external returns (uint256 amountOut) {
        address positionManager =
            positionManagerOverride == address(0) ? DEFAULT_LIKWID_POSITION_MANAGER : positionManagerOverride;

        if (tokenIn == address(0)) {
            _ensureNativeBalance(wNative, amountIn);
        } else {
            IERC20(tokenIn).forceApprove(positionManager, amountIn);
        }

        address token0 = tokenIn < tokenOut ? tokenIn : tokenOut;
        address token1 = tokenIn < tokenOut ? tokenOut : tokenIn;
        bytes32 poolId = keccak256(abi.encode(token0, token1, fee, uint24(tickSpacing)));
        bool zeroForOne = tokenIn < tokenOut;

        uint256 nativeBefore = tokenOut == address(0) ? address(this).balance : 0;
        uint256 tokenBefore = tokenOut == address(0) ? 0 : IERC20(tokenOut).balanceOf(address(this));
        (, , amountOut) = ILikwidPositionManager(positionManager).exactInput{value: tokenIn == address(0) ? amountIn : 0}(
            ILikwidPositionManager.SwapInputParams({
                poolId: poolId,
                zeroForOne: zeroForOne,
                to: address(this),
                amountIn: amountIn,
                amountOutMin: 0,
                deadline: block.timestamp + 60
            })
        );

        if (tokenOut == address(0)) {
            uint256 nativeDelta = address(this).balance - nativeBefore;
            if (nativeDelta > 0) {
                IWNative(wNative).deposit{value: nativeDelta}();
            }
            amountOut = nativeDelta;
        } else if (amountOut == 0) {
            amountOut = IERC20(tokenOut).balanceOf(address(this)) - tokenBefore;
        }

        _refundDust(tokenIn, payerOrigin);
        return amountOut;
    }

    function _ensureNativeBalance(address wNative, uint256 need) private {
        uint256 nativeBal = address(this).balance;
        if (nativeBal >= need) return;
        IWNative(wNative).withdraw(need - nativeBal);
    }

    function _refundDust(address token, address payerOrigin) private {
        if (token == address(0)) {
            uint256 nativeDust = address(this).balance;
            if (nativeDust > 0) {
                (bool ok, ) = payerOrigin.call{value: nativeDust}("");
                require(ok, "LIKWID_REFUND_NATIVE");
            }
            return;
        }

        uint256 dust = IERC20(token).balanceOf(address(this));
        if (dust > 0) {
            IERC20(token).safeTransfer(payerOrigin, dust);
        }
    }
}
