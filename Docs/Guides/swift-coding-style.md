# Swift 编码风格指南

> 本文档是 GEMINI.md 中 `## 代码风格约定` 的详细展开。高频规范保留在 GEMINI.md，细节约定在此。

## 代码质量与复杂度指标 (Complexity & Quality)

- **圈复杂度 (McCabe Cyclomatic Complexity)**: 单个函数的圈复杂度严禁超过 **15**。
- **函数长度**: 单个函数行数严禁超过 **100 行**（Non-Blank, Non-Comment, NBNC）。
- **设计原则**: 严格遵循 **SOLID** 和 **KISS** (Keep It Simple, Stupid) 原则。模块/文件/函数必须具备**单一职责**，确保**高内聚、低耦合**。
- **避免硬编码**: 严禁在业务逻辑中出现魔鬼数字 (Magic Numbers) 和硬编码字符串 (Magic Strings)，必须提取为 Constants 或配置。

## 注释规范 (Comments)

- **语言**: 必须使用**中文**编写所有注释。
- **完备性**: 文件头、函数头、关键控制流过程、枚举、类和结构体等都必须具备完备的中文注释。
  - **文档注释 (`///`)**：解释“为什么”，用于公开 API、类和枚举。
  - **实现注释 (`//`)**：解释“怎么做”，用于内部关键过程逻辑。
  - **MARK 标签**：`// MARK: - 中文标题` 用于分隔代码区块。

## 需求追踪与可回溯性 (Traceability)

为了实现最强的可回溯性，当前特性、规格、设计、代码和测试用例必须严格对应：
- 所有需求、测试用例、设计均需具备**编号**（如 SR-01）、**标题**和**描述**，并记录在文档中（如 `SOFTWARE_REQUIREMENTS_SPECIFICATION.md`）。
- **代码标记**: 在代码实现中，必须将对应的 SRS 编号以 `// MARK:` 或文档注释的形式标注出来。
  - 示例：`// MARK: [SR-03] 金库级锁定` 或 `/// @Docs/Requirements/SOFTWARE_REQUIREMENTS_SPECIFICATION.md#SR-03`
- **测试同步**: 必须同步考虑对应模块的单元测试、集成测试和系统测试的完整性。同时同步考虑 `.xcstrings` (String Catalog) 划分的合理性，其划分必须参考模块划分并建立对应关系。

## 可靠性与可运维性 (DFX, Logging, Tracing & Metrics)

- **日志与追踪**: 关键路径和异常分支必须有清晰的 Log 记录（区分 `debug`, `info`, `warning`, `error` 级别）。
- **性能监控 (Metrics)**: 核心算法和耗时操作需考虑注入性能埋点（Metrics），追踪响应延迟与成功率。
- **DFX (Design for X)**: 设计时需充分考虑可测试性 (Design for Testability)、可维护性 (Design for Maintainability) 与可靠性 (Design for Reliability)。

## 类型后缀语义

不同后缀代表所属层级与职责：

| 后缀 | 层级 | 用途 | 示例 |
|------|------|------|------|
| `Store` | L1 | 数据持久化与存储库实现 | `SQLiteStore`, `AnyPageStore` |
| `Service` | L1.5/L2 | 业务逻辑、领域行为或 UI 服务 | `LinkService`, `ChatService` |
| `Manager` | L0.5 | 系统资源管理与 OS 能力封装 | `SecurityManager`, `DatabaseManager` |
| `Provider` | — | 协议级功能或视图插件提供者 | `EmbeddingProvider`, `ViewProvider` |
| `Adapter` | — | 第三方服务或老旧接口适配 | `LLMAdapter` |
| `Coordinator`| L3 | 复杂视图导航或状态流转编排 | `iCloudSyncCoordinator` |
| `Delegate` | — | 跨层或跨模块回调代理 | `CollaborationDelegate` |

- 持久化操作统一后缀为 `Store`。
- 业务大脑逻辑统一后缀为 `Service`。
- 系统/硬件集成统一后缀为 `Manager`。

## 跨平台开发与平台宏规范 (Platform Macro Conventions)

为了确保“智宇”能够优雅地在 iOS, macOS, watchOS 间复用代码，必须严格执行以下三原则：

