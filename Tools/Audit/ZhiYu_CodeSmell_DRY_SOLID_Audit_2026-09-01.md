# ZhiYu 代码坏味道与 DRY/SOLID 合规审计

> 审计日期：2026-09-01
> 审计范围：`Sources/` + `Packages/`（排除 Tests / build / scratch）
> 代码规模：829 个 Swift 文件，113,628 行，2,478 个函数
> 审计方式：PMD-CPD 重复检测 + Periphery 死代码 + 自建 SOLID 六维静态扫描 + 现网 Gatekeeper 门禁复跑

---

## 一、结论先行

**IS_PASS: NO（有条件通过）**

代码本身的坏味道水平**中上**（7.3 / 10），DRY 重复率 1.64% 优于 SonarQube 3.0% 红线；但审计过程中发现**一项 P0 级质量基建缺陷**：守护"分层单向依赖"这条核心红线的门禁 `audit-arch-dependency.py` 处于**假绿灯**状态——它每次都输出"100% 洁净"，实际是因为待检实体被豁免集污染成了空集。

| 结论组 | 评分 | 判定 |
|--------|------|------|
| 代码坏味道（DRY/SOLID 六维） | **7.3 / 10** | 🟡 中上，有明确整改点 |
| 质量基建有效性 | **4.0 / 10** | 🔴 P0 缺陷，需立即修复 |
| SPM 模块依赖方向 | **10 / 10** | 🟢 0 违规，严格单向 |

**最优先处置**：修复 `audit-arch-dependency.py` 的实体过滤逻辑，否则"分层架构单向依赖"这条红线**当前没有任何自动化保护**。

---

## 二、六维评分总表

| 维度 | 评分 | 核心指标 | 判定 |
|------|------|----------|------|
| **DRY** | 7.5 | 重复率 1.64%（1,867 行 / 113,628 行），跨文件复制粘贴 74 处 | 🟡 达标但有热点 |
| **SRP** | 7.0 | 长方法 42 个（占 1.7%），>600 行文件 5 个 | 🟡 可控 |
| **OCP** | 8.5 | 巨型 switch 经甄别为**误报**；类型分派 150 处 / 63 文件 | 🟢 良好 |
| **LSP** | 8.5 | fatalError 13 处，多数为合理前置断言 | 🟢 良好 |
| **ISP** | 6.5 | 臃肿协议 5 个，`AppStoreProtocol` 25 成员混合 4 类职责 | 🟡 需拆分 |
| **DIP** | 6.0 | 业务单例直调 275 处绕过 DI；`ServiceContainer.shared` 210 处（Service Locator） | 🔴 主要短板 |
| **架构门禁有效性** | 4.0 | 1 个 P0 假绿灯 + 2 个脚本缺依赖时静默退出 0 | 🔴 需修复 |

---

## 三、P0：质量基建缺陷（须立即修复）

### P0-1 分层依赖门禁假绿灯

| 项 | 内容 |
|----|------|
| 文件 | `Tools/ios/audit-arch-dependency.py:69` |
| 现象 | 每次运行均输出"🟢 架构各分层 100% 遵循单向洁净依赖，0 处冲突"，但同屏打印的实体统计为 **各层 0 个实体** |
| 根因 | `COMMON_KEYWORDS = sdk_symbols ∪ project_symbols ∪ manual_symbols`，其中 `project_symbols` 含 **22,412** 个符号，覆盖了项目自身全部类型名（`KnowledgePage`/`AppStore`/`Logger`/`NetworkClient`…）。实体提取处用该集合做过滤，导致待检实体被全部滤除 → `forbidden_entities` 为空集 → 必然 0 违规 |
| 影响 | Sources/ 目录（733 文件，占代码主体）的分层单向依赖**无自动化保护**。注意：`Packages/` 的 SPM 模块依赖另有物理隔离保障，已验证 0 违规 |
| 修复 | 实体提取阶段只用 `sdk_symbols ∪ manual_symbols` 过滤；`project_symbols` 仅用于**违规判定的豁免**，不参与实体提取 |

**为何不直接给出"真实违规数"**：我尝试用文本匹配重新扫描，得到 1,092 处，但样本中大量是 `CodingKeys`、`Layout`、`LogModule`、`MarkdownSyntax` 等**各层同名类型**造成的误报（Swift 中同名类型在不同目录并不冲突）。文本匹配无法准确量化，需基于编译期符号解析（SourceKit / index）才能定论。**因此本报告只断言"门禁失效"这一可验证事实，不断言 Sources/ 层存在多少真实违规**——风险敞口待精确工具量化。

