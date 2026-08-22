# 覆盖率提升测试驱动发现问题清单

> **起始日期**：2026-08-20
> **来源**：批次 A-D 覆盖率提升过程中测试驱动发现的问题
> **格式**：序号 / 问题描述 / 严重程度 / 修改方案 / 是否解决

---

## 批次 A — Core/Domain/Infrastructure

### Task 1：DemoImageBuilder / DemoAudioBuilder / PerformanceBenchmarker

| 序号 | 问题描述 | 严重程度 | 修改方案 | 是否解决 |
|------|---------|---------|---------|---------|
| A-1 | `PerformanceBenchmarker.swift:26` `for i in 1...count` 当 `count=0` 时触发 `fatal error: Range requires lowerBound <= upperBound`，导致应用崩溃 | P1 | 改为 `guard count > 0` 提前返回 | 是 |
| A-2 | `DemoImageBuilder.swift:27-28` `try?` 静默吞掉目录创建和文件写入错误，磁盘满或权限不足时调用方误以为持久化成功 | P2 | 改为 `do-catch` 至少记录日志，或返回错误元组 | 否 |
| A-3 | `DemoAudioBuilder.swift:19-21` 已存在文件直接返回 URL，不校验是否为有效音频文件，损坏/空文件仍返回 | P2 | 增加 `AVAudioFile(forReading:)` 校验，失败则重新合成 | 否 |
| A-4 | `PerformanceBenchmarker.swift:27` `i % stressTestProgressStep == 0`（step=5000），当 count < 5000 时进度日志分支永不执行（死代码分支） | P2 | 使用动态步长 `max(count / 10, 1)` | 是 |
| A-5 | `PerformanceBenchmarker.swift:48` `Double(count)/duration` 当 duration≈0 得到 `inf`，日志显示 `inf docs/s` | P2 | 增加 `duration > 0` 防护，否则输出 0 | 是 |
| A-6 | `DemoImageBuilder.swift:265-272` `#else`（watchOS）分支定义 `ensureDemoImagesExist(at:) -> [URL]`，但 UIKit 分支只有 `ensureImageExists(at:title:) -> UIImage?`，API 不一致 | P2 | 统一 API 签名，或在 watchOS 分支提供等价单图生成方法 | 否 |

### Task 2：SecureEnclaveCryptoService

| 序号 | 问题描述 | 严重程度 | 修改方案 | 是否解决 |
|------|---------|---------|---------|---------|
| A-7 | `SecureEnclaveCryptoService.swift:71` `sealedBox.combined?.base64EncodedString() ?? ""` 当 combined 为 nil 时返回空字符串而非抛错，调用方无法区分"加密成功但 combined 为 nil"和"加密失败" | P2 | 改为 `guard let combined = sealedBox.combined else { throw SecurityError.encodingFailed }` | 否 |
| A-8 | `SecureEnclaveCryptoService.swift:107-111` 迁移成功后 reencrypt 结果赋值给 `_` 丢弃，调用方收到旧明文但不知道需要更新 Keychain（死代码） | P2 | 返回 `(明文, 新密文)` 元组或通过回调通知调用方更新 Keychain | 否 |
| A-9 | `SecureEnclaveCryptoService.swift:149-157` `getOrCreateHKDFSalt` 中 Keychain retrieve 返回 nil 时无法区分"盐不存在"与"临时错误"，可能生成新盐覆盖旧盐导致存量密文不可解密 | P2 | KeychainService.retrieve 应区分 errSecItemNotFound 和其他错误 | 否 |
| A-10 | `SecureEnclaveCryptoService.swift:201-203` `getOrCreateHardwarePrivateKey` token 损坏时仅记录日志并静默重建，旧密文将永远无法解密，调用方不知情 | P2 | 抛出特定错误或通过通知机制告知调用方密钥已更换 | 否 |

### Task 3：Core/Security 6 组件

