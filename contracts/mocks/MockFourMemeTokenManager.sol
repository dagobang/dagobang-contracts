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
    require(msg.value == 0, "NO_NATIVE");
    IERC20(middleToken).safeTransferFrom(msg.sender, address(this), amountIn);

    uint256 amountOut = amountIn * memePerMiddle;
    require(amountOut >= minOut, "INSUFFICIENT_OUT");
    IMintableERC20(memeToken).mint(recipient, amountOut);
  }

  function sell(address memeToken, address recipient, uint256 amountIn, uint256 minOut) external {
    IERC20(memeToken).safeTransferFrom(msg.sender, address(this), amountIn);

    uint256 amountOut = amountIn / memePerMiddle;
    require(amountOut >= minOut, "INSUFFICIENT_OUT");
    IMintableERC20(middleToken).mint(recipient, amountOut);
  }
}
