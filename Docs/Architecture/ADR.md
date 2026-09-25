# 架构决策记录 (ADR)

> 状态: 活跃 — 持续记录重大架构决策

## ADR 列表

| # | 日期 | 决策 | 状态 |
|---|------|------|------|
| ADR-001 | 2026-01 | 采用 SwiftUI + @Observable 而非 MVVM | 已实施 |
| ADR-002 | 2026-01 | GRDB (SQLite+FTS5) 而非 Core Data | 已实施 |
| ADR-003 | 2026-02 | L0-L3 严格分层架构（含 L1.5 领域层） | 已实施 |
| ADR-004 | 2026-03 | 协议导向的跨层依赖注入（@Inject → @Dependency 演进） | 已实施 |
| ADR-005 | 2026-07 | 平台适配采用 PlatformRegistrar 协议而非 #if os 宏扩散 | 已实施 |
| ADR-006 | 2026-07 | Base64 编码错误消息改为明文（安全审计发现冗余混淆） | 已实施 |
| ADR-007 | 2026-08-04 | NSLock 全局迁移至 OSAllocatedUnfairLock（Swift 6 异步安全） | 已实施 |
| ADR-008 | 2026-08-04 | 启动顺序重构：DI-first + Store 延迟实例化 + 14 服务启动断言 | 已实施 |
| ADR-009 | 2026-08-04 | @Inject 非可选注入为主流模式（对齐 Resolver/Swinject/Koin/Spring） | 已实施 |
| ADR-010 | 2026-08-04 | Domain 层禁止 #if os()，平台条件编译下沉至 Platforms/ | 已实施 |
| ADR-011 | 2026-08-04 | inject_exempt/arch_exempt 豁免机制规范化 | 已实施 |
| ADR-012 | 2026-08-04 | SecurityManager 密钥存储失败改 assertionFailure + 临时密钥降级 | 已实施 |

---

## ADR-001: SwiftUI + @Observable 而非 MVVM

**日期**: 2026-01
**状态**: 已实施
**背景**: 项目启动时需选择 UI 架构模式。传统 MVVM 基于 `ObservableObject` + `@Published`，存在全量刷新、属性包装器嵌套复杂等问题。Swift 5.9 引入 Observation 框架（`@Observable` 宏），提供细粒度属性级观察。
**决策**: 采用 SwiftUI + `@Observable` 宏作为 ViewModels 的默认模式，而非传统 MVVM + `ObservableObject`。
**影响**: 全项目 ViewModels 统一使用 `@Observable` 类；`@State` / `@Binding` / `@Environment` 直接引用 `@Observable` 对象。
**后果**: 仅被读取的属性不触发视图刷新，性能更优；语法更简洁（无需 `@Published`）；但 `@Observable` 类不能用 `@Dependency` 属性在 init 中赋值，需改为存储属性。

## ADR-002: GRDB (SQLite+FTS5) 而非 Core Data

**日期**: 2026-01
**状态**: 已实施
**背景**: 知识管理应用需要高效的全文检索和跨平台持久化。Core Data 是 Apple 原生 ORM，但缺乏原生全文检索支持，且抽象层较重。SQLite + FTS5 提供成熟的全文检索能力，GRDB.swift 提供类型安全的 Swift 封装。
**决策**: 采用 GRDB.swift (~> 6.29) 作为 SQLite + FTS5 的 Swift 封装层，而非 Core Data。
**影响**: `UFPStorage` SPM 包物理收敛 GRDB 依赖，通过 `GRDBReexport` 唯一导出；`Sources/` 层使用 `import UFPStorage` 而非 `import GRDB`。
**后果**: 获得 FTS5 原生全文检索 + 向量混合搜索能力；SQL 级别控制性能优化（`PRAGMA mmap_size`、WAL 模式）；但需手动管理 Schema 迁移（`DatabaseSchemaMigrator`）。

## ADR-003: L0-L3 严格分层架构（含 L1.5 领域层）

**日期**: 2026-02
**状态**: 已实施
**背景**: 项目代码量增长至 ~90K 行，需防止跨层依赖导致的"大泥球"架构。传统三层架构（MVC/MVVM）缺乏编译期隔离。
**决策**: 采用 L0-L3 严格分层 + L1.5 领域层，通过本地 SPM 多 Package 实现编译期硬隔离：
- L0 底座包（`UFPCore`）— DI 容器、协议、工具类
- L1 基础设施包（`UFPStorage` / `ZhiYuAICore`）— 存储引擎、AI 适配器
- L1.5 领域包（`ZhiYuDomain`）— 业务规则、RAG 编排、跨模块契约
- L2 功能包（`ZhiYuFeatures`）— 垂直业务功能切片
- L3 应用层（`ZhiYu App`）— SwiftUI Views、ViewModels、路由
**影响**: 依赖关系严格自顶向下，严禁反向；跨层访问通过协议（定义在 L1.5 `Domain/Protocols/` 或 L0 `Core/Base/Protocols/`）。
**后果**: 编译期硬隔离，毫秒级独立单元测试（`make test-spm`）；但新增功能需跨多个 Package 协作，初始开发成本略高。

