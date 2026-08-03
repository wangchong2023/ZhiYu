# 智宇 (ZhiYu) - AI 原生知识管理应用

智宇 (ZhiYu) 是一款面向 iOS、macOS 和 watchOS 的 AI 原生知识管理应用，基于 Andrej Karpathy 的 LLM Wiki 方法论构建。它不仅仅是一个 Markdown 编辑器，更是一个完整的 RAG (Retrieval-Augmented Generation) 闭环系统。

## 项目概览

- **核心目标**：语义分块 → 混合 FTS5+向量存储 → AI 合成实验室（深度引用）。
- **主要技术栈**：
  - **语言**：Swift 6 (开启严格并发检查)
  - **UI 框架**：SwiftUI (全平台统一代码库)
  - **存储**：SQLite (GRDB.swift) + 向量存储
  - **AI**：本地/远程 LLM 适配，RAG 管道
  - **工程化**：XcodeGen (`project.yml`), SwiftLint, String Catalog (`.xcstrings`)

## 构建与开发

所有构建日志应存放在 `build/` 目录下。

```bash
# 从 project.yml 生成 Xcode 项目（配置变更后必须执行）
xcodegen generate

# 构建 iOS (iPhone/iPad)
xcodebuild build -project ZhiYu.xcodeproj -scheme ZhiYu -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO > build/ios_build.log 2>&1

# 构建 macOS (Catalyst)
xcodebuild build -project ZhiYu.xcodeproj -scheme ZhiYuMac -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO > build/mac_build.log 2>&1

# 构建 watchOS
xcodebuild build -project ZhiYu.xcodeproj -scheme ZhiYuWatch -destination 'generic/platform=watchOS Simulator' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO > build/watch_build.log 2>&1

# 运行 SPM 本地包极速单测 (脱离模拟器，毫秒级通过)
swift test --package-path Packages/UFPCore
swift test --package-path Packages/ZhiYuDomain
swift test --package-path Packages/ZhiYuAICore

# 运行主 App 单元测试
xcodebuild test -project ZhiYu.xcodeproj -scheme ZhiYu -destination 'platform=iOS Simulator,name=iPhone 17 Pro' > build/test_results.log 2>&1
```

## 架构规范 (SPM 本地多 Package 物理隔离)

项目遵循基于 SPM 本地多 Package 的垂直化切片架构，物理隔离 `import` 依赖。

| 层级 | 名称 | SPM 物理包 | 物理路径 | 核心职责 |
| :--- | :--- | :--- | :--- | :--- |
| **L3** | 应用层 (App) | `ZhiYu` App Target | `Sources/App/` | 全局入口、环境配置、路由中心 |
| **L2** | 业务功能层 (Features) | `ZhiYuFeatures` | `Packages/ZhiYuFeatures/` | 业务切片 (AI/Knowledge/Insight) |
| **L1.5** | 领域层 (Domain) | `ZhiYuDomain` | `Packages/ZhiYuDomain/` | **核心业务大脑**：业务规则、RAG 契约 |
| **L1** | 基础设施层 (Infra) | `ZhiYuAICore` / `UFPStorage` | `Packages/ZhiYuAICore/`, `Packages/UFPStorage/` | AI 适配器与物理存储算子 |
| **L0** | 底层基座层 (Base) | `UFPCore` | `Packages/UFPCore/` | 内核：DI 容器、Logger、全局协议 |
| **Shared** | 共享标准层 | `UFPDesignSystem` | `Packages/UFPDesignSystem/` | 视觉标准：Design Token、`Bundle.module` |

## 目录结构 (物理归位)

- `Packages/`: 本地 SPM 物理隔离包（`UFPCore`, `UFPStorage`, `UFPDesignSystem`, `ZhiYuDomain`, `ZhiYuAICore`, `ZhiYuFeatures`）。
- `Sources/App`: 应用启动逻辑与全局路由调度。
- `Sources/Core/Base`: 极简内核，无业务逻辑，无系统依赖。
- `Sources/Core/System`: 封装 Apple 系统框架能力。
- `Sources/Domain`: 核心业务逻辑、领域模型与中台化服务。
- `Sources/Infrastructure`: AI 客户端、存储引擎的具体实现。
- `Sources/Features`: 业务功能模块，按领域分组。
- `Sources/Shared`: 设计令牌与跨业务通用 UI 组件。
- `Sources/Localization`: 全局 String Catalog 资源。
- `Sources/Platforms`: 平台特有的桥接实现（iOS, macOS, watchOS）。
- `Docs/Architecture`: 存储架构设计文档、分层规范与运维手册。


## 开发约定

### 1. 依赖注入 (DI) 与依赖倒置 (DIP)
- 使用 `ServiceContainer` 模式和 `@Inject` 属性包装器。
- **强制约束**：业务功能层 (Features) 严禁直接依赖基础设施的具体实现类（如 `SQLiteStore`）。必须通过定义在 `Core/Base` 或 `Domain/Protocols` 中的协议（如 `any AnyPageStoreCapabilities`）进行注入。所有服务必须在 `ZhiYuApp.init()` 中注册。

