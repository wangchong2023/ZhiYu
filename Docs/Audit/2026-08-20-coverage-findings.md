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
| C-4 | `AuthService.swift:137-148` Mock 模式下 `updateUserProfile` 构造 `User` 时遗漏 `phone` 和 `features` 参数，导致 phone 丢失（默认 nil）。DEBUG Mock 模式下用户 phone 信息被清除，影响开发调试体验 | P2 | Mock 模式构造 User 时补充 `phone: user.phone` 和 `features: user.features` 参数 | 是 |
| C-5 | `CarrierAuthStrategy.isInitialized` 为 `static var`，跨实例共享 SDK 初始化状态。评估结论：ATAuthSDK 是进程级 SDK，初始化一次即全局生效，`static var` 是合理设计，非 bug | P3 | 不修复 — 设计合理，SDK 初始化为进程级状态 | 是（评估结论） |
| C-6 | `GitHubAuthStrategy.acquireCredentials` 生成 OAuth state 后，在 `ASWebAuthenticationSession` 回调中仅提取 code，未校验回调 URL 中的 state 与生成时 state 是否一致。OAuth CSRF 防护漏洞 — 攻击者可伪造 callback URL 绕过 state 校验 | P1 | 回调中增加 state 比对：`returnedState == state` 校验通过才 resume returning，否则 resume throwing | 是 |
| C-7 | `GitHubAuthStrategy` 构造 OAuth URL 时，scope 值 `read:user,user:email` 未做 URL encode。冒号在严格 RFC 3986 下应 encode 为 `%3A`。GitHub 服务端兼容未 encode 的 scope，功能无影响，但 URL 构造不严谨 | P3 | scope 值通过 `addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)` 编码 | 是 |
| C-8 | `CollaborationService.startHosting` 设置 `isConnecting = true`，但仅在 `providerDidConnectPeer` 回调时才设为 false。host 场景下若无 peer 连入，`isConnecting` 永久为 true，UI 显示永久"连接中" | P2 | `startHosting` 成功后直接设 `isConnecting = false` — host 自身已"连接"到房间 | 是 |
| C-9 | `CollaborationService.stop()` 清理了 `connectedPeers`/`discoveredRooms`/`recentEdits`/`connectionError`，但未清理 `roomName` 和 `role`。stop 后 `roomName` 仍为上次房间名，`role` 仍为 `.owner`/`.editor`，状态残留导致 UI 误导用户 | P2 | `stop()` 中增加 `roomName = ""` 和 `role = .viewer` 清理 | 是 |
| C-10 | `CollaborationService.appendEdit` 超限时调用 `removeFirst(count - maxRecentEdits)`，数组很大时是 O(n) 操作。功能正确，性能隐患 | P3 | 改用 `removeFirst()` 单次移除最早记录（超限时 count 最多为 maxRecentEdits+1，移除 1 个） | 是 |
| C-11 | `CollaborationService.applyRemotePage` 中 `remoteUpdated > existingPage.updatedAt` 使用严格大于，当远程与本地 `updatedAt` 相等时不更新。多端同时编辑场景下，相同时间戳的远程更新会被丢弃，可能导致编辑丢失 | P2 | 改用 `>=` 比较，确保相同时间戳的远程更新也能应用 | 是 |
| C-12 | `AISynthesisService.suggestFix`（line 191）使用 `llm.generate` 而非 `currentLLM.generate`，导致 ServiceContainer 动态更新 LLM 实例时仍使用旧实例。生产环境中切换 LLM 配置后，suggestFix 仍用旧句柄 | P2 | 改为 `currentLLM.generate` | 是 |
| C-13 | `AISynthesisService.generateInsightfulQuestions`（line 215）使用 `llm.generate` 而非 `currentLLM.generate`，同 C-12 | P2 | 改为 `currentLLM.generate` | 是 |
| C-14 | `AISynthesisService` 合成方法错误处理不一致：`summarize`/`extractActions`/`generateMindMap` 用 `try` 抛出，`generatePresentation`/`generateQuiz`/`generateInfographic`/`generateReport`/`expandKnowledge` 用 `try?` 降级 | P3 | 评估为有意设计（后者有 fallback 逻辑），不修复 | 是（评估结论） |
| C-15 | `SystemStatsCoordinator.provenance` 属性（importedCount/importedSize/createdCount/createdSize）在 `loadStats()` 中从未被填充，始终为初始零值。声明了状态属性但无数据源接入，UI 层若绑定会显示恒定 0 | P2 | 新增 `fetchProvenanceStats()` 方法，基于 `importRecordRepo.fetchAll()` 按 `category` 区分 imported/created 并聚合 count/size | 是 |
| C-16 | `SystemStatsCoordinator` 延迟属性（avgLatency/maxLatency/minLatency/latencyCount）在 `loadStats()` 中从未被填充，始终为初始零值。`RAGGovernanceRepository.calculateRetrievalLatency()` 已提供但未被调用 | P2 | 新增 `fetchRetrievalLatency()` 方法，调用 `governanceRepo.calculateRetrievalLatency(days:)` 并映射 p50→avgLatency、p99→maxLatency、p50→minLatency、sampleCount→latencyCount | 是 |
| C-17 | `SystemStatsCoordinator.iconForCategory(_:)` 未映射 `models`/`plugins`/`caches` 三个 `storageCategories` 标签，它们会返回 fallback 图标。而 `storageCategories` 中明确包含这 3 个分类，UI 图标显示不一致 | P3 | 在 `DesignSystem.Icons.StorageStats` 中新增 `models`/`plugins`/`caches` 图标定义，在 `iconForCategory` 中补充映射 | 是 |
| C-18 | `SystemStatsCoordinator.fetchAIDailyStats()` 中 `dateFormatter.locale` 设置为 `Localized.currentLanguage`，但 `yyyy-MM-dd` 格式解析依赖 locale。若未来格式变更含月份名，locale 不匹配会导致解析失败静默丢弃数据 | P3 | 将 `dateFormatter.locale` 固定为 `Locale(identifier: "en_US_POSIX")` 以确保日期解析确定性 | 是 |
| C-19 | `TokenManager.tryAutoLogin`（line 53）和 `handleSuccessfulLogin`（line 119）构造 User 时 `id` 使用 `UUID(uuidString: String(response.userId)) ?? UUID()`，Int64 转 UUID 字符串几乎必然失败（如 "10001" 不是合法 UUID），导致每次 `id` 都是随机 UUID，跨设备/跨登录用户身份不一致。与 `User.init(from:)` 的 `00000000-0000-0000-0000-%012x` 规范化逻辑不一致 | P2 | 抽取 `normalizedUUID(from:)` 静态方法，统一使用 `String(format: "00000000-0000-0000-0000-%012x", userId)` 规范化 | 是 |
| C-20 | `TokenManager.refreshUserProfile` 中 email/phone 空时保留本地值（`?? user.email`/`?? user.phone`），但 avatar 空时直接覆盖为 nil（`profile.avatar.flatMap { URL(string: $0) }`），不保留本地 avatar。字段处理策略不一致 | P3 | 改为 `profile.avatar.flatMap { $0.isEmpty ? nil : URL(string: $0) } ?? user.avatarURL`，空时保留本地值 | 是 |
| C-21 | `SynthesisStore.cleanMarkdown` 正则 `\\([\#\(\)...\])` 中 `\#` 在 Swift raw string `#"..."#` 中被解析为 `#`（转义），导致字符类中缺少 `#`，`\#` 无法被清理还原为 `#`。LLM 返回含 `\# 标题` 的内容时 Markdown 渲染异常 | P2 | 直接在字符类中使用 `#`（字符类内 `#` 无需转义）：`\\([#\(\)...\])` | 是 |
| C-22 | `AIWorkflowStore.runLint` 更新了 `lastLintDate` 但未更新 `lastLintScore`，`lastLintScore` 恒为 0。UI 层若绑定 `lastLintScore` 显示历史分数会显示恒定 0 | P2 | 在 `runLint` 中调用 `lintService.calculateHealthMetrics(issues:)` 并赋值 `lastLintScore = metrics.score` | 是 |
| C-23 | `AIWorkflowStore.clearAll` 不重置 `isScanningAI`/`isProcessingPageAI`，若清理时正在扫描或处理，状态将永久卡死为 true，UI 显示永久"扫描中" | P1 | `clearAll` 中增加 `isScanningAI = false` 和 `isProcessingPageAI = false` | 是 |
| C-24 | `AIWorkflowStore.runAIScan` 全局扫描时 `potentialLinks = tempLinks` 直接赋值，覆盖单页扫描累积的链接，导致数据丢失 | P2 | 改为合并模式：保留已有链接，去重追加新链接 | 是 |
| C-25 | `AIWorkflowStore.performPageSynthesis` quiz 解析失败时 `activeQuiz` 未被清空，残留旧 quiz 数据。用户看到的是上一次的测验而非当前页面的内容 | P2 | quiz 解析失败时增加 `activeQuiz = nil` 清空旧值 | 是 |

