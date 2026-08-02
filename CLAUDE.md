# CLAUDE.md

本文件为 Claude Code (claude.ai/code) 在此仓库中工作时提供指导，回复问题和任务规划采用简体中文。

## 参考指南

| 指南 | 内容 |
|------|------|
| [swift-coding-style.md](Docs/Guides/swift-coding-style.md) | 命名、Protocol、Localization key、CodingKeys、Boolean 前缀等 Swift 编码约定 |
| [config-conventions.md](Docs/Guides/config-conventions.md) | project.yml、AppConfig.json、Asset Catalog、.xcstrings、文档目录规范 |
| [implementation-patterns.md](Docs/Guides/implementation-patterns.md) | Swift 6 变通方案、图谱模式、合成文档、缓存策略、Mermaid、UI 框架等 |

## 文档索引

| 文档 | 内容 |
|------|------|
| `Docs/Architecture/HIGH_LEVEL_DESIGN.md` | L0-L3 分层、模块依赖、数据流 |
| `Docs/Architecture/LAYERING_L0_L3.md` | 严格分层架构定义与依赖规则 |
| `Docs/Architecture/AUTH_ARCHITECTURE.md` | 认证架构与多平台登录流程 |
| `Docs/Design/DATABASE_SCHEMA.md` | 完整 DDL、ER 关系、索引设计 |
| `Docs/Design/SECURITY_DESIGN.md` | 安全设计、OWASP、个人信息保护 |
| `Docs/Design/UI_COMPONENTS.md` | 通用 UI 组件库规范 |
| `Docs/Design/PLUGIN_SDK.md` | 插件 SDK 接口与沙箱规范 |
| `Docs/Requirements/PRODUCT_REQUIREMENTS.md` | 产品需求与功能范围 |
| `Docs/Requirements/SOFTWARE_REQUIREMENTS_SPECIFICATION.md` | 软件需求规格说明 |
| `Docs/Testing/TEST_CASES.md` | 各模块测试用例 |
| `Docs/Testing/UNIT_TEST_GUIDE.md` | 单元测试编写指南 |
| `Docs/Testing/SYSTEM_TEST_PLAN.md` | 系统测试计划 |
| `Docs/Architecture/CI_CD_WORKFLOW.md` | CI/CD 流水线与构建部署 |
| `Docs/Design/SECURITY_THREAT_MODEL.md` | 安全威胁模型 |
| `Docs/Requirements/ROADMAP.md` | 版本路线图 |
| `Docs/Guides/CONTRIBUTING.md` | 贡献指南 |
## 四大强制质量红线 (4 Non-Negotiable Quality Redlines)

> **所有 Agent 在此仓库编写、修补或重构 Swift 代码时，必须严格遵守以下 4 条绝对红线，严禁任何违规！**

1. **🌐 多国语言 (L10n) 强约束**：
   - 严禁在视图层、服务层或处理器中出现硬编码中文/ASCII 文本字符串或裸露过滤关键词（如 `"篇幅要求"`, `"目标受众"`）。
   - 禁止直接调用 `.tr()`；必须通过 `L10n.模块.属性` 强类型访问。
   - 所有展示与过滤文本必须在 `Sources/Localization/Extensions/L10n+XXX.swift` 注册，并在 `.xcstrings` Catalog 配置。

2. **🎨 设计系统 Token 强约束 (Design System Tokens)**：
   - 严禁在 SwiftUI 视图中使用硬编码字号、边距、圆角或透明度（如 `.padding(12)`, `.font(.system(size: 16))`）。
   - 视图样式与间距必须统一引用 `DesignSystem` 令牌（如 `DesignSystem.standardPadding`, `DesignSystem.medium`, `DesignSystem.titleFontSize`）。

3. **🏗️ 架构分层 (L0-L3 + SPM) 单向依赖**：
   - 依赖关系严格自顶向下：L3 应用层 (`ZhiYu App`) → L2 业务功能切片包 (`ZhiYuFeatures`) → L1.5 领域大脑包 (`ZhiYuDomain`) → L1 基础设施包 (`ZhiYuAICore` / `UFPStorage`) → Shared (`UFPDesignSystem`) → L0 底座包 (`UFPCore`)。
   - 严禁反向跨层依赖或在领域层导入 UI 框架（`UIKit`/`AppKit`/`SwiftUI`）。

