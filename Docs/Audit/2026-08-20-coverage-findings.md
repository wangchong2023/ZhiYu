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
| A-19 | `ApiResponse.swift:61,77` `NetworkError.errorDescription` 硬编码英文（"Token expired.", "Missing refresh token." 等），L10n 审计 WARNING | P3 | 改用 `L10n.Network.*` 强类型访问（已有完整词条注册） | 是 |