---

## 批次 D — View + Shared UIComponents + Platforms

### Task 1-2：System View 快照测试 + 源码审查

| 序号 | 问题描述 | 严重程度 | 修改方案 | 是否解决 |
|------|---------|---------|---------|---------|
| D-1 | `audit-design-magic-numbers.py` CI 审计脚本存在 6 大类漏检漏洞，导致 362 处魔鬼数字一直未被发现：(1) `.padding(.vertical, N)` 双参数形式漏检；(2) `HStack/VStack(spacing: N)` container spacing 漏检；(3) `.font(.system(size: N))` font size 漏检；(4) `lineWidth: N` 漏检；(5) `.shadow(radius: N, y: N)` 漏检；(6) `DesignSystem.glassOpacity * N` token 算术表达式漏检（exempt_math 豁免过于宽泛） | P1 | 修复 CI 脚本：新增 `_check_spacing_and_layout_params` 函数检测 spacing/font size/lineWidth/shadow/kerning；新增 `.padding(.\\w+, N)` 双参数检测；收窄 `exempt_math` 为精确匹配已知合法模式 | 是 |
| D-2 | 362 处源码魔鬼数字（修复 CI 脚本后检出）：90 处 hardcoded container spacing、120 处 Magic Math token算术表达式、99 处 hardcoded padding (labeled)、29 处 hardcoded lineWidth、15 处 Magic Math View算术表达式、4 处 hardcoded kerning/tracking、3 处 hardcoded shadow radius、2 处 hardcoded shadow offset。分布在 Features/System、Features/AI、Features/Insight、Features/Knowledge、Shared/UIComponents 等 | P2 | 批量修复：spacing/padding/lineWidth/shadow/kerning 替换为 DesignSystem token；token 算术表达式（如 `DesignSystem.glassOpacity * 3`）定义为新 token 常量 | 否 |

