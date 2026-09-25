# 基础设施架构

> 本文档描述智宇 (ZhiYu) 的本地优先 (Local-First) 基础设施架构。
> 作为 iOS/macOS/watchOS 本地应用，本项目不依赖 Nacos/Redis/MySQL 等服务端基础设施，
> 所有数据存储与计算均在设备端完成，iCloud 仅用于跨设备同步。

## 1. 存储引擎 (Storage Engine)

### 1.1 SQLite (GRDB) — 主存储

| 组件 | 路径 | 职责 |
|------|------|------|
| `SQLiteStore` | `Sources/Infrastructure/Storage/Engine/SQLiteStore.swift` | 核心 Actor，实现 `AnyPageStoreCapabilities`，管理知识库 CRUD |
| `DatabaseManager` | `Sources/Infrastructure/Storage/Persistence/DatabaseManager.swift` | 数据库生命周期管理（初始化、热切换、连接池） |
| `DatabaseSchemaMigrator` | `Sources/Infrastructure/Storage/Persistence/DatabaseSchemaMigrator.swift` | Schema 版本迁移（v1→v9+） |
| `TransactionGatekeeper` | `Sources/Infrastructure/Storage/Persistence/TransactionGatekeeper.swift` | ACID 事务安全守卫 |
| `StorageConstants` | `Sources/Infrastructure/Storage/StorageConstants.swift` | 存储常量（WAL 模式、页面大小等） |

- **模式**：WAL (Write-Ahead Logging)，支持并发读写
- **全文搜索**：FTS5 虚拟表，支持 CJK 分词增强
- **迁移历史**：v1→v9+，含 PageLink、PluginRecord、RAGModels、FTS 等扩展

### 1.2 仓储层 (Repository)

| 仓储 | 路径 | 职责 |
|------|------|------|
| `KnowledgePageRepository` | `Sources/Infrastructure/Storage/Repositories/KnowledgePageRepository.swift` | 知识页面 CRUD + FTS 搜索 |
| `TagRepository` | `Sources/Infrastructure/Storage/Repositories/TagRepository.swift` | 标签管理 |
| `VectorDataRepository` | `Sources/Infrastructure/Storage/Repositories/VectorDataRepository.swift` | 向量数据持久化 |
| `SQLiteVaultRepository` | `Sources/Infrastructure/Storage/Repositories/SQLiteVaultRepository.swift` | 金库隔离存储 |
| `SQLitePluginRepository` | `Sources/Infrastructure/Storage/Repositories/SQLitePluginRepository.swift` | 插件元数据 |
| `RAGGovernanceSQLiteStore` | `Sources/Infrastructure/Storage/Repositories/RAGGovernanceSQLiteStore.swift` | RAG 治理记录 |

### 1.3 向量引擎 (Vector Engine)

| 组件 | 路径 | 职责 |
|------|------|------|
| `EmbeddingManager` | `Sources/Infrastructure/VectorDB/EmbeddingManager.swift` | Apple NLEmbedding 语义向量化 |
| `VectorIndexer` | `Sources/Infrastructure/VectorDB/VectorIndexer.swift` | 向量索引构建与检索 |
| `ContextReranker` | `Sources/Infrastructure/VectorDB/ContextReranker.swift` | 上下文重排（RRF 融合） |

- **向量计算**：基于 Accelerate 框架 (vDSP) 的余弦相似度
- **混合检索**：FTS5 + 向量 RRF (Reciprocal Rank Fusion) 融合

## 2. AI 中台 (LLM Infrastructure)

### 2.1 LLM 适配层

| 组件 | 路径 | 职责 |
|------|------|------|
| `LLMClient` | `Sources/Infrastructure/LLM/LLMClient.swift` | HTTP 客户端，调用远程 LLM API |
| `LLMAdapters` | `Sources/Infrastructure/LLM/LLMAdapters.swift` | OpenAI / DeepSeek / SiliconFlow / Ollama 适配器 |
| `OnDeviceLLMService` | `Sources/Infrastructure/LLM/OnDeviceLLMService.swift` | 端侧模型推理 |
| `LLMContextBuilder` | `Sources/Infrastructure/LLM/LLMContextBuilder.swift` | RAG 上下文构建与脱敏 |
| `PromptSecuritySanitizer` | `Sources/Infrastructure/LLM/PromptSecuritySanitizer.swift` | Prompt 注入防护 |

### 2.2 检索增强

