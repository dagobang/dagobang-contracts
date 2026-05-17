// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IHyperZap} from "../interfaces/IHyperZap.sol";

library HyperZapSwapLib {
  using SafeERC20 for IERC20;

  function buy(address hyperZap, address usdc, address tokenOut, uint256 amountIn, bytes calldata data)
    internal
    returns (uint256 amountOut)
  {
    (uint256 minTokensOut, address referrer) = data.length == 0 ? (uint256(0), address(0)) : abi.decode(data, (uint256, address));

    IERC20(usdc).forceApprove(hyperZap, 0);
    IERC20(usdc).forceApprove(hyperZap, amountIn);
    amountOut = IHyperZap(hyperZap).buy(tokenOut, amountIn, minTokensOut, referrer);
    IERC20(usdc).forceApprove(hyperZap, 0);
  }

  function sell(address hyperZap, address tokenIn, uint256 amountIn, bytes calldata data)
    internal
    returns (uint256 amountOut)
  {
    uint256 minUsdcOut = data.length == 0 ? 0 : abi.decode(data, (uint256));

    IERC20(tokenIn).forceApprove(hyperZap, 0);
    IERC20(tokenIn).forceApprove(hyperZap, amountIn);
    amountOut = IHyperZap(hyperZap).sell(tokenIn, amountIn, minUsdcOut);
    IERC20(tokenIn).forceApprove(hyperZap, 0);
  }
}