4. **🔢 彻底去魔鬼化数字 / 字符 / 字符串 (No Magic Numbers/Strings)**：
   - 业务逻辑、限制阈值、校验常量、Prompt 关键词组必须抽取为强类型常量枚举或 `L10n` 扩展。
   - 严禁在代码中出现内联魔鬼数字（如 `3`, `5`, `15`）或硬编码正则特征字面量。

## 项目概览

智宇 (ZhiYu) — 面向 iOS/macOS/watchOS 的 AI 原生知识管理应用，基于 Karpathy 的 LLM Wiki 方法论构建。不仅是一个 Markdown 编辑器，更是一个 RAG 闭环系统：语义分块 → 混合 FTS5+向量存储 → AI 合成实验室（含深度引用）。

## 构建与开发

```bash
# 从 project.yml 生成 Xcode 项目（配置变更后必须执行）
xcodegen generate

# 构建 iOS
xcodebuild build -project ZhiYu.xcodeproj -scheme ZhiYu -destination 'generic/platform=iOS'

# 构建 macOS (Catalyst)
xcodebuild build -project ZhiYu.xcodeproj -scheme ZhiYuMac -destination 'platform=macOS'

# 构建 watchOS
xcodebuild build -project ZhiYu.xcodeproj -scheme ZhiYuWatch -destination 'generic/platform=watchOS'

# 列出可用模拟器
xcodebuild -project ZhiYu.xcodeproj -scheme ZhiYu -showdestinations | grep simulator

# 运行 SPM 本地包极速单测 (脱离模拟器，毫秒级通过)
swift test --package-path Packages/UFPCore
swift test --package-path Packages/ZhiYuDomain
swift test --package-path Packages/ZhiYuAICore

# 运行主 App 单元测试
xcodebuild test -project ZhiYu.xcodeproj -scheme ZhiYu -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -enableCodeCoverage YES

# 运行单个测试类
xcodebuild test -project ZhiYu.xcodeproj -scheme ZhiYu -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:ZhiYuTests/AppStoreTests

# 代码检查（需安装 SwiftLint）
swiftlint --strict
```

## 架构：L0–L3 严格分层

依赖规则：**上层依赖下层，绝不可反向。** 跨层访问必须通过协议。

### 本地化 (L10n) 强约束规范

1. **禁止硬编码**：UI 层严禁出现硬编码字符串（包括 ASCII 文本，如 "Settings"）。
2. **禁止直接调用 tr()**：视图层（View）及业务逻辑层严禁直接调用 `.tr("key")` 或 `.trf("key", ...)`。必须通过 `L10n.模块.属性` 访问。
3. **扩展定义**：所有本地化词条必须在 `Sources/Localization/Extensions/L10n+XXX.swift` 中定义为强类型属性。
4. **禁止假国际化**：在 `L10n+XXX.swift` 扩展文件中，严禁直接给属性赋值硬编码的中文（如 `var ok: String { "确定" }`），必须调用底层 `tr()` 方法映射至 `.xcstrings`。
5. **强制网关**：`Tools/Gatekeeper/check_localization.py` 已集成至编译流程。违反上述规则（如硬编码中文或直接调用 tr）将**直接导致编译失败**。

| 层级 | 名称 | 内容 |
|-------|------|-----------------|
| **L3** | 表现层 | SwiftUI Views、`@Observable` ViewModels、导航（Router、ViewFactory） |
| **L2** | 领域/功能层 | 业务逻辑服务 — 按功能域组织（AI / Knowledge / Insight / System） |
| **L1** | 服务层 | 数据仓储（Repository）、AI 适配器（LLM、Embedding）、存储引擎 |
| **L0** | 基础设施层 | SQLite (GRDB)、网络、Keychain、Logger、平台适配、插件系统 |

## 项目结构（关键路径）

