# AGENTS.md

本文件为 Codex (Codex.ai/code) 在此仓库中工作时提供指导，回复问题和任务规划采用简体中文。

## 参考指南

| 指南 | 内容 |
|------|------|
| [swift-coding-style.md](Docs/Guides/swift-coding-style.md) | 命名、Protocol、Localization key、CodingKeys、Boolean 前缀等 Swift 编码约定 |
| [config-conventions.md](Docs/Guides/config-conventions.md) | project.yml、AppConfig.json、Asset Catalog、.xcstrings、文档目录规范 |
| [implementation-patterns.md](Docs/Guides/implementation-patterns.md) | Swift 6 变通方案、图谱模式、合成文档、缓存策略、Mermaid、UI 框架等 |
| [file-header-template.md](Docs/Guides/file-header-template.md) | 文件头注释模板：`系统层级` + `核心职责` 标注规范 |

## 文档索引

| 文档 | 内容 |
|------|------|
| `Docs/Architecture/HIGH_LEVEL_DESIGN.md` | L0-L3 分层、模块依赖、数据流 |
| `Docs/Architecture/LAYERING_L0_L3.md` | 严格分层架构定义与依赖规则（含 8 条红线 + 12 项 CI 门禁） |
| `Docs/Architecture/PLATFORM_PROTOCOL_ARCHITECTURE.md` | 🆕 跨平台协议分层设计、#if os() 宏协议化、PlatformRegistrar 模式 |
| `Docs/Guides/srp-file-organization.md` | 🆕 SRP 文件拆分原则、重构方法论、View/Service 拆分模式 |
| `Docs/Architecture/AUTH_ARCHITECTURE.md` | 认证架构与多平台登录流程 |
| `Docs/Design/DATABASE_SCHEMA.md` | 完整 DDL、ER 关系、索引设计 |
| `Docs/Design/EXTERNAL_API_SPECIFICATION.md` | 🆕 对外 RESTful API 接口规范（认证、订阅、反馈、RAG评估、本地LLM、插件市场等） |
| `Docs/Design/SECURITY_DESIGN.md` | 安全设计、OWASP、个人信息保护 |
| `Docs/Design/UI_COMPONENTS.md` | 通用 UI 组件库规范 |
| `Docs/Design/PLUGIN_SDK.md` | 插件 SDK 接口与沙箱规范 |
| `Docs/Requirements/PRODUCT_REQUIREMENTS.md` | 产品需求与功能范围 |
| `Docs/Requirements/SOFTWARE_REQUIREMENTS_SPECIFICATION.md` | 软件需求规格说明 |
| `Docs/Testing/TEST_CASES.md` | 各模块测试用例 |
| `Docs/Testing/UNIT_TEST_GUIDE.md` | 单元测试编写指南 |
| `Docs/Testing/SYSTEM_TEST_PLAN.md` | 系统测试计划 |
| `Docs/Architecture/CI_CD_WORKFLOW.md` | CI/CD 流水线与构建部署、Git 分支管理与 MR 卡控规范（对齐 ZhiYu-Backend） |
| `Docs/Design/SECURITY_THREAT_MODEL.md` | 安全威胁模型 |
| `Docs/Requirements/ROADMAP.md` | 版本路线图 |
| `Docs/Guides/CONTRIBUTING.md` | 贡献指南 |
| `Docs/Guides/USER_GUIDE.md` | 用户使用手册 |
## 任务清单与实施计划更新规范 (Task & Plan Protection Policy)

> **实施计划 (`implementation_plan.md`) 和任务清单 (`task.md`) 中如果存在未完成的事项，严禁未经 USER 确认直接覆写、删除或重置！修改或替换未完成事项前必须明确向 USER 汇报并获得确认。**

## 开源选型优先原则 (Open-Source First Policy)

> **如果实现 1 个功能在业界存在开源成熟、稳定的开源库，必须优先通知 USER 进行技术选型与决策，严禁直接造轮子自研写代码！**

1. **先评估后选型**：在规划任何复杂功能（如算法、解析器、加解密、文本清洗、语义分词等）时，必须先盘点业界主流开源方案（如 GitHub 高 Star SPM / CocoaPods / CMake 库）。
2. **主动通知决策**：列出开源库与自研方案在包体积、性能、维护成本、安全许可（License）上的对比，提交给 USER 进行选型确认后方可落地。