### P0-2 门禁脚本缺依赖时静默退出 0

| 文件 | 现象 |
|------|------|
| `Tools/ios/audit-arch-dependency.py` | 缺 PyYAML 时打印"❌ 缺少 PyYAML 依赖"，但**退出码仍为 0** |
| `Tools/ios/check-arch-di-registration.py` | 同上 |

CI 会将其判定为通过。**修复**：依赖缺失时 `sys.exit(1)`。

> 补充：本仓库 `make audit` 仅串联 6 个脚本，`audit-arch-dependency.py` **并不在其中**，即该门禁即使在健康状态下也未被纳入 CI 主链路。

---

## 四、P1：需排期整改

### P1-1 DIP 违反：275 处业务服务单例直调

全库 `.shared` 调用 993 次 / 251 文件，分类后：

| 类别 | 次数 | 判定 |
|------|------|------|
| 安全基础设施（`FileManager`/`UserDefaults`/`Logger` 等无状态） | 350 | 🟢 可接受 |
| `ServiceContainer.shared` | 210 | 🟡 Service Locator 折中，非构造器注入 |
| `HapticFeedback.shared` | 159 | 🟡 无状态副作用，但测试不可 mock |
| **业务服务单例（真实架构债）** | **275** | 🔴 应走 `@Inject` |

业务单例分布 TOP：

| 类型 | 次数 | 说明 |
|------|------|------|
| `KeychainService` | 30 | 安全敏感，应可注入以便测试替换 |
| `AuthSession` | 23 | 会话状态，直调导致测试难隔离 |
| `DatabaseManager` | 20 | 持久化根，应注入 |
| `SecurityManager` | 19 | 安全敏感 |
| `VaultService` | 18 | 业务服务 |
| `AppEventBus` | 18 | 事件总线，直调造成隐式全局耦合 |
| `NetworkClient` | 16 | 网络层，测试需 mock |
| `AISynthesisService` | 13 | 业务服务 |

### P1-2 ISP 违反：臃肿协议

| 协议 | 成员数 | 位置 | 问题 |
|------|--------|------|------|
| `AppStoreProtocol` | 25 | `Sources/Domain/Protocols/AppStoreProtocol.swift:19` | 混合**指标数据**（pages/totalWords/tags…）+ **UI 状态**（showCreateSheet/pendingCoachMark…）+ **核心逻辑**（refresh/deletePage…）+ **建议应用**（applyRefactorSuggestion）四类职责 |
| `RAGGovernanceRepository` | 21 | `Sources/Domain/Protocols/RAGGovernanceRepository.swift:16` | 治理数据仓储，含 `logTokenUsage` 7 参数方法 |
| `AnyPageStore` | 20 | `Sources/Domain/Protocols/StoreCapabilities.swift:38` | 混合页面 CRUD + 审计日志 + 存储统计；另见 P2-3 |
| `SpeechServiceProtocol` | 18 | `Sources/Domain/Protocols/SpeechServiceProtocol.swift:17` | 语音服务 |
| `OnDeviceLLMServiceProtocol` | 17 | `Sources/Domain/Protocols/OnDeviceLLMServiceProtocol.swift:16` | 端侧 LLM |

`AppStoreProtocol` 建议拆为 `KnowledgeMetricsProviding`（只读指标）/ `AppUIStateProviding`（UI 状态）/ `KnowledgePageOperating`（操作）三个小协议。

### P1-3 过长参数列表

| 位置 | 参数数 | 建议 |
|------|--------|------|
| `Sources/Core/System/Logger/Logger.swift:423` `addLog()` | **9** | 引入 `LogEntry` 参数对象 |
| `Sources/Localization/Extensions/L10n+AI.swift:347` `ragJudgePrompt()` | 6 | 引入 `RAGJudgeContext` |
| `Sources/Features/Knowledge/Ingest/Model/IngestStore.swift:198` `ingestWithFolding()` | 6 | 引入 `IngestOptions` |
| `Sources/Features/Knowledge/Graph/View/Components/GraphInfoPanel.swift:223` `insightSection()` | 6 | 视图构建参数合并 |

`Logger.addLog` 是跨协议重复出现的签名（`AnyPageStore.addLog` 7 参数、`Logger.addLog` 9 参数），统一为 `LogEntry` 后可同时消除 DRY 与过长参数两个问题。

