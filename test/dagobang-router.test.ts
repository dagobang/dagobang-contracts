import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { network } from "hardhat";

describe("DagobangRouter", async () => {
  const { viem } = await network.connect();
  const [owner, user, feeCollector] = await viem.getWalletClients();
  const publicClient = await viem.getPublicClient();
  const ZERO = "0x0000000000000000000000000000000000000000";
  const ZERO32 = "0x0000000000000000000000000000000000000000000000000000000000000000";

  it("swap supports native -> token via V3 pool", async () => {
    const wNative = await viem.deployContract("MockWNative");
    const token = await viem.deployContract("MockERC20", ["Mock", "MOCK", 18]);
    const factory = await viem.deployContract("MockV3Factory");
    const pool = await viem.deployContract("MockV3Pool", [wNative.address, token.address]);

    await factory.write.setPool([wNative.address, token.address, 2500, pool.address]);

    await token.write.mint([pool.address, 1_000_000n * 10n ** 18n]);

    const router = await viem.deployContract("DagobangRouter");
    await router.write.initialize([owner.account.address, wNative.address, factory.address]);

    const amountIn = 1n * 10n ** 18n;
    const minOut = amountIn;
    const deadline = BigInt((await publicClient.getBlock()).timestamp + 60n);

    const userTokenBefore = await token.read.balanceOf([user.account.address]);

    const descs = [
      {
        swapType: 1,
        tokenIn: ZERO,
        tokenOut: token.address,
        poolAddress: pool.address,
        fee: 2500,
        tickSpacing: 0,
        hooks: ZERO,
        hookData: "0x",
        poolManager: ZERO,
        parameters: ZERO32,
        data: "0x",
      },
    ] as const;
    await router.write.swap([descs, ZERO, amountIn, minOut, deadline], { account: user.account, value: amountIn });

    const userTokenAfter = await token.read.balanceOf([user.account.address]);
    assert.equal(userTokenAfter - userTokenBefore, amountIn);
  });

  it("swap supports token -> native via V3 pool", async () => {
    const wNative = await viem.deployContract("MockWNative");
    const token = await viem.deployContract("MockERC20", ["Mock", "MOCK", 18]);
    const factory = await viem.deployContract("MockV3Factory");
    const pool = await viem.deployContract("MockV3Pool", [token.address, wNative.address]);

    await factory.write.setPool([token.address, wNative.address, 2500, pool.address]);

    await wNative.write.deposit({ value: 100n * 10n ** 18n });
    await wNative.write.transfer([pool.address, 100n * 10n ** 18n]);

    const router = await viem.deployContract("DagobangRouter");
    await router.write.initialize([owner.account.address, wNative.address, factory.address]);

    await token.write.mint([user.account.address, 2n * 10n ** 18n]);
    await token.write.approve([router.address, 2n * 10n ** 18n], { account: user.account });

    const deadline = BigInt((await publicClient.getBlock()).timestamp + 60n);
    const userNativeBefore = await publicClient.getBalance({ address: user.account.address });

    const amountIn = 2n * 10n ** 18n;
    const descs = [
      {
        swapType: 1,
        tokenIn: token.address,
        tokenOut: ZERO,
        poolAddress: pool.address,
        fee: 2500,
        tickSpacing: 0,
        hooks: ZERO,
        hookData: "0x",
        poolManager: ZERO,
        parameters: ZERO32,
        data: "0x",
      },
    ] as const;
    const hash = await router.write.swap([descs, ZERO, amountIn, 0n, deadline], { account: user.account });
    await publicClient.waitForTransactionReceipt({ hash });

    const userNativeAfter = await publicClient.getBalance({ address: user.account.address });
    assert.ok(userNativeAfter > userNativeBefore);
  });

  it("takes native fee when configured", async () => {
    const wNative = await viem.deployContract("MockWNative");
    const token = await viem.deployContract("MockERC20", ["Mock", "MOCK", 18]);
    const factory = await viem.deployContract("MockV3Factory");
    const pool = await viem.deployContract("MockV3Pool", [wNative.address, token.address]);

    await factory.write.setPool([wNative.address, token.address, 2500, pool.address]);
    await token.write.mint([pool.address, 1_000_000n * 10n ** 18n]);

    const router = await viem.deployContract("DagobangRouter");
    await router.write.initialize([owner.account.address, wNative.address, factory.address]);
    await router.write.setFeeCollector([feeCollector.account.address]);
    await router.write.setFeeBps([100]);

    const amountIn = 1n * 10n ** 18n;
    const deadline = BigInt((await publicClient.getBlock()).timestamp + 60n);

    const collectorBefore = await publicClient.getBalance({ address: feeCollector.account.address });

    const descs = [
      {
        swapType: 1,
        tokenIn: ZERO,
        tokenOut: token.address,
        poolAddress: pool.address,
        fee: 2500,
        tickSpacing: 0,
        hooks: ZERO,
        hookData: "0x",
        poolManager: ZERO,
        parameters: ZERO32,
        data: "0x",
      },
    ] as const;
    await router.write.swap([descs, ZERO, amountIn, (amountIn * 99n) / 100n, deadline], { account: user.account, value: amountIn });

    const collectorAfter = await publicClient.getBalance({ address: feeCollector.account.address });
    assert.equal(collectorAfter - collectorBefore, amountIn / 100n);
  });

  it("swap supports native -> middle -> tokenOut", async () => {
    const wNative = await viem.deployContract("MockWNative");
    const usd = await viem.deployContract("MockERC20", ["USD", "USD", 18]);
    const meme = await viem.deployContract("MockERC20", ["MEME", "MEME", 18]);
    const factory = await viem.deployContract("MockV3Factory");

    const pool1 = await viem.deployContract("MockV3Pool", [wNative.address, usd.address]);
    const pool2 = await viem.deployContract("MockV3Pool", [usd.address, meme.address]);

    await factory.write.setPool([wNative.address, usd.address, 500, pool1.address]);
    await factory.write.setPool([usd.address, meme.address, 2500, pool2.address]);

    await usd.write.mint([pool1.address, 1_000_000n * 10n ** 18n]);
    await meme.write.mint([pool2.address, 1_000_000n * 10n ** 18n]);

    const router = await viem.deployContract("DagobangRouter");
    await router.write.initialize([owner.account.address, wNative.address, factory.address]);

    const amountIn = 1n * 10n ** 18n;
    const deadline = BigInt((await publicClient.getBlock()).timestamp + 60n);

    const userBefore = await meme.read.balanceOf([user.account.address]);
    const descs = [
      {
        swapType: 1,
        tokenIn: ZERO,
        tokenOut: usd.address,
        poolAddress: pool1.address,
        fee: 500,
        tickSpacing: 0,
        hooks: ZERO,
        hookData: "0x",
        poolManager: ZERO,
        parameters: ZERO32,
        data: "0x",
      },
      {
        swapType: 1,
        tokenIn: usd.address,
        tokenOut: meme.address,
        poolAddress: pool2.address,
        fee: 2500,
        tickSpacing: 0,
        hooks: ZERO,
        hookData: "0x",
        poolManager: ZERO,
        parameters: ZERO32,
        data: "0x",
      },
    ] as const;
    await router.write.swap([descs, ZERO, amountIn, amountIn, deadline], { account: user.account, value: amountIn });
    const userAfter = await meme.read.balanceOf([user.account.address]);
    assert.equal(userAfter - userBefore, amountIn);
  });

  it("swap supports native -> token via V2 pair", async () => {
    const wNative = await viem.deployContract("MockWNative");
    const token = await viem.deployContract("MockERC20", ["Mock", "MOCK", 18]);

    const reserveNative = 1_000n * 10n ** 18n;
    const reserveToken = 1_000n * 10n ** 18n;

    await wNative.write.deposit({ value: reserveNative });
    const pair = await viem.deployContract("MockV2Pair", [wNative.address, token.address, reserveNative, reserveToken]);
    await wNative.write.transfer([pair.address, reserveNative]);
    await token.write.mint([pair.address, reserveToken]);

    const factory = await viem.deployContract("MockV3Factory");
    const router = await viem.deployContract("DagobangRouter");
    await router.write.initialize([owner.account.address, wNative.address, factory.address]);

    const amountIn = 1n * 10n ** 18n;
    const deadline = BigInt((await publicClient.getBlock()).timestamp + 60n);

    const userBefore = await token.read.balanceOf([user.account.address]);
    const descs = [
      {
        swapType: 0,
        tokenIn: ZERO,
        tokenOut: token.address,
        poolAddress: pair.address,
        fee: 25,
        tickSpacing: 0,
        hooks: ZERO,
        hookData: "0x",
        poolManager: ZERO,
        parameters: ZERO32,
        data: "0x",
      },
    ] as const;
    await router.write.swap([descs, ZERO, amountIn, 0n, deadline], { account: user.account, value: amountIn });
    const userAfter = await token.read.balanceOf([user.account.address]);

    assert.ok(userAfter > userBefore);
  });

  it("swap supports token -> token via V4 pool manager", async () => {
    const wNative = await viem.deployContract("MockWNative");
    const tokenIn = await viem.deployContract("MockERC20", ["In", "IN", 18]);
    const tokenOut = await viem.deployContract("MockERC20", ["Out", "OUT", 18]);
    const poolManager = await viem.deployContract("MockV4PoolManager");

    await tokenOut.write.mint([poolManager.address, 1_000_000n * 10n ** 18n]);

    const factory = await viem.deployContract("MockV3Factory");
    const router = await viem.deployContract("DagobangRouter");
    await router.write.initialize([owner.account.address, wNative.address, factory.address]);
    await router.write.setV4PoolManager([poolManager.address]);

    const amountIn = 2n * 10n ** 18n;
    await tokenIn.write.mint([user.account.address, amountIn]);
    await tokenIn.write.approve([router.address, amountIn], { account: user.account });

    const deadline = BigInt((await publicClient.getBlock()).timestamp + 60n);
    const before = await tokenOut.read.balanceOf([user.account.address]);

    const descs = [
      {
        swapType: 2,
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

  it("swap supports token -> token via Pancake Infinity CL", async () => {
    const wNative = await viem.deployContract("MockWNative");
    const tokenIn = await viem.deployContract("MockERC20", ["In", "IN", 18]);
    const tokenOut = await viem.deployContract("MockERC20", ["Out", "OUT", 18]);

    const vault = await viem.deployContract("MockPancakeInfinityVault");
    const clPm = await viem.deployContract("MockPancakeInfinityCLPoolManager", [vault.address]);
    const binPm = await viem.deployContract("MockPancakeInfinityBinPoolManager", [vault.address]);

    await tokenOut.write.mint([vault.address, 1_000_000n * 10n ** 18n]);

    const factory = await viem.deployContract("MockV3Factory");
    const router = await viem.deployContract("DagobangRouter");
    await router.write.initialize([owner.account.address, wNative.address, factory.address]);
    await router.write.setPancakeInfinityVault([vault.address]);
    await router.write.setPancakeInfinityClPoolManager([clPm.address]);
    await router.write.setPancakeInfinityBinPoolManager([binPm.address]);

    const amountIn = 3n * 10n ** 18n;
    await tokenIn.write.mint([user.account.address, amountIn]);
    await tokenIn.write.approve([router.address, amountIn], { account: user.account });

    const deadline = BigInt((await publicClient.getBlock()).timestamp + 60n);
    const before = await tokenOut.read.balanceOf([user.account.address]);

    const descs = [
      {
        swapType: 3,
        tokenIn: tokenIn.address,
        tokenOut: tokenOut.address,
        poolAddress: ZERO,
        fee: 2500,
        tickSpacing: 0,
        hooks: ZERO,
        hookData: "0x",
        poolManager: clPm.address,
        parameters: ZERO32,
        data: "0x",
      },
    ] as const;

    await router.write.swap([descs, ZERO, amountIn, 0n, deadline], { account: user.account });
    const after = await tokenOut.read.balanceOf([user.account.address]);

    assert.equal(after - before, amountIn);
  });

  it("swap supports native -> middle then buys from four.meme", async () => {
    const wNative = await viem.deployContract("MockWNative");
    const usd = await viem.deployContract("MockERC20", ["USD", "USD", 18]);
    const meme = await viem.deployContract("MockERC20", ["MEME", "MEME", 18]);
    const factory = await viem.deployContract("MockV3Factory");

    const pool = await viem.deployContract("MockV3Pool", [wNative.address, usd.address]);
    await factory.write.setPool([wNative.address, usd.address, 500, pool.address]);
    await usd.write.mint([pool.address, 1_000_000n * 10n ** 18n]);

    const tokenManager = await viem.deployContract("MockFourMemeTokenManager", [usd.address, 2n]);

    const router = await viem.deployContract("DagobangRouter");
    await router.write.initialize([owner.account.address, wNative.address, factory.address]);

    const amountIn = 1n * 10n ** 18n;
    const deadline = BigInt((await publicClient.getBlock()).timestamp + 60n);

    const userBefore = await meme.read.balanceOf([user.account.address]);
    const descs = [
      {
        swapType: 1,
        tokenIn: ZERO,
        tokenOut: usd.address,
        poolAddress: pool.address,
        fee: 500,
        tickSpacing: 0,
        hooks: ZERO,
        hookData: "0x",
        poolManager: ZERO,
        parameters: ZERO32,
        data: "0x",
      },
      {
        swapType: 5,
        tokenIn: usd.address,
        tokenOut: meme.address,
        poolAddress: tokenManager.address,
        fee: 0,
        tickSpacing: 0,
        hooks: ZERO,
        hookData: "0x",
        poolManager: ZERO,
        parameters: ZERO32,
        data: "0x",
      },
    ] as const;
    await router.write.swap([descs, ZERO, amountIn, amountIn * 2n, deadline], { account: user.account, value: amountIn });
    const userAfter = await meme.read.balanceOf([user.account.address]);

    assert.equal(userAfter - userBefore, amountIn * 2n);
  });

  it("swap supports tokenIn -> middle -> native", async () => {
    const wNative = await viem.deployContract("MockWNative");
    const usd = await viem.deployContract("MockERC20", ["USD", "USD", 18]);
    const meme = await viem.deployContract("MockERC20", ["MEME", "MEME", 18]);
    const factory = await viem.deployContract("MockV3Factory");

    const pool1 = await viem.deployContract("MockV3Pool", [meme.address, usd.address]);
    const pool2 = await viem.deployContract("MockV3Pool", [usd.address, wNative.address]);

    await factory.write.setPool([meme.address, usd.address, 500, pool1.address]);
    await factory.write.setPool([usd.address, wNative.address, 2500, pool2.address]);

    await usd.write.mint([pool1.address, 1_000_000n * 10n ** 18n]);

    await wNative.write.deposit({ value: 100n * 10n ** 18n });
    await wNative.write.transfer([pool2.address, 100n * 10n ** 18n]);

    const router = await viem.deployContract("DagobangRouter");
    await router.write.initialize([owner.account.address, wNative.address, factory.address]);

    await meme.write.mint([user.account.address, 2n * 10n ** 18n]);
    await meme.write.approve([router.address, 2n * 10n ** 18n], { account: user.account });

    const deadline = BigInt((await publicClient.getBlock()).timestamp + 60n);
    const userNativeBefore = await publicClient.getBalance({ address: user.account.address });

    const amountIn = 2n * 10n ** 18n;
    const descs = [
      {
        swapType: 1,
        tokenIn: meme.address,
        tokenOut: usd.address,
        poolAddress: pool1.address,
        fee: 500,
        tickSpacing: 0,
        hooks: ZERO,
        hookData: "0x",
        poolManager: ZERO,
        parameters: ZERO32,
        data: "0x",
      },
      {
        swapType: 1,
        tokenIn: usd.address,
        tokenOut: ZERO,
        poolAddress: pool2.address,
        fee: 2500,
        tickSpacing: 0,
        hooks: ZERO,
        hookData: "0x",
        poolManager: ZERO,
        parameters: ZERO32,
        data: "0x",
      },
    ] as const;
    const hash = await router.write.swap([descs, ZERO, amountIn, 0n, deadline], { account: user.account });
    await publicClient.waitForTransactionReceipt({ hash });

    const userNativeAfter = await publicClient.getBalance({ address: user.account.address });
    assert.ok(userNativeAfter > userNativeBefore);
  });
});