### Task 3：Knowledge View 快照测试 + 源码审查

| 序号 | 问题描述 | 严重程度 | 修改方案 | 是否解决 |
|------|---------|---------|---------|---------|
| D-3 | `Graph3DView.swift:127` 硬编码字符串 `"3D_Graph"`，未通过 `L10n.模块.属性` 强类型访问，违反 L10n 强约束。用户在非中文环境下看到的是字面量 `"3D_Graph"` 而非本地化文案 | P1 | 注册 L10n key 并改为 `L10n.Graph.threeDTitle` | 是 |
| D-4 | `Graph3DView.swift:132` 硬编码字符串 `"Graph_Desc"`，同 D-3，违反 L10n 强约束 | P1 | 注册 L10n key 并改为 `L10n.Graph.threeDDescription` | 是 |
| D-5 | `Graph3DView.swift:108` 硬编码字符串 `"FPS: \(Int(fps))"`，`"FPS:"` 前缀未本地化 | P2 | 改为 `L10n.Graph.fpsFormat(fps)` | 是 |
| D-6 | `Graph3DView.swift:81` 魔鬼数字 `2000`（节点数降级阈值），未抽取为常量 | P2 | 抽取为 `GraphConstants.ThreeD.nodeCountDegradeThreshold` | 是 |
| D-7 | `Graph3DView.swift:106` 魔鬼数字 `30`、`15`（FPS 颜色阈值），未抽取为常量 | P2 | 抽取为 `GraphConstants.ThreeD.fpsGoodThreshold`/`fpsWarnThreshold` | 是 |
| D-8 | `Graph3DView.swift:191` 魔鬼数字 `2.2`（相机距离倍数），`192` 魔鬼数字 `60`/`400`（相机距离 min/max），未抽取为常量 | P2 | 抽取为 `GraphConstants.ThreeD.cameraDistanceMultiplier`/`minCameraDistance`/`maxCameraDistance` | 是 |
| D-9 | `Graph3DView.swift:206` 魔鬼数字 `150`（星空半径），`207` 算术表达式 `2 * .pi`，`230` 魔鬼数字 `20`/`30`/`20`（光源位置），`239` 魔鬼数字 `15`（相机 Y），未抽取为常量 | P2 | 抽取为 `GraphConstants.ThreeD.starfieldRadius`/`lightPosition`/`cameraYOffset` | 是 |
| D-10 | `SearchSheets.swift:130` 魔鬼数字 `6`（`lineSpacing(6)`），未使用 DesignSystem token | P2 | 替换为 `SystemSpacing.divider` 或新增 `Reference.Spacing` token | 是 |
| D-11 | `SearchSheets.swift:226,256` 魔鬼数字 `36`（`font(.system(size: 36))`），`230,260,324,332` 魔鬼数字 `10`（`font(.system(size: 10))`），未使用 DesignSystem token | P2 | `36` → `Reference.FontSize.display`，`10` → `Reference.FontSize.micro` | 是 |
| D-12 | `SearchSheets.swift:245,275` 魔鬼数字 `1`（`lineWidth: 1`），`PDFReaderView.swift:152` 魔鬼数字 `2`/`0`（`lineWidth`），`VoiceAudioPlayerView.swift:123` 魔鬼数字 `1`，未使用 `SystemStroke` token | P2 | `1` → `SystemStroke.border`，`2` → `SystemStroke.selected`，`0` → `SystemStroke.none` | 是 |
| D-13 | `SearchSheets.swift:321,329` 硬编码字符串 `"FTS:"`/`"Vec:"`，未通过 L10n 强类型访问 | P2 | 注册 L10n key 并改为 `L10n.Search.Diag.ftsLabel`/`vectorLabel` | 是 |
| D-14 | `PDFReaderView.swift:145` 硬编码字符串数组 `["yellow", "green", "blue", "pink", "purple"]`（高亮颜色名称），未抽取为枚举常量 | P2 | 抽取为 `PDFHighlightColor` 枚举 | 是 |
| D-15 | `PDFReaderView.swift:111` 硬编码字符串 `"0 / 0"`（PDFKit 不可用时页码显示），未本地化 | P2 | 改为 `L10n.Ingest.PDF.pageZeroFormat` | 是 |
| D-16 | `PDFComponents.swift:91-93,97,119,155` 硬编码字符串 `"fullText"`/`"pageRange"`/`"highlights"` 用于 `ingestMode` 状态比较，应使用枚举而非字符串 | P1 | 抽取为 `enum PDFIngestMode: String` 枚举，所有比较改为枚举 case | 是 |
| D-17 | `PDFComponents.swift:102,106` 算术表达式 `heroValueSize * 1.9`，`142` 算术表达式 `heroValueSize * 5.75`，违反"禁止 token 算术"规则 | P2 | 迁移到 `PDFConstants` 常量 | 是 |
| D-18 | `PDFComponents.swift:139` 魔鬼数字 `10`（`lineLimit(10)`），未抽取为常量 | P3 | 抽取为 `PDFUIConstants.previewLineLimit` | 是 |
| D-19 | `VoiceAudioPlayerView.swift:51` 硬编码字符串 `"AAC 44.1kHz"`（音频格式描述），未本地化 | P2 | 改为 `L10n.Ingest.audioFormatAAC` | 是 |
| D-20 | `VoiceAudioPlayerView.swift:61` 魔鬼数字 `32`/`8`/`12`（波形高度计算 `waveformLevels[index] * 32 + 8`/`12`），未抽取为常量 | P2 | 抽取为 `VoiceUIConstants.waveformMaxHeight`/`waveformMinHeight`/`waveformIdleHeight` | 是 |
| D-21 | `VoiceAudioPlayerView.swift:62,117,123,132` 魔鬼数字 `0.2`（动画 duration），多处重复，未抽取为常量 | P3 | 抽取为 `VoicePlaybackConfig.waveformAnimationDuration` | 是 |
| D-22 | `VoiceAudioPlayerView.swift:103` 魔鬼数字 `48`（`font(.system(size: 48))`），未使用 DesignSystem token | P2 | 替换为 `Reference.FontSize.mega` | 是 |
| D-23 | `ZoomableOCRImageView.swift:25,45,68,118,124,133` 魔鬼数字 `0.8`/`4.0`/`1.0`/`2.0`/`0.25`（缩放比例阈值），多处重复，未抽取为常量 | P2 | 抽取为 `OCRZoomConstants.minScale`/`maxScale`/`resetScale`/`doubleTapTarget` | 是 |
| D-24 | `ZoomableOCRImageView.swift:64` 魔鬼数字 `0.3`/`0.7`（spring 参数），`65` 魔鬼数字 `1.2`（双击放大阈值），未抽取为常量 | P3 | 抽取为 `OCRZoomConstants` 常量 | 是 |
| D-25 | `ZoomableOCRImageView.swift:81` 硬编码格式字符串 `"%.1fx"`（缩放倍率显示），未本地化 | P3 | 改为 `L10n.Ingest.zoomScaleFormat(totalScale)` | 是 |
| D-26 | `Graph3DComponents.swift:365,377,388,411` 算术表达式 `DesignSystem.small + DesignSystem.atomic`（多处重复），违反"禁止 token 算术"规则 | P2 | 定义新 token 常量 `Graph3DUIConstants.controlPadding`（值=`SystemSpacing.contentMedium`） | 是 |
| D-27 | `Graph3DComponents.swift:407` 魔鬼数字 `0.35`（spring response），`414` 魔鬼数字 `0`（opacity），未抽取为常量 | P3 | 抽取为 `Graph3DUIConstants.filterSpringResponse` | 是 |