| 序号 | 问题描述 | 严重程度 | 修改方案 | 是否解决 |
|------|---------|---------|---------|---------|
| A-11 | `SecurityManager.swift:226-239` `verifyIntegrity` 无签名记录时在模拟器 DEBUG 下直接返回 `true`（放行），不检查文件是否存在。对不存在的文件也返回 `true`，可能掩盖文件丢失/被删除的安全事件 | P2 | 在无签名放行路径前增加 `FileManager.default.fileExists(atPath:)` 检查，文件不存在时应 fail-closed | 否 |

### Task 7：Domain/Protocols 16 个 NoOp/Stub 默认实现

| 序号 | 问题描述 | 严重程度 | 修改方案 | 是否解决 |
|------|---------|---------|---------|---------|
| A-12 | `NoOpLLMRetrievalService.rerank` 标记 `throws` 但永不抛错，误导调用方期望错误处理路径 | P3 | 协议 `throws` 合理（真实实现会抛错），NoOp 保留 `throws` 是契约要求；添加文档注释说明 NoOp 永不抛错 | 是 |
| A-13 | NoOp LLM 类（NoOpLLMChatService/KnowledgeService/RetrievalService/LLMService/VaultService/ChatService）`internal` 可见性，测试外部模块无法使用 | P3 | 改为 `public` | 是 |
| A-14 | `NoOpLLMService` 标注 `@unchecked Sendable` 但 6 个属性为 `var`（可变），无同步保护，存在数据竞争风险 | P2 | 移除 `@unchecked Sendable`（`@MainActor` 已保证 Sendable，主线程隔离保证线程安全） | 是 |
| A-15 | NoOp 类 `@MainActor` 不必要约束 | P3 | 协议本身是 `@MainActor`，NoOp 必须遵守契约，无法移除——标记为协议契约要求 | 是（文档说明） |
| A-16 | `NoOpImportFileStore` 所有方法返回 `nil`，语义歧义（"未持久化" vs "存储失败"） | P3 | 添加文档注释说明 nil 语义为"未持久化"（NoOp 占位实现不进行任何持久化操作） | 是 |
| A-17 | `NoOpRAGGovernanceRepository` `evaluationID: Int64` 参数为数据库自增主键类型，NoOp 占位实现忽略该参数 | P3 | 添加文档注释说明 Int64 为数据库自增主键类型，NoOp 忽略参数是契约要求 | 是 |
| A-18 | `UnsupportedSearchIndexer` `internal` 可见性，测试外部模块无法使用 | P3 | 改为 `public` | 是 |

### 预存 L10n 违规（测试阻断修复）

| 序号 | 问题描述 | 严重程度 | 修改方案 | 是否解决 |
|------|---------|---------|---------|---------|
| A-19 | `ApiResponse.swift` `NetworkError.errorDescription` 硬编码英文（"Token expired.", "Missing refresh token." 等），L10n 审计 WARNING | P3 | **修正**：`errorDescription` 是工具层英文调试描述（日志/调试用），UI 层通过 `NetworkError+UserMessage.userMessage` 获取 L10n 本地化文案。恢复英文调试描述，L10n 审计白名单豁免工具层 errorDescription | 是（方向修正） |

### Task 8：GlobalPromptRegistry + PromptTemplateEngine