---

## 五、P2：观察与清理

### P2-1 死代码 44 处（Periphery）

集中在 `Sources/Features/FeatureConstants.swift`（20+ 处未使用常量，如 `GoogleConfig`、`ListItemPrefix`、`mockAppleCode`、`carrier` 等），另有 `ModuleRegistrar`/`PlatformRegistrar` 协议被判为冗余存在类型。

### P2-2 长方法 42 个（>60 行）

| 位置 | 行数 |
|------|------|
| `Sources/Domain/Protocols/StoreCapabilities.swift:46` `fetchAllPages()` | 155 |
| `Sources/Infrastructure/Plugins/PluginSandboxGateway.swift:23` `JSContextGroupSetExecutionTimeLimit()` | 117 |
| `Sources/Infrastructure/Storage/Utility/InitialNotebookGenerator.swift:258` `buildPKMPageSeeds()` | 100 |
| `Sources/Infrastructure/Storage/Utility/InitialNotebookGenerator.swift:366` `buildResearchPageSeeds()` | 90 |
| `Sources/Domain/Protocols/RAGGovernanceRepository.swift:20` `logTokenUsage()` | 81 |
| `Sources/Core/System/Workflow/WorkflowService.swift:44` `syncToReminders()` | 77 |
| `Sources/App/Core/ModuleRegistrar.swift:62` `register()` | 77 |
| `Sources/Infrastructure/Network/NetworkClient.swift:245` `handleTokenRefreshAndRetry()` | 76 |

### P2-3 `AnyPageStore` 双份删除 API

`Sources/Domain/Protocols/StoreCapabilities.swift` 同时声明 `deletePage(_:) async throws` 与 `anyDeletePage(_:) async`（类型抹除封装版）。两者语义重叠，属接口冗余，建议收敛为一个。

### P2-4 跨文件复制粘贴热点（DRY）

162 处重复块中 **74 处为跨文件**，累计 931 行。TOP：

| 重复行数 | 位置 A | 位置 B |
|---------|--------|--------|
| 40 | `Auth/View/AuthPhonePanel.swift:62` | `Auth/View/OverseasLoginCardView.swift:80` |
| 29 | `ModelManager/Model/ParameterPreset.swift:16` | `ModelManager/View/InferenceParametersView.swift:47` |
| 27 | `iOS/Registrar/iOSPlatformCapabilities.swift:20` | `watchOS/Services/WatchPlatformCapabilities.swift:26` |
| 23 | `LLM/Adapters/NativeMemoryEngine.swift:20` | `LLM/Adapters/SwarmMemoryAdapter.swift:21` |
| 23 | `iOS/Registrar/iOSPlatformCapabilities.swift:19` | `macOS/MacOSPlatformCapabilities.swift:20` |
| 23 | `macOS/MacOSPlatformCapabilities.swift:21` | `watchOS/Services/WatchPlatformCapabilities.swift:26` |
| 20 | `Dashboard/View/Subviews/ConceptDetailBodyView.swift:52` | `Dashboard/View/Subviews/EntityDetailBodyView.swift:45` |
| 19 | `Dashboard/View/CircularTagBubbleView.swift:147` | `Dashboard/View/TagCapsuleView.swift:173` |
| 18 | `Plugins/LocalPluginDetailView.swift:33` | `Plugins/PluginCenterView.swift:273` |
| 18 | `LLM/ChatLLMService.swift:159` | `LLM/ChatRunner.swift:253` |

**三份 `*PlatformCapabilities` 两两重复**是其中最典型的一项：项目已建立 `PlatformRegistrar` 协议抽象，但 iOS/macOS/watchOS 三端实现仍以复制粘贴方式各自维护，后续新增能力需同步改三处。

---

## 六、误报澄清（经人工甄别，不计入坏味道）

为保证结论可信，以下初筛命中项经复核后**判定为误报**：

| 初筛项 | 判定 | 理由 |
|--------|------|------|
| `Router.swift:93` switch **22 cases** | ✅ 非违规 | enum 自洽计算 `id`，编译器强制穷尽，新增 case 不会静默漏掉 |
| `Router.swift:121` switch 17 cases | ✅ 非违规 | 同上（`sidebarSelection` 映射） |
| `AppStore.swift:269` switch 15 cases | ✅ 非违规 | `ToolItem → AppRoute` enum 映射，同上 |
| 消息链 597 处 | ✅ 基本误报 | 样本几乎全为 `AppConstants.Keys.Storage.xxx` 常量命名空间与 SwiftUI 链式修饰符，非 Law of Demeter 违反 |
| 布尔标识参数 10 处 | ✅ 基本误报 | 样本为 `set(true, forKey:)`（UserDefaults 正常用法）与 `CFStringTransform`（系统 API） |
| 长方法初筛 306/388 行等 | ✅ 扫描器 bug | 我的大括号匹配在嵌套 enum 单行方法上误吞后续方法，已修正后重扫（详见下节） |