### 1. 协议屏蔽 (Rule 1: Protocol Shielding)
业务逻辑层（L1, L1.5, L2）**严禁散落** `#if os()`。任何涉及平台差异的功能（如触感、文件导出、提醒事项）必须：
- 在 `Base` 层定义抽象协议 (Protocol)。
- 在 `Platforms/` 目录下为各平台编写独立实现。
- 业务代码仅通过注入的协议引用，无需感知具体平台。

### 2. DI 路由 (Rule 2: DI Routing)
`#if` 唯一合法的**非 UI 场所**是 `ModuleRegistrar.swift`。
- 利用预编译宏在 `ModuleRegistrar` 中决定向 `ServiceContainer` 注入哪个平台的具体实现。

### 3. UI 优雅隔离 (Rule 3: UI Isolation)
在 SwiftUI 视图中，仅在无法通过原生修饰符抹平差异时才允许使用条件编译。
- 必须将差异部分提炼为独立的 `@ViewBuilder` 组件或局部视图结构。
- 严禁在主视图的布局逻辑中嵌套大段的 `#if os` 块。

---

## 属性包装器使用规范

- **依赖注入**: 统一使用 `@Inject` 访问跨层服务。
- **状态管理**: 逻辑层使用 `Observation` 框架的 `@Observable`；View 层使用 `@State`, `@Environment`。
- **持久化**: 全局偏好设置使用 `@AppStorage`（Key 必须来源于 `AppConstants.Keys.Storage`）。

---

## Protocol 命名

三种场景各用不同命名方式：

- **服务抽象**：`XxxProtocol` 后缀，如 `LLMServiceProtocol`, `LogServiceProtocol`
- **功能抽象**：`XxxProvider` / `XxxAdapter` / `XxxPlugin`，如 `EmbeddingProvider`, `LLMAdapter`
- **存在类型擦除**：`AnyXxx` 前缀 + 协议名，如 `AnyPageStore`

## Localization Key 格式

使用点分三级路径：`"domain.context.key"`

```swift
Localized.tr("splash.appName")                     // 页面 + 元素
Localized.tr("type.entity")                         // 分类 + 值
Localized.tr("schema.entity.field.definition")      // 域 + 上下文 + 字段
```

- 一级：功能域/页面（`splash`, `type`, `settings`, `schema`, `log`, `collab`）
- 二级：上下文（`entity`, `language`, `action`）
- 三级：具体字段/值

## CodingKeys 映射

GRDB / Codable 模型的 `CodingKeys` 使用 `snake_case` 映射，缩写展开：

```swift
enum CodingKeys: String, CodingKey {
    case id, title, type                          // 同名无需映射
    case customIcon = "custom_icon"               // camelCase → snake_case
    case sourceURL = "source_url"                 // 缩写(URL)展开
    case rawTextSnippet = "raw_snippet"           // 去掉冗余词
}
```

## Boolean 属性命名

统一前缀：`is` / `has` / `can` / `should`

```swift
let isPinned = true           // 状态判断
let hasSeenSplash = false     // 是否已发生
var canEdit: Bool             // 能力判断
var shouldRefresh: Bool       // 条件判断
```

## 补充规则

### 枚举布局风格

- 短枚举（3-5 个 case，无附加属性）：写在一行 `case a, b, c`
- 长枚举（有附加属性或方法）：每行一个 case，便于 diff

### 枚举 Raw Values

- **隐式**：仅内部使用、无 `Codable` 的枚举
- **显式**：实现了 `Codable` 的枚举

### 默认访问控制

默认 `internal`，`private` 优先于 `fileprivate`。测试通过 `@testable import` 访问。

### import 管理

- Model / Service 层：`import Foundation`，绝不导入 `SwiftUI`
- View 层：`import SwiftUI`

### 文件声明顺序

```
// MARK: - Properties         // 存储属性
// MARK: - Initialization     // init / setup
// MARK: - Public Methods     // 对外暴露的方法
// MARK: - Private Methods    // 内部实现
// MARK: - ProtocolName       // 协议遵循（每个协议一个 extension）
```

### 协议遵循用 Extension

协议实现放在独立 `extension` 中，不在类型声明体内联。`Identifiable`、`Equatable` 等无方法实现的协议可 SDK 直接标注。
