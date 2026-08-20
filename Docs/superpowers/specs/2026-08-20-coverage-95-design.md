# 主 App 覆盖率提升 46.16% → 95%（语句）+ 62.46% → 90%（分支）

> **起始日期**：2026-08-20
> **状态**：设计已批准，待编写实现计划
> **范围**：主 App（Sources/）全层覆盖率提升（语句 + 分支双指标）
> **目标**：全 App 语句覆盖率 46.16% → 95%、分支覆盖率 62.46% → 90%（SonarQube 门禁）
> **前序规格**：`Docs/superpowers/specs/2026-08-06-mainapp-coverage-design.md`（旧目标 24.80%→34%，已由 P10 部分完成）

---

## 1. 背景与动机

### 1.1 当前基线（2026-08-20 xccov 真实测量，双指标）

全 App 语句覆盖率 **46.16%**（27553/59687 行可执行代码），距 SonarQube 95% 门禁差 ~49 个百分点 / ~32134 行。
全 App 分支覆盖率 **62.46%**（8717/13956 分支），距 SonarQube 90% 门禁差 ~28 个百分点 / ~5239 分支。

各层双指标分布：

| 层 | 语句覆盖率 | 分支覆盖率 | 可执行行 | 分支数 | 状态 |
|----|-----------|-----------|---------|-------|------|
| Infrastructure | 86.4% | 63.0% | 11901 | 6194 | 🟡 语句差 9%，分支差 27% |
| Core | 83.6% | 69.4% | 2580 | 1244 | 🟡 语句差 11%，分支差 21% |
| Domain | 80.1% | 70.6% | 2199 | 966 | 🟡 语句差 15%，分支差 19% |
| Localization | 70.9% | 31.2% | 2751 | 32 | 🟡 语句差 24%，分支差 59%（分支数少） |
| App | 33.9% | 70.4% | 2428 | 304 | 🔴 语句差 61%，分支差 20% |
| Shared | 29.9% | 64.3% | 4980 | 740 | 🔴 语句差 65%，分支差 26% |
| Features | 29.2% | 57.6% | 30312 | 4420 | 🔴 语句差 66%，分支差 32%（最大瓶颈） |
| Platforms | 9.8% | 39.3% | 2536 | 56 | 🔴 语句差 85%，分支差 51% |
| **总计** | **46.16%** | **62.46%** | **59687** | **13956** | 语句差 49%，分支差 28% |

**关键观察**：分支覆盖率（62.46%）高于语句覆盖率（46.16%），因为分支只统计条件语句（if/guard/switch/for 等），而语句覆盖率包含所有可执行行（大量 View body 未覆盖拉低语句覆盖率，但 View 中条件分支少）。

### 1.2 业界 Swift 分支覆盖率实践

**业界标准做法**（SonarSource 官方）：
1. 用 `xcodebuild test -enableCodeCoverage YES` 运行测试
2. 用 `xcrun xccov view --archive <xcresult>`（**文本格式**，非 `--report --json`）提取覆盖率
3. 用官方脚本 `xccov-to-sonarqube-generic.sh` 转换为 SonarQube generic XML
4. XML 中 `lineToCover` 节点含 `branchesToCover`/`coveredBranches` 属性 → SonarQube 自动计算分支覆盖率

**之前的问题**：项目用 slather 转换，slather **不提取分支数据**（只提取行覆盖率）。已改用 SonarSource 官方脚本 `Tools/CI/coverage/xccov-to-sonarqube-generic.sh`，可获得完整双指标。

**xccov 分支数据格式**：
```
13: 2 [            <- covered line with branch info
(33, 9, 0)         <- branch at column 33: 9 hits on one path, 0 on other
]
```
每个分支元组 `(column, count1, count2)` 代表 2 个分支路径，`count > 0` 表示该路径被执行。

### 1.3 P10 已完成工作

