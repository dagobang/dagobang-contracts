// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IWNative} from "../interfaces/IWNative.sol";

interface IOpenFourCore {
    function buyByBudget(
        address token,
        uint256 maxQuotePayAmount,
        uint256 minAmountOut,
        uint256 options,
        bytes calldata proof
    ) external payable;

    function sell(address token, uint256 amount, uint256 minQuoteReceive, uint256 options, bytes calldata proof) external;
}

library OpenFourSwapLib {
    using SafeERC20 for IERC20;

    address internal constant DEFAULT_OPEN_FOUR_CORE = 0xebe7b6C1089D9F72aD07f34E36d898e44E5e27f3;
    uint256 internal constant SELL_OPTION_RECEIVE_WRAPPED_NATIVE = 1;

    function swap(
        address wNative,
        address coreOverride,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        bytes memory data,
        address payerOrigin
    ) external returns (uint256 amountOut) {
        require(data.length > 0, "OF_BAD_ARGS");
        (bool isBuy, uint256 minAmountOut, uint256 options, bytes memory proof) =
            abi.decode(data, (bool, uint256, uint256, bytes));
        address core = coreOverride == address(0) ? DEFAULT_OPEN_FOUR_CORE : coreOverride;

        if (isBuy) {
            require(tokenOut != address(0), "OF_BAD_OUT");
            if (tokenIn == address(0)) {
                _ensureNativeBalance(wNative, amountIn);
                uint256 beforeBal = IERC20(tokenOut).balanceOf(address(this));
                IOpenFourCore(core).buyByBudget{value: amountIn}(tokenOut, amountIn, minAmountOut, options, proof);
                amountOut = IERC20(tokenOut).balanceOf(address(this)) - beforeBal;
            } else {
                IERC20(tokenIn).forceApprove(core, amountIn);
                uint256 beforeBal = IERC20(tokenOut).balanceOf(address(this));
                IOpenFourCore(core).buyByBudget(tokenOut, amountIn, minAmountOut, options, proof);
                amountOut = IERC20(tokenOut).balanceOf(address(this)) - beforeBal;
            }
            _refundDust(tokenIn, payerOrigin);
            return amountOut;
        }

        require(tokenIn != address(0), "OF_BAD_IN");
        IERC20(tokenIn).forceApprove(core, amountIn);

        if (tokenOut == address(0)) {
            uint256 wrappedBefore = IERC20(wNative).balanceOf(address(this));
            uint256 nativeBefore = address(this).balance;
            IOpenFourCore(core).sell(
                tokenIn,
                amountIn,
                minAmountOut,
                options | SELL_OPTION_RECEIVE_WRAPPED_NATIVE,
                proof
            );
            uint256 nativeDelta = address(this).balance - nativeBefore;
            if (nativeDelta > 0) {
                IWNative(wNative).deposit{value: nativeDelta}();
            }
            amountOut = IERC20(wNative).balanceOf(address(this)) - wrappedBefore;
        } else {
            uint256 beforeBal = IERC20(tokenOut).balanceOf(address(this));
            IOpenFourCore(core).sell(tokenIn, amountIn, minAmountOut, options, proof);
            amountOut = IERC20(tokenOut).balanceOf(address(this)) - beforeBal;
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
                require(ok, "OF_REFUND_NATIVE");
            }
            return;
        }

        uint256 dust = IERC20(token).balanceOf(address(this));
        if (dust > 0) {
            IERC20(token).safeTransfer(payerOrigin, dust);
        }
    }
}