```
Packages/                        # 本地 SPM 多 Package 物理隔离目录
├── UFPCore/                     # [UFP] 通用底座 & DI 容器
├── UFPStorage/                  # [UFP] 通用存储引擎 (SQLite/GRDB 物理 DB)
├── UFPDesignSystem/             # [UFP] 通用 UI Token 与 Bundle.module 资源
├── ZhiYuDomain/                 # [ZhiYu] 业务领域大脑 & 契约 Protocols
├── ZhiYuAICore/                 # [ZhiYu] AI 中台适配器 (Prompt 沙箱/Reranker/MemoryAdapters)
└── ZhiYuFeatures/               # [ZhiYu] 垂直业务功能切片 (AI/Knowledge/Insight)

Sources/
├── App/                         # [L3] @main 入口、环境初始化、路由、AppStore、主题
│   ├── ZhiYuApp.swift           # 入口点，场景定义，全局环境注入
│   ├── AppEnvironment.swift     # L0-L2 初始化顺序编排，所有 Store 单例持有者
│   ├── ModuleRegistrar.swift    # 模块化 DI 注册（Core/Storage/Domain/App 四模块）
│   ├── Router.swift             # 全局导航状态管理（NavigationPath + AppRoute 枚举）
│   ├── ViewFactory.swift        # 按功能域注册 ViewProvider，解耦视图创建
│   ├── Store/AppStore.swift     # 全局状态树
│   └── Environment/             # 平台 AppEnvironmentProtocol 实现
├── Core/                        # [L0] ServiceContainer (DI)、协议、工具类、系统能力
│   ├── Base/                    # ServiceContainer、@Inject、协议定义、扩展、DTOs
│   └── System/                  # Logger、Analytics、Haptic、Security、Routing 等
├── Infrastructure/              # [L0–L1] 存储引擎、AI 客户端、向量索引、处理器
│   ├── LLM/                     # LLMService、LLMClient、PromptService、适配器
│   ├── Plugins/                 # PluginRegistry、PluginProtocols
│   ├── VectorDB/                # EmbeddingManager、VectorIndexer
│   ├── Storage/                 # SQLiteStore（GRDB）、Repository 实现、同步引擎、备份
│   ├── Processors/              # 文档处理器（TextChunker、Markdown、OCR）、图谱布局
│   └── Performance/             # PerformanceBenchmarker
├── Domain/                      # [L2] 模型定义、领域协议、RAG 管道抽象
│   ├── Models/                  # KnowledgePage、PageLink、PageSchema 等核心模型
│   ├── Protocols/               # KnowledgeRepository、VectorRepository 等仓储协议
│   └── RAG/                     # KnowledgeIngestPipeline、PromptRegistry、RAGEvaluation
├── Features/                    # [L2–L3] 按功能域组织的业务逻辑与视图
│   ├── AI/                      # Chat、Synthesis、Quiz、VoiceNote、TaskCenter
│   ├── Knowledge/               # Ingest、Graph、Search、Vault、NotebookHub
│   ├── Insight/                 # Dashboard、Lint、Log、MedalWall
│   └── System/                  # Settings、Auth、Collaboration
├── Shared/                      # [L3] 跨平台共享
│   ├── DesignSystem/            # 设计令牌（Colors、Typography、Spacing）、主题管理
│   ├── UIComponents/            # 通用 UI 组件库（Buttons、Cards、Editors、Overlays 等）
│   └── Platforms/Adaptor/       # 跨平台适配
├── Platforms/                   # 平台特定实现 (iOS / macOS / watchOS)
└── Localization/                # 多语言 .xcstrings（含分表，通过 update_localization.py 合并）
Tests/
├── Unit/                        # 单元测试（AI、Graph、Plugins、Security、Services、Storage）
├── Integration/                 # 集成测试（如 RAGPipelineTests）
├── UI/                          # UI 测试
├── SnapshotTests/               # 快照测试（使用 pointfreeco/swift-snapshot-testing）
├── Boundary/                    # 边界测试
├── Performance/                 # 性能测试
└── Shared/                      # 共享测试资源（AppStoreTests、TestMocks）
```

## 关键模式

### 启动顺序与依赖注入

服务注册遵循严格的初始化链条（见 `AppEnvironment.init()`）：