P10 阶段新增 334 个单元测试，覆盖率从 24.80% 提升至 46.16%（+21%）。旧设计规格（目标 34%）已被超越。本规格在此基础上将目标提升至 95%（语句）+ 90%（分支）。

### 1.4 瓶颈分析

- **Features 层 30312 行（占总量 51%）**：85 个 0% View 文件占 14424 行，29 个非 View 低覆盖文件占 1694 行；分支 4420 个（占 32%）
- **Shared 层 4980 行**：多为 UIComponents（0% 覆盖），189 个 View/UI 文件共 23348 行未覆盖
- **App 层 2428 行**：Scene/Layout/Overlay 组件低覆盖
- **Infrastructure 分支覆盖率 63.0%**：6194 个分支中 2289 个未覆盖，需重点补充分支测试

### 1.5 工作原则

延续 P10 测试驱动工作模式：
- **测试以发现问题为目的**（用户最高优先级指示），而非纯粹追求覆盖率
- **混合策略**：核心业务逻辑用问题驱动深度测试（等价类/边界值/决策表/状态转换/错误猜测）；纯工具/扩展/常量/Stub 用轻量补盲；View 用快照测试
- **问题记录**：发现问题记录到统一 findings 表格（序号/描述/黑盒影响/严重程度/修改方案/状态）
- **阶段修复**：每批次末暂停测试，统一确认 findings，集中修复，重测验证

---

## 2. 方案选择

### 2.1 攻击顺序：方案 1（按 ROI 从高到低，分 4 批）

按 Core/Domain/Infrastructure → Localization/App → Features非View → View+Shared UI 分批，每批 ROI 递减但确定性递增。

**选择理由**：
1. 批次 A（2340 行未覆盖，纯逻辑）是验证混合策略的最佳试验田，快速推到 95%
2. 每批独立 commit，失败不阻塞，符合分批验证原则
3. View 快照测试（批次 D，23348 行）后置到最后，届时方法论已成熟，且 swift-snapshot-testing 基础设施已就绪

### 2.2 否决方案

- **方案 2（按体量从大到小）**：首批即遇大量 View 快照测试，方法论未验证就攻难点，风险高
- **方案 3（纯单元测试优先，View 后置）**：非 View 全覆盖后总覆盖率约 65%，View 层 19000 行仍需处理，且无明确分批边界

---

## 3. 批次范围与目标

### 3.1 批次 A — Core/Domain/Infrastructure 补盲（2479 行未覆盖 → 95%）

**目标**：Core/Domain/Infrastructure 三层非 View 文件从当前覆盖率推到 95%
- Core：424 行未覆盖，381 分支未覆盖
- Domain：438 行未覆盖，284 分支未覆盖
- Infrastructure：1617 行未覆盖，2289 分支未覆盖
- 合计：2479 行未覆盖，2954 分支未覆盖

**重点文件**（按未覆盖行数排序）：

| 文件 | 层 | 当前 | 未覆盖行 | 测试策略 |
|------|---|------|---------|---------|
| DemoImageBuilder | Infra | 0% | 238 | 轻量补盲（Demo 数据生成） |
| SecureEnclaveCryptoService | Core | 14.1% | 128 | 问题驱动（加密/解密/密钥管理边界） |
| LLMServiceProtocol | Domain | 13.3% | 72 | 问题驱动（协议默认实现分支） |
| PerformanceBenchmarker | Infra | 0% | 48 | 轻量补盲（性能测量桩） |
| DemoAudioBuilder | Infra | 0% | 39 | 轻量补盲（Demo 数据生成） |
| DataCoordinator | Infra | 3.3% | 29 | 问题驱动（同步协调状态机） |
| SpeechServiceProtocol | Domain | 13.8% | 25 | 轻量补盲（协议默认实现） |
| GlobalPromptRegistry | Domain | 0% | 31 | 问题驱动（Prompt 注册/查找） |
| 各 Protocol 默认实现 | Core/Domain | 0% | ~100 | 轻量补盲（协议桩行为验证） |
| 其余 ~96 个文件 | 各层 | <95% | ~1630 | 混合（按文件性质决定） |