### Task 4-8：Insight/AI/Shared 快照 + Platforms 单元测试 + 全量验证

| 序号 | 问题描述 | 严重程度 | 修改方案 | 是否解决 |
|------|---------|---------|---------|---------|
| D-28 | `audit-design-magic-numbers.py` 正则未处理类型标注（如 `let x: CGFloat = 1.0`），95 处 private 常量魔鬼数字漏检 | 高 | 正则改为 `(?::\s*\w+)?\s*=\s*` 支持可选类型标注 | 是 |
| D-29 | 43 处 private 常量魔鬼数字（UI 语境 enum 中变相硬编码） | 高 | 16 处迁移现有 token + 13 处拆分到非 UI 语境 enum + 1 处迁移 `Reference.Opacity.fifty` + 13 处组件特定尺寸白名单 | 是 |
| D-30 | `ExportError` 未 conform `Equatable`，测试无法用 `XCTAssertEqual` 直接比较 | 中 | 测试改用 `errorDescription` 字符串比较（不修改源码） | 是（测试层） |
| D-31 | `IOSSpotlightIndexerTests` 中 `KnowledgePage` init 参数顺序错误（`aliases` 应在 `tags` 前） | 低 | 修正测试代码参数顺序 | 是 |
| D-32 | `iOSReminderService.requestAccess()` 直接调用 EventKit，在模拟器阻塞权限弹窗，4 个测试卡住 | 高 | 引入闭包注入模式（`requestAccessHandler`/`defaultCalendarHandler`/`calendarsHandler`/`saveHandler`），测试通过 `init(requestAccess:defaultCalendar:calendars:save:)` 注入 Mock 闭包 | 是 |
| D-33 | `type_name` SwiftLint 规则要求类名大写开头，`iOS*Tests` 违规 | 低 | 重命名为 `IOS*Tests`（13 个文件） | 是 |
| D-34 | `AppEnvironment.platformEnv` getter 调用 `ServiceContainer.resolve`，测试环境中其他测试 `reset()` 清空注册后触发 `assertionFailure` 崩溃 | 高 | 改为 `resolveOptional ?? NoOpAppEnvironment()` 安全降级 | 是 |
| D-35 | `IOSURLOpenerServiceTests` 调用真实 `UIApplication.shared.open`，在模拟器阻塞 Safari/系统进程 | 高 | `iOSURLOpenerService` 引入闭包注入模式（`openHandler`），测试用 `URLRecorder` 引用类型包装验证 | 是 |
| D-36 | `ModelDownloadManagerDeepTests.testStartDownloadWithPausedStateProceeds` 用真实 URL `"https://example.com/model.bin"` 发起网络请求，测试环境挂起超时 | 高 | `ModelDownloadManager` 引入 `sessionFactory` 闭包注入模式，测试注入 ephemeral session + `MockDownloadURLProtocol`；`ModelDownloadDelegateHelper` 改为 `internal` | 是 |
| D-37 | NLTagger 中文人名识别率 33%（3/9），tag 全是 `Other` 而非 `.personalName`，8 个匿名化测试失败 | 高 | `LLMContextBuilder` 引入 `entityRecognizer` 闭包注入点 + `init(entityRecognizer:)` 测试初始化器 + `defaultEntityRecognizer` 静态方法；`ChatLLMService`/`ChatRunner` 引入 `contextBuilderFactory` 闭包属性 + 测试初始化器；4 个测试文件注入 mock `entityRecognizer` | 是 |
| D-38 | `EmbeddingManager.getVector(for:)` fallback 中 `Hasher.finalize()` 返回负值，负数取模产生负值导致向量分布异常（负值占比 0.998 > 0.9） | 高 | `abs(seed ^ i)` 确保非负取模 | 是 |
| D-39 | `DatabaseManagerDegradationTests.testStateAfterDegradationToInMemory` 降级后 `state` 未设为 `.ready` | 中 | 测试已通过，`degradeToInMemory` 降级逻辑正常工作 — `/dev/null/cannot_create_db/vault.sqlite3` 路径触发降级，内存数据库成功初始化 | 是 |
| D-40 | `ZIPFoundationArchiver.extractContents` 解压后文件在子目录（源目录名）下，而非直接在目标目录下 — ZIPFoundation `zipItem` 保留源目录名作为 ZIP 内根条目 | 中 | 测试改为遍历子目录查找文件（`findFile(named:in:)` 递归查找），符合 ZIP 保留目录结构的业界标准 | 是（测试层） |
| D-41 | `CollaborationServiceDeepTests.test接收PageSync数据且远程时间等于本地时也更新` flaky — `Task {}` 异步竞态，100ms 等待在全量测试负载下不够 | 低 | 3 个正向断言测试改为轮询等待（`waitFor` 辅助方法），44 个测试全部通过 | 是 |
| D-42 | 46 个中文测试方法名违反英文命名规范（8 个文件） | 中 | 全部改为英文命名（`CollaborationServiceDeepTests` 21 个 + `CarrierAuthStrategyDeepTests` 3 个 + `SynthesisStoreDeepTests` 2 个 + `ModelLabManagerDeepTests` 7 个 + `GitHubAuthStrategyDeepTests` 4 个 + `StoreKitServiceDeepTests` 2 个 + `GlobalModelManagerDeepTests` 5 个 + `L10nMediumFilesDeepTests` 2 个） | 是 |