1. **数据库** → `DatabaseManager.shared.setup(at:)` 确保护航数据库就绪
2. **L0 注册** → `CoreModuleRegistrar`：Logger、平台适配器、系统服务
3. **L1 注册** → `StorageModuleRegistrar`：SQLiteStore、Repository 实现、EmbeddingManager
4. **L2 注册** → `DomainModuleRegistrar`：LLMService、AISynthesisService、IngestService 等
5. **L3 注册** → `AppModuleRegistrar`：Router、ViewFactory 注册各功能域 ViewProvider
6. **Store 初始化** → `IngestStore()`、`SynthesisStore()`、`AppStore()` （在 DI 完成后实例化）

### `@Inject` 属性包装器

```swift
@Inject var store: AppStore
```

从 `ServiceContainer.shared` 解析服务。服务必须在使用前注册——未注册会触发 `fatalError`。
对于 `@Observable` 类型，一般由 `AppEnvironment` 直接持有并通过 SwiftUI `.environment()` 注入，而非通过 `@Inject` 解析。

### 模块化注册 — ModuleRegistrar 协议

所有服务注册通过实现 `ModuleRegistrar` 协议完成。四个注册器按序执行，解耦 ZhiYuApp 的初始化：
- `CoreModuleRegistrar` — 日志、平台适配、系统级服务
- `StorageModuleRegistrar` — 数据库、仓储、向量索引（`guard` 确保数据库就绪）
- `DomainModuleRegistrar` — 业务逻辑、AI 能力、插件系统
- `AppModuleRegistrar` — Router、ViewFactory

### 路由系统

`Router` 是全局导航状态管理者（`@Observable`，`@MainActor`，单例）：
- `AppRoute` 枚举定义所有路由目标（含 `.sidebarSelection`、`.domain` 映射）
- `NavigationPath` 管理推栈导航；顶层切换时自动清空路径
- 详情页（`.pageDetail`、`.settings` 等）推入路径，顶层工具切换替换 `sidebarSelection`

### 视图工厂 — ViewFactory

功能域视图通过 `ViewFactory` + `ViewProvider` 协议注册，按 `FeatureDomain`（knowledge/ai/insight/system）分派视图创建，解耦全局路由与具体视图实现。

### 并发

- 严格并发检查**已启用**（`SWIFT_STRICT_CONCURRENCY: complete` — Swift 6 模式）
- 优先使用 `async/await` 和 `actor`；绝不使用锁或信号量
- UI 绑定代码必须标注 `@MainActor`
- 非 `Sendable` 单例类，将 `static let shared` 标记为 `nonisolated(unsafe)`。

## Targets

- **ZhiYu** — iOS 应用（iPhone/iPad），主 target
- **ZhiYuMac** — Mac Catalyst 应用
- **ZhiYuWatch** — 独立 watchOS 应用
- **ZhiYuWidgets** — iOS Widget 扩展（Live Activities）
- **ZhiYuTests** — 单元测试 bundle

## 外部依赖

- [GRDB](https://github.com/groue/GRDB.swift.git) (~> 6.29) — SQLite + FTS5 数据库
- [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing) (~> 1.17) — 快照测试

## 提交规范

- `feat:` — 新功能
- `fix:` — 缺陷修复
- `docs:` — 文档更新
- `refactor:` — 代码重构
- `perf:` — 性能优化

## 注释规范

统一使用**简体中文**书写所有注释：
- **文档注释（`///`）**：解释"为什么"，用于公开 API。
- **实现注释（`//`）**：解释"怎么做"，用于内部逻辑。
- **MARK 标签**：使用 `// MARK: - 中文标题` 格式。

## Skill routing

When the user's request matches an available skill, invoke it via the Skill tool. When in doubt, invoke the skill.

Key routing rules:
- Product ideas/brainstorming → invoke /office-hours
- Strategy/scope → invoke /plan-ceo-review
- Architecture → invoke /plan-eng-review
- Design system/plan review → invoke /design-consultation or /plan-design-review
- Full review pipeline → invoke /autoplan
- Bugs/errors → invoke /investigate
- QA/testing site behavior → invoke /qa or /qa-only
- Code review/diff check → invoke /review
- Visual polish → invoke /design-review
- Ship/deploy/PR → invoke /ship or /land-and-deploy
- Save progress → invoke /context-save
- Resume context → invoke /context-restore
- Author a backlog-ready spec/issue → invoke /spec