**问题驱动重点**：SecureEnclaveCryptoService（加密边界）、DataCoordinator（同步状态机）、GlobalPromptRegistry（Prompt 注册查找）

### 3.2 批次 B — Localization/App 非View（2406 行未覆盖 → 95%）

**目标**：Localization + App 层非 View 文件推到 95%
- Localization：801 行未覆盖，22 分支未覆盖
- App：1605 行未覆盖，90 分支未覆盖
- 合计：2406 行未覆盖，112 分支未覆盖

**重点文件**：

| 文件 | 层 | 当前 | 未覆盖行 | 测试策略 |
|------|---|------|---------|---------|
| AppLayoutComponents | App | 0% | 321 | 快照测试（布局组件） |
| SidebarRowComponents | App | 2.0% | 336 | 快照测试（侧边栏行） |
| CoachMarkOverlay | App | 0% | 109 | 快照测试（引导覆盖层） |
| ZhiYuApp | App | 17.4% | 109 | 轻量补盲（入口点初始化验证） |
| L10n+Common | Localization | 37.8% | 206 | 轻量补盲（key 存在性 + 返回值） |
| L10n+Plugin | Localization | 27.9% | 93 | 轻量补盲 |
| L10n+Dashboard | Localization | 44.4% | 109 | 轻量补盲 |
| AppEnvironment | App | 57.5% | 79 | 问题驱动（DI 初始化顺序） |
| ViewFactory | App | 29.2% | 34 | 轻量补盲（视图注册表） |
| 其余 27 个文件 | 各 | <95% | ~563 | 混合 |

**注**：App 层部分文件（AppLayoutComponents/SidebarRowComponents）虽非 `View.swift` 后缀，但实为 UI 组件，归入快照测试。

### 3.3 批次 C — Features 非View Service/ViewModel/Coordinator（21471 行未覆盖 → 85%）

**目标**：Features 层非 View 文件推到 85%（非 95%，因为 Features 层总量大 30312 行，非 View 部分约 6870 行，先推到 85% 验证策略，剩余在批次 D 后视情况补盲）
- Features 非View：约 6870 行未覆盖，1875 分支未覆盖
- Features 全层：21471 行未覆盖（含 View 14602 行），1875 分支未覆盖

**注**：批次 C 目标 85% 而非 95%，因为 Features 层是最大瓶颈（30312 行占全 App 51%），非 View 部分用问题驱动测试深度覆盖到 85%，View 部分在批次 D 用快照测试覆盖。批次 D 完成后 Features 全层达到 95%。

**重点文件**：

| 文件 | 当前 | 未覆盖行 | 测试策略 |
|------|------|---------|---------|
| IngestFileHandler | 15.5% | 125 | 问题驱动（文件导入边界：格式/大小/权限） |
| StoreKitService | 15.8% | 96 | 问题驱动（订阅状态机：未购买→试用→订阅→过期） |
| IngestCoordinator | 24.4% | 146 | 问题驱动（导入协调状态机） |
| ChatCoordinator | 28.0% | 134 | 问题驱动（聊天会话生命周期） |
| AuthService | 30.9% | 134 | 问题驱动（多平台认证流程） |
| IngestStore | 32.3% | 86 | 问题驱动（导入状态管理） |
| AppleAuthStrategy | 25.7% | 52 | 问题驱动（Apple ID 认证边界） |
| GitHubAuthStrategy | 34.8% | 43 | 问题驱动（GitHub OAuth 边界） |
| CarrierAuthStrategy | 37.5% | 30 | 问题驱动（运营商认证边界） |
| VaultDataCoordinator | 40.3% | 74 | 问题驱动（保险库数据协调） |
| CollaborationService | 53.5% | 73 | 问题驱动（协作同步） |
| IngestService | 58.1% | 88 | 问题驱动（导入服务核心逻辑） |
| ModelLabManager | 66.5% | 83 | 问题驱动（模型实验室管理） |
| AISynthesisService | 67.6% | 66 | 问题驱动（AI 合成服务） |
| GlobalModelManager | 71.0% | 73 | 问题驱动（全局模型管理） |
| SynthesisStore | 75.6% | 77 | 问题驱动（合成状态管理） |
| TokenManager | 76.4% | 38 | 问题驱动（Token 刷新/过期） |
| 其余 11 个文件 | <85% | ~254 | 混合 |

