// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IOKXDexRouter} from "../interfaces/IOKXDexRouter.sol";
import {IWNative} from "../interfaces/IWNative.sol";

library OkxSwapLib {
  using SafeERC20 for IERC20;

  function swap(address wNative, address okxRouter, address tokenIn, address tokenOut, uint256 amountIn, bytes calldata hookData, address recipient)
    internal
    returns (uint256 amountOut)
  {
    require(okxRouter != address(0), "OKX_ADDR_0");
    require(amountIn > 0, "ZI");

    if (tokenIn == address(0)) {
      _ensureNativeBalance(wNative, amountIn);
      uint256 nativeBefore = address(this).balance - amountIn;
      uint256 tokenBefore = tokenOut == address(0) ? 0 : IERC20(tokenOut).balanceOf(address(this));
      bytes memory scaledCallData = _okxScaling(hookData, amountIn, recipient);
      (bool success,) = okxRouter.call{value: amountIn}(scaledCallData);
      require(success, "OKX_SWAP_FAIL");
      amountOut = _captureOutput(wNative, tokenOut, recipient, nativeBefore, tokenBefore);
      return amountOut;
    }

    uint256 tokenInBefore = IERC20(tokenIn).balanceOf(address(this));
    require(tokenInBefore >= amountIn, "INSUFFICIENT_TOKEN_IN");
    IERC20(tokenIn).forceApprove(_getTokenApproveForChain(block.chainid), amountIn);

    uint256 nativeBefore2 = address(this).balance;
    uint256 tokenBefore2 = tokenOut == address(0) ? 0 : IERC20(tokenOut).balanceOf(address(this));
    bytes memory scaledCallData2 = _okxScaling(hookData, amountIn, recipient);
    (bool success2,) = okxRouter.call(scaledCallData2);
    require(success2, "OKX_SWAP_FAIL");
    amountOut = _captureOutput(wNative, tokenOut, recipient, nativeBefore2, tokenBefore2);
  }

  function _captureOutput(
    address wNative,
    address tokenOut,
    address recipient,
    uint256 nativeBefore,
    uint256 tokenBefore
  ) private returns (uint256 amountOut) {
    if (tokenOut == address(0)) {
      uint256 nativeAfter = address(this).balance;
      amountOut = nativeAfter - nativeBefore;
      if (amountOut > 0) {
        IWNative(wNative).deposit{value: amountOut}();
        IERC20(wNative).safeTransfer(recipient, amountOut);
      }
      return amountOut;
    }

    uint256 tokenAfter = IERC20(tokenOut).balanceOf(address(this));
    amountOut = tokenAfter - tokenBefore;
    if (amountOut > 0) {
      IERC20(tokenOut).safeTransfer(recipient, amountOut);
    }
  }

  function _okxScaling(bytes calldata rawCallData, uint256 actualAmount, address receiverToReplace)
    private
    pure
    returns (bytes memory scaledCallData)
  {
    bytes4 selector = bytes4(rawCallData[:4]);
    bytes calldata dataToDecode = rawCallData[4:];

    if (selector == IOKXDexRouter.uniswapV3SwapTo.selector) {
      (uint256 receiver, uint256 amount, uint256 minReturn, uint256[] memory pools) =
        abi.decode(dataToDecode, (uint256, uint256, uint256, uint256[]));
      receiver = uint256(uint160(receiverToReplace));
      minReturn = (minReturn * actualAmount) / amount;
      amount = actualAmount;
      scaledCallData = abi.encodeWithSelector(selector, receiver, amount, minReturn, pools);
    } else if (selector == IOKXDexRouter.smartSwapTo.selector) {
      (
        uint256 orderId,
        address receiver,
        IOKXDexRouter.BaseRequest memory baseRequest,
        uint256[] memory batchesAmount,
        IOKXDexRouter.RouterPath[][] memory batches,
        IOKXDexRouter.PMMSwapRequest[] memory extraData
      ) = abi.decode(
        dataToDecode,
        (uint256, address, IOKXDexRouter.BaseRequest, uint256[], IOKXDexRouter.RouterPath[][], IOKXDexRouter.PMMSwapRequest[])
      );
      receiver = receiverToReplace;
      batchesAmount = _scaleArray(batchesAmount, actualAmount, baseRequest.fromTokenAmount);
      baseRequest.minReturnAmount = (baseRequest.minReturnAmount * actualAmount) / baseRequest.fromTokenAmount;
      baseRequest.fromTokenAmount = actualAmount;
      scaledCallData = abi.encodeWithSelector(selector, orderId, receiver, baseRequest, batchesAmount, batches, extraData);
    } else if (selector == IOKXDexRouter.unxswapTo.selector) {
      (uint256 srcToken, uint256 amount, uint256 minReturn, address receiver, bytes32[] memory pools) =
        abi.decode(dataToDecode, (uint256, uint256, uint256, address, bytes32[]));
      receiver = receiverToReplace;
      minReturn = (minReturn * actualAmount) / amount;
      amount = actualAmount;
      scaledCallData = abi.encodeWithSelector(selector, srcToken, amount, minReturn, receiver, pools);
    } else if (selector == IOKXDexRouter.unxswapByOrderId.selector) {
      (uint256 srcToken, uint256 amount, uint256 minReturn, bytes32[] memory pools) =
        abi.decode(dataToDecode, (uint256, uint256, uint256, bytes32[]));
      minReturn = (minReturn * actualAmount) / amount;
      amount = actualAmount;
      scaledCallData = abi.encodeWithSelector(selector, srcToken, amount, minReturn, pools);
    } else if (selector == IOKXDexRouter.smartSwapByOrderId.selector) {
      (
        uint256 orderId,
        IOKXDexRouter.BaseRequest memory baseRequest,
        uint256[] memory batchesAmount,
        IOKXDexRouter.RouterPath[][] memory batches,
        IOKXDexRouter.PMMSwapRequest[] memory extraData
      ) = abi.decode(
        dataToDecode,
        (uint256, IOKXDexRouter.BaseRequest, uint256[], IOKXDexRouter.RouterPath[][], IOKXDexRouter.PMMSwapRequest[])
      );
      batchesAmount = _scaleArray(batchesAmount, actualAmount, baseRequest.fromTokenAmount);
      baseRequest.minReturnAmount = (baseRequest.minReturnAmount * actualAmount) / baseRequest.fromTokenAmount;
      baseRequest.fromTokenAmount = actualAmount;
      scaledCallData = abi.encodeWithSelector(selector, orderId, baseRequest, batchesAmount, batches, extraData);
    } else if (selector == IOKXDexRouter.dagSwapTo.selector) {
      (uint256 orderId, address receiver, IOKXDexRouter.BaseRequest memory baseRequest, IOKXDexRouter.RouterPath[] memory paths) =
        abi.decode(dataToDecode, (uint256, address, IOKXDexRouter.BaseRequest, IOKXDexRouter.RouterPath[]));
      receiver = receiverToReplace;
      baseRequest.minReturnAmount = (baseRequest.minReturnAmount * actualAmount) / baseRequest.fromTokenAmount;
      baseRequest.fromTokenAmount = actualAmount;
      scaledCallData = abi.encodeWithSelector(selector, orderId, receiver, baseRequest, paths);
    } else if (selector == IOKXDexRouter.dagSwapByOrderId.selector) {
      (uint256 orderId, IOKXDexRouter.BaseRequest memory baseRequest, IOKXDexRouter.RouterPath[] memory paths) =
        abi.decode(dataToDecode, (uint256, IOKXDexRouter.BaseRequest, IOKXDexRouter.RouterPath[]));
      baseRequest.minReturnAmount = (baseRequest.minReturnAmount * actualAmount) / baseRequest.fromTokenAmount;
      baseRequest.fromTokenAmount = actualAmount;
      scaledCallData = abi.encodeWithSelector(selector, orderId, baseRequest, paths);
    } else {
      revert("OKX_SELECTOR_UNSUPPORTED");
    }

    bytes memory tail = rawCallData[scaledCallData.length:];
    scaledCallData = bytes.concat(scaledCallData, tail);
  }

  function _scaleArray(uint256[] memory arr, uint256 newAmount, uint256 oldAmount) private pure returns (uint256[] memory out) {
    out = new uint256[](arr.length);
    for (uint256 i = 0; i < arr.length; i++) {
      out[i] = (arr[i] * newAmount) / oldAmount;
    }
  }

  function _getTokenApproveForChain(uint256 chainid) private pure returns (address) {
    if (chainid == 1) return 0x40aA958dd87FC8305b97f2BA922CDdCa374bcD7f;
    if (chainid == 10) return 0x68D6B739D2020067D1e2F713b999dA97E4d54812;
    if (chainid == 56) return 0x2c34A2Fb1d0b4f55de51E1d0bDEfaDDce6b7cDD6;
    if (chainid == 42_161) return 0x70cBb871E8f30Fc8Ce23609E9E0Ea87B6b222F58;
    if (chainid == 8453 || chainid == 5000) return 0x57df6092665eb6058DE53939612413ff4B09114E;
    if (chainid == 146) return 0xD321ab5589d3E8FA5Df985ccFEf625022E2DD910;
    if (chainid == 9745) return 0x9FD43F5E4c24543b2eBC807321E58e6D350d6a5A;
    revert("OKX_TOKEN_APPROVE_UNKNOWN");
  }

  function _ensureNativeBalance(address wNative, uint256 need) private {
    uint256 nativeBal = address(this).balance;
    if (nativeBal >= need) return;
    IWNative(wNative).withdraw(need - nativeBal);
  }
}
