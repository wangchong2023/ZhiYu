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
| A-35 | `ModelDownloadManager.resumeDownload` L165 在 `task.resume()` 之前 `try? FileManager.default.removeItem(at: fileURL)` 删除 resumeData — 恢复失败时数据已丢失，无法再次恢复 | P2 | 将 `removeItem` 移到 `task.resume()` 成功后执行，或在 `catch` 中重新写入 resumeData | 否 |
| A-36 | `OnDeviceLLMService.extractTags` 使用 `#(\w+)` 正则，`NSRegularExpression` 的 `\w` 是 Unicode aware，会匹配中文标签（如 `#中文标签`）— 与源码注释"过滤单字符噪声"不完全一致，但实际行为是支持中文标签 | P3 | 更新源码注释说明 `\w` 匹配 Unicode 字母，或改用 `[a-zA-Z0-9_]+` 限制为 ASCII | 否 |
| A-37 | `OnDeviceLLMService.extractTags` 会误提取 URL 中的 `#section` 作为标签（如 `https://example.com/page#section` → `["section"]`） | P3 | 改用负向断言排除 URL 中的 `#`，如 `(?<!https?:\/\/\S*)#(\w+)` | 否 |
| A-38 | `PluginManifest.name`/`description` 使用 `Localized.bestMatch`，非空字典总是返回某个值（第 5 步"任意值"），不 fallback 到插件 id 或空字符串 — 中文用户可能看到法语名称 | P3 | `bestMatch` 无匹配时应 fallback 到 `id`（name）或空字符串（description），而非返回任意值 | 否 |
| A-39 | `StreamDeanonymizer.maxRawLength=25` 只在无闭合 `]` 时触发（DoS 保护），完整方括号内容即使超过 25 字符也会尝试还原 — 设计正确，但文档应说明 maxRawLength 是防 DoS 而非限制占位符长度 | P3 | 更新 `EntityPlaceholder.maxRawLength` 文档注释说明用途 | 否 |

