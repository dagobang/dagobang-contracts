// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IPancakeCLPool} from "../interfaces/IPancakeCLPool.sol";
import {ICLPoolManager} from "../interfaces/IPancakeCLPool.sol";
import {MockPancakeInfinityVault} from "./MockPancakeInfinityVault.sol";
import {BalanceDeltaLibrary} from "../swaplib/BalanceDelta.sol";
import {BalanceDelta} from "../swaplib/BalanceDelta.sol";

contract MockPancakeInfinityCLPoolManager is IPancakeCLPool {
  MockPancakeInfinityVault public immutable vault;

  constructor(address payable vault_) {
    vault = MockPancakeInfinityVault(vault_);
  }

  function swap(PoolKey memory key, ICLPoolManager.SwapParams memory params, bytes memory) external returns (int256 delta) {
    require(params.amountSpecified < 0, "ONLY_EXACT_IN");
    uint256 amountIn = uint256(-params.amountSpecified);
    uint256 amountOut = amountIn;

    address currencyIn = params.zeroForOne ? key.currency0 : key.currency1;
    address currencyOut = params.zeroForOne ? key.currency1 : key.currency0;

    vault.setDelta(msg.sender, currencyIn, -int256(amountIn));
    vault.setDelta(msg.sender, currencyOut, int256(amountOut));

    int128 a0 = params.zeroForOne ? -int128(int256(amountIn)) : int128(int256(amountOut));
    int128 a1 = params.zeroForOne ? int128(int256(amountOut)) : -int128(int256(amountIn));
    delta = BalanceDelta.unwrap(BalanceDeltaLibrary.from(a0, a1));
  }
}
