// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../interfaces/IPancakeV3Router.sol";
import "../interfaces/IWNative.sol";

interface IMintableERC20 {
  function mint(address to, uint256 amount) external;
}

contract MockPancakeV2Router {
  using SafeERC20 for IERC20;

  address public immutable wNative;
  uint256 public immutable tokenPerNative;

  error InvalidPath();
  error Expired();
  error InsufficientAmountOut();

  constructor(address wNative_, uint256 tokenPerNative_) payable {
    wNative = wNative_;
    tokenPerNative = tokenPerNative_;
  }

  receive() external payable {}

  function swapExactETHForTokensSupportingFeeOnTransferTokens(
    uint256 amountOutMin,
    address[] calldata path,
    address to,
    uint256 deadline
  ) external payable {
    if (block.timestamp > deadline) revert Expired();
    if (path.length != 2 || path[0] != wNative) revert InvalidPath();
    address tokenOut = path[1];

    uint256 amountOut = msg.value * tokenPerNative;
    if (amountOut < amountOutMin) revert InsufficientAmountOut();
    IMintableERC20(tokenOut).mint(to, amountOut);
  }

  function swapExactTokensForETHSupportingFeeOnTransferTokens(
    uint256 amountIn,
    uint256 amountOutMin,
    address[] calldata path,
    address to,
    uint256 deadline
  ) external {
    if (block.timestamp > deadline) revert Expired();
    if (path.length != 2 || path[1] != wNative) revert InvalidPath();
    address tokenIn = path[0];

    IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);

    uint256 amountOut = amountIn / tokenPerNative;
    if (amountOut < amountOutMin) revert InsufficientAmountOut();
    (bool ok, ) = to.call{ value: amountOut }("");
    require(ok, "NATIVE_TRANSFER_FAILED");
  }

  function exactInputSingle(
    IPancakeV3Router.ExactInputSingleParams calldata params
  ) external payable returns (uint256 amountOut) {
    if (block.timestamp > params.deadline) revert Expired();

    if (params.tokenIn == wNative && params.tokenOut != address(0)) {
      IERC20(params.tokenIn).safeTransferFrom(msg.sender, address(this), params.amountIn);
      amountOut = params.amountIn * tokenPerNative;
      if (amountOut < params.amountOutMinimum) revert InsufficientAmountOut();
      IMintableERC20(params.tokenOut).mint(params.recipient, amountOut);
      return amountOut;
    }

    if (params.tokenOut == wNative && params.tokenIn != address(0)) {
      IERC20(params.tokenIn).safeTransferFrom(msg.sender, address(this), params.amountIn);
      amountOut = params.amountIn / tokenPerNative;
      if (amountOut < params.amountOutMinimum) revert InsufficientAmountOut();
      IWNative(wNative).deposit{ value: amountOut }();
      IERC20(wNative).safeTransfer(params.recipient, amountOut);
      return amountOut;
    }

    revert InvalidPath();
  }
}