**Mock 需求**：MockStoreKit、MockAuthSession、MockURLSession（扩展现有 TestMocks）

### 3.4 批次 D — View + Shared UIComponents + Platforms 快照测试（~19968 行未覆盖 → 95%）

**目标**：Features View（14602 行 0%）+ Shared UIComponents（2341 行 0%）+ Platforms（1534 行 0%）+ App View（999 行 0%）用 swift-snapshot-testing 推到 95%
- 合计 0% 文件：179 个，19968 行未覆盖
- 分支：约 388 个未覆盖分支（View 中分支较少）

**子批次划分**（按工作量进一步拆分）：

| 子批次 | 范围 | 文件数 | 未覆盖行 | 策略 |
|--------|------|--------|---------|------|
| D1 | Shared/UIComponents | ~38 | ~2341 | 快照测试（暗色/亮色双快照） |
| D2 | Features/System View | ~40 | ~6300 | 快照测试（按 Settings/Auth/ModelManager/Collaboration 分组） |
| D3 | Features/Knowledge View | ~25 | ~3400 | 快照测试（按 Graph/Ingest/Search/Vault 分组） |
| D4 | Features/Insight + AI View | ~28 | ~4900 | 快照测试（按 Dashboard/Log/AI Chat/Synthesis 分组） |
| D5 | App/Platforms View | ~26 | ~2533 | 快照测试（Scene/Layout/Overlay + iOS/macOS/watchOS 平台适配） |

**快照测试基础设施**：
- 已有 `swift-snapshot-testing` 依赖（pointfreeco，~> 1.17）
- 已有 93 个快照测试（P10 期间建立的模式）
- 双快照策略：`.light` + `.dark` 模式各一张
- 设备配置：iPhone 17 Pro（与单元测试一致）

**风险与缓解**：
- View 重构导致快照失效 → 快照测试放最后，届时 View 已稳定
- 快照数量爆炸 → 按组件分组，一个测试方法覆盖多个相关 View

---

## 4. 测试方法论

### 4.1 问题驱动测试方法（核心业务逻辑）

| 方法 | 适用场景 | 示例 |
|------|---------|------|
| 等价类划分 | 输入域划分 | `IngestFileHandler`：有效文件/损坏文件/空文件/超大文件 |
| 边界值分析 | 边界点 + 两侧 | `StoreKitService`：试用期最后一天/过期当天/续订窗口 |
| 决策表 | 多条件组合 | `AuthService`：Apple+GitHub+Carrier+Google 四平台 × 已登录/未登录/Token过期 |
| 状态转换 | 状态机 | `IngestCoordinator`：idle→ingesting→processing→completed/failed |
| 错误猜测 | 易错点 | `TokenManager`：Token 即将过期/已过期/刷新失败/网络中断 |

**分支覆盖率重点**：问题驱动测试天然覆盖分支（每个等价类/边界值/决策表条件组合都执行不同分支路径）。重点确保：
- `if/guard` 的 true 和 false 两侧都被覆盖
- `switch` 的每个 case 都被命中
- `for/while` 循环的零次/一次/多次三种情况
- `nil` 可选值的 nil 和非 nil 两条路径
- 错误处理的 `try/catch` 成功和失败两条路径

### 4.2 轻量补盲测试方法（纯工具/扩展/常量/Stub/Protocol 默认实现）