## ADR-004: 协议导向的跨层依赖注入（@Inject → @Dependency 演进）

**日期**: 2026-03
**状态**: 已实施（已演进）
**背景**: 跨层调用需解耦，不能直接依赖具体类。需选择 DI 机制。
**决策**: 采用协议导向的 DI 模式。初期自研 `ServiceContainer` + `@Inject` 属性包装器（从 `ServiceContainer.shared` 解析服务）。
**演进**: 2026-08 起，`@Inject` 被 [swift-dependencies](https://github.com/pointfreeco/swift-dependencies) 的 `@Dependency` 取代。`@Dependency` 通过 `DependencyKey` 注册服务，支持 `liveValue` / `testValue` / `previewValue` 三环境。CI-4 门禁禁止 `Sources/` 中新增 `@Inject`，仅白名单保留存量。
**影响**: 服务注册通过模块注册器模式实现（`CoreModuleRegistrar` / `StorageModuleRegistrar` / `AppModuleRegistrar`），按序执行。功能域注册器（`KnowledgeModuleRegistrar` / `AIModuleRegistrar` / `AuthModuleRegistrar`）按需注册业务服务。
**后果**: 解耦跨层依赖；测试环境可注入 Mock；但 `@Dependency` 在 `@Observable` 类中需加 `@ObservationIgnored`，且 init 时解析一次并缓存。

---

## ADR-007: NSLock → OSAllocatedUnfairLock

**日期**: 2026-08-04
**状态**: 已实施
**背景**: Swift 6 严格并发模式（SWIFT_STRICT_CONCURRENCY: complete）下，NSLock 的 lock()/unlock() 在 async 上下文中不安全，会产生编译警告并最终成为错误。
**决策**: 全局将 NSLock/NSRecursiveLock 迁移至 OSAllocatedUnfairLock（os 模块，Swift 5.9+），使用 withLock 闭包模式。
**影响**: 7 个文件迁移（SecurityManager/IntentRateLimiter/DynamicComplianceManager/CoreMLModerationClassifier/Localized/SwarmMemoryAdapter/NativeMemoryEngine）。
**后果**: 消除全部 Swift 6 异步锁警告；withLock 闭包需显式返回值类型标注。

## ADR-008: 启动顺序重构（DI-first）

**日期**: 2026-08-04
**状态**: 已实施
**背景**: 原 AppEnvironment 中 Store 实例化在 DI 注册之前，导致 Store 的 @Inject 属性首次业务访问时 DI 未就绪。
**决策**: 方案 C+E：Store 实例化移到 registerDIModules() 之后（方案 C）+ 启动期断言 14 个关键服务已注册（方案 E）。Store 属性 let → private(set) var（延迟赋值）。
**影响**: AppEnvironment.swift + ServiceContainer.swift（新增 assertRegistered 方法）。
**后果**: 启动顺序确定性保证；DI 未就绪时启动期断言而非运行时崩溃。

## ADR-009: @Inject 非可选注入为主流模式

**日期**: 2026-08-04
**状态**: 已实施
**背景**: 审计发现 125 处非可选 @Inject 注入，质疑是否应改为可选注入（方案 A）。
**决策**: 保留非可选注入为主流模式，对齐业界 DI 框架（Resolver/Swinject/Koin/Spring）。仅真正可选依赖用 @Inject var x: T?。125 处非可选注入符合主流模式，0 处 HIGH 风险。
**影响**: 无代码变更，确认现状合理。
**后果**: inject_exempt 豁免机制用于真正需要跳过检查的场景。

## ADR-010: Domain 层禁止 #if os()

**日期**: 2026-08-04
**状态**: 已实施
**背景**: Domain 层（L1.5）应保持平台无关，但 AppStoreProtocol 和 OnDeviceLLMServiceProtocol 含 #if !os(watchOS) 条件编译。
**决策**: 删除 Domain 层所有 #if os() 宏；watchOS target 从 project.yml.template 移除这两个协议引用（而非在协议内用条件编译）。
**影响**: AppStoreProtocol.swift + OnDeviceLLMServiceProtocol.swift + project.yml.template。
**后果**: Domain 层 100% 平台纯净；平台差异下沉至 Platforms/ 层。

## ADR-011: 豁免机制规范化

**日期**: 2026-08-04
**状态**: 已实施
**背景**: 部分代码需合理跳过审计检查（如测试代码、平台兼容预留）。
**决策**: 统一 inject_exempt / arch_exempt 行注释豁免机制，与 l10n 白名单互补。
**影响**: 审计脚本支持行注释豁免。
**后果**: 审计误报可控，豁免有据可查。

## ADR-012: SecurityManager 密钥存储失败降级

**日期**: 2026-08-04
**状态**: 已实施
**背景**: 生产环境下 Keychain 存储失败原 fatalError 导致白屏崩溃。
**决策**: 改为 assertionFailure（DEBUG 崩溃、Release 记录）+ 返回内存中的临时密钥（重启后丢失，但不崩溃）。
**影响**: SecurityManager.swift:90。
**后果**: 生产环境不再因 Keychain 故障白屏；临时密钥不持久化，重启后重新生成。
