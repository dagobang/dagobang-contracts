import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { network } from "hardhat";

describe("DagobangRouterEth", async () => {
  const { viem } = await network.connect();
  const [owner, user] = await viem.getWalletClients();
  const publicClient = await viem.getPublicClient();
  const ZERO = "0x0000000000000000000000000000000000000000";
  const ZERO32 = "0x0000000000000000000000000000000000000000000000000000000000000000";

  it("supports native -> token via PRINTR_EXACT_IN", async () => {
    const wNative = await viem.deployContract("MockWNative");
    const factory = await viem.deployContract("MockV3Factory");
    const tokenOut = await viem.deployContract("MockERC20", ["PT", "PT", 18]);
    const printr = await viem.deployContract("MockPrintrTrading");

    const router = await viem.deployContract("DagobangRouterEth");
    await router.write.initialize([owner.account.address, wNative.address, factory.address]);

    const amountIn = 1n * 10n ** 18n;
    const minOut = 2n * 10n ** 18n;
    const deadline = 0n;

    const before = await tokenOut.read.balanceOf([user.account.address]);
    const descs = [
      {
        swapType: 6, // PRINTR_EXACT_IN
        tokenIn: ZERO,
        tokenOut: tokenOut.address,
        poolAddress: printr.address,
        fee: 0,
        tickSpacing: 0,
        hooks: ZERO,
        hookData: "0x",
        poolManager: ZERO,
        parameters: ZERO32,
        data: "0x",
      },
    ] as const;

    await router.write.swap([descs, ZERO, amountIn, minOut, deadline], { account: user.account, value: amountIn });
    const after = await tokenOut.read.balanceOf([user.account.address]);

    assert.equal(after - before, minOut);
  });

  it("supports token -> native via PRINTR_EXACT_IN", async () => {
    const wNative = await viem.deployContract("MockWNative");
    const factory = await viem.deployContract("MockV3Factory");
    const tokenIn = await viem.deployContract("MockERC20", ["PT", "PT", 18]);
    const printr = await viem.deployContract("MockPrintrTrading");
    await printr.write.seed({ value: 10n * 10n ** 18n });

    const router = await viem.deployContract("DagobangRouterEth");
    await router.write.initialize([owner.account.address, wNative.address, factory.address]);

    const amountIn = 2n * 10n ** 18n;
    await tokenIn.write.mint([user.account.address, amountIn]);
    await tokenIn.write.approve([router.address, amountIn], { account: user.account });

    const deadline = BigInt((await publicClient.getBlock()).timestamp + 60n);
    const nativeBefore = await publicClient.getBalance({ address: user.account.address });

    const descs = [
      {
        swapType: 6, // PRINTR_EXACT_IN
        tokenIn: tokenIn.address,
        tokenOut: ZERO,
        poolAddress: printr.address,
        fee: 0,
        tickSpacing: 0,
        hooks: ZERO,
        hookData: "0x",
        poolManager: ZERO,
        parameters: ZERO32,
        data: "0x",
      },
    ] as const;

    const hash = await router.write.swap([descs, ZERO, amountIn, amountIn / 2n, deadline], { account: user.account });
    await publicClient.waitForTransactionReceipt({ hash });
    const nativeAfter = await publicClient.getBalance({ address: user.account.address });

    assert.ok(nativeAfter > nativeBefore);
  });

  it("supports token -> token via V4_EXACT_IN", async () => {
    const wNative = await viem.deployContract("MockWNative");
    const factory = await viem.deployContract("MockV3Factory");
    const tokenIn = await viem.deployContract("MockERC20", ["IN", "IN", 18]);
    const tokenOut = await viem.deployContract("MockERC20", ["OUT", "OUT", 18]);
    const v4PoolManager = await viem.deployContract("MockV4PoolManager");
    await tokenOut.write.mint([v4PoolManager.address, 1_000_000n * 10n ** 18n]);

    const router = await viem.deployContract("DagobangRouterEth");
    await router.write.initialize([owner.account.address, wNative.address, factory.address]);
    await (router.write as any).setV4PoolManager([v4PoolManager.address]);

    const amountIn = 2n * 10n ** 18n;
    await tokenIn.write.mint([user.account.address, amountIn]);
    await tokenIn.write.approve([router.address, amountIn], { account: user.account });
    const deadline = BigInt((await publicClient.getBlock()).timestamp + 60n);

    const before = await tokenOut.read.balanceOf([user.account.address]);
    const descs = [
      {
        swapType: 2, // V4_EXACT_IN
        tokenIn: tokenIn.address,
        tokenOut: tokenOut.address,
        poolAddress: ZERO,
        fee: 3000,
        tickSpacing: 60,
        hooks: ZERO,
        hookData: "0x",
        poolManager: ZERO,
        parameters: ZERO32,
        data: "0x",
      },
    ] as const;

    await router.write.swap([descs, ZERO, amountIn, 0n, deadline], { account: user.account });
    const after = await tokenOut.read.balanceOf([user.account.address]);
    assert.equal(after - before, amountIn);
  });
});