## 四大强制质量红线 (4 Non-Negotiable Quality Redlines)

> **所有 Agent 在此仓库编写、修补或重构 Swift 代码及自动化脚本时，必须严格遵守以下 4 条绝对红线，严禁任何违规！**

1. **🛡️ SonarQube 全语言 Quality Gate 硬阻断**：
   - 支持扫描全语言资产：`Swift (iOS/macOS)`、`Python`、`Shell (.sh/.bash)`、`YAML (.yaml/.yml)`。
   - 语句/行覆盖率 (Line / Instruction Coverage) 必须达标 **≥ 90.0%**。
   - 分支覆盖率 (Branch Coverage) 必须达标 **≥ 85.0%**。
   - 代码重复率 (Duplicated Lines %) 必须严格控制在 **< 3.0%**（全语言 CPD 引擎卡控）。
   - 触发方式：由 CI/CD 流水线中的 `sonar-scanner -Dsonar.qualitygate.wait=true` 执行卡控与阻断。

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

智宇 (ZhiYu) — 面向 iOS/macOS/watchOS 的 AI 原生知识管理应用，基于 Karpathy 的 LLM Wiki 方法论构建。不仅是一个 Markdown 编辑器，更是一个 RAG 闭环系统：语义分块 → 混合 FTS5+向量存储 → AI 合成实验室（含深度引用）。660 个 Swift 文件，~90K 行代码。

## 构建与开发 (Makefile SSOT)

建议优先使用根目录 `Makefile` 快捷入口（自动强载 `Config/.env.local` 环境变量并触发 `bootstrap.sh` 校验）：

```bash
# 自动强载环境变量 → 自动 xcodegen → 一键构建对应 Targets
make ios                  # 构建 iOS App (ZhiYu scheme)
make mac                  # 构建 macOS Catalyst App (ZhiYuMac scheme)
make watch                # 构建 watchOS App (ZhiYuWatch scheme)
make test                 # 运行主 App 单元测试
make test-spm PKG=包名     # 运行指定 SPM 本地包极速单测 (例: make test-spm PKG=UFPStorage)
make test-spm-all         # 运行全量 6 大 SPM 本地包极速单测 (UFPCore/Storage/DesignSystem/Domain/AICore/Features)
make test-all             # 运行全量 SPM 单测 + 主 App 单元测试
make audit                # 运行 CI 8 大架构与依赖审计门禁
make gen                  # 仅运行 bootstrap 加载环境并重生成 ZhiYu.xcodeproj
make lint                 # 运行 SwiftLint 严格检查

# 直接使用 xcodebuild（需手动先 source Config/.env.local）
xcodebuild build -project ZhiYu.xcodeproj -scheme ZhiYu -destination 'generic/platform=iOS'
xcodebuild build -project ZhiYu.xcodeproj -scheme ZhiYuMac -destination 'platform=macOS'
xcodebuild build -project ZhiYu.xcodeproj -scheme ZhiYuWatch -destination 'generic/platform=watchOS'
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
| **L2** | 功能层 | 业务逻辑服务 — 按功能域组织（AI / Knowledge / Insight / System） |
| **L1.5** | 领域层 | 业务规则、RAG 编排、跨模块契约（Domain Models、Protocols、KnowledgePageManager、KnowledgeIngestPipeline） |
| **L1** | 服务层 | 数据仓储（Repository）、AI 适配器（LLM、Embedding）、存储引擎、插件系统 |
| **L0** | 基础设施层 | SQLite (GRDB)、网络、Keychain、Logger、平台适配、DI 容器、基础协议 |

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

### 跨层协议定义位置

| 上层 → 下层调用 | 下层 → 上层调用 |
|----------------|----------------|
| 协议定义在 **L1.5 `Domain/Protocols/`** | 协议定义在 **L0 `Core/Base/Protocols/`** |
| 例：`TagStoreProtocol`、`IngestServiceProtocol`、`KnowledgeStoreProtocol` | 例：`SyncStateProvider`、`TextChunker` |

**DI 双注册规则**：必须同时注册协议类型和具体类型：
```swift
container.register(tagStore as any TagStoreProtocol, for: (any TagStoreProtocol).self)
container.register(tagStore, for: TagStore.self)
```

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