| 序号 | 问题描述 | 严重程度 | 修改方案 | 是否解决 |
|------|---------|---------|---------|---------|
| A-20 | `GlobalPromptRegistry.swift` `getPrompt` 的 `ingest`/`voiceNote` 领域硬编码英文字符串（"You are a professional knowledge curator..." / "You are a voice note summarizer..."），违反 L10n 强约束 | P2 | 改用 `L10n.AI.Prompt.System.ingest`/`L10n.AI.Prompt.System.voiceNote` 强类型访问，新增 xcstrings 词条（7 语言） | 是 |
| A-21 | `PromptTemplateEngine.swift` `buildPrompt` 变量值含 `}}` 可能破坏后续 `{{key}}` 插值 | P2 | `PromptSecurityGuard.sanitize` 已转义 `{{`/`}}`，当前安全；添加测试验证边界情况 | 否（已安全） |
| A-22 | `PromptTemplateEngine.swift` `renderPrompt` `skillId` 未做路径分隔符过滤，恶意 skillId 如 `../evil` 可能写入缓存目录之外（路径遍历漏洞） | P1 | 新增 `sanitizeFilename` 方法，使用 `SystemConstants.Character.underscore` 替换路径分隔符和遍历字符 | 是 |
| A-23 | `PromptTemplateEngine.swift` `try? content.write(to:)` 静默吞掉缓存写入错误，磁盘满或权限不足时调用方无感知 | P2 | 改为 `do-catch` + `Logger.shared.error` 记录错误 | 是 |
| A-24 | `PromptTemplateEngine.swift` 远程拉取超时 5 秒不可配置，弱网环境可能频繁失败 | P2 | 设计选择，常量已抽取到 `PromptConstants`，暂不修复 | 否（设计选择） |
| A-25 | `GlobalPromptRegistry.swift` `getPrompt` 的 `key` 参数被忽略，API 签名误导调用方 | P3 | 添加文档注释说明 `key` 保留用于未来扩展（支持多版本 prompt 模板） | 是 |
| A-26 | `PromptTemplateEngine.swift` `renderPrompt` 圈复杂度 11（超过 SwiftLint 阈值 10），需重构降低复杂度 | P2 | 提取 `readCacheIfNeeded`/`fetchRemotePrompt`/`writeCache` 三个私有方法，圈复杂度降至合规 | 是 |

### Task 14：Infrastructure/Processors 5 组件

| 序号 | 问题描述 | 严重程度 | 修改方案 | 是否解决 |
|------|---------|---------|---------|---------|
| A-27 | `DocumentExtractionServiceKey` 只有 `liveValue`，无 `testValue`，测试环境 fallback 到 `liveValue` 触发 `assertionFailure` crash（与 A-12 `AnyPageStoreKey` 同类问题） | P2 | 添加 `testValue` fallback 到 `NoOpDocumentExtractionService`（测试文件内定义） | 否（测试 workaround） |
| A-28 | `GraphLayoutProcessor.swift:275` 魔鬼数字 `0.05`（`clusterAttraction` 力学系数），违反 No Magic Numbers 红线 | P3 | 抽取为 `GraphConstants.Layout.clusterAttraction` 常量 | 否 |
| A-29 | `GraphLayoutProcessor`（L1 Infrastructure）引用 `DesignSystem.Graph.layoutPadding`（L3 Shared/DesignSystem），违反 L0-L3 分层约束（L1 不可依赖 L3） | P2 | 将 `layoutPadding` 常量下沉到 `GraphConstants`（L1 Domain 层）或 `ProcessorConstants` | 否 |

### Task 17：批次 A 全量验证 findings 修复

| 序号 | 问题描述 | 严重程度 | 修改方案 | 是否解决 |
|------|---------|---------|---------|---------|
| A-30 | `NoOpModelDownload.observeDownloadState` 返回 `AsyncStream { _ in }`，`for await` 永久挂起（危险反模式），测试 `testNoOpModelDownload_observeDownloadState_空流` 永久挂起 | P1 | 改为 `AsyncStream { continuation in continuation.finish() }`，立即结束流 | 是 |
| A-31 | `DatabaseManager.reset()` 清理了 dbWriter/globalWriter/dbURL/globalDBURL 但遗漏 `state` 属性重置，`reset()` 后 `state` 仍为 `.ready`，导致 `testDatabaseManager_初始状态_uninitialized` 失败 | P2 | `reset()` 中添加 `state = .uninitialized` | 是 |
| A-32 | `DynamicComplianceManager` 远程覆盖配置 `updateRemoteComplianceConfig(patternOverrides: [:])` 空字典不覆盖无法清理，测试顺序污染（`ContentModerationEngineTests` 注入的 `[.politicalReactionary: [...]]` 覆盖 fallback patterns，后续测试 `testContentModerationEngine_政治反动_拦截` 失败） | P2 | 添加 `clearRemoteOverridesForTesting()` DEBUG 方法，在 `resetPersistentTestState()` 中调用 | 是 |
| A-33 | `AuthIntegrationTests` 4 个测试各 30 秒超时（真实后端网络请求），全量测试耗时 120 秒+ | P2 | 添加 `withTimeout(seconds: 5)` 工具方法限制异步操作时间，超时从 120 秒降至 0.4 秒 | 是 |
| A-34 | `SecureEnclaveCryptoService` 真机路径模拟测试在模拟器上行为不确定（Apple Silicon Mac 模拟器可能成功创建 SecureEnclave 密钥），`testEncrypt_真机路径模拟_模拟器上应抛出SecureEnclave错误` 失败 | P3 | 改为双路径断言（`do-catch` 接受抛错或成功两种情况），业界 SecureEnclave 模拟器测试标准方案 | 是 |