- 调用每个公开方法/属性一次，验证返回值类型与基本正确性
- 常量/枚举：验证值唯一性、非空
- Stub/Protocol 默认实现：验证返回 unsupported 行为正确
- **分支覆盖策略**：对简单工具方法，覆盖主路径即可；对含条件判断的工具方法（如 `isEmpty`/`isValid`），覆盖 true/false 两侧

### 4.3 快照测试方法（View/UIComponents）

- 使用 `assertSnapshot(of:_, as:)` API
- 双模式：`.light` + `.dark`（`UIUserInterfaceStyle`）
- 固定尺寸：`.fixed(width: 390, height: 844)`（iPhone 17 Pro 逻辑分辨率）
- 本地化固定：`zh-Hans`（避免本地化差异导致快照失效）
- 每个 View 一个测试方法，相关组件可合并
- **分支覆盖策略**：快照测试主要提升语句覆盖率，View 中条件分支较少，分支覆盖率提升有限。View 的分支覆盖通过不同状态快照间接覆盖（如 loading/loaded/error 三态各一张快照）

### 4.4 双指标提升策略

| 批次 | 语句覆盖率重点 | 分支覆盖率重点 |
|------|--------------|--------------|
| A（Core/Domain/Infra） | 补盲未覆盖行 | **重点**：Infrastructure 6194 分支中 2289 未覆盖，用问题驱动覆盖条件分支 |
| B（Localization/App） | 补盲未覆盖行 | App 层 304 分支，覆盖 Scene/Layout 条件分支 |
| C（Features 非View） | 补盲未覆盖行 | **重点**：Features 4420 分支中 1875 未覆盖，用状态机/决策表覆盖 |
| D（View+Shared UI） | 快照测试覆盖 View body | 间接覆盖 View 条件分支（通过不同状态快照） |

**分支覆盖率提升优先级**：
1. **Infrastructure 层**（2289 未覆盖分支）：加密/存储/同步逻辑的条件分支，问题驱动测试
2. **Features 非View 层**（1875 未覆盖分支）：业务状态机的条件分支，状态转换测试
3. **Core/Domain 层**（565 未覆盖分支）：协议默认实现/工具方法条件分支
4. **View 层**：通过不同状态快照间接覆盖，不单独追求

---

## 5. Mock 策略

### 5.1 扩展现有 Mock 模式

- 新增 Mock 集中放 `Tests/Shared/TestMocks.swift`（扩展现有文件）或按域放 `Tests/Unit/<域>/Mock*.swift`
- 命名：`Mock<被Mock对象>`（如 `MockStoreKit`、`MockAuthSession`、`MockIngestCoordinator`）
- 协议优先：若被测代码依赖具体类，先抽协议再 Mock（仅测试需要时抽，不预先重构）
- 外部资源 Mock：StoreKit（`MockStoreKit`）、URLSession（`MockURLSession`）、Keychain（`MockKeychain`）

### 5.2 测试文件组织

- 路径：`Tests/Unit/<域>/<被测文件名>Tests.swift`（如 `Tests/Unit/Features/IngestFileHandlerTests.swift`）
- 快照测试路径：`Tests/SnapshotTests/<域>/<被测View>SnapshotTests.swift`
- 命名：`<被测类型>Tests`（单元测试）/ `<被测类型>SnapshotTests`（快照测试）
- 文件头：遵循 `file-header-template.md`（系统层级 + 核心职责）
- 一个被测文件可对应多个测试文件（按方法/场景拆分，避免单文件过大）

### 5.3 已知同名测试类冲突（需避免）

| 已有类名 | 新测试应命名 |
|---------|------------|
| PDFModelsTests | PDFModelsSupplementTests |
| RAGGovernanceModelsTests | RAGGovernanceModelsSupplementTests |
| DocumentFormatTests | DocumentFormatSupplementTests |
| PageContentUtilityTests | PageContentUtilitySupplementTests |
| LLMUtilsTests / PromptRegistryTests | LLMUtilsDomainTests / PromptRegistryDomainTests |
| DocumentFormatEdgeCaseTests | DocumentFormatDiscoveryTests |