| 组件 | 路径 | 职责 |
|------|------|------|
| `RerankService` | `Sources/Infrastructure/LLM/RerankService.swift` | 语义重排服务 |
| `QueryReranker` | `Sources/Infrastructure/LLM/QueryReranker.swift` | 查询改写优化 |
| `LLMRetrievalService` | `Sources/Infrastructure/LLM/LLMRetrievalService.swift` | 检索链路编排 |

## 3. 安全基础设施 (Security)

| 组件 | 路径 | 职责 |
|------|------|------|
| `KeychainService` | `Sources/Core/System/Security/KeychainService.swift` | Keychain 封装（API Key、JWT Token） |
| `VaultStorageSecurityService` | `Sources/Infrastructure/Storage/Services/VaultStorageSecurityService.swift` | 金库级生物识别锁定 |
| `AESGCMCryptoHelper` | `Sources/Core/System/Security/AESGCMCryptoHelper.swift` | AES-GCM 对称加密 |
| `SecureEnclaveCryptoService` | `Sources/Core/System/Security/SecureEnclaveCryptoService.swift` | Secure Enclave 硬件密钥 |
| `JailbreakDetector` | `Sources/Core/System/Security/JailbreakDetector.swift` | 越狱检测 |
| `ContentModerationEngine` | `Sources/Core/System/Security/ContentModerationEngine.swift` | 内容审核（Core ML 分类器） |
| `PIIMasker` | `Sources/Core/System/Security/PIIMasker.swift` | PII 个人信息脱敏 |

## 4. 云同步 (Cloud Sync)

| 组件 | 路径 | 职责 |
|------|------|------|
| `AppCloudSyncService` | `Sources/Infrastructure/Storage/Sync/AppCloudSyncService.swift` | 云同步编排器 |
| `CloudKitSyncProvider` | `Sources/Infrastructure/Storage/Sync/CloudKitSyncProvider.swift` | CloudKit 同步实现 |
| `iCloudSyncCoordinator` | `Sources/Infrastructure/Storage/Sync/iCloudSyncCoordinator.swift` | 同步协调器 |
| `DataCoordinator` | `Sources/Infrastructure/Storage/Sync/DataCoordinator.swift` | 数据协调 |

- **冲突解决**：Lamport LWW (Last-Writer-Wins) 策略
- **同步范围**：知识页面、标签、设置

## 5. 备份与恢复 (Backup)

| 组件 | 路径 | 职责 |
|------|------|------|
| `BackupService` | `Sources/Infrastructure/Storage/Services/AppBackupService.swift` | 数据库备份与恢复 |
| `MaintenanceService` | `Sources/Infrastructure/Storage/Services/MaintenanceService.swift` | 数据库维护（VACUUM、 integrity check） |

## 6. 网络层 (Network)

| 组件 | 路径 | 职责 |
|------|------|------|
| `NetworkClient` | `Sources/Infrastructure/Network/NetworkClient.swift` | HTTP Actor 客户端 |

## 7. 插件系统 (Plugin System)

| 组件 | 路径 | 职责 |
|------|------|------|
| `PluginSandboxGateway` | `Sources/Infrastructure/Plugins/PluginSandboxGateway.swift` | JSContext 沙盒网关 + Watchdog |
| `PluginRuntime` | `Sources/Infrastructure/Plugins/PluginRuntime.swift` | 插件运行时生命周期 |
| `PluginProtocols` | `Sources/Infrastructure/Plugins/PluginProtocols.swift` | 插件协议定义 |

## 8. 轻量配置 (UserDefaults)

通过 `SettingsStore`（`Sources/Features/System/Settings/Model/SettingsStore.swift`）管理用户偏好，
键名统一注册在 `AppConstants.Keys.Storage`（`Sources/Core/Base/Constants/AppConstants.swift`）。

## 9. SPM 物理隔离包

| 包 | 路径 | 职责 |
|----|------|------|
| `UFPCore` | `Packages/UFPCore/` | L0 底座：DI 容器、Logger、全局协议 |
| `UFPStorage` | `Packages/UFPStorage/` | L1 存储引擎：SQLite/GRDB 物理 DB |
| `UFPDesignSystem` | `Packages/UFPDesignSystem/` | 共享 UI Token 与 Bundle.module 资源 |
| `ZhiYuDomain` | `Packages/ZhiYuDomain/` | L1.5 领域大脑：业务规则、RAG 契约 |
| `ZhiYuAICore` | `Packages/ZhiYuAICore/` | L1 AI 中台：Prompt 沙箱/Reranker/MemoryAdapters |
| `ZhiYuFeatures` | `Packages/ZhiYuFeatures/` | L2 业务功能切片：AI/Knowledge/Insight |