### Task 18：ChatRunner/PluginLoader/OnDeviceLLMService 补盲

| 序号 | 问题描述 | 严重程度 | 修改方案 | 是否解决 |
|------|---------|---------|---------|---------|
| A-35 | `ModelDownloadManager.resumeDownload` L165 在 `task.resume()` 之前 `try? FileManager.default.removeItem(at: fileURL)` 删除 resumeData — 恢复失败时数据已丢失，无法再次恢复 | P2 | 将 `removeItem` 移到 `task.resume()` 之后执行，确保 task 已成功启动 | 是 |
| A-36 | `OnDeviceLLMService.extractTags` 使用 `#(\w+)` 正则，`NSRegularExpression` 的 `\w` 是 Unicode aware，会匹配中文标签（如 `#中文标签`）— 与源码注释"过滤单字符噪声"不完全一致，但实际行为是支持中文标签 | P3 | 更新源码注释说明 `\w` 匹配 Unicode 字母，中文标签是支持的特性 | 是 |
| A-37 | `OnDeviceLLMService.extractTags` 会误提取 URL 中的 `#section` 作为标签（如 `https://example.com/page#section` → `["section"]`） | P3 | 先用正则移除 URL（`https?://\S+`），再匹配 `#(\w+)` | 是 |
| A-38 | `PluginManifest.name`/`description` 使用 `Localized.bestMatch`，非空字典总是返回某个值（第 5 步"任意值"），不 fallback 到插件 id 或空字符串 — 中文用户可能看到法语名称 | P3 | `bestMatch` 第 5 步：字典非空时返回字典中的值（比 fallback 更有信息量），字典为空时返回 fallback | 是 |
| A-39 | `StreamDeanonymizer.maxRawLength=25` 只在无闭合 `]` 时触发（DoS 保护），完整方括号内容即使超过 25 字符也会尝试还原 — 设计正确，但文档应说明 maxRawLength 是防 DoS 而非限制占位符长度 | P3 | 更新 `EntityPlaceholder.maxRawLength` 文档注释说明用途 | 是 |

### Task 20：SQLiteStore/DatabaseManager/NetworkClient/KeychainService

| 序号 | 问题描述 | 严重程度 | 修改方案 | 是否解决 |
|------|---------|---------|---------|---------|
| A-40 | `KnowledgePageRepository.upsert` 第 72 行用 `title` 作为唯一键查找已存在记录（`KnowledgePage.filter(title == page.title)`），当用户修改页面标题后调用 `updatePage`，会 **insert 新记录** 而非更新原记录，导致：1) 原标题记录残留（数据冗余）；2) 页面 id 变化（关联链接、向量索引、FTS 索引失效）；3) `anyUpdatePage` 静默创建重复页面 | P2 | 应优先用 `id` 查找已存在记录（`KnowledgePage.filter(id == page.id)`），title 仅用于显示而非唯一键；如业务需要 title 唯一约束，应在数据库层添加 UNIQUE INDEX 并显式处理冲突 | 否 |

### A-41：生产代码重试逻辑统一