---

## 6. 阶段修复机制

### 6.1 阶段修复流程（每批次末）

1. **暂停测试编写** — 批次测试编写完成且全绿后，停止新增测试
2. **汇总 findings** — 整理本批次 `Docs/Audit/2026-08-20-coverage-findings.md` 中本批次的新增条目
3. **用户确认** — 汇报本批次发现的问题清单（序号/描述/黑盒影响/严重程度/修改方案），逐条确认
4. **集中修复** — 对所有"已确认→已修复"问题，一次性修改源码
5. **重测验证** — `make test` 确认修复未引入回归 + 测试全绿
6. **更新 findings** — 表格状态字段更新为 `已修复`/`预期行为不修`
7. **commit** — 测试 + 修复一起提交
8. **进入下一批次**

### 6.2 findings 表格

文件：`Docs/Audit/2026-08-20-coverage-findings.md`

结构：

| 字段 | 说明 |
|------|------|
| 序号 | 全局递增（跨批次连续） |
| 严重程度 | 🔴 P0 / 🟡 P1 / 🟢 P2 |
| 文件:行号 | 问题定位 |
| 问题类型 | 死代码/错误假设/不一致行为/边界缺陷/安全漏洞等 |
| 问题描述 | 根因分析 |
| 黑盒影响 | 对用户/业务的影响 |
| 修改方案 | 修复思路 |
| 处理状态 | 待确认 → 已确认 → 已修复 / 预期行为不修 |
| 批次 | A/B/C/D |

### 6.3 严重程度判定标准

- 🔴 **P0**：数据损坏/丢失、崩溃、安全漏洞、资金损失（订阅/支付）
- 🟡 **P1**：逻辑错误、行为不一致、边界处理缺陷、错误处理缺失
- 🟢 **P2**：健壮性不足、维护负担、死代码、命名/注释问题

---

## 7. 验证方式

### 7.1 编写中验证

针对性跑单个测试类（iOS Simulator，与 `make test` 一致）：

```bash
xcodebuild test -only-testing:ZhiYuTests/<测试类> \
  -project ZhiYu.xcodeproj -scheme ZhiYu \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath build/DerivedData-ios \
  -enableCodeCoverage NO
```

### 7.2 批次末验证

全量测试 + 覆盖率报告（使用 SonarSource 官方脚本，支持双指标）：

```bash
# 全量测试（后台运行 + 日志轮询，耗时 ~5-8 分钟）
xcodebuild test -project ZhiYu.xcodeproj -scheme ZhiYu \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath build/DerivedData-ios \
  -enableCodeCoverage YES \
  -test-timeouts-enabled YES -default-test-execution-time-allowance 120

# 生成覆盖率报告（含分支数据，使用 SonarSource 官方脚本）
XCRESULT=$(ls -t build/DerivedData-ios/Logs/Test/*.xcresult | head -1)
Tools/CI/coverage/xccov-to-sonarqube-generic.sh "$XCRESULT" \
  > build/coverage/sonarqube-generic-coverage.xml
```

### 7.3 覆盖率验证脚本（双指标）

```bash
# CI 门禁校验（85% 红线，直接从 xcresult 提取）
python3 Tools/CI/assert-test-coverage.py

# 95% 门禁校验（本地开发用，指定阈值）
python3 Tools/CI/assert-test-coverage.py --threshold 95 --branch-threshold 90
```

输出示例：
```
语句覆盖率: 46.16% (27553/59687) — 距 95% 门禁差 48.84pp
分支覆盖率: 62.46% (8717/13956) — 距 90% 门禁差 27.54pp
```

### 7.4 覆盖率工具链迁移

**旧工具链**（slather，不支持分支）：
- `.slather.yml` → `slather coverage --sonarqube-xml`
- 输出：仅语句覆盖率