---

## 七、审计方法学说明

自建扫描器在开发过程中修复了 3 处缺陷，记录以备复现：

1. **字符串字面量干扰括号计数** — 预处理阶段移除 `"..."` 内容。
2. **单行方法误吞** — 初版要求"闭合行须含 `{`"，导致嵌套 enum 内的 `func x() { ... }` 越过闭合行、吞并后续方法，`L10n+Dashboard.wordCount()` 被误报为 230 行（实际 1 行）。修正为"见过开括号后深度归零即结束"。
3. **zsh 单词分割** — `cmd="python3 Tools/x.py"; $cmd` 在 zsh 下不做分词，整个字符串被当作命令名导致 EXIT=127。须用显式分支或 `${=cmd}`。

另有一处**数据作废**：散弹式修改维度因排序键写反导致输出为字母倒序，未纳入报告，也未重跑——该维度用文本引用计数近似本就不可靠，建议改用 `git log` 变更耦合分析。

---

## 八、通过的门禁（复跑确认）

| 门禁 | 结果 |
|------|------|
| `check-arch-layer-markers.sh` | ✅ 层级标记合规 |
| `audit-arch-domain-purity.py` | ✅ 领域层 76 文件 100% 平台纯净化 |
| `check-code-platform-macros.py` | ✅ Features/Domain 无 `#if os()` |
| `check-arch-test-di-setup.py` | ✅ 测试 DI 注册完整 |
| `check-code-di-crash-risk.py` | ✅ DI 崩溃风险通过 |
| `check-arch-di-registration.py` | ✅ 10 个 @Inject + 19 个 assertRegistered 全部注册（需 venv Python） |
| `check-code-complexity.py` | ✅ 圈复杂度 ≤ 10（SwiftLint warning 8 / error 10） |
| `audit-code-swift-quality.py` | ✅ 注释与文件头合规 |
| **SPM 模块 import 方向** | ✅ **0 违规**（自建核验） |

SPM 依赖矩阵（严格自上而下）：

```
UFPCore(L0)         -> (无跨模块依赖)
UFPStorage(L1)      -> (无跨模块依赖)
UFPDesignSystem(L1) -> UFPCore×1
ZhiYuDomain(L1.5)   -> UFPCore×2
ZhiYuAICore(L1)     -> UFPCore×4, ZhiYuDomain×4
ZhiYuFeatures(L2)   -> UFPCore×3, UFPDesignSystem×3, ZhiYuDomain×3, ZhiYuAICore×1
```

---

## 九、整改优先级

| 优先级 | 事项 | 工作量 | 收益 |
|--------|------|--------|------|
| **P0** | 修复 `audit-arch-dependency.py` 实体过滤逻辑 | 0.5h | 恢复分层红线保护，暴露真实敞口 |
| **P0** | 依赖缺失时 `sys.exit(1)`（2 个脚本） | 0.2h | 消除静默假绿灯 |
| **P0** | 将 `audit-arch-dependency.py` 纳入 `make audit` | 0.1h | 门禁真正进 CI |
| **P1** | 拆分 `AppStoreProtocol`（25 → 3 个小协议） | 4h | ISP/SRP 双改善 |
| **P1** | 引入 `LogEntry` 参数对象，统一 `addLog` 签名 | 3h | 消除 9 参数 + 跨协议重复 |
| **P1** | 275 处业务单例改 `@Inject`（分模块推进） | 2-3d | 可测试性根本改善 |
| **P2** | 三端 `*PlatformCapabilities` 抽公共实现 | 4h | DRY，消除三处同步改 |
| **P2** | 清理 44 处死代码 | 2h | 降低维护噪音 |
| **P2** | 收敛 `AnyPageStore` 双份删除 API | 1h | 接口去重 |

---

*本报告由静态扫描生成，所有数字均可通过复跑脚本验证。误报已逐项人工甄别并标注，未核实为问题的一律不计入扣分。*
