# dagobang-contracts

本仓库提供 Dagobang 的链上统一交易入口合约（Router），供浏览器插件直接调用完成买卖。

## 合约入口

- [contracts/DagobangRouter.sol](file:///home/catgroup/projects/remote/meme/dagobang/dagobang-contracts/contracts/DagobangRouter.sol)
- 可升级代理： [contracts/proxy/DagobangProxy.sol](file:///home/catgroup/projects/remote/meme/dagobang/dagobang-contracts/contracts/proxy/DagobangProxy.sol)

## 统一入口：swap()

DagobangRouter 使用 `swap(SwapDesc[] descs, address feeToken, uint256 amountIn, uint256 minReturn, uint256 deadline)` 作为统一入口：
- `descs`：一组“逐跳描述”，会按顺序执行；上一跳输出会作为下一跳输入
- `tokenIn = address(0)` / `tokenOut = address(0)`：表示原生币（BSC 上为 BNB）
- `feeToken`：当前仅支持 `address(0)`（否则会回滚）

### SwapType（数值枚举）

与链上枚举顺序一致：
- `0`：V2_EXACT_IN
- `1`：V3_EXACT_IN
- `2`：V4_EXACT_IN
- `3`：PANCAKE_INFINITY_EXACT_IN
- `4`：LUNA_LAUNCHPAD_V2
- `5`：FOUR_MEME_BUY_AMAP
- `6`：FOUR_MEME_SELL
- `7`：FLAP_EXACT_INPUT

### SwapDesc 字段说明

每一跳都使用同一个结构体（不用的字段填 0 即可）：
- `swapType`：上面的枚举值
- `tokenIn` / `tokenOut`：本跳输入/输出 token（原生币用 `address(0)`）
- `poolAddress`：
  - V2：pair 地址
  - V3：pool override（可填 0，内部会用 factory 取 pool）
  - FourMeme / Flap：对应的 tokenManager/manager 地址
  - V4 / Infinity：当前不使用（填 0）
- `fee`：
  - V3：池费率（500/2500/10000 等）
  - V2：手续费 bps（不填默认按 25 处理；即 0.25%）
  - V4 / Infinity：传入对应 PoolKey 的 fee 字段（取决于目标协议）
- `tickSpacing` / `hooks` / `hookData`：V4/Infinity 的 pool 参数（不使用时填 0）
- `poolManager` / `parameters`：仅 Infinity 使用（不使用时填 0）
- `data`：扩展字段
  - FourMeme BUY：可传 `abi.encode(minOut)`，不传则按 0
  - FourMeme SELL：可传 `abi.encode(minFunds)`，不传则按 0
  - Flap：可传 `abi.encode(minOut)`，不传则按 0

## 参数与风控要点

### minOut / deadline
- `minOut`：建议由插件用 Quoter/链下报价计算并按滑点 bps 得到（例如 `minOut = quoteOut * (1 - slippage)`）
- `deadline`：建议是 `block.timestamp + 600`（10 分钟）或更短

### amountIn / msg.value
- 当 `descs[0].tokenIn == address(0)`：`msg.value` 必须 `>= amountIn`，建议严格等于 `amountIn`（多余的 value 不会自动退回）
- 当 `descs[0].tokenIn != address(0)`：`msg.value` 必须为 0，且需要先对 Router `approve(tokenIn, amountIn)`

### 平台费（可选）

- `setFeeCollector(address)`：设置收款地址（不设则无法开启费率）
- `setFeeBps(uint16)`：设置费率（bps），例如 100 = 1%
- `setFeeExempt(address,bool)`：将特定调用方/账户加入免手续费列表

计费方式：
- 仅对“原生币（BNB）”收取：买入从 `msg.value` 扣费；卖出从最终 BNB 到手扣费

### 暂停开关
- `pause()` / `unpause()`：owner 可暂停交易入口（紧急开关）

### 兼容性注意事项
- Router 的 swap 输出默认发给 `msg.sender`（没有 `to` 参数）；插件/聚合器如果需要代付/代收，需要在上层自行处理
- V4/Infinity 依赖回调（`unlockCallback`/`lockAcquired`），并且会校验调用方必须是已配置的 poolManager/vault
- Infinity 的 vault 通常还要求 router 在 vault 上完成 app 注册（`registerApp(router)`），否则 `lock()` 可能直接回滚

### FourMeme 特别说明
- 买入：
  - `swapType = FOUR_MEME_BUY_AMAP`
  - `poolAddress = FourTokenManager`
  - 原生买入：`tokenIn = 0`，`amountIn = msg.value`
    - `data = ""` 或 `abi.encode(minOut)` 视为 AMAP
    - 对于支持精确买入（带签名）的合约，可以将 `data` 设为 `abi.encode(args, time, signature)`，由 FourMeme 合约内部验证
  - ERC20 买入（稳定币等）：`tokenIn = stableToken`
    - 目前仅支持 AMAP 模式（`data=""` 或 `abi.encode(minOut)`），并且需要对 Router 先 `approve`
- 卖出：
  - `swapType = FOUR_MEME_SELL`，`tokenIn = FourMemeToken`，`tokenOut` 建议为 `0`（原生）
  - FourMeme 卖出必须出现在 descs[0]（第一跳），否则会回滚
  - 对于新版本合约，Router 会直接调用 `sellToken(origin, token, from, amount, minFunds, feeRate, feeRecipient)`，需要对 TokenManager 做 `approve`
  - 对于老版本（仅支持 `saleToken`）的合约，Router 会按 V1 方式先收 token 再卖出

## 额外配置（V4 / Pancake Infinity / Luna）

- V4：
  - `setV4PoolManager(address)`
  - `swapType = V4_EXACT_IN` 时会触发 poolManager 的 `unlock()`，并回调 Router 的 `unlockCallback()`
- Pancake Infinity：
  - `setPancakeInfinityVault(address)`
  - `setPancakeInfinityClPoolManager(address)`
  - `setPancakeInfinityBinPoolManager(address)`
  - `swapType = PANCAKE_INFINITY_EXACT_IN` 时会触发 vault 的 `lock()`，并回调 Router 的 `lockAcquired()`
  - 注意：生产网通常还需要 vault owner/权限方对 Router 执行 `registerApp(router)`，否则可能无法 `lock()`
- Luna：
  - `setLunaLaunchpad(address)`、`setLunaRouter(address)`
  - `swapType = LUNA_LAUNCHPAD_V2`：当 `tokenIn==0` 走 buy；当 `tokenOut==0` 走 sell

## 部署与配置

### 必要配置
- `initialize(owner, wNative, v3Factory)`
  - BSC 主网：
    - `wNative = WBNB`（0xbb4C…）
    - `v3Factory = Pancake V3 Factory`（0x0BFb…）

### Ignition（推荐）

本仓库使用 Hardhat Ignition 支持“首次部署”和“合约更新（升级）部署”两种流程。

模块：
- 首次部署（实现合约 + 代理 + initialize）：[DagobangRouterDeploy.ts](file:///home/catgroup/projects/remote/meme/dagobang/dagobang-contracts/ignition/modules/dagobang/DagobangRouterDeploy.ts)
- 升级部署（部署新实现合约 + proxy.upgradeToAndCall）：[DagobangRouterUpgrade.ts](file:///home/catgroup/projects/remote/meme/dagobang/dagobang-contracts/ignition/modules/dagobang/DagobangRouterUpgrade.ts)

参数模板：
- 本地（mocks）：[dagobang.local.deploy.json](file:///home/catgroup/projects/remote/meme/dagobang/dagobang-contracts/ignition/parameters/dagobang.local.deploy.json)
- 本地升级： [dagobang.local.upgrade.json](file:///home/catgroup/projects/remote/meme/dagobang/dagobang-contracts/ignition/parameters/dagobang.local.upgrade.json)
- BSC 主网： [dagobang.bsc.deploy.json](file:///home/catgroup/projects/remote/meme/dagobang/dagobang-contracts/ignition/parameters/dagobang.bsc.deploy.json)
- BSC 测试网： [dagobang.bscTestnet.deploy.json](file:///home/catgroup/projects/remote/meme/dagobang/dagobang-contracts/ignition/parameters/dagobang.bscTestnet.deploy.json)

首次部署示例：
```bash
npx hardhat ignition deploy ignition/modules/dagobang/DagobangRouterDeploy.ts \
  --parameters ignition/parameters/dagobang.bscTestnet.deploy.json \
  --network bscTestnet
```

升级部署示例：
```bash
npx hardhat ignition deploy ignition/modules/dagobang/DagobangRouterUpgrade.ts \
  --parameters ignition/parameters/dagobang.bscTestnet.upgrade.json \
  --network bscTestnet
```

升级要点：
- `proxyAddress` 传已部署的 RouterProxy 地址
- 升级交易必须由该 Proxy 的 `admin` 发起，否则会回滚
- `upgradeCallData` 默认为 `"0x"`；如果你要升级后执行 reinitializer，可传入对应 calldata

## 合约验证
### 直连 Etherscan 验证（prod）
yarn verify:prod

### 通过 HTTP 代理验证（prod）
HTTPS_PROXY=http://your.proxy:port yarn verify:prod:proxy

### 测试网同理
yarn verify:test
HTTPS_PROXY=http://your.proxy:port yarn verify:test:proxy

## 与插件对接

插件侧需要改为调用 `swap()` 并构造 `SwapDesc[]`。

### 示例：BNB -> V3 -> Token

```ts
const ZERO = "0x0000000000000000000000000000000000000000";
const ZERO32 =
  "0x0000000000000000000000000000000000000000000000000000000000000000";

const descs = [
  {
    swapType: 1, // V3_EXACT_IN
    tokenIn: ZERO,
    tokenOut: tokenOut,
    poolAddress: ZERO, // 可填 0
    fee: 2500,
    tickSpacing: 0,
    hooks: ZERO,
    hookData: "0x",
    poolManager: ZERO,
    parameters: ZERO32,
    data: "0x",
  },
];

await router.write.swap([descs, ZERO, amountIn, minReturn, deadline], {
  value: amountIn,
});
```

### 示例：BNB -> V3(中转稳定币) -> FourMeme 内盘买币

```ts
const descs = [
  {
    swapType: 1, // V3_EXACT_IN
    tokenIn: ZERO,
    tokenOut: usd1,
    poolAddress: ZERO,
    fee: 500,
    tickSpacing: 0,
    hooks: ZERO,
    hookData: "0x",
    poolManager: ZERO,
    parameters: ZERO32,
    data: "0x",
  },
  {
    swapType: 5, // FOUR_MEME_BUY_AMAP
    tokenIn: usd1,
    tokenOut: memeToken,
    poolAddress: fourMemeTokenManager,
    fee: 0,
    tickSpacing: 0,
    hooks: ZERO,
    hookData: "0x",
    poolManager: ZERO,
    parameters: ZERO32,
    data: "0x", // 可改为 abi.encode(minOut)
  },
];
await router.write.swap([descs, ZERO, amountIn, minReturn, deadline], {
  value: amountIn,
});
```

### 示例：ERC20 -> Pancake Infinity（CL/Bin）

`swapType = 3`，并填写 `hooks/poolManager/fee/parameters/hookData`；同时需要 owner 先配置：
`setPancakeInfinityVault/setPancakeInfinityClPoolManager/setPancakeInfinityBinPoolManager`。

### 示例：FourMeme 卖出 -> V3 -> 稳定币

```ts
const descs = [
  {
    swapType: 6, // FOUR_MEME_SELL
    tokenIn: memeToken,
    tokenOut: ZERO,
    poolAddress: fourMemeTokenManager,
    fee: 0,
    tickSpacing: 0,
    hooks: ZERO,
    hookData: "0x",
    poolManager: ZERO,
    parameters: ZERO32,
    data: abi.encode(minFundsNative), // 可选
  },
  {
    swapType: 1, // V3_EXACT_IN
    tokenIn: ZERO,
    tokenOut: usd1,
    poolAddress: ZERO,
    fee: 500,
    tickSpacing: 0,
    hooks: ZERO,
    hookData: "0x",
    poolManager: ZERO,
    parameters: ZERO32,
    data: "0x",
  },
];
await router.write.swap([descs, ZERO, amountIn, minReturn, deadline], {
  // FourMeme 卖出场景常见的是先对 TokenManager 或 Router 做 approve
});
```

## 本地验证

```bash
yarn compile
yarn test
```