**新工具链**（SonarSource 官方脚本，支持双指标）：
- `Tools/CI/coverage/xccov-to-sonarqube-generic.sh` → 直接从 xcresult 提取
- 输出：语句 + 分支双指标
- **路径处理**：脚本输出绝对路径，SonarQube 需相对路径，需在 CI 中处理（`sed` 替换工作目录前缀）

---

## 8. 提交规范

每批次一个 commit，格式：

```
test(<批次>): <批次描述> + 修复 N 项测试驱动发现的问题

<批次范围说明>

发现问题 #<起始>-#<结束>:
- #<N> (P0/P1/P2): <一句话描述> — <修复/不修>

新增 X 个测试文件 Y 个用例，总计 Z 个测试 0 失败
覆盖率: <旧>% → <新>%
pre-push 门禁全通过
```

---

## 9. 预期终态

### 9.1 语句覆盖率预期

| 层 | 当前 | 批次A后 | 批次B后 | 批次C后 | 批次D后 | 目标 |
|----|------|--------|--------|--------|--------|------|
| Core | 83.6% | 95% | 95% | 95% | 95% | 95% |
| Domain | 80.1% | 95% | 95% | 95% | 95% | 95% |
| Infrastructure | 86.4% | 95% | 95% | 95% | 95% | 95% |
| Localization | 70.9% | 70.9% | 95% | 95% | 95% | 95% |
| App | 33.9% | 33.9% | 95% | 95% | 95% | 95% |
| Features | 29.2% | 29.2% | 29.2% | ~48% | 95% | 95% |
| Shared | 29.9% | 29.9% | 29.9% | 29.9% | 95% | 95% |
| Platforms | 9.8% | 9.8% | 9.8% | 9.8% | 95% | 95% |
| **全 App** | **46.16%** | **~48.9%** | **~52.5%** | **~62.1%** | **~95%** | **95%** |

### 9.2 分支覆盖率预期

| 层 | 当前 | 批次A后 | 批次B后 | 批次C后 | 批次D后 | 目标 |
|----|------|--------|--------|--------|--------|------|
| Core | 69.4% | 90% | 90% | 90% | 90% | 90% |
| Domain | 70.6% | 90% | 90% | 90% | 90% | 90% |
| Infrastructure | 63.0% | 90% | 90% | 90% | 90% | 90% |
| Localization | 31.2% | 31.2% | 90% | 90% | 90% | 90% |
| App | 70.4% | 70.4% | 90% | 90% | 90% | 90% |
| Features | 57.6% | 57.6% | 57.6% | 85% | 90% | 90% |
| Shared | 64.3% | 64.3% | 64.3% | 64.3% | 90% | 90% |
| Platforms | 39.3% | 39.3% | 39.3% | 39.3% | 90% | 90% |
| **全 App** | **62.46%** | **~77.6%** | **~78.2%** | **~86.8%** | **~90%** | **90%** |

**注**：
- 批次 A 对分支覆盖率提升最大（+15pp），因为 Infrastructure 层 2289 个未覆盖分支被问题驱动测试覆盖
- 批次 C 对分支覆盖率提升次大（+8.6pp），因为 Features 层 1875 个未覆盖分支被状态机/决策表测试覆盖
- 批次 D（View 快照）对分支覆盖率贡献较小（+3.2pp），因为 View 中分支较少

---

## 10. 风险与缓解

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|---------|
| 快照测试数量爆炸（批次 D） | 高 | 工作量大 | 按组件分组，5 个子批次分批完成 |
| View 重构导致快照失效 | 中 | 返工 | 快照测试放最后，View 已稳定 |
| Mock 过度导致测试脆弱 | 中 | 维护负担 | 协议优先 Mock，避免 Mock 具体类内部状态 |
| 强依赖文件难以测试 | 中 | 覆盖率卡点 | 抽协议注入，仅测试需要时重构 |
| 全量测试耗时过长 | 高 | 迭代慢 | 编写中用单类测试，批次末才全量验证 |

---

## 11. 后续规格（不在本次范围）

- 无。本规格目标 95% 已达 SonarQube 门禁要求。
