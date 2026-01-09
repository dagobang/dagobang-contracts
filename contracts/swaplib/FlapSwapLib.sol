// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IFlapTokenManager} from "../interfaces/IFlapTokenManager.sol";
import {IWNative} from "../interfaces/IWNative.sol";

library FlapSwapLib {
  using SafeERC20 for IERC20;

  function exactInput(
    address manager,
    address wNative,
    address tokenIn,
    address tokenOut,
    uint256 amountIn,
    uint256 minOut
  ) internal returns (uint256 amountOutWrappedNative) {
    if (tokenIn == address(0)) {
      uint256 outBeforeInNative = IERC20(tokenOut).balanceOf(address(this));
      IFlapTokenManager.ExactInputParams memory paramsInNative = IFlapTokenManager.ExactInputParams({
        inputToken: address(0),
        outputToken: tokenOut,
        inputAmount: amountIn,
        minOutputAmount: minOut,
        permitData: bytes("")
      });
      IFlapTokenManager(manager).swapExactInput{value: amountIn}(paramsInNative);
      uint256 outAfterInNative = IERC20(tokenOut).balanceOf(address(this));
      return outAfterInNative - outBeforeInNative;
    }

    if (tokenOut == address(0)) {
      IERC20(tokenIn).forceApprove(manager, amountIn);
      uint256 nativeBefore = address(this).balance;
      IFlapTokenManager.ExactInputParams memory paramsToNative = IFlapTokenManager.ExactInputParams({
        inputToken: tokenIn,
        outputToken: address(0),
        inputAmount: amountIn,
        minOutputAmount: minOut,
        permitData: bytes("")
      });
      IFlapTokenManager(manager).swapExactInput(paramsToNative);
      uint256 nativeAfter = address(this).balance;
      uint256 nativeOut = nativeAfter - nativeBefore;
      IWNative(wNative).deposit{value: nativeOut}();
      return nativeOut;
    }

    IERC20(tokenIn).forceApprove(manager, amountIn);
    uint256 outBeforeTokenToToken = IERC20(tokenOut).balanceOf(address(this));
    IFlapTokenManager.ExactInputParams memory paramsTokenToToken = IFlapTokenManager.ExactInputParams({
      inputToken: tokenIn,
      outputToken: tokenOut,
      inputAmount: amountIn,
      minOutputAmount: minOut,
      permitData: bytes("")
    });
    IFlapTokenManager(manager).swapExactInput(paramsTokenToToken);
    uint256 outAfterTokenToToken = IERC20(tokenOut).balanceOf(address(this));
    return outAfterTokenToToken - outBeforeTokenToToken;
  }
}
