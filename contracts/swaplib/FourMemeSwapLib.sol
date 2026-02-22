// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IFourTokenManager} from "../interfaces/IFourTokenManager.sol";
import {IWNative} from "../interfaces/IWNative.sol";

library FourMemeSwapLib {
    using SafeERC20 for IERC20;

    // bytes4(keccak256("sellToken(uint256,address,address,uint256,uint256,uint256,address)"));
    bytes4 private constant SEL_V2_SELL_FROM = 0xe63aaf36;

    function _sell(address tokenManager, address tokenIn, uint256 amountIn, uint256 minFunds, address payerOrigin, bool isV2, address feeRecipient) internal returns (bool ok) {
        if (isV2) {
            (ok, ) = tokenManager.call(abi.encodeWithSelector(SEL_V2_SELL_FROM, uint256(0), tokenIn, payerOrigin, amountIn, minFunds, uint256(0), feeRecipient));
            return ok;
        }

        IERC20(tokenIn).forceApprove(tokenManager, amountIn);
        IFourTokenManager(tokenManager).saleToken(tokenIn, amountIn);
        return true;
    }

    function buy(address tokenManager, address tokenIn, address tokenOut, uint256 amountIn, bytes calldata data, address payerOrigin) internal returns (uint256 amountOut) {
        bool isAmap = data.length == 0 || data.length == 32;
        uint256 minOut = data.length == 32 ? abi.decode(data, (uint256)) : 0;
        uint256 tokenOutBeforeRouter = IERC20(tokenOut).balanceOf(address(this));
        uint256 tokenOutBeforeRecipient = IERC20(tokenOut).balanceOf(payerOrigin);

        if (tokenIn == address(0)) {
            (bool ok, bytes memory ret) = tokenManager.staticcall(abi.encodeWithSelector(IFourTokenManager._tokenInfos.selector, tokenOut));
            if (ok && ret.length > 0) {
                IFourTokenManager.TokenInfo memory info = abi.decode(ret, (IFourTokenManager.TokenInfo));
                if (info.template & 0x10000 > 0) {
                    // X-Mode
                    bytes memory args = abi.encode(uint256(0), tokenOut, payerOrigin, uint256(0), uint256(0), amountIn, minOut);
                    IFourTokenManager(tokenManager).buyToken{value: amountIn}(args, 0, bytes("0x"));
                } else {
                    IFourTokenManager(tokenManager).buyTokenAMAP{value: amountIn}(tokenOut, payerOrigin, amountIn, minOut);
                }
            } else {
                require(isAmap, "FVA");
                IFourTokenManager(tokenManager).purchaseTokenAMAP{value: amountIn}(0, tokenOut, address(this), (amountIn * 99) / 100, minOut);
            }
            if (address(this).balance > 0) {
                (bool refundOk, ) = payerOrigin.call{value: address(this).balance}("");
                require(refundOk, "FRN");
            }
        } else {
            require(isAmap, "FTA");
            uint256 balanceBefore = IERC20(tokenIn).balanceOf(address(this)) - amountIn;
            IERC20(tokenIn).forceApprove(tokenManager, amountIn);
            IFourTokenManager(tokenManager).buyTokenAMAP(tokenOut, payerOrigin, amountIn, minOut);

            uint256 balanceAfter = IERC20(tokenIn).balanceOf(address(this));
            uint256 refund = balanceAfter - balanceBefore;
            if (refund > 0) {
                IERC20(tokenIn).safeTransfer(payerOrigin, refund);
            }
        }

        uint256 tokenOutAfterRouter = IERC20(tokenOut).balanceOf(address(this));
        uint256 tokenOutAfterRecipient = IERC20(tokenOut).balanceOf(payerOrigin);
        uint256 deltaRouter = tokenOutAfterRouter - tokenOutBeforeRouter;
        uint256 deltaRecipient = tokenOutAfterRecipient - tokenOutBeforeRecipient;
        if (deltaRouter > 0) {
            IERC20(tokenOut).safeTransfer(payerOrigin, deltaRouter);
        }
        amountOut = deltaRouter + deltaRecipient;
    }

    function sellToNativeWrapped(
        address tokenManager,
        address wNative,
        address tokenIn,
        uint256 amountIn,
        uint256 minFunds,
        address payerOrigin,
        bool isV2
    ) internal returns (uint256 amountOutWNative) {
        uint256 nativeBefore = address(this).balance;
        bool ok = _sell(tokenManager, tokenIn, amountIn, minFunds, payerOrigin, isV2, address(this));
        require(ok, "FS2");
        uint256 nativeAfter = address(this).balance;

        uint256 nativeOut = nativeAfter - nativeBefore;
        IWNative(wNative).deposit{value: nativeOut}();
        amountOutWNative = nativeOut;
    }

    function sellToToken(
        address tokenManager,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minFunds,
        address payerOrigin,
        bool isV2
    ) internal returns (uint256 amountOut) {
        uint256 beforeRecipient = IERC20(tokenOut).balanceOf(payerOrigin);

        bool ok = _sell(tokenManager, tokenIn, amountIn, minFunds, payerOrigin, isV2, address(this));
        require(ok, "FS2");

        uint256 afterRecipient = IERC20(tokenOut).balanceOf(payerOrigin);
        amountOut = afterRecipient - beforeRecipient;
    }
}