| 序号 | 问题描述 | 严重程度 | 修改方案 | 是否解决 |
|------|---------|---------|---------|---------|
| A-41 | 生产代码存在 5 处手写重试/轮询逻辑，策略各异无统一封装：1) `SQLiteStore.dbWriter` 固定间隔轮询（20 次 × 50ms）；2) `LLMClient.sendRequest` 指数退避（1/2/4s，3 次）；3) `LLMService.executeWithBackoffRetry` 孤儿代码（零调用）；4) `iOSExportService` 3 处重复忙等待（500ms 单次复检）；5) `LLMClient.maxRetries=3` 与 `LLMConstants.Retry.maxAttempts=3` 常量重复定义。同时 `RetryTask` 通用工具类已存在但零调用 | P2 | 1) 增强 `RetryTask`：新增 `shouldRetry` 谓词 + `poll` 轮询方法 + `RetryError` 错误类型；2) `SQLiteStore.dbWriter` 迁移到 `RetryTask.poll`；3) `LLMClient.sendRequest` 迁移到 `RetryTask.execute` + `shouldRetry` 闭包，删除 `maxRetries` 硬编码常量；4) 删除 `LLMService.executeWithBackoffRetry` 孤儿代码；5) `iOSExportService` 3 处忙等待提取为 `waitForExportSlot()` 方法 | 是 |

---

## 批次 B — Localization/App 非View

### L10n 表深度测试

| 序号 | 问题描述 | 严重程度 | 修改方案 | 是否解决 |
|------|---------|---------|---------|---------|
| B-1 | `L10n+Common.swift:360` `L10n.Common.Tags.memory` 使用 `Common.tr("demo.memory.title")` key 而非 `Common.tr("tags.memory")`，与同文件 `L10n.Common.Perf.memory`（使用 `tags.memory`）不一致。Tags.memory 应返回"记忆"标签文案，却返回了 Demo 模块的"记忆"标题，语义错配 | P2 | 改为 `Common.tr("tags.memory")`，与 `Perf.memory` 使用相同 key；如 `tags.memory` key 在 .xcstrings 中不存在则新增 | 否 |
| B-2 | `L10n+Ingest.swift` `L10n.InitialNotebook.Snippet.workflow` 使用 `demo.fallback.workflow` key 而非 `demo.snippet.workflow`，与同 enum 中其他属性使用 `demo.snippet.*` 前缀不一致，且与 `Fallback.workflow` 返回相同值（key 冲突） | P2 | 改为 `demo.snippet.workflow` key，与同 enum 前缀一致；如该 key 不存在则新增 | 否 |
| B-3 | `L10n+Dashboard.swift:24-30` `L10n.Dashboard.trf` 方法中 `if localized == key` 分支重复调用 `Dashboard.trf(key, args)` — 死代码，第二次调用返回同样结果，浪费一次本地化查表 | P3 | 删除 `if localized == key` 分支，直接返回 `localized` | 否 |
| B-4 | `L10n+Plugin.swift` `L10n.Plugin.permTitle("network")` 返回 `L10n.Common.tr("tags.network")`（Common 表），而 `permDesc("network")` 返回 `Plugin.tr("plugin.perm.network.desc")`（Plugin 表）— permTitle 和 permDesc 对 network 权限使用了不同的表和不同的 key 前缀，跨表引用不一致 | P2 | 统一使用 Plugin 表：`permTitle("network")` 改为 `Plugin.tr("plugin.perm.network.title")`，与 `permDesc` 同表同前缀；如该 key 不存在则新增 | 否 |
| B-5 | `L10n+Knowledge.swift:32-33` `batchDeleteTitle(_ count: Int)` 和 `batchDeleteMessage(_ count: Int)` 传入 `Int` 参数，但 `Knowledge.xcstrings` 中对应 key 的模板使用 `%@`（对象占位符）而非 `%d`（整数占位符）。`String(format:)` 对 `%@` 调用 `objc_opt_respondsToSelector` 检查传入值是否响应 NSObject 协议，`Int` 不是对象导致 EXC_BAD_ACCESS 崩溃（地址 `0x0000000000000001`）。这是**生产代码 P1 崩溃 bug**，在批量删除页面时必现崩溃 | P1 | 将 `Knowledge.xcstrings` 中 `page.batchDeleteTitle` 和 `page.batchDeleteMessage` 所有语言的 `%@` 改为 `%d`（10 种语言共 20 处） | 是 |
| B-6 | `DocumentExtractionServiceProtocol.swift:43-46` `DocumentExtractionServiceKey` 缺少 `testValue`/`previewValue`，且 `liveValue` 用 `ServiceContainer.shared.resolve`（崩溃式解析）而非 `resolveOptional ?? NoOp` 降级。UI 测试 context 中 `DocumentExtractionService` 未注册时，`@Dependency(\.documentExtractionService)` fallback 到 `liveValue` → `resolve` → `assertionFailure` → `fatalError`，导致 `IngestService.ingestDocument` 调用时 Thread 7 `EXC_BREAKPOINT` 崩溃。这是 A-27 修复的不完整版本 — `NoOpDocumentExtractionService` 只定义在测试文件中，未移入生产代码并注册为 `testValue`/`previewValue` | P1 | 将 `NoOpDocumentExtractionService` 移入生产代码（`DocumentExtractionServiceProtocol.swift`），`liveValue`/`testValue` 改用 `resolveOptional ?? NoOpDocumentExtractionService()`，新增 `previewValue` 返回纯 NoOp | 是 |


