// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IMintableERC20 {
  function mint(address to, uint256 amount) external;
}

contract MockFourMemeTokenManager {
  using SafeERC20 for IERC20;

  address public immutable middleToken;
  uint256 public immutable memePerMiddle;

  constructor(address middleToken_, uint256 memePerMiddle_) {
    middleToken = middleToken_;
    memePerMiddle = memePerMiddle_;
  }

  function buyTokenAMAP(address memeToken, address recipient, uint256 amountIn, uint256 minOut) external payable {
    if (msg.value > 0) {
      require(msg.value == amountIn, "VALUE_MISMATCH");
    } else {
      IERC20(middleToken).safeTransferFrom(msg.sender, address(this), amountIn);
    }

    uint256 amountOut = amountIn * memePerMiddle;
    require(amountOut >= minOut, "INSUFFICIENT_OUT");
    IMintableERC20(memeToken).mint(recipient, amountOut);
  }

  function buyToken(bytes memory args, uint256, bytes memory) external payable {
    (uint256 origin, address token, address to, uint256 amount, uint256 maxFunds, uint256 funds, uint256 minAmount) =
      abi.decode(args, (uint256, address, address, uint256, uint256, uint256, uint256));
    require(origin == 0, "BAD_ORIGIN");
    require(token != address(0) && to != address(0), "BAD_ARGS");

    if (funds > 0) {
      require(amount == 0 && maxFunds == 0, "BAD_ARGS");
      require(msg.value == funds, "VALUE_MISMATCH");
      uint256 amountOut = funds * memePerMiddle;
      require(amountOut >= minAmount, "INSUFFICIENT_OUT");
      IMintableERC20(token).mint(to, amountOut);
      return;
    }

    require(amount > 0 && maxFunds > 0, "BAD_ARGS");
    uint256 cost = (amount + memePerMiddle - 1) / memePerMiddle;
    require(cost <= maxFunds, "MAX_FUNDS");
    require(msg.value >= cost, "VALUE_MISMATCH");
    require(amount >= minAmount, "INSUFFICIENT_OUT");
    IMintableERC20(token).mint(to, amount);

    uint256 refund = msg.value - cost;
    if (refund > 0) {
      (bool ok, ) = msg.sender.call{value: refund}("");
      require(ok, "REFUND_FAILED");
    }
  }

  function sell(address memeToken, address recipient, uint256 amountIn, uint256 minOut) external {
    IERC20(memeToken).safeTransferFrom(msg.sender, address(this), amountIn);

    uint256 amountOut = amountIn / memePerMiddle;
    require(amountOut >= minOut, "INSUFFICIENT_OUT");
    IMintableERC20(middleToken).mint(recipient, amountOut);
  }
}
