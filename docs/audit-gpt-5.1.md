Dagobang Router 智能合约安全审计报告（GPT‑5.1）
===============================================

## 一、审计概览

- 项目名称：Dagobang Router 智能合约
- 仓库地址：`dagobang/dagobang-contracts`
- 主要合约：
  - 路由器实现：[DagobangRouter.sol](file:///home/catgroup/projects/remote/meme/dagobang/dagobang-contracts/contracts/DagobangRouter.sol#L27-L387)
  - 升级代理：[DagobangProxy.sol](file:///home/catgroup/projects/remote/meme/dagobang/dagobang-contracts/contracts/proxy/DagobangProxy.sol#L7-L42)
  - 交换库：
    - V2 交换库：[V2SwapLib.sol](file:///home/catgroup/projects/remote/meme/dagobang/dagobang-contracts/contracts/swaplib/V2SwapLib.sol#L9-L56)
    - V3 交换库：[V3SwapLib.sol](file:///home/catgroup/projects/remote/meme/dagobang/dagobang-contracts/contracts/swaplib/V3SwapLib.sol#L7-L39)
    - V4 交换库：[V4SwapLib.sol](file:///home/catgroup/projects/remote/meme/dagobang/dagobang-contracts/contracts/swaplib/V4SwapLib.sol#L15-L217)
    - Pancake Infinity 交换库：[PancakeInfinitySwapLib.sol](file:///home/catgroup/projects/remote/meme/dagobang/dagobang-contracts/contracts/swaplib/PancakeInfinitySwapLib.sol#L17-L267)
    - four.meme 交换库：[FourMemeSwapLib.sol](file:///home/catgroup/projects/remote/meme/dagobang/dagobang-contracts/contracts/swaplib/FourMemeSwapLib.sol#L10-L81)
    - Flap 交换库：[FlapSwapLib.sol](file:///home/catgroup/projects/remote/meme/dagobang/dagobang-contracts/contracts/swaplib/FlapSwapLib.sol#L10-L64)
    - Luna LaunchPad 交换库：[LunaSwapLib.sol](file:///home/catgroup/projects/remote/meme/dagobang/dagobang-contracts/contracts/swaplib/LunaSwapLib.sol#L10-L37)
- 审计时间：相对本报告生成时间的静态代码审计
- Solidity 版本：`pragma solidity ^0.8.28;`
- 框架与依赖：
  - OpenZeppelin v5 升级合约与安全库（OwnableUpgradeable、PausableUpgradeable、ReentrancyGuardUpgradeable、SafeERC20 等）
  - Hardhat + Ignition 部署框架

### 审计目标

1. 全面安全审计：检查合约是否存在常见与高阶安全问题。
2. 功能逻辑完整性：验证路由多种交换路径的业务逻辑是否自洽。
3. 漏洞探测：从攻击者视角设计潜在攻击路径并验证可行性。
4. 资金安全性：确认用户资产在正常与异常场景下的安全性。
5. 黑客攻防视角分析：评估可被利用的攻击面与缓解手段。

### 审计范围说明

本次审计聚焦于生产相关合约与核心库：

- DagobangRouter 合约及其回调函数
- DagobangProxy 升级代理合约
- 所有位于 `contracts/swaplib` 的交换库
- 路由依赖的接口定义（interfaces）
- Ignition 部署与升级模块

测试专用的 mocks 合约不作为安全攻击面的一部分，但作为逻辑验证的重要参考。

不在本次审计范围之内的内容：

- 外部协议合约（Uniswap V2/V3、Pancake Infinity、four.meme、Flap、LunaLaunchPad 等）自身实现安全性
- 前端与 off-chain 脚本（除用于部署的 Ignition 模块）

### 结论摘要

- 合约整体架构清晰，权限边界与回调权限校验较为严谨。
- 未发现直接导致用户资金可被任意盗取的高危漏洞。
- 未发现明显的无限增发、任意转账、绕过权限的严重逻辑错误。
- 整体重入风险控制较为合理，关键交换入口使用了 `ReentrancyGuardUpgradeable`，且外部回调函数对调用方做了严格校验。
- 升级代理采用透明代理模式（Transparent Proxy）实现，admin 调用受限且无法通过 fallback 调用逻辑函数，符合最佳实践。

发现的问题主要集中在：

- 部分配置错误可能导致合约功能性 DoS（如设置了费用但未设置 feeCollector）。
- 对外部协议强依赖，在外部协议行为异常或恶意实现时，可能造成损失或 reentrancy 攻击面增加（属于信任假设问题）。
- 部分场景中多次收取原生币手续费的经济逻辑需要文档层面说明，以避免用户误解。

在遵循推荐的部署与操作规范前提下，合约当前版本在安全性和功能完整性上总体处于较为可靠的状态。


## 二、架构与信任模型

### 2.1 路由核心结构

DagobangRouter 的主要责任是统一封装不同 DEX / Launchpad / 自定义交易逻辑，并支持多步路由：

- 关键状态变量：
  - WNative 地址：`wNative`（包装原生币，如 WBNB/WETH）
  - V3 工厂地址：`v3Factory`
  - Luna Launchpad & Router：`lunaLaunchpad`、`lunaRouter`
  - V4 池管理器：`v4PoolManager`
  - Pancake Infinity：`pancakeInfinityVault`、`pancakeInfinityClPoolManager`、`pancakeInfinityBinPoolManager`
  - 费用相关：`feeCollector`、`feeBps`、`feeExempt`

核心入口函数：

- `swap(SwapDesc[] calldata descs, address feeToken, uint256 amountIn, uint256 minReturn, uint256 deadline)`
  - 单一多步骤路由调用，支持多种 `SwapType` 串联。
  - 使用 `nonReentrant`、`whenNotPaused` 与 `checkDeadline` 修饰。

交换路径通过 `SwapDesc` 数组描述：

- `SwapDesc` 字段：[DagobangRouter.sol](file:///home/catgroup/projects/remote/meme/dagobang/dagobang-contracts/contracts/DagobangRouter.sol#L69-L81)
  - `swapType`：枚举类型，标识 V2/V3/V4/Infinity/Luna/FourMeme/Flap 等不同路径。
  - `tokenIn`、`tokenOut`：输入输出 token，`address(0)` 代表原生币。
  - `poolAddress`、`poolManager`、`hooks`、`hookData`、`parameters`：外部协议相关参数。

### 2.2 升级与权限模型

升级代理合约：[DagobangProxy.sol](file:///home/catgroup/projects/remote/meme/dagobang/dagobang-contracts/contracts/proxy/DagobangProxy.sol#L7-L42)

- 使用 OpenZeppelin `ERC1967Proxy` 与 `ERC1967Utils` 标准实现。
- 核心特性：
  - `admin()` 返回当前代理 admin。
  - `implementation()` 返回当前逻辑合约。
  - `upgradeToAndCall` / `changeAdmin` 仅允许 admin 调用（通过 `NotAdmin` 错误控制）。
  - `_fallback` 函数中若 `msg.sender == admin` 则直接 revert (`ProxyDeniedAdminAccess`)，防止 admin 通过代理直接调用逻辑合约函数，符合透明代理模式最佳实践。

部署模块：

- 部署模块：[DagobangRouterDeploy.ts](file:///home/catgroup/projects/remote/meme/dagobang/dagobang-contracts/ignition/modules/dagobang/DagobangRouterDeploy.ts#L3-L22)
  - 先部署 Router 实现，再构造 Proxy，初始化时通过 `initData` 调用 Router 的 `initialize`。
- 升级模块：[DagobangRouterUpgrade.ts](file:///home/catgroup/projects/remote/meme/dagobang/dagobang-contracts/ignition/modules/dagobang/DagobangRouterUpgrade.ts#L3-L18)
  - 通过 Ignition 调用 Proxy 的 `upgradeToAndCall`，执行升级与可选初始化。

DagobangRouter 本身权限：

- 继承自 `OwnableUpgradeable`，`owner` 可以：
  - 暂停/恢复路由：`pause` / `unpause`
  - 配置所有外部依赖地址：`setWNative`、`setV3Factory`、`setLunaLaunchpad`、`setLunaRouter`、`setV4PoolManager`、`setPancakeInfinityVault`、`setPancakeInfinityClPoolManager`、`setPancakeInfinityBinPoolManager`
  - 配置手续费相关参数：`setFeeCollector`、`setFeeBps`、`setFeeExempt`

因此，系统信任假设包括：

- Proxy admin 和 Router owner 必须是高度可信实体（例如多签）。
- 所有外部协议地址（V3 工厂、V4 管理器、Infinity Vault、四方 Meme 管理器、Flap/Luna 管理器等）需要由可信方配置，避免被指向恶意合约。


## 三、功能与逻辑完整性分析

### 3.1 swap 主流程

核心函数：[swap](file:///home/catgroup/projects/remote/meme/dagobang/dagobang-contracts/contracts/DagobangRouter.sol#L165-L214)

关键检查：

- `descs.length > 0`，禁止空交易路径。
- 当前实现 `feeToken` 必须为 `address(0)`，即只支持原生币计费路径。
- `amountIn > 0`，禁止零输入。
- `deadline` 检查：`block.timestamp <= deadline`。

输入资产处理：

- 若首个 `tokenIn` 为原生币（`address(0)`）：
  - 要求 `msg.value >= amountIn`。
  - 调用 `_takeNativeFee(payerOrigin, amountIn)` 扣除手续费，还原后更新 `amountIn`。
  - 多余 `msg.value` 不会自动退回，将留在合约内（非推荐使用方式）。
- 若首个 `tokenIn` 为 ERC20：
  - 要求 `msg.value == 0`，防止误转原生币。
  - 对于 `FOUR_MEME_SELL` 路径：
    - 先通过 `_fourMemeIsV2` 探测是否为四方 Meme V2 管理器。
    - 若非 V2，会将代币先转入 Router，由 Router 进行授权与出售。
    - 若为 V2，则不转入 Router，由 `FourMemeSwapLib` 直接调用 tokenManager，从用户地址出售，实现非托管。
  - 其他 swapType：直接 `safeTransferFrom` 将 `amountIn` 从用户转入 Router。

路由执行：

- 维护 `currentAmountIn`，从 `amountIn` 开始，依次传入每一步 `_executeSwap`，返回值作为下一步的 `amountIn` 使用。
- 最终 `currentAmountIn` 代表整条路径的输出数量。

最终输出处理：

- 若最终 `tokenOut` 为原生币：
  - 调用 `IWNative(wNative).withdraw(currentAmountIn)` 将 WNative 兑换为原生币。
  - 再调用 `_takeNativeFee(payerOrigin, currentAmountIn)` 再次收取原生币手续费。
  - 确保 `netOut >= minReturn`，并将净额发送给用户。
- 若最终为 ERC20：
  - 要求 `currentAmountIn >= minReturn`。
  - 将 `tokenOut` 从 Router 安全转账给用户。

日志记录：

- 事件 `Swap(payer, receiver, feeToken, amountIn, amountOut, descs)`，其中 `descs` 会从 calldata 拷贝到 memory（通过 `_toMemory`），方便链上溯源。

### 3.2 各 SwapType 实现逻辑

`_executeSwap`：[DagobangRouter.sol](file:///home/catgroup/projects/remote/meme/dagobang/dagobang-contracts/contracts/DagobangRouter.sol#L216-L315)

支持的枚举类型：

- `V2_EXACT_IN`：通过 `V2SwapLib.exactIn` 与 V2 Pair 交互。
- `V3_EXACT_IN`：通过 `V3SwapLib.exactIn` 与 Uniswap V3 Pool 交互。
- `V4_EXACT_IN`：通过 `V4SwapLib.swapExactIn` 与 V4 Pool Manager 交互。
- `PANCAKE_INFINITY_EXACT_IN`：通过 `PancakeInfinitySwapLib.swapExactIn` 与 Infinity Vault 和 CL/Bin Pool 交互。
- `LUNA_LAUNCHPAD_V2`：通过 `LunaSwapLib` 调用 Luna LaunchPad。
- `FOUR_MEME_BUY_AMAP` / `FOUR_MEME_SELL`：通过 `FourMemeSwapLib` 与 four.meme 管理器交互。
- `FLAP_EXACT_INPUT`：通过 `FlapSwapLib.exactInput` 与 Flap 管理器交互。

关键逻辑校验包括：

- V3/V2：
  - `_wrapToken(address(0))` 转换为 WNative 地址。
  - 若 `tokenIn == address(0)` 则先将原生币 `deposit` 成 WNative。
  - 最终输出数额由 pool 的实际状态决定。
- V4：
  - 要求 `v4PoolManager` 已配置（非零地址）。
  - 通过 `V4SwapLib` 使用 `Locker` 机制锁定 `_msgSender`，防止复杂重入。
  - V4 的 `unlockCallback` 仅接受来自 `v4PoolManager` 的调用。
- Pancake Infinity：
  - 要求 `vault`、`clPm`、`binPm` 均为非零地址，否则 revert `"INFINITY_NOT_CONFIGURED"`。
  - 在 Vault 的 `lock` 回调中完成债务结算与多币种余额处理。
- Luna Launchpad：
  - 要求 `lunaLaunchpad` 与 `lunaRouter` 均已配置。
  - 要求买卖操作必须其中一侧是原生币（`tokenIn` 或 `tokenOut` 为 `address(0)`）。
- four.meme：
  - `FOUR_MEME_BUY_AMAP`：
    - 使用 `_tokenInfos` 探测模板类型，根据 template 标志位选择 XMODE 或 AMAP 流程。
    - 对输入 `data` 非空 / 有特定长度时进行约束，避免混用 AMAP 与 XMODE。
    - 对多余原生币会统一退款给 `payerOrigin`。
  - `FOUR_MEME_SELL`：
    - 要求该步骤必须是第 0 步（`i == 0`），防止从中间插入复杂卖出逻辑。
    - 使用 `_fourMemeIsV2` 区分 V2 与非 V2 管理器，在 V2 模式下不托管用户代币。
- Flap：
  - 支持 `token → token`，`native → token` 和 `token → native` 三种路径。
  - `token → native` 时将原生币包装为 WNative 后返回数额。

综合来看，交换流程在类型与配置上的边界检查相对完备，不易出现明显路径错配造成的资金损失。


## 四、安全性详细分析

### 4.1 重入攻击风险评估

防护机制：

- `swap` 函数使用 `nonReentrant` 修饰，防止重复进入同一入口。
- V4 与 Pancake Infinity 库内部使用 `Locker`：
  - `Locker` 利用固定存储槽记录当前“逻辑调用者”，防止在同一逻辑上下文中递归嵌套。
  - 若 `Locker.get() != address(0)` 再次进入，则 revert `ContractLocked`。
- 回调函数调用方限制：
  - `uniswapV3SwapCallback` 要求 `msg.sender` 必须等于 `v3Factory.getPool(tokenIn, tokenOut, fee)` 得到的池子地址。
  - `unlockCallback` 要求 `msg.sender == v4PoolManager` 且非零。
  - `lockAcquired` 要求 `msg.sender == pancakeInfinityVault` 且非零。

攻击者视角：

- 即便攻击者控制某个外部池合约，在回调中尝试：
  - 直接调用 `swap` 会被 `nonReentrant` 阻止。
  - 调用 `unlockCallback`、`lockAcquired` 等函数需要伪造为指定管理器或 Vault 地址，否则会被 require 拒绝。
  - 调用其他只读函数或仅限 owner 的管理函数则无法获得实际收益。

结论：

- 在路由主要入口处的重入攻击面较小。
- 对于 WNative 合约若被恶意替换为可重入合约，仍可能构造更复杂的攻击链路，因此要求部署时 WNative 地址必须为知名、可审计的标准实现。

### 4.2 授权与代币安全

授权处理主要集中在各 swaplib 内部：

- 统一使用 `SafeERC20` 中的 `safeTransfer`、`safeTransferFrom` 和 `forceApprove`。
- 未使用裸 `approve`，避免 non-standard ERC20 导致的授权问题。
- 在 four.meme / Flap / Luna 等场景中，授权前会将 token 转入 Router，并以 Router 作为 spender，用户侧仅需要对 Router 执行一次批准。
- four.meme V2 卖出路径通过低级 `call` 调用 tokenManager 的 `sellToken`，但此调用由 Router 直接发起，用户代币不会离开用户地址之前被 Router 非法消耗。

潜在风险点：

- 对于 `forceApprove`，若目标代币为恶意 ERC20 实现，可能在 `approve` 回调中做不安全操作，但这是典型 DeFi 路由器对外部 ERC20 的信任假设问题，无法从 Router 单方完全规避。
- 在 four.meme / Flap / Luna 多协议组合路径中，若后续步骤使用的是恶意 token 或恶意协议，同样可能导致代币损失，因此需要在前端与部署层面做好白名单与风控。

### 4.3 手续费与经济安全

手续费实现：`_takeNativeFee`：[DagobangRouter.sol](file:///home/catgroup/projects/remote/meme/dagobang/dagobang-contracts/contracts/DagobangRouter.sol#L371-L386)

逻辑：

- 当 `feeBps == 0` 或 `feeExempt[payer] == true` 时，不收取手续费。
- 计算：`fee = (amount * feeBps) / FEE_DENOMINATOR`。
- 若费额为 0（四舍五入结果），则不做任何转账。
- 要求 `feeCollector != address(0)`，否则 revert `"FEE_COLLECTOR_NOT_SET"`。

收取场景：

- 原生币作为输入时：
  - 在 `swap` 开始前，对 `amountIn` 执行一次 `_takeNativeFee`。
  - 用户实际用于路由的输入数量为 `amountIn - fee`。
- 原生币作为输出时：
  - 在结束前，对 `currentAmountIn`（此时表示路由输出数量）再次调用 `_takeNativeFee`。
  - 用户最终收到的是扣费后的数量。

设计含义：

- 在 Native → Token 场景下，只在输入侧收一次费。
- 在 Token → Native 场景下，只在输出侧收一次费。
- 在 Native → ... → Native 场景下，将在输入和输出分别收取手续费，类似“进出两边收取”的模型。

潜在问题与建议：

- 配置风险：若运营方设置了 `feeBps > 0` 但忘记设置 `feeCollector`，所有涉及原生币的路径都会由于 `"FEE_COLLECTOR_NOT_SET"` 而失败，形成功能性 DoS。
  - 建议在前端/运维工具中增加保护：在修改 `feeBps` 前先检查 `feeCollector` 非零。
- 多次收费模型需要在产品文档中解释清楚，以免用户误认为多步路由只收一次手续费。

### 4.4 时间与滑点控制

时间约束：

- 使用 `checkDeadline` 修饰器，要求 `block.timestamp <= deadline`。
  - 防止无限期挂单和 MEV / sandwich attacker 长期观察订单。

滑点控制：

- `minReturn` 在最终输出位置进行校验：
  - 原生币输出：在扣除最终手续费后的净额与 `minReturn` 对比。
  - ERC20 输出：在最终 `currentAmountIn` 与 `minReturn` 对比。
- 部分子协议内部也有独立的最小输出约束：
  - V2：通过 `_getAmountOut` 计算，用户整体滑点由 `minReturn` 控制。
  - Pancake Infinity / V4：内部有 `amountOutMinimum` 字段。
  - four.meme / Flap / Luna：根据各自协议函数的 `minOut` 参数控制。

结论：

- 用户可以通过合理设置 `minReturn` 与特定子协议参数来控制整体滑点，避免价格大幅波动下的不利成交。

### 4.5 外部协议信任假设

DagobangRouter 作为路由器，核心逻辑依赖多种外部合约接口：

- Uniswap V2/V3 池子与工厂
- V4 池管理器
- Pancake Infinity Vault 与 CL/Bin Pool Manager
- four.meme TokenManager
- Flap 管理器
- Luna LaunchPad 与其 Router

安全假设：

- 这些外部合约遵循各自协议的标准行为，不会恶意调用或攻击 Router。
- 外部合约不会在回调中直接调用 Router 的敏感函数，或即便调用也因为权限限制无法造成损失。

攻击场景分析：

- 若某个外部协议被恶意替换为攻击者合约：
  - 可以在 Router 将代币转入外部合约后拒绝返回任何资产，构成资金冻结或直接损失。
  - 可以在回调中尝试调用 Router 的其他函数，但由于 `nonReentrant` 和权限限制，一般很难进一步扩展攻击面。
- 这类风险属于“集成第三方协议”的常见信任问题，解决方案主要是：
  - 部署时对外部协议地址进行严格白名单控制。
  - 前端只允许用户使用所认可的协议组合。


## 五、黑客视角攻防分析

从黑客视角全面检视 DAGOBANG Router，可归纳潜在攻击面与结论如下。

### 5.1 直接资金窃取

目标：在无需用户授权或无需用户主动调用的情况下，将 Router 中托管的代币或原生币转出至攻击者地址。

分析：

- Router 未暴露任何“提币/扫币”函数，资金只能通过正常 swap 流程或外部协议回调移动。
- 所有需要从用户地址拉取 token 的逻辑均使用 `safeTransferFrom` 并受 `msg.sender == 用户` 约束。
- Proxy admin 与 Router owner 即便恶意，也只能通过：
  - 调整外部协议地址，使后续 swap 将用户资产导入恶意协议。
  - 升级 Router 实现为恶意版本。
- 因此，“直接盗币”攻击本质是“管理权被盗（私钥泄露）”问题，而非 Router 代码逻辑漏洞。

结论：

- 未发现无需管理权限即可执行的直接资金窃取路径。
- 强烈建议将 Proxy admin 与 Router owner 设为安全多签，并配合硬件钱包管理私钥。

### 5.2 重入与逻辑绕过

目标：在 swap 调用过程中通过重入绕过滑点或费用检查，或重复消费同一输入资产。

分析：

- swap 主函数使用 `nonReentrant`，在调用任何外部协议前已经锁定重入状态。
- 回调函数（如 `uniswapV3SwapCallback`、`unlockCallback`、`lockAcquired`）均不带 `nonReentrant`，但：
  - 调用者限制严格，攻击者难以伪造合法调用方。
  - 内部只进行协议特定的结算操作，不修改全局配置或用户余额。
  - 不会重新调用 `swap` 等入口函数。
- 少数地方使用 `call` 发送 ETH（如 FourMemeSwapLib 对 payerOrigin 的退款），理论上存在 fallback 重入机会，但受 `ReentrancyGuard` 保护。

结论：

- 当前实现下，从 Router 侧发起的重入攻击面较小，未发现实际可利用的路径。

### 5.3 手续费与经济博弈

潜在攻击目标：

- 借由手续费机制制造 DoS 或不公平经济行为。

分析：

- 费用基于 BPS 并上下限为 `[0, FEE_DENOMINATOR]`，无法溢出。
- 即便管理员将 `feeBps` 设置为 `FEE_DENOMINATOR`（100%），用户也会因 `minReturn` 设置不合理而拒绝交易，这更偏向配置风险/产品层面的错误。
- `feeCollector` 地址必须为可接收原生币的地址，否则会因为 `"FEE_TRANSFER_FAILED"` 造成交易失败，同样属于配置不当的风险。

结论：

- 手续费机制本身没有明显安全漏洞，但运维层面需要严格流程与自动化检测，避免配置错误带来的经济问题。


## 六、测试与验证情况

### 6.1 单元测试

测试文件：[dagobang-router.test.ts](file:///home/catgroup/projects/remote/meme/dagobang/dagobang-contracts/test/dagobang-router.test.ts#L1-L434)

主要覆盖内容：

- V3 路径：
  - 原生币 → Token（单池）
  - Token → 原生币（单池）
  - 原生币 → 中间 Token → 目标 Token（多步路由）
- V2 路径：
  - 原生币 → Token（单 Pair）
- V4 路径：
  - Token → Token 通过 V4 Pool Manager。
- Pancake Infinity 路径：
  - Token → Token 通过 Infinity CL 池。
- four.meme 路径：
  - 原生币 → 中间 Token → four.meme Token。
  - Token → 中间 Token → 原生币。
- 费用逻辑：
  - 设置 `feeCollector` 与 `feeBps` 后，验证手续费成功转入 feeCollector。

单测中广泛使用 mocks 合约来模拟外部协议，确保：

- Router 在典型成功场景下行为正确。
- 关键事件与余额变化符合预期。

### 6.2 编译与类型检查

在项目根目录 `/home/catgroup/projects/remote/meme/dagobang/dagobang-contracts` 下执行：

- `yarn check`
  - 含义：`hardhat compile` + `hardhat test` + TypeScript `tsc --noEmit`。
  - 命令返回码为 0，表示合约成功编译，测试全部通过，TypeScript 类型检查无错误。

这进一步佐证了当前版本在实现层面与测试覆盖下的内部一致性。


## 七、已识别风险与建议

本节将风险按严重程度分为：高、中、低、信息。

### 7.1 高危风险

当前版本未发现无需管理权限即可导致用户资金直接被盗或协议整体资产损失的高危漏洞。

### 7.2 中危风险

1. 手续费配置错误导致原生币路径全部失败

- 描述：
  - `_takeNativeFee` 要求 `feeCollector` 非零地址。
  - 当 `feeBps > 0` 且 `feeCollector == address(0)` 时，所有涉及原生币输入或输出的 swap 都会 revert。
- 影响：
  - 协议功能性 DoS，用户无法完成含原生币的交易。
- 建议：
  - 在前端管理面板中添加校验逻辑：禁止在 `feeCollector == address(0)` 时将 `feeBps` 设置为非零。
  - 或者在合约层添加一种“原子配置”方法，同时设置两个参数，降低运维错误可能性。

2. 外部协议地址配置错误风险

- 描述：
  - Router 依赖多个外部协议地址由 owner 设置。
  - 若被错误配置为恶意合约地址，可能导致资金损失或长时间锁定。
- 影响：
  - 单次或多次交易损失承担方为用户。
- 建议：
  - 使用多签管理 owner 权限。
  - 部署时对外部协议地址进行白名单限制，与前端联动，只暴露已审计、可信协议。

### 7.3 低危风险

1. 多次原生币手续费收取可能造成用户误解

- 描述：
  - 在 Native → Native 多步路径中，会在输入和最终输出两个位置收取手续费。
  - 对普通用户可能不易理解，易产生“被多扣费”的主观感受。
- 建议：
  - 在产品文档与前端提示中明确说明收费模型。
  - 或根据产品决策，将其中一次收费逻辑改为仅在某一端收取。

2. 多余 msg.value 未自动退款

- 描述：
  - 当 `tokenIn` 为原生币时，Router 只要求 `msg.value >= amountIn`，对多余值不进行退款。
  - 这些多余的原生币会留在 Router 合约中，当前版本没有提现函数，属于“卡死”状态。
- 建议：
  - 前端严格保证 `msg.value == amountIn`。
  - 若未来需要提现功能，应设计安全的资金取回流程（例如仅允许多签 owner 提现，并公开透明记录）。

### 7.4 信息性风险与注意事项

- 路由高度依赖外部协议安全性，任何外部协议本身的漏洞或恶意行为都可能反向影响 Router 用户。
- Proxy 升级能力强大，升级新逻辑前应再次进行审计，并通过多签与 timelock 控制上线流程。


## 八、综合结论与建议

在当前代码与测试范围内，Dagobang Router 智能合约具备以下特点：

- 架构清晰，充分利用 OpenZeppelin v5 安全组件与标准升级模式。
- 多种 SwapType 的集成边界条件较为严谨，对回调调用者做了严格验证。
- 使用了 `ReentrancyGuardUpgradeable` 与内部 `Locker` 机制对重入风险进行了较好控制。
- 费用、滑点、deadline 等关键经济与时间参数均有显式检查。
- 单元测试对典型路径有良好覆盖，所有测试与类型检查均通过。

整体判断：

- 在管理权限（Proxy admin、Router owner）安全、外部协议地址配置正确的前提下，Dagobang Router 当前版本在安全性和逻辑完整性方面是可接受的，可以用于主网部署。

后续建议：

- 在主网部署前后，建议：
  - 将关键权限交由多签管理，并结合硬件钱包。
  - 对所有外部协议地址进行严格白名单控制，并在前端仅展示白名单协议。
  - 明确公开手续费模型与可能的双向收费场景。
  - 对未来的任何 Router 升级版本在上线前再次进行完整审计。

本报告基于静态代码分析与现有测试用例，未包含形式化验证与经济模型博弈分析。如后续协议功能或经济模型发生重大变更，建议重新进行安全审计。