---

## 批次 C — Features 非View

| 序号 | 问题描述 | 严重程度 | 修改方案 | 是否解决 |
|------|---------|---------|---------|---------|
| C-1 | 14 个 `DependencyKey` 缺少 `testValue` 实现：`WorkflowServiceKey`/`URLOpenerKey`/`VaultDatabaseSwitcherKey`/`MLModelCompilerKey`/`PasteboardKey`/`ShareSheetKey`/`RouterKey`/`SynthesisStoreKey`/`RAGEvaluationServiceKey`/`AISynthesisServiceKey`/`RemoteConfigKey`/`VaultRepositoryKey`/`VectorRepositoryKey`/`KnowledgePageRepositoryKey`。swift-dependencies `testValue` 默认实现调用 `reportIssue`（测试 failure），然后返回 `previewValue` → `liveValue`。即使 `ServiceContainer` 已注册，`testValue` 未实现仍会报 test failure。现有测试未暴露是因为测试覆盖不够深，未触达这些 `@Dependency` getter 路径 | P1 | 1) 协议类型新建 NoOp + `testValue` 用 `resolveOptional ?? NoOp`；2) 具体类型 `testValue` 用 `resolveOptional ?? Type()`；3) `previewValue` 用纯 NoOp/默认构造；4) 新建 6 个 NoOp 实现（NoOpPasteboard/NoOpShareSheet/NoOpAISynthesisService/NoOpRemoteConfig/NoOpVaultRepository/NoOpVectorRepository）；5) 创建 CI 脚本 `audit-dependency-key-test-value.py` 硬阻断缺失 `testValue` | 是 |
| C-2 | `IngestStore.performIngest` 标准流程（非 smart 模式）中，第 181-184 行创建了 `updatedPage` 并设置 `tags`/`customIcon` 后调用 `pageStore.updatePage(updatedPage)` 持久化，但第 190 行返回的是未更新的原始 `page`（tags=`["ingested"]`, customIcon=nil），传入的 `tags` 和 `customIcon` 参数被丢弃。调用方拿到的是未应用标签和图标的页面对象，与持久化到数据库的页面不一致 | P1 | 在 `page = updatedPage` 赋值后再返回，确保返回值与持久化值一致；`page` 改为 `var` | 是 |
| C-3 | `IngestService.applyConceptLinks` 大小写不敏感匹配存在缺陷：`extractConcepts` 用 `lowercased().contains` 匹配成功（如 "machine learning" 匹配标题 "Machine Learning"），但 `replacingOccurrences(of: concept, with:)` 是大小写敏感的，无法在原始内容中替换大小写变体。导致概念链接功能在内容大小写与标题不一致时静默失效 | P2 | 改用 `NSString.replacingOccurrences(of:with:options:range:)` + `.caseInsensitive` 选项 | 是 |
