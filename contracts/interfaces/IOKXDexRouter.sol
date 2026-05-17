// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IOKXDexRouter {
  struct BaseRequest {
    uint256 fromToken;
    address toToken;
    uint256 fromTokenAmount;
    uint256 minReturnAmount;
    uint256 deadLine;
  }

  struct RouterPath {
    address[] mixAdapters;
    address[] assetTo;
    uint256[] rawData;
    bytes[] extraData;
    uint256 fromToken;
  }

  struct PMMSwapRequest {
    uint256 pathIndex;
    address payer;
    address fromToken;
    address toToken;
    uint256 fromTokenAmountMax;
    uint256 toTokenAmountMax;
    uint256 salt;
    uint256 deadLine;
    bool isPushOrder;
    bytes extension;
  }

  function uniswapV3SwapTo(uint256 receiver, uint256 amount, uint256 minReturn, uint256[] calldata pools)
    external
    payable
    returns (uint256 returnAmount);

  function smartSwapTo(
    uint256 orderId,
    address receiver,
    BaseRequest calldata baseRequest,
    uint256[] calldata batchesAmount,
    RouterPath[][] calldata batches,
    PMMSwapRequest[] calldata extraData
  ) external payable;

  function unxswapTo(uint256 srcToken, uint256 amount, uint256 minReturn, address receiver, bytes32[] calldata pools)
    external
    payable
    returns (uint256 returnAmount);

  function unxswapByOrderId(uint256 srcToken, uint256 amount, uint256 minReturn, bytes32[] calldata pools)
    external
    payable
    returns (uint256 returnAmount);

  function smartSwapByOrderId(
    uint256 orderId,
    BaseRequest calldata baseRequest,
    uint256[] calldata batchesAmount,
    RouterPath[][] calldata batches,
    PMMSwapRequest[] calldata extraData
  ) external payable returns (uint256 returnAmount);

  function dagSwapTo(uint256 orderId, address receiver, BaseRequest calldata baseRequest, RouterPath[] calldata paths)
    external
    payable
    returns (uint256 returnAmount);

  function dagSwapByOrderId(uint256 orderId, BaseRequest calldata baseRequest, RouterPath[] calldata paths)
    external
    payable
    returns (uint256 returnAmount);
}
