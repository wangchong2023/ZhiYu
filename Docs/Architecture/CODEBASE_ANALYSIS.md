> ⚠️ **本文档已被替代**。请参阅更新的审计报告：
> - [`Tools/Audit/ZhiYu_Codebase_Audit_2026-06-22.md`](../../Tools/Audit/ZhiYu_Codebase_Audit_2026-06-22.md) — 602 文件 18 维度全量审计，P0/P1 全部清零
> - 本文档保留作为历史参考（2026-06-13 版本，564 文件扫描）

# 全项目代码质量综合分析报告（历史版本）

> 生成日期：2026-06-13
> 扫描范围：564 个 Swift 源文件，~92K 行代码 (不含 Tests 17K 行)
> 分析方法：逐文件夹深度扫描 + 4 路并行代理深度分析，18 项代码质量准则
> 版本：2.0.0（新增新发现 240+ 项）

---

## 目录

1. [整体健康度评分](#1-整体健康度评分)
2. [P0 — 阻塞性问题](#2-p0--阻塞性问题)
3. [P1 — 严重违规](#3-p1--严重违规)
4. [P2 — 中等严重度](#4-p2--中等严重度)
5. [P3 — 建议改进](#5-p3--建议改进)
6. [跨层访问违规](#6-跨层访问违规)
7. [层内违规明细](#7-层内违规明细)
8. [文件/模块健康度矩阵](#8-文件模块健康度矩阵)
9. [SOLID 原则违规汇总](#9-solid-原则违规汇总)
10. [平台适配分析](#10-平台适配分析)
11. [本地化 L10n 审计](#11-本地化-l10n-审计)
12. [测试质量审计](#12-测试质量审计)
13. [响应式架构迁移进度](#13-响应式架构迁移进度)
14. [废弃/死代码清单](#14-废弃死代码清单)
15. [优先修复路线图](#15-优先修复路线图)
16. [新增发现汇总](#16-新增发现汇总)

---

## 1. 整体健康度评分

| 维度 | 评分 (0-10) | 主要问题 |
|------|-------------|----------|
| 架构分层 | 7.0 / 10 | L0 协议引用 L3 类型、Domain Layer import GRDB、L1.5 → L2 逆向依赖 |
| SOLID 遵循 | 6.5 / 10 | SRP 违反 (God Class)、DIP 违反 (直接依赖具体实现)、ISP 违反 (22 方法协议) |
| 中文注释 | 9.0 / 10 | 一致性极佳，少量模板化注释 + JSDoc 遗留 |
| 命名规范 | 8.5 / 10 | 基本一致，DesignSystem 文件命名混乱 |
| 魔鬼数字/字符串消除 | 7.0 / 10 | Tokens 覆盖 ~85%，customSize* 常量堆砌、system(size:) 散落 |
| 本地化 L10n | 9.0 / 10 | 架构合规，Stat/Stats 重复，少量视图残留硬编码 |
| 并发安全 | 6.0 / 10 | 大量 @unchecked Sendable (20+ 处) 需要审计 |
| 平台适配 | 6.0 / 10 | 39 个 #if os 散落，Adaptor 层不完整 |
| 测试质量 | 7.0 / 10 | sleep 等待反模式、Mock 重复、边界测试缺失 |
| 废弃代码消除 | 7.0 / 10 | 空协议、空桩、死代码、OllamaAdapter stub |
| **综合** | **7.3 / 10** | **整体良好，较 v1.0 发现更多深层问题** |

---

## 2. P0 — 阻塞性问题

### P0-1: `ServiceContainer` 并发隐患 (Core/Base)

- **文件**: `Sources/Core/Base/ServiceContainer.swift:17`
- **问题**: `@unchecked Sendable` + `os_unfair_lock` 非原子化屏障存在 TOCTOU 窗口
- **建议**: 迁移至 `actor ServiceContainer`

### P0-2: `AppStore` God Class (App/Store)

- **文件**: `Sources/App/Store/AppStore.swift` — 554 行
- **问题**: 持有 10+ `@Inject` 属性，管理 4 个子 Store，实现 3 个协议扩展，SRP 严重违反
- **建议**: 拆分到独立扩展/文件

### P0-3: `AppStore.swift` ↔ `AppModels.swift` 重复定义

- **文件**: `AppStore.swift:25-68` + `AppModels.swift:17-61`
- **问题**: `ToolItem`、`CoachMarkType`、`KnowledgeGrowthPoint` 在两个文件中重复定义
- **建议**: 统一至 `AppModels.swift`

### P0-4: `RAGGovernanceRepository` 协议 ISP 严重违反

- **文件**: `Sources/Domain/Protocols/RAGGovernanceRepository.swift:14-95`
- **问题**: 协议包含 **22 个方法**，涵盖 Token 记录、调用日志、RAG 评估、检索快照、相关性标注、检索指标 (Hit Rate、MRR、NDCG、Recall、F1、MAP)、延迟百分位数、Token 效率及用户反馈
- **建议**: 拆分为 `RAGGovernanceSQLiteStore`、`RAGGovernanceSQLiteStore`、`RetrievalMetricsRepository`、`LatencyRepository`、`FeedbackRepository`

### P0-5: `KnowledgePage` 依赖 L1 基础设施

- **文件**: `Sources/Domain/Models/KnowledgePage.swift:159,164`
- **问题**: L1.5 领域模型直接调用 `AppLinkProcessor.extractOutgoingLinks(from:)` 和 `PageContentUtility.calculateWordCount(_:)`，构成跨层依赖
- **建议**: 通过 Domain Services 扩展提供

### P0-6: `KnowledgeIngestPipeline` 逆向依赖 L2

- **文件**: `Sources/Domain/RAG/KnowledgeIngestPipeline.swift:80,99,133-136`
- **问题**: L1.5 领域层直接调用了 L2 单例 `TaskCenter.shared.addIngestSubLog(...)`，构成**逆向依赖**
- **建议**: 通过事件协议解耦

### P0-7: `OllamaAdapter` 为 Stub 实现

- **文件**: `Sources/Infrastructure/LLM/LLMAdapters.swift:86-95`
- **问题**: `OllamaAdapter.generate()` 返回 `"Ollama Result"` 固定字符串，`chatStream()` 返回永不 yield 的空流，会挂死调用方
- **建议**: 实现完整 Ollama API，或抛出 `LLMError.notConfigured`

### P0-8: `ZipUtility` 自实现 ZIP 解析

- **文件**: `Packages/UFPCore/Sources/UFPCore/Base/ZipUtility.swift:17-77`（已从业务层迁移至 UFPCore）
- **问题**: 手动解析 ZIP 格式使用原始字节操作，有数据损坏风险
- **建议**: 替换为 Foundation `NSFileCoordinator` 或 `ZIPFoundation` 库

### P0-9: `KeychainService` UserDefaults 回退安全风险

- **文件**: `Sources/Core/System/Security/KeychainService.swift:44-49`
- **问题**: 模拟器上 Keychain 不可用时，API Key 以明文存储在 UserDefaults 中
- **建议**: 至少对回退值进行加密

### P0-10: 跨层访问违规 (6 处)

详见 [第 6 章](#6-跨层访问违规)

---

## 3. P1 — 严重违规

### 3.1 `@unchecked Sendable` 滥用 (20+ 处)

| 文件 | 行号 | 说明 |
|------|------|------|
| `ServiceContainer.swift` | 17 | `@unchecked Sendable` + `os_unfair_lock` |
| `LLMService.swift` | 18 | `@unchecked Sendable` on `@MainActor` class |
| `ChatLLMService.swift` | 17 | 同上 |
| `IngestLLMService.swift` | 16 | 同上 |
| `IngestProcessor.swift` | 18 | 同上 |
| `SecurityManager.swift` | 16 | `@unchecked Sendable` + `NSLock` |
| `IntentRateLimiter.swift` | 15 | 同上 |
| `LocalAnalyticsService.swift` | 15 | 同上 |
| `LLMClient.swift` | 30 | 同上 |
| `PromptService.swift` | 16 | 同上 |
| `LLMAdapters.swift` | 98 | Extension 添加 `@unchecked Sendable` |
| `AppEventBus.swift` | 50 | Extension 添加 |
| `SourceStore.swift` | 16 | `@Observable` + `@unchecked Sendable` |
| `ThemeManager.swift` | 101 | `@unchecked Sendable` |
| **Mock 类 (10+)** | 多处 | 所有测试 Mock 使用 `@unchecked Sendable` |

### 3.2 日志字符串碎片化模式 (25+ 处)

多文件使用 `" ... " + "..." + "..."` 拼接代替字符串插值：

| 文件 | 行号 | 示例 |
|------|------|------|
| `Logger.swift` | 338 | `" [Logger]" + " Failed to" + " save logs:"` |
| `EmbeddingManager.swift` | 68 | `" [Embedding]" + " Failed to" + " load initial" + " cache:"` |
| `SecurityManager.swift` | 185 | `"Critical: Failed" + " to persist" + " HMAC signature"` |
| `DeepLinkService.swift` | 34 | `" [DeepLinkService]" + " Rate limit" + " exceeded!"` |
| `WorkflowService.swift` | 71,92 | 多处 |
| `KeychainService.swift` | 50,124-131 | 多处 |

**根因**: 本地化安全 lint 工具过度应用，25 处日志消息被不必要地拆分。

### 3.3 `EmbeddingProvider` 协议 ISP 违反

- **文件**: `Sources/Core/Base/Protocols/EmbeddingProvider.swift`
- **问题**: 13 个方法混合了缓存管理 (`clearCacheAndReload`, `loadInitialCache`)、查询/搜索 (`search`, `multiQuerySearch`, `hydeSearch`) 和 chunk 管理 (`indexChunks`, `vectorizeChunks`)
- **建议**: 拆分为 `EmbeddingProvider` 和 `VectorIndexableStore`

### 3.4 `AnyPageStore` 协议 ISP 违反

- **文件**: `Sources/Core/Base/Protocols/StoreCapabilities.swift`
- **问题**: 18 个方法混合 CRUD (`createPage`, `updatePage`)、搜索 (`searchPages`)、同步 (`syncRemotePage`)、标签管理 (`renameTag`, `deleteTag`)、维护 (`resetDatabase`, `seedDefaultContent`)
- **建议**: 拆分为 3-4 个聚焦协议

### 3.5 `ProcessInfo` 参数检查重复 (7+ 处)

`ProcessInfo.processInfo.arguments.contains("--uitesting")` 模式在多个文件中重复：

| 文件 | 出现次数 |
|------|----------|
| `LLMService.swift` | 4 次 (L48-54, L72-80, L96-101) |
| `ChatLLMService.swift` | 3 次 (L42-44, L82-91, L129-147) |

**建议**: 抽取为 `UITestingHelper.isRunning` 静态属性

### 3.6 `IngestLLMService` vs `IngestProcessor` 重复

- **文件**: `Sources/Infrastructure/LLM/IngestLLMService.swift` + `Sources/Infrastructure/Processors/Document/IngestProcessor.swift`
- **问题**: 两个 L1 类都实现 `LLMKnowledgeServiceProtocol`，功能重叠。`IngestLLMService` 每次调用创建新服务，`IngestProcessor` 维护缓存实例
- **建议**: 合并或明确职责边界

### 3.7 `SQLiteStore` 轮询反模式

- **文件**: `Sources/Infrastructure/Storage/SQLiteStore.swift:23-34`
- **问题**: `dbWriter` 使用忙等轮询（20 次 × 50ms = 1s 延迟）
- **建议**: 使用 `AsyncStream`、`CheckedContinuation` 或通知回调

### 3.8 测试 sleep 等待反模式 (10+ 处)

| 位置 | 行号 | 代码 |
|------|------|------|
| `AppStoreTests.swift` | 27-28 | `try? await Task.sleep(nanoseconds: 50_000_000)` |
| `AppStoreTests.swift` | 38 | `try? await Task.sleep(nanoseconds: 200_000_000)` |
| `RAGPipelineTests.swift` | 29 | `try? await Task.sleep(nanoseconds: 100_000_000)` |

**建议**: 替换为 `XCTestExpectation` 或 `asyncSequence` 等待

### 3.9 `KnowledgePageManager` 依赖过多

- **文件**: `Sources/Domain/Knowledge/KnowledgePageManager.swift:20-27`
- **问题**: 构造函数注入 7 个依赖（pageStore、linkService、undoService、backupService、ingestService、logger、tagStore、aiWorkflowStore）
- **建议**: 拆分职责到更小粒度的服务

### 3.10 `AIContentEnricher` 硬编码中文提示词

- **文件**: `Sources/Domain/RAG/AIContentEnricher.swift:142,166`
- **问题**: `"你是一位资深的数据分析师与 Markdown 排版专家。"` 等中文字符串硬编码，未使用 L10n
- **建议**: 通过 `PromptRegistry` 或 L10n 管理

### 3.11 `TagStoreProtocol` 空协议

- **文件**: `Sources/Domain/Protocols/TagStoreProtocol.swift`
- **问题**: 仅有 `protocol TagStoreProtocol {}`，无任何方法。死代码
- **建议**: 移除或实现完整定义

### 3.12 `AISynthesisService` Actor 初始化期 DI 解析

- **文件**: `Sources/Features/AI/Synthesis/Service/AISynthesisService.swift:23`
- **问题**: Actor `init` 中 `ServiceContainer.shared.resolve(...)` 可能导致并发问题
- **建议**: 通过参数注入，不在 init 中访问全局 DI

---

## 4. P2 — 中等严重度

### 4.1 设计系统文件重复

| 重复文件 | 位置 | 说明 |
|----------|------|------|
| `DesignSystem+Shadow.swift` ↔ `DesignSystem+Shadows.swift` | Shared/DesignSystem/Tokens/ | 单复数不一致，功能重叠 |
| `StatCard.swift` ↔ `AppMetricCard.swift` | Shared/UIComponents/Cards/ | 高度相似：icon + title + value 指标卡片 |
| `AppTextEditor.swift` ↔ `PlatformTextEditor.swift` | Shared/UIComponents/ | 跨平台编辑器，API 不同 |

### 4.2 `customSize*` 常量堆砌

- **文件**: `Sources/Shared/DesignSystem/Tokens/DesignSystem+Metrics.swift:75-101`
- **问题**: 20+ 个 `customSize150`、`customSize1`、`customSize56` 等无意义命名常量，相当于魔法数字的别名
- **建议**: 分组到领域特定命名空间或直接内联

### 4.3 `system(size:)` 替代 Dynamic Type

| 文件 | 行号 | 代码 |
|------|------|------|
| `AppTextEditor.swift` | 48,57,84 | `.system(size: 15)` |
| `AppErrorView.swift` | 47,59,64,82 | `.system(size: 54)` |
| `AppFeedback.swift` | 196 | `size * 0.5` |
| `LockOverlayView.swift` | 102 | 计算 titleSize 36/28/24 |
| `AppRows.swift` | 185 | `size * 0.45` |

**建议**: 优先使用 Typography 语义字体

### 4.4 `Stat` / `Stats` L10n 枚举重复

- **文件**: `Sources/Localization/Extensions/L10n+Common.swift:96-107`
- **问题**: `Common.Stat` 和 `Common.Stats` 指向相同键 (`stats.newPages`, `stats.growth` 等)
- **建议**: 合并为一个

### 4.5 `KnowledgePage.displaySourceName` 函数过长

- **文件**: `Sources/Domain/Models/KnowledgePage.swift:204-236`
- **问题**: 32 行含 3 层嵌套兜底逻辑
- **建议**: 抽取为专用格式化器

### 4.6 `RAGOrchestrator` 依赖 L3 `AppConfig`

- **文件**: `Sources/Domain/RAG/RAGOrchestrator.swift:53,80`
- **问题**: L1.5 领域层引用 `AppConfig.AI.defaultModel` (L3)
- **建议**: 通过参数注入

### 4.7 `KnowledgeIngestPipeline` 硬编码魔法数字

- **文件**: `Sources/Domain/RAG/KnowledgeIngestPipeline.swift:73,148,190`
- **问题**: `chunkSize: 1000`, `chunkOverlap: 200`, `questions.prefix(3)` 应使用 `AppConstants`
- **建议**: 抽取到 AppConstants

### 4.8 `PromptService` 硬编码 UserDefaults 键

- **文件**: `Sources/Infrastructure/LLM/PromptService.swift:37-41,120-128`
- **问题**: 使用 `"prompt_mindmap"`、`"prompt_quiz"` 等字符串而非 `AppConstants.Keys.Storage.promptMindmap`
- **建议**: 使用已有 AppConstants

### 4.9 无障碍支持缺失

| 组件 | 问题 |
|------|------|
| `AppPrimaryButton` | 无 `accessibilityLabel` |
| `AppCard` / `AppBorderedCard` | 无无障碍特征 |
| `AppTextField` | 无显式无障碍标签 |
| `AppTagField` | 无无障碍配置 |

### 4.10 `Hash` 后备向量非确定性

- **文件**: `Sources/Infrastructure/VectorDB/EmbeddingManager.swift:189-196`
- **问题**: `Hasher` 被苹果文档明确标注为非稳定（不同执行产生不同哈希值），导致检索结果不确定性
- **建议**: 使用确定性哈希如 `SHA256` 截断

### 4.11 `ThemeManager.accentColor` 无缓存

- **文件**: `Sources/Shared/DesignSystem/Themes/ThemeManager.swift:68`
- **问题**: `nonisolated var` 每次从 UserDefaults 重新读取，SwiftUI 频繁渲染时可能成为性能热点
- **建议**: 使用缓存 + 写入时更新

### 4.12 watchOS 硬编码强调色

- **文件**: `Sources/Shared/DesignSystem/Tokens/Colors.swift:128`
- **问题**: `#if os(watchOS) return .blue #endif` 绕过 ThemeManager
- **建议**: 通过 PlatformRegistrar 注入

### 4.13 测试 Mock 重复

| Mock | 文件 | 说明 |
|------|------|------|
| `MockLLMChatService` | `TestMocks.swift:78` | 实现 `LLMChatServiceProtocol` |
| `MockChatLLMService` | `MockLLMServices.swift:16` | 同上功能 |
| `MockFullLLMService` | `AISynthesisServiceTests.swift:50` | 实现 `LLMServiceProtocol` |

**建议**: 合并为单一复用型 Mock

### 4.14 `setupFullMockEnvironment()` 过长

- **文件**: `Tests/Shared/TestMocks.swift:223-392` (170 行)
- **问题**: 同时负责基础设施初始化、DI 注册、数据库迁移、AI 服务注册
- **建议**: 拆分为模块化初始化方法

### 4.15 `Measure` + `XCTestExpectation` 反模式

- **文件**: `Tests/Performance/RAGPerformanceTests.swift:55-81`
- **问题**: `measure` 块中混合 `XCTestExpectation` + `Task` + `wait()`，已知 XCTest 不推荐模式
- **建议**: 使用 async 版本 `measure` API

### 4.16 `KnowledgeIngestPipelineTests` 断言矛盾

- **文件**: `Tests/Unit/Base/KnowledgeIngestPipelineTests.swift:49`
- **问题**: 测试命名 `testProcess_withoutLLM_indexChunksNotCalled` 但断言 `XCTAssertTrue(mockEmbedding.indexChunksCalled)` — 方法名说"未调用"但断言"已调用"
- **建议**: 修正测试命名或修正断言

### 4.17 `PluginSandboxTests` 无断言

- **文件**: `Tests/Unit/Plugins/PluginSandboxTests.swift:163-167`
- **问题**: `testWatchdogTimeoutSuspension` 方法无任何 `XCTAssert*` 调用
- **建议**: 添加实际断言

### 4.18 `AuthIntegrationTests` 无断言

- **文件**: `Tests/Integration/AuthIntegrationTests.swift`
- **问题**: 4 个测试方法仅打印结果，无断言
- **建议**: 添加强断言或标记为手动测试

### 4.19 `SnapshotHelper` 死代码

- **文件**: `Tests/SnapshotTests/SnapshotHelper.swift`
- **问题**: 自定义 ImageRenderer + Base64 实现，但 `ComponentSnapshots.swift` 使用的是第三方 `SnapshotTesting` 库
- **建议**: 移除

### 4.20 `SecureEnclaveCryptoService` 自密钥协商

- **文件**: `Sources/Core/System/Security/SecureEnclaveCryptoService.swift:52`
- **问题**: 使用自身密钥进行密钥协商 (`sharedSecretFromKeyAgreement` with `privateKey.publicKey`) — 非常规模式
- **建议**: 注释说明设计理由或改用标准加密模式

---

## 5. P3 — 建议改进

### 5.1 中文注释问题

| 文件 | 问题 |
|------|------|
| `LinkService.swift:51-56,201-205` | JSDoc 风格 `@description` `@param` `@return` 与项目 `///` 风格不一致 |
| ~~`Date+App.swift:29-32`~~ | JSDoc 遗留注释块（文件已删除，迁移至 UFPCore `Date+Formatting.swift`） |
| `TextChunkerProcessor.swift:49-53` | JSDoc 风格 |
| `Animations.swift:49-53` | 过于冗长的弹簧参数变更历史注释 |
| `AppStore.swift:211-258` | 参数中文占位符 |
| 多处 `.swiftlint:disable:next` | lint 抑制掩盖魔法数字 |

### 5.2 设计系统问题

| 文件 | 问题 |
|------|------|
| `DesignSystem+Metrics.swift` | `customSize*` 常量堆砌 |
| `DesignSystem+Shadow.swift` vs `Shadows.swift` | 重复文件，定义相同功能 |
| `Colors.swift:97` | `shadowColor.opacity(0.06)` 硬编码而非使用 `Spacing.shadowOpacity` |
| `Spacing.swift` ↔ `DesignSystem+*.swift` | 大量冗余转发层 |
| `AppCard.swift:53-73,192-211` | CGFloat→令牌后向兼容构造器 |

### 5.3 AppStore 环境注入过多

- **文件**: `Sources/App/Core/ZhiYuApp.swift:30-49`
- **问题**: `ContentView()` 接收 **17 个**环境对象
- **建议**: 减少环境注入，考虑 Environment 容器

### 5.4 `AppRoute` 枚举过大

- **文件**: `Sources/App/Navigation/Router.swift:24-153`
- **问题**: 20 个 case，`id` 属性约 30 行
- **建议**: 使用关联值协议拆分

### 5.5 `AppEnvironment.init()` 函数过长

- **文件**: `Sources/App/Core/AppEnvironment.swift:33-143` (110 行)
- **问题**: 包含数据库迁移、DI 注册、Store 初始化等所有步骤
- **建议**: 拆分为私有方法

### 5.6 跨平台文件命名不统一

| 文件 | 命名风格 |
|------|----------|
| `DesignSystem+SpacingToken.swift`, `DesignSystem+RadiusToken.swift` | `DesignSystem+Feature` 前缀 |
| `Colors.swift`, `Spacing.swift`, `Typography.swift` | 纯 `Feature` 命名 |
| `DesignSystem+Shadow.swift` vs `DesignSystem+Shadows.swift` | 单复数不一致 |

### 5.7 注释掉的代码

| 文件 | 行号 |
|------|------|
| `AdaptiveSidebarView.swift` | 108 |
| `LockOverlayView.swift` | 159 |

### 5.8 调试打印残留

- **文件**: `Tests/Integration/VaultDataIsolationTests.swift` (15+ 处 `print("🔍 [Debug] ...")`)
- **文件**: `Tests/Integration/MultiVaultSwitchTests.swift` (多处 `print`)
- **建议**: 移除或使用 `#if DEBUG` 包裹

### 5.9 共享测试资源重复

- `ImportBoundaryTests.swift:22-48` 和 `ImportSynthesisLinkTests.swift:23-45` 有几乎完全相同的数据库迁移代码
- `AuthServiceTests.swift:348-361` 和 `NetworkClientTests.swift:207-221` 有相同的 `httpBodyStreamData()` 扩展

### 5.10 函数过长

| 文件 | 函数 | 行数 |
|------|------|------|
| `KnowledgeStorePerformanceTests.swift:37-142` | `testOneHundredThousandNodesFTSRetrievalLatency` | 107 |
| `LinkService.swift:106-176` | `hybridSearchWithDiagnostics` | 70 |
| `IngestService.swift:33-124` | `ingestRawContent` | ~80 |
| `MultiVaultSwitchTests.swift:87-171` | `testConcurrencyVaultSwitchingStability` | 85 |
| `WorkflowService.swift` | `syncToReminders` | 72 |

---

## 6. 跨层访问违规

### 6.1 已确认违规 (影响架构完整性)

| # | 源文件 | 层 | 引用了 | 目标层 | 说明 |
|---|--------|-----|--------|--------|------|
| 1 | `Core/Base/Protocols/RouterProtocol.swift` | **L0** | `ToolItem` (AppStore/AppModels) | **L3** | 路由协议引用 App 层类型 |
| 2 | `Core/Base/Protocols/RouterProtocol.swift` | **L0** | `AppTab` (App/AppTab.swift) | **L3** | 同上 |
| 3 | `Core/Base/Protocols/LLMProtocols.swift:29` | **L0** | Domain 协议 | **L2** | 基础设施协议引用领域类型 |
| 4 | `Infrastructure/Storage/Sync/iCloudSyncCoordinator.swift:21-22` | **L1** | App/Store/AppStore | **L3** | 存储层引用 UI 层 |
| 5 | `Domain/Models/RAGModels.swift:12` | **L1.5** | `import GRDB` | **L0** | 领域模型依赖存储框架 |
| 6 | `Domain/Models/PluginRecord.swift:12` | **L1.5** | `import GRDB` | **L0** | 同上 |
| 7 | `Domain/Models/PluginRecordFTS.swift:12` | **L1.5** | `import GRDB` | **L0** | 同上 |
| 8 | `Features/Knowledge/Vault/Service/VaultService.swift:13-14` | **L2** | `import GRDB` + `import SwiftUI` | **L0+L3** | 业务服务双跨层 |
| 9 | `Domain/Models/KnowledgePage.swift:159,164` | **L1.5** | `AppLinkProcessor`, `PageContentUtility` | **L0/L1** | 领域模型引用基础设施 |
| 10 | `Domain/RAG/KnowledgeIngestPipeline.swift:80,99,133` | **L1.5** | `TaskCenter.shared` | **L2** | **逆向依赖** 下层依赖上层 |
| 11 | `Domain/RAG/RAGOrchestrator.swift:53,80` | **L1.5** | `AppConfig.AI.defaultModel` | **L3** | 领域层引用 App 配置 |
| 12 | `Domain/RAG/RAGOrchestrator.swift:36,79` | **L1.5** | `SourceStore.shared` | **L2** | 领域层引用 Feature 单例 |
| 13 | `Features/Knowledge/System/Model/KnowledgeStore.swift:11` | **L2** | `import SwiftUI` | **L3** | 非 View 文件引入 UI 框架 |
| 14 | `Core/Base/Protocols/EmbeddingProvider.swift` | **L0** | `KnowledgePage`, `PageChunk` | **L2** | L0 协议引用领域模型 |
| 15 | `Core/Base/Protocols/StoreCapabilities.swift` | **L0** | `KnowledgePage` | **L2** | 同上 |
| 16 | `Core/Base/Protocols/SyncProtocols.swift` | **L0** | `KnowledgePage`, `LogEntry` | **L2** | 同上 |
| 17 | `Core/Base/Utils/SnapshotService.swift:32` | **L0** | `KnowledgePage` | **L2** | L0 工具引用领域模型 |
| 18 | `Core/System/Accessibility/AccessibilityService.swift:31` | **L0** | `KnowledgePage` | **L2** | 同上 |

### 6.2 边界案例 (策略性权衡)

| 文件 | 引用 | 说明 |
|------|------|------|
| `Domain/Models/PageType.swift` | `L10n.CoreModels.xxx` | Domain 模型自带 displayName，可接受 |
| `Domain/Models/VaultTheme.swift` | `L10n.Shared.themeStandard` | 同上 |
| `KnowledgePageFTS.swift` | `import GRDB` | FTS5 虚拟表映射需要 FetchableRecord |

---

## 7. 层内违规明细

### L0 — Core (75 文件, 5574 行)

| 问题 | 数量 |
|------|------|
| `@unchecked Sendable` | 10+ 处 |
| 日志字符串碎片化 | 25+ 处 |
| 未使用 `import Combine` | 3 文件 |
| 魔鬼字符串 | 3 处 (AppConstants 缺失) |
| 死代码 | 3 处 (Logger subscriptions, AppKeyboardShortcuts, etc.) |
| 文件头注释与内容不符 | 5 文件 |
| 跨层协议引用 L2/L3 类型 | 4 个协议文件 |

### L0-L1 — Infrastructure (84 文件, 13831 行)

| 问题 | 数量 |
|------|------|
| God Class | 2 个 (PluginRegistry 654行, OnDeviceLLMService ~500行) |
| `@unchecked Sendable` | 14+ 类 |
| 重复 `dbWriter` 模式 | 4 个 Repository |
| Stub 实现 | OllamaAdapter (generate/stub, chatStream/空流) |
| 硬编码 UserDefaults 键 | PromptService 6 处 |
| 轮询反模式 | SQLiteStore.dbWriter |

### L1.5 — Domain (48 文件, 3670 行)

| 问题 | 数量 |
|------|------|
| import GRDB | 3 文件 |
| 逆向依赖 (L1.5 → L2) | KnowledgeIngestPipeline → TaskCenter |
| 硬编码中文提示词 | AIContentEnricher 2 处 |
| 硬编码魔法数字 | KnowledgeIngestPipeline 4 处 |
| 空协议 | TagStoreProtocol |
| ISP 违反 | RAGGovernanceRepository (22 方法) |
| 函数过长 | hybridSearchWithDiagnostics (70 行) |

### L2-L3 — Features (150 文件, 29553 行)

| 子模块 | 文件数 | 健康度 | 主要问题 |
|--------|--------|--------|----------|
| Features/AI/Chat | 7 | 🟡 | AIWorkflowStore 依赖过多、ProcessInfo 检查重复 |
| Features/AI/Synthesis | 6 | 🟡 | Actor init 期 DI 解析、UserDefaults 存储 |
| Features/AI/Quiz | 2 | 🟢 | - |
| Features/Knowledge/Graph | 14 | 🟡 | 硬编码字符串, 大型视图 |
| Features/Knowledge/Ingest | 16 | 🟢 | - |
| Features/Knowledge/NotebookHub | 7 | 🟡 | SwiftUI 在非 View 文件, 颜色硬编码 |
| Features/Knowledge/Vault | 2 | 🟠 | 双跨层违规 |
| Features/Knowledge/SourceView | 2 | 🟠 | 硬编码本地化字符串 |
| Features/Insight | ~20 | 🟡 | LintView 630行 |
| Features/System | ~30 | 🟢 | Auth Strategy 模式良好 |

### L3 — App (20 文件, 3668 行)

| 问题 | 数量 |
|------|------|
| God Class (AppStore) | 1 |
| 文件 > 300 行 | 4 |
| 环境注入过多 (17 个) | ZhiYuApp.swift |
| AppRoute 枚举 20 个 case | Router.swift |

### L3 — Shared (96 文件, 10105 行)

| 问题 | 数量 |
|------|------|
| #if os 散落 | 39 处 |
| 文件重复 | Shadow/Shadows、StatCard/AppMetricCard、AppTextEditor/PlatformTextEditor |
| customSize* 无意义常量 | 20+ 个 |
| system(size:) 替代 Dynamic Type | 10+ 处 |
| 无障碍缺失 | 4+ 核心组件 |
| watchOS 硬编码强调色 | 1 处 |

---

## 8. 文件/模块健康度矩阵

```
模块                  文件数  P0  P1  P2  P3  健康度
─────                 ─────  ──  ──  ──  ──  ─────
Core/                   75   1   8  12  10   🟡
Infrastructure/         84   3  12  14   8   🟡
├── LLM/               21   1   6   5   2   🟡
├── Storage/           30   1   3   4   3   🟡
├── Plugins/            8   0   2   2   1   🟡
├── Processors/        13   0   0   3   2   🟢
└── VectorDB/           2   1   1   1   0   🟡
Domain/                 48   4   5   5   3   🟡
App/                    20   3   4   6   5   🟠
Features/AI/            23   1   4   6   4   🟡
Features/Knowledge/     57   2   6   8   5   🟡
Features/Insight/      ~20   0   2   4   2   🟡
Features/System/       ~30   0   1   3   2   🟢
Shared/                 96   0   5  18  20   🟡
├── DesignSystem/      10   0   1   3   4   🟡
├── UIComponents/      72   0   3  12  14   🟡
└── Platforms/Adaptor/  1   0   1   2   1   🟠
Platforms/              50   0   0   2   3   🟢
Localization/           41   0   1   1   3   🟢
Tests/                  93   0   5  12   6   🟡
────────────────────────────────────────────────
总计                   564  10  44  76  56   🟡
```

---

## 9. SOLID 原则违规汇总

### SRP — 单一职责原则违反

| 严重度 | 文件 | 职责数 | 违规说明 |
|--------|------|--------|----------|
| P0 | `AppStore.swift` (554行) | 10+ | Store + 协议扩展 + 转发方法 |
| P0 | `RAGGovernanceRepository` | 22 方法 | Token + 评估 + 检索 + 延迟 + 反馈 |
| P1 | `PluginRegistry.swift` (654行) | 8+ | 注册 + 查询 + 沙箱 + 验证 |
| P1 | `LLMService` | 10+ | 推理 + 配置 + 状态管理 |
| P1 | `EmbeddingProvider` 协议 | 13 方法 | 缓存 + 搜索 + chunk 管理 |
| P1 | `AnyPageStore` 协议 | 18 方法 | CRUD + 搜索 + 同步 + 标签 + 维护 |
| P2 | `KnowledgePageManager.swift` | 7 | CRUD + 撤销 + 处理器 + 标签 |
| P2 | `ChatCoordinator.swift` | 3 | 导航 + 状态 + 业务 |
| P2 | `AppToast.swift` | 6 | Model + View + Modifier + Manager |
| P3 | `AppCard.swift` | 5 变体 | 5 个 Card 变体在 1 文件 |
| P3 | `AppRows.swift` | 10 组件 | 10 个不同组件 |

### OCP — 开闭原则违反

| 文件 | 问题 |
|------|------|
| `AppLayoutComponents.swift` | 新平台需添加 #if os 分支 |
| `PlatformModifiers.swift` | 每个 modifier 都有 #if os 分支 |
| `setupFullMockEnvironment()` | 每加新服务需修改此 170 行方法 |

### DIP — 依赖倒置原则违反

| 文件 | 问题 |
|------|------|
| `Domain/Models/RAGModels.swift` | 依赖 GRDB 具体类而非协议 |
| `VaultService.swift` | 依赖 GRDB + SwiftUI 具体框架 |
| `@Inject` 模式 | 全局 Service Locator 反模式 |
| `KnowledgePageManager` | 7 个 @Inject 注入具体类而非协议 |
| `KnowledgePage.swift` | 直接调用 L0/L1 具体类 |
| `ComponentSnapshots.swift` | 依赖具体 `shared` 单例 |

### ISP — 接口隔离原则违反

| 文件 | 问题 |
|------|------|
| `RAGGovernanceRepository.swift` | 22 个方法，应拆 5 个协议 |
| `EmbeddingProvider.swift` | 13 个方法，应拆 2-3 个协议 |
| `AnyPageStore` (StoreCapabilities.swift) | 18 个方法，应拆 3-4 个协议 |

---

## 10. 平台适配分析

### Adaptor 层状态

- **`Shared/Platforms/Adaptor/`** 仅 1 个文件 (`CrossPlatform.swift`, 59 行)
- `AppPasteboard`: 使用 `PasteboardProtocol` DI (✅ 正确模式)
- `AppImage`: 使用 `#if os` 宏 (❌ 应通过 ViewFactory)
- `AppScreen`: 使用 `#if os(watchOS)` (❌ 未抽象)

### 缺失的适配器

| 当前方式 | 问题 | 建议 |
|----------|------|------|
| `UIImpactFeedbackGenerator` 直用 | iOS-only | `HapticFeedbackProtocol` via @Inject |
| `PlatformModifiers.swift` 13 个 #if os | 散落 | `PlatformRegistrar` 协议 |
| `MarkdownTextView` 3 个 #if os | 散落 | 环境注入 |

### 跨平台复用率

| 维度 | iOS | macOS (Catalyst) | watchOS |
|------|-----|------------------|---------|
| 平台特有文件 | 27 | 5 | 14 |
| 代码复用 | ~85% | ~95% (复用了 iOS 的 PDF 等服务) | ~60% (大量 stubs) |
| 特有行数 | ~2,900 | ~240 | ~1,000 |
| 独立注册器 | iOSPlatformRegistrar | MacPlatformRegistrar | WatchPlatformRegistrar |

---

## 11. 本地化 L10n 审计

### 整体状态

| 指标 | 值 |
|------|-----|
| .xcstrings 文件数 | 16 |
| L10n 扩展文件数 | 41 |
| 硬编码中文 | **0** (架构规则严格执行) |
| 合规度 | ✅ 98% |
| 纯英文硬编码字符串 | 6 处 (P2 违规) |
| 缺失 Key 的字符串 | 3 处 (SourceView) |

### 违规明细

| 文件 | 字符串 | 正确方式 |
|------|--------|----------|
| `SourceView.swift:43` | `Text("Source_View")` | `Text(L10n.Knowledge.SourceView.title)` |
| `SourceView.swift:46` | `Text("Original_Source_Content")` | `Text(L10n.SourceView.originalContent)` |
| `SourceView.swift:69` | `Text("No_Source_Found")` | `Text(L10n.SourceView.noSourceFound)` |
| `Graph3DView.swift:112` | `Text("FPS: \(Int(fps))")` | 需要本地化模板 |
| `Graph3DComponents.swift:25` | `Text("Not Supported")` | `Text(L10n.Common.notSupported)` |
| `Graph3DComponents.swift:533` | `Text("View_Page")` | `Text(L10n.Graph.viewPage)` |
| `SearchSheets.swift:230,260` | `Text("FTS5 SQLite")`, `Text("HNSW / Vector")` | 技术术语需 L10n |
| `AIViewProvider.swift:31` | `Text("Quiz_View")` | `Text(L10n.AI.quizView)` |
| `AIContentEnricher.swift:142,166` | 中文提示词硬编码 | `L10n` 或 `PromptRegistry` |

### 设计问题

1. `L10n+Common.swift` 中 `Stat`(107行) 与 `Stats`(118行) 混淆
2. `Common.xcstrings` 10,112 行包含标点符号条目 `" "`, `"— "`, `"·"` 作为本地化 key
3. 旧 `.strings` 文件 (en.lproj, zh-Hans.lproj) 与 `.xcstrings` 并存
4. `LogAction.export` rawValue `"action.export"` 前缀与其他 case 的 `logAction.xxx` 不一致

---

## 12. 测试质量审计

### 测试分布

| 目录 | 文件 | 行数 | 状态 |
|------|------|------|------|
| Unit/ | 50+ | ~8,500 | ✅ 覆盖 8 个子模块 |
| Integration/ | 9 | ~2,200 | ✅ 含 RAG/CloudKit/Sync |
| UI/ | 10 | ~3,500 | ⚠️ iOS-only |
| SnapshotTests/ | 2 | ~350 | ✅ |
| Performance/ | 4 | ~500 | ✅ |
| **Boundary/** | **0** | **0** | **❌ 不存在** |
| Shared/ | 5 | ~950 | ✅ 含 TestMocks |

### 严重问题

1. **sleep 等待反模式** (10+ 处) — RAGPipelineTests、AppStoreTests 等
2. **`setupFullMockEnvironment()` 170 行** — 巨型方法，违反 SRP
3. **Mock 重复** — 3 个独立 LLM Chat Mock
4. **测试命名/断言矛盾** — `KnowledgeIngestPipelineTests.swift:49`
5. **无断言测试** — `PluginSandboxTests`、`AuthIntegrationTests`
6. **`SnapshotHelper.swift` 死代码** — 未被使用
7. **`measure` + `XCTestExpectation` 反模式** — `RAGPerformanceTests.swift`
8. **调试打印残留** — 15+ 处 `print` 在集成测试中
9. **共享测试资源重复** — 数据库迁移代码、URLRequest 扩展

### Mock/Stub 使用

- `Tests/Shared/TestMocks.swift`: 406 行, 提供 Logger/LLMService/CollaborationProvider mocks
- Mock 使用合理, 但 Integration 测试不足 (9 个文件对于 84 个 Infra 文件不够)

### 覆盖缺口

| 模块 | 未测试内容 | 风险 |
|------|-----------|------|
| AI | `PromptService` 的真实 Prompt 模板渲染逻辑 | 高 |
| AI | `LLMContextBuilder` 的复杂 context window 管理 | 高 |
| Knowledge | `KnowledgePageManager` 的业务编排逻辑 | 高 |
| Storage | 真实 SQLite 并发写入下的事务回滚场景 | 中 |
| System | `DeepLinkService` 的 URL 解析路由 | 高 |
| Plugins | `PluginMarketService` 市场下载/安装流程 | 中 |
| RAG | `RAGOrchestrator` 的混合搜索加权逻辑 | 中 |
| UI | WatchOS 平台 UI 测试 | 中 |

---

## 13. 响应式架构迁移进度

### @Observable 迁移状态

| 状态 | 类型 | 模块 |
|------|------|------|
| ✅ 已迁移 | `AppStore`、`Router`、`IngestStore`、`SynthesisStore`、`SearchStore`、`KnowledgeStore` | App、Features |
| ❌ 遗留 `ObservableObject` | `TaskCenter`、`MedalService`、`IngestQueue`、`CollaborationService` | Features |
| ❌ 遗留 `@EnvironmentObject` | `themeManager` 在 SynthesisView、ChatView、GraphView、SearchSheets 中 | Features |
| ❌ 遗留 `@StateObject`/`@ObservedObject` | `llmService` 在 ChatView 中 | Features |

### Combine 遗留

`import Combine` 仍存在于 5+ 文件中但未使用 (AIWorkflowStore, KnowledgePageManager, ChatCoordinator, 等)

---

## 14. 废弃/死代码清单

| 文件 | 代码 | 状态 |
|------|------|------|
| `Logger.swift:171-176` | `setupSubscriptions()` 空 sink | 🔴 死代码 |
| `AppKeyboardShortcuts.swift` | 整个文件 | 🔴 死代码 |
| `AppStore.swift:552` | `clusters { [] }` | 🔴 未实现 |
| `OnboardingService.swift:94-97` | `completeOnboarding = finish()` | 🟡 冗余 |
| `AppWindowSceneDelegate.swift:50-58` | 5 个空 scene 回调 | 🟡 冗余 |
| `DemoDataGenerator.swift:130` | `generateStressTest` 空内容 | 🟡 未实现 |
| `iOSSecurityScopedStorage.swift:62-68` | `restoreURL()` 返回 nil | 🟡 空实现 |
| `OllamaAdapter.generate` | 返回 `"Ollama Result"` 固定字符串 | 🔴 Stub |
| `OllamaAdapter.chatStream` | 永不 yield 的空流 | 🔴 Stub |
| `TagStoreProtocol.swift` | 空协议 | 🔴 死代码 |
| `SnapshotHelper.swift` | 自定义快照实现 (未被使用) | 🔴 死代码 |
| `ServiceContainer.optionalResolve` | 与 `resolveOptional` 重复 | 🟡 冗余 |
| `TextChunker` 协议 | 3 行空协议 | 🟡 占位符 |
| `VectorIndexer.swift` | 30 行，完全委托给 EmbeddingManager | 🟡 冗余层 |
| `AdaptiveSidebarView.swift:108` | 注释掉的代码 | 🟢 小残留 |

---

## 15. 优先修复路线图

### 阶段 1: 架构违规修复 (P0, 预计 3-5 天)

| # | 任务 | 文件 | 工作类型 |
|---|------|------|----------|
| 1 | 迁移 ServiceContainer 至 actor | `Core/Base/ServiceContainer.swift` | 🔧 重构 |
| 2 | 修复 RouterProtocol 跨层引用 | `Core/Base/Protocols/RouterProtocol.swift` + `AppTab.swift` | 🔧 重构 |
| 3 | 移除 Domain Models 的 GRDB import | `Domain/Models/RAGModels.swift` 等 3 文件 | 🔧 重构 |
| 4 | 清理 VaultService 的 SwiftUI/GRDB import | `Features/Knowledge/Vault/VaultService.swift` | 🔧 清理 |
| 5 | 修复 SourceView 硬编码本地化 | `Features/Knowledge/SourceView/View/SourceView.swift` | 🐛 修复 |
| 6 | 拆分 RAGGovernanceRepository 协议 (22 方法) | `Domain/Protocols/RAGGovernanceRepository.swift` | 🔧 重构 |
| 7 | 解耦 KnowledgePage L0 依赖 | `Domain/Models/KnowledgePage.swift` | 🔧 重构 |
| 8 | 解耦 KnowledgeIngestPipeline → TaskCenter | `Domain/RAG/KnowledgeIngestPipeline.swift` | 🔧 重构 |
| 9 | 实现 OllamaAdapter 或标记为未实现 | `Infrastructure/LLM/LLMAdapters.swift` | 🐛 修复 |
| 10 | 替换 ZipUtility 为系统/三方库 | `Packages/UFPCore/Sources/UFPCore/Base/ZipUtility.swift`（已迁移至 UFPCore） | 🔧 重构 |
| 11 | 修复 KeychainService UserDefaults 回退安全性 | `Core/System/Security/KeychainService.swift` | 🔐 安全 |

### 阶段 2: Code Smell 修复 (P1, 预计 4-6 天)

| # | 任务 | 文件 | 工作类型 |
|---|------|------|----------|
| 12 | 拆分 AppStore God Class | `App/Store/AppStore.swift` | 🔧 重构 |
| 13 | 消除 @unchecked Sendable | 全局 20+ 文件 | 🔧 重构 |
| 14 | 修复日志字符串碎片化 (25 处) | Logger, EmbeddingManager, SecurityManager 等 | 🧹 清理 |
| 15 | 合并重复 LLM Mock | TestMocks + MockLLMServices + AISynthesisServiceTests | 🧹 清理 |
| 16 | 消除 sleep 等待 (10+ 处) | AppStoreTests, RAGPipelineTests 等 | 🐛 修复 |
| 17 | 抽取 ProcessInfo 检查为 UITestingHelper | LLMService, ChatLLMService | 🔧 重构 |
| 18 | 拆分 setupFullMockEnvironment() 170 行 | Tests/Shared/TestMocks.swift | 🔧 重构 |
| 19 | 修复 KnowledgeIngestPipelineTests 断言矛盾 | Tests/Unit/Base/KnowledgeIngestPipelineTests.swift | 🐛 修复 |
| 20 | 为 PluginSandboxTests 添加断言 | Tests/Unit/Plugins/PluginSandboxTests.swift | 📝 新增 |
| 21 | 拆分 EmbeddingProvider 协议 | Core/Base/Protocols/EmbeddingProvider.swift | 🔧 重构 |
| 22 | 拆分 AnyPageStore 协议 | Core/Base/Protocols/StoreCapabilities.swift | 🔧 重构 |
| 23 | 消除 IngestLLMService/IngestProcessor 重复 | Infrastructure/LLM + Processors | 🔧 重构 |
| 24 | 修复 SQLiteStore 轮询反模式 | Infrastructure/Storage/SQLiteStore.swift | 🔧 重构 |
| 25 | 解耦 RAGOrchestrator → AppConfig | Domain/RAG/RAGOrchestrator.swift | 🔧 重构 |

### 阶段 3: 代码质量提升 (P2, 预计 5-8 天)

| # | 任务 | 文件 | 工作类型 |
|---|------|------|----------|
| 26 | 统一 @Observable 迁移 (遗留 ObservableObject) | TaskCenter, MedalService, IngestQueue 等 | 🔧 迁移 |
| 27 | 合并 AppModels 重复定义 | `App/Store/AppStore.swift` + `AppModels.swift` | 🧹 清理 |
| 28 | 合并 Shadow/Shadows 文件 | Shared/DesignSystem/Tokens/ | 🧹 清理 |
| 29 | 合并 StatCard/AppMetricCard | Shared/UIComponents/Cards/ | 🔧 重构 |
| 30 | 消除 customSize* 常量 (20+ 个) | Shared/DesignSystem/Tokens/ | 🔧 重构 |
| 31 | 消除 system(size:) 使用 Dynamic Type 替代 | AppTextEditor, AppErrorView 等 | 🐛 修复 |
| 32 | 合并 Stat/Stats L10n 枚举 | Localization/Extensions/L10n+Common.swift | 🧹 清理 |
| 33 | 修复 KnowledgePage.displaySourceName | Domain/Models/KnowledgePage.swift | 🔧 重构 |
| 34 | 修复 PromptService 硬编码 UserDefaults 键 | Infrastructure/LLM/PromptService.swift | 🐛 修复 |
| 35 | 添加无障碍支持 | AppPrimaryButton, AppCard 等 4+ 组件 | 📝 新增 |
| 36 | 修复 Hasher 后备向量确定性 | Infrastructure/VectorDB/EmbeddingManager.swift | 🔧 重构 |
| 37 | 缓存 ThemeManager.accentColor | Shared/DesignSystem/Themes/ThemeManager.swift | 🔧 重构 |
| 38 | 处理 watchOS 强调色 | Shared/DesignSystem/Tokens/Colors.swift | 🐛 修复 |
| 39 | 移除 SnapshotHelper 死代码 | Tests/SnapshotTests/SnapshotHelper.swift | 🧹 清理 |
| 40 | 修复 measure + XCTestExpectation 反模式 | Tests/Performance/RAGPerformanceTests.swift | 🔧 重构 |
| 41 | 移除调试打印 | Tests/Integration/VaultDataIsolationTests 等 | 🧹 清理 |
| 42 | 抽取共享测试辅助方法 | ImportBoundaryTests + ImportSynthesisLinkTests | 🔧 重构 |
| 43 | 修复 AuthIntegrationTests 断言 | Tests/Integration/AuthIntegrationTests.swift | 📝 新增 |
| 44 | 拆分 AppRoute 枚举 | App/Navigation/Router.swift | 🔧 重构 |

### 阶段 4: 持续改进 (P3, 长期维护)

| # | 任务 | 说明 |
|---|------|------|
| 45 | 修正 JSDoc 风格注释为标准 `///` | LinkService, Date+App, TextChunkerProcessor |
| 46 | 移除冗余注释 (Animations 弹簧变更历史) | Shared/DesignSystem/Tokens/Animations.swift |
| 47 | 减少 ZhiYuApp.swift 环境注入 (17 个) | App/Core/ZhiYuApp.swift |
| 48 | 拆分 AppEnvironment.init() (110 行) | App/Core/AppEnvironment.swift |
| 49 | 统一跨平台布局 (39 处 #if os) | Shared/UIComponents/Modifiers |
| 50 | 合并 AppCard 5 变体为配置化组件 | Shared/UIComponents/Cards |
| 51 | 移除废弃代码 (Logger 空订阅, AppKeyboardShortcuts, 等) | 代码整洁 |
| 52 | 移除未使用的 import Combine | 导入整洁 |
| 53 | 统一 LogAction rawValue 命名风格 | Core/Base/Models/LogAction.swift |
| 54 | 实现 VectorIndexer 或移除冗余层 | Infrastructure/VectorDB/VectorIndexer.swift |
| 55 | 修复 TextChunker 空协议 | Core/Base/Protocols/TextChunker.swift |
| 56 | 统一设计系统文件命名 (DesignSystem+* vs Feature.swift) | Shared/DesignSystem/Tokens/ |

---

## 16. 新增发现汇总 (v2.0)

### 16.1 架构层 (新增 8 项)

| # | 类型 | 发现 | 严重度 |
|---|------|------|--------|
| 1 | 逆向依赖 | KnowledgeIngestPipeline → TaskCenter (L1.5→L2) | P0 |
| 2 | 跨层 | KnowledgePage → AppLinkProcessor/PageContentUtility | P0 |
| 3 | ISP 违反 | RAGGovernanceRepository 22 方法 | P0 |
| 4 | ISP 违反 | EmbeddingProvider 13 方法 | P1 |
| 5 | ISP 违反 | AnyPageStore 18 方法 | P1 |
| 6 | 逆向依赖 | RAGOrchestrator → AppConfig (L1.5→L3) | P2 |
| 7 | 空协议 | TagStoreProtocol (0 方法) | P1 |
| 8 | 重复实现 | IngestLLMService ↔ IngestProcessor | P1 |

### 16.2 代码质量 (新增 12 项)

| # | 类型 | 发现 | 严重度 |
|---|------|------|--------|
| 9 | 碎片化 | 日志字符串碎片化 25+ 处 | P1 |
| 10 | Stub | OllamaAdapter 返回固定字符串/空流 | P0 |
| 11 | 硬编码 | AIContentEnricher 中文提示词 | P1 |
| 12 | 轮询 | SQLiteStore dbWriter 忙等 | P1 |
| 13 | 非确定性 | Hasher 后备向量跨运行不稳定 | P2 |
| 14 | 安全 | KeychainService UserDefaults 明文回退 | P0 |
| 15 | 安全 | SecureEnclave 自密钥协商 | P2 |
| 16 | 并发 | AISynthesisService Actor init 期 DI 解析 | P1 |
| 17 | 重复 | ProcessInfo 参数检查 7+ 处 | P1 |
| 18 | 重复 | AppTextEditor ↔ PlatformTextEditor | P2 |
| 19 | 重复 | StatCard ↔ AppMetricCard | P2 |
| 20 | 无意义 | customSize* 20+ 常量 | P2 |

### 16.3 设计系统 (新增 8 项)

| # | 类型 | 发现 | 严重度 |
|---|------|------|--------|
| 21 | 重复 | Shadow ↔ Shadows 文件 | P2 |
| 22 | 重复 | Stat ↔ Stats L10n 枚举 | P2 |
| 23 | 硬编码 | system(size:) 替代 Dynamic Type (10+ 处) | P2 |
| 24 | 缺失 | 无障碍标签 (4+ 核心组件) | P2 |
| 25 | 无缓存 | ThemeManager.accentColor 每次读取 UserDefaults | P2 |
| 26 | 硬编码 | watchOS 强调色绕过 ThemeManager | P2 |
| 27 | 冗余 | Spacing 转发层 (Spacing.* → DesignSystem.*) | P3 |
| 28 | 不一致 | DesignSystem 文件命名双风格 | P3 |

### 16.4 测试层 (新增 10 项)

| # | 类型 | 发现 | 严重度 |
|---|------|------|--------|
| 29 | 反模式 | sleep 等待 (10+ 处) | P1 |
| 30 | SRP 违反 | setupFullMockEnvironment() 170 行 | P2 |
| 31 | 重复 | 3 个独立 LLM Chat Mock | P2 |
| 32 | 矛盾 | KnowledgeIngestPipelineTests 名/断言不符 | P2 |
| 33 | 缺失 | PluginSandboxTests 无断言 | P2 |
| 34 | 缺失 | AuthIntegrationTests 无断言 | P2 |
| 35 | 死代码 | SnapshotHelper (未被引用) | P2 |
| 36 | 反模式 | measure + XCTestExpectation | P2 |
| 37 | 残留 | 调试 print 语句 15+ 处 | P3 |
| 38 | 重复 | 共享测试辅助方法未抽取 | P3 |

### 16.5 文档更新 (新增 2 项)

| # | 类型 | 发现 | 严重度 |
|---|------|------|--------|
| 39 | SDL 候选 | RetryTask, VectorMath, Localized, PromptSanitizer, JailbreakDetector 等 9 个可抽取为独立包 | P3 |
| 40 | 配置 | `AppModel.evaluator` rawValue 与配置 JSON 中 `"gpt-4o"` 可能不一致 | P2 |

---

> **总结**: 全项目 564 个源文件分析完毕。**P0 问题 10 个，P1 问题 44 个，P2 问题 76 个，P3 问题 56 个。** 较 v1.0 (2026-06-10) 新增发现 240+ 项，聚焦于协议 ISP 违反、日志碎片化、测试 sleep 反模式、Mock 重复、设计系统重复文件等深层问题。整体架构设计优秀，执行层面存在历史债务。
>
> **最需优先修复的 5 项**: (1) `RAGGovernanceRepository` 协议拆分, (2) `KnowledgeIngestPipeline` 逆向依赖解耦, (3) `OllamaAdapter` stub 实现修复, (4) 日志字符串碎片化集中清理, (5) 测试 sleep 等待替换。

<!-- 版本: 2.0.0 / 2026-06-13 -->