### 2. 领域层纯净化 (Domain Purity)
- **强制约束**：L1.5 领域层必须保持平台无关。严禁在 Domain 层导入 `ActivityKit`, `UIKit`, `AppKit` 或使用 `#if os` 宏进行业务分支。平台相关的能力必须抽象为协议并下沉至 `Platforms/` 或 `Core/System/` 实现。

### 3. 并发模型 (Swift 6)
- 启用 `SWIFT_STRICT_CONCURRENCY: complete`。
- 优先使用 `async/await` 和 `actor`；避免使用传统锁。
- UI 绑定代码必须标注 `@MainActor`。
- 非 `Sendable` 的单例常量需标注 `nonisolated(unsafe)`。

### 3. 注释与文档
- **统一使用简体中文**书写所有注释。
- **文档注释 (`///`)**：解释“为什么”，用于公开 API。
- **实现注释 (`//`)**：解释“怎么做”，用于内部逻辑。
- **MARK 标签**：`// MARK: - 中文标题`。

### 4. 本地化 (L10n) 强约束规范
- **禁止硬编码**：UI 层、业务逻辑与处理器严禁出现硬编码中文/ASCII 字符串或裸露过滤关键词（如 `"篇幅要求"`, `"目标受众"`）。所有展示与过滤文本必须通过 `L10n.模块.属性` 强类型访问。
- **禁止直连 tr()**：严禁在业务视图或服务层直接调用 `.tr()`。
- **禁止假国际化**：在 `L10n+XXX.swift` 扩展中，禁止直接赋值硬编码中文，必须映射至 `.xcstrings`。
- **强校验网关**：项目已集成 `ios-check-code-localization.py` 编译网关。任何硬编码非 ASCII 字符或非法 `.tr()` 调用将**阻断编译**。

### 5. 设计系统 Token 强约束 (Design System Tokens)
- **禁止硬编码 UI 尺寸**：严禁在 SwiftUI 视图中使用硬编码字号、边距、圆角或透明度（如 `.padding(12)`, `.font(.system(size: 16))`）。
- **统一 Token 引用**：必须使用 `DesignSystem` 令牌（如 `DesignSystem.standardPadding`, `DesignSystem.medium`, `DesignSystem.titleFontSize`）。

### 6. 去魔鬼化数字/字符/字符串 (No Magic Numbers/Strings)
- **提取强类型常量**：业务逻辑、限制阈值、校验常量、Prompt 关键词组必须抽取为强类型常量枚举或 `L10n` 扩展。
- **禁止内联魔鬼常量**：严禁在代码中出现内联魔鬼数字（如 `3`, `5`, `15`）或硬编码正则特征字面量。

### 5. 编码风格
- 遵循 `Docs/Guides/swift-coding-style.md`。
- `import` 管理：Model/Service 层 `import Foundation`（严禁导入 `SwiftUI`）；View 层 `import SwiftUI`。
- 协议遵循放在独立 `extension` 中。

### 6. 脚本管理规范
- **长期工具**：存放在 `Tools/` 目录下，按用途分入子目录（`Gatekeeper/`、`CI/`、`Lint/`、`Mock/`、`Plugins/`、`Utils/`）。
- **文档维护**：新增或移动脚本后，必须同步更新 `Tools/README.md`。

### 8. 单元测试编写核心原则（反覆盖率虚胖）
- **测试目的**：测试用例的唯一目的是发现真实潜在缺陷，绝非满足覆盖率的静态数字。
- **反模式拦截**：严禁编写无断言、常量断言或全依赖 Mock 绕过核心逻辑的“空测试”。
- **变异与错误路径**：除 Happy Path 外，必须包含注入错误参数、依赖故障或临界越界的变异/反向断言。
- **禁止静默 `try?`**：抛错路径必须使用 `XCTAssertThrowsError` 精准校验类型与 Message。

### 9. 开源选型优先原则 (Open-Source First Policy)
- **强约束规则**：如果实现 1 个功能在业界存在开源成熟、稳定的开源库，**必须优先通知 USER 进行选型对比与决策**，严禁擅自直接造轮子自研写代码。

## 提交规范
使用 Conventional Commits 格式：
- `feat:` (新功能), `fix:` (缺陷修复), `docs:` (文档), `refactor:` (重构), `perf:` (优化)。

## 关键文件路径
- `Sources/ZhiYuApp.swift`: 应用入口与服务注册中心。
- `Sources/Core/Base/ServiceContainer.swift`: DI 容器实现。
- `Sources/Domain/Models/`: 核心领域模型。
- `Sources/Shared/UIComponents/`: 跨平台 SwiftUI 通用视图。
- `Tools/`: 开发者工具（`Gatekeeper/` 编译门禁、`CI/` 流水线、`Lint/` 代码检查、`Mock/` 模拟服务器、`Plugins/` 插件SDK、`Utils/` 辅助脚本）。
- `project.yml`: XcodeGen 项目定义。
