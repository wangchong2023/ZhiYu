# 实现模式参考

> 本文档是 CLAUDE.md 中 `## 关键模式` 的详细展开。

## Swift 6 编译器变通方案

- **`static let` 配合自定义 `Color(light:dark:)` 初始化器会失败**：Swift 6 在使用带嵌套闭包的自定义初始化器的 `static let` 属性时可能产生 "failed to produce diagnostic for expression" 错误。**变通方案**：改用 `static var` 计算属性：
  ```swift
  static var wikiCard: Color { Color(light: Color(hex: "ffffff"), dark: Color(hex: "202031")) }
  ```
- **`nonisolated(unsafe)` 用于单例**：非 `Sendable` 类中的 `static let shared` 需要该属性才能在 Swift 6 严格并发下编译通过。

## 架构解耦模式

### 1. 模块化 DI (Modular Dependency Injection)
### 1.1 SPM 本地包模块化与静态库链接范式 (Local SPM Packages)
为了在编译期硬阻断反向越级依赖并防止 iOS App 启动 (t1) 耗时恶化，本地包使用 `.static` 链接并在 `Package.swift` 中统一配置多平台支持：

```swift
let package = Package(
    name: "UFPCore",
    platforms: [.iOS(.v17), .macOS(.v14), .watchOS(.v10)],
    products: [
        .library(name: "UFPCore", type: .static, targets: ["UFPCore"]),
        .library(name: "UFPCoreTestMocks", type: .static, targets: ["UFPCoreTestMocks"])
    ],
    targets: [
        .target(name: "UFPCore"),
        .target(name: "UFPCoreTestMocks", dependencies: ["UFPCore"]),
        .testTarget(name: "UFPCoreTests", dependencies: ["UFPCore", "UFPCoreTestMocks"])
    ]
)
```

在测试环境中，单测通过 `swift test --package-path Packages/UFPCore` 秒级触发，无模拟器装载开销。

### 2. 能力协议 (Capability Protocols)
当 L2 服务需要访问 L1 Store 的特定高级功能（如向量索引）时，不要使用类型强转（`as? SQLiteStore`）。
- 定义 `VectorIndexableStore` 协议。
- Store 遵循协议。
- 服务通过 `if let store = pageStore as? any VectorIndexableStore` 访问。
- **优点**：消除硬编码依赖，维持分层边界。

### 3. Actor 化重型处理器 (Actor-based Processors)
计算密集型服务（OCR、语音识别）应定义为 `actor` 而非 `class`。
- **职责**：确保内部状态（如 Vision 请求队列）的并发安全。
- **规范**：移除 `@unchecked Sendable`，拥抱 Swift 6 的原生数据隔离。

### 4. 表现层扩展 (View Extensions)
模型（Model）层严禁 `import SwiftUI`。
- 图标（icon）、颜色（Color）属性应存放在 `Views/Styles/` 目录下的 Extension 中。
- **优点**：保持 Model 的纯粹性，方便多平台（如无 UI 的 CLI 工具）重用模型。

## 设计系统 Token 3级分层与 CI 魔鬼数字门禁

智宇遵循 W3C DTCG 与 Apple HIG 规范，建立三层 Token 结构：
1. **Tier 1 (Primitive)**: 基础物理数值 (`Spacing.small = 8pt`, `Opacity.subtle = 0.12`)。
2. **Tier 2 (Semantic)**: 场景语义数值 (`Color.appCard`, `Color.appBorder`, `Color.appText`, `Color.theme.red`)。
3. **Tier 3 (Component)**: 组件上下文数值 (`Spacing.Action.buttonHeight`, `Spacing.Sidebar.width`)。

### 规则与禁令：
- **绝对禁止 View 层变相算术 (Magic Math)**：严禁在 UI 视图组件中写 `loosePadding * 1.5`、`tiny * 0.6` 或 `atomic * 2` 等内联乘除加减法。必须直接使用具体命名的语义 Token。
- **静态 CI 门禁强阻断 (`audit-design-magic-numbers.py`)**：自动对 `.padding()`, `.frame()`, `.opacity()`, `Color(hex:)`, `Color(red:)`, `UIColor(red:)` 及 View 层 `Magic Math` 算术表达式进行编译拦截。

## SwiftUI 图谱模式

- **浮动控件**：对浮动在内容之上的控件（Picker、缩放按钮、筛选药丸），使用 `.overlay(alignment:)`。避免使用带有 `VStack { Spacer() }` 的 ZStack 子视图——它们会创建透明的全屏层，拦截触摸事件。`.overlay(alignment:)` 仅占据其内容的固有尺寸。
- **节点定位**：仅在最外层视图上使用**单个** `.position()` 修饰符。绝不要嵌套 `.position()`——双重定位会使节点偏移约 2 倍，而 Canvas 绘制的边则保持在正确的坐标，造成视觉错位。

## 合成文档多份存储

`AppStore.synthesisResults` 是 `[SynthesisType: [SynthesisDocument]]`，每种类型最多保留 **5 份**文档（新文档插入数组头部，超出则截断）。通过 `UserDefaults` key `synthesis_docs_<type.rawValue>` 持久化 JSON 数组。

- `renameSynthesisDoc(type:docID:newName:)` — 重命名
- `deleteSynthesisDoc(type:docID:)` — 删除
- `SynthesisView` 中通过 `.contextMenu` 长按触发重命名/删除，`selectedDoc` 驱动输出 sheet

## 每日/每周洞察缓存

- **每日闪念**（`KnowledgeInsightService.generateDailyRecap`）：UserDefaults key `daily_recap_yyyyMMdd`，当天仅生成一次，`forceRefresh: true` 可强制重新生成
- **每周报告**（`AppStore.generateWeeklyInsight`）：UserDefaults key `weekly_insight_<year>_<weekOfYear>`，当周仅生成一次，`forceRefresh: true` 可强制重新生成
- Dashboard 手动下拉刷新传入 `forceRefresh: true`

## 测验生成流程

AI 输出 JSON（匹配 `QuizModel` 结构，`answer` 为 0 起始索引，0=A/1=B/2=C/3=D）→ `AISynthesisService.canDecodeAsQuizModel()` 验证格式 → `PageDetailView` 解码为 `QuizModel` → `QuizView` 交互式展示（选项标签 A/B/C/D，解释文本中数字索引替换为字母）。若 JSON 格式不匹配，回退到 Markdown 渲染。

## Mermaid 渲染模式

**始终使用程序化 `mermaid.render()`**，不要依赖 `startOnLoad: true`（不稳定）。标准模式：

1. HTML 中设置 `startOnLoad: false`，使用 `mermaid.render('id', code)` 异步渲染 SVG
2. 外层 `waitForMermaid()` 轮询 CDN 脚本加载完成
3. `WKWebView.evaluateJavaScript` 会等待 Promise 完成
4. 渲染失败时显示中文错误提示

`MermaidWebView`（展示）和 `exportMindmapToPDF()`（导出 PDF）均遵循此模式。

## WebViewExportService

`WebViewExportService`（L0 层）使用隐藏 `WKWebView` 执行 JavaScript 实现跨平台导出：
- **PDF**：`marked.parse()` 渲染 Markdown → `WKWebView.createPDF()`
- **PPTX**：解析 Markdown 为幻灯片 → `PptxGenJS` 生成 Base64 → 写入文件

## UI 框架

- 100% SwiftUI（除 `LaunchScreen.storyboard` 外无 UIKit storyboard）
- 使用 Swift 5.9 `@Observable` 宏（非 `@ObservableObject` / `@Published`）
- `NavigationSplitView` 自适应布局：iPhone 上为 TabView，iPad 上为三列布局
- 通过 `ZhiYuMac` target 支持 Mac Catalyst，带有键盘快捷键（`CommandGroup`、`.keyboardShortcut`）

## LLM 提示词输入/输出长度控制（三层防御）

业界标准做法：**API 硬限制 + Prompt 软引导 + 客户端兜底截断**，三重保障防止回复失控和费用浪费。

### 架构

```
输入截断                         API 调用                         输出控制
────────                        ────────                         ────────
Chat 用户输入                    max_tokens = 1000               API 硬限制
  .prefix(1000)         ──→      (ChatRunner.generate)    ──→    绝对不超

合成功能 content                 Prompt 注入                      Prompt 软引导
  .truncated(500)       ──→      "控制在1000字以内"        ──→    提升质量

所有 generate() 调用             PromptConstants.TokenLimits     客户端兜底
  自动携带 maxTokens 默认值       统一配置入口                     .prefix()
```

### 统一常量 (`PromptConstants.TokenLimits`)

| 常量 | 值 | 作用域 | 说明 |
|------|----|--------|------|
| `maxUserInputLength` | 4000 | Chat 用户输入 | ChatCoordinator 发送前截断 |
| `maxSynthesisInputLength` | 8000 | 合成/后台 prompt | AISynthesisService 截断防护 |
| `defaultMaxOutputTokens` | 3072 | 所有 LLM 调用 | LLMService.generate() 的 max_tokens 参数 |

> 所有限制归位至 `Sources/Domain/Models/PromptConstants.swift` 的 `PromptConstants.TokenLimits` 中统一治理。

### 5. 提示词安全沙箱模式 (`PromptSecuritySanitizer`)
为防御恶意的外部网页/Markdown 文本引发的 Prompt 越狱注入攻击：
- 使用 `<context>` 标签显式包裹 RAG 召回的知识库文本。
- 使用 `<user_query>` 标签显式包裹用户输入的 Prompt，隔离伪造的 System Prompt。
- 集成特征词检测器 (`scanJailbreakAttempt`)，拦截注入模式。

### 6. RAG 二次重排序模式 (`ContextReranker`)
在多路召回（Vector + FTS5）之后，使用 `ContextReranker` 执行二阶段重排序：
- 按关键词交叉覆盖密度 (Cross-Matching Density) + 向量分值二次计分。
- 按 0.35 置信度极小门限剔除噪点，精选 Top-5 高匹配度切片，降低 Context 幻觉。

### 7. 开源适配器与契约隔离模式 (`MemoryEngineProtocol` & `SwarmMemoryAdapter`)
为了方便未来将 L1.5 领域层的记忆引擎无缝替换为开源实现（如 Swarm / Wax）：
- **L1.5 领域契约**：定义纯粹的 `MemoryEngineProtocol`。
- **L1 适配器**：实现自研的 `NativeMemoryEngine` 与开源 `SwarmMemoryAdapter`。
- **L3 / L2 解耦**：表现层与 Store 仅依赖 `MemoryEngineProtocol` 接口，可以在 DI 注册中心 (`ServiceContainer`) 中零修改热切换底层引擎。

### 流式 Chat 特殊处理

流式 Chat（`LLMChatService.streamChat`）走独立管线：
- **API 层**：`max_tokens: BusinessConstants.AI.maxOutputTokens`
- **Prompt 层**：注入 `lengthHint` → `"Keep response within 1000 characters."`
- **输入层**：`ChatCoordinator` 截断用户输入至 `maxUserInputLength`

### 非流式 generate() 特殊处理

所有通过 `llm.generate()` 的调用（合成、摄取、检索、重构）：
- `ChatRunner.generate()` 接受 `maxTokens` 参数，默认值 = `BusinessConstants.AI.maxOutputTokens`
- 协议 `LLMChatServiceProtocol` 声明 `maxTokens:` 为必选参数
- 所有现有调用方无需修改——默认值自动生效
- 特殊需求（如 `LLMRefactorService`）可显式传参覆盖：
  ```swift
  // 链接发现只需短输出
  try await generate(prompt: ..., systemPrompt: ..., maxTokens: 500)
  ```

### 如何调整

```swift
// Sources/Domain/Models/BusinessConstants.swift
public struct AI {
    public static let maxUserInputLength: Int = 1000     // ← 改这里
    public static let maxSynthesisInputLength: Int = 500 // ← 改这里
    public static let maxOutputTokens: Int = 1000        // ← 改这里
}
```

修改后重新编译即可，无需改动任何其他代码。

## AppError 统一错误工厂 (v2.0 新增)

所有业务层 NSError 创建收敛至 `Core/Base/Utils/AppError.swift`：

```swift
// ❌ 旧模式 — 分散的 NSError 样板
throw NSError(domain: "Insight", code: -1, userInfo: [NSLocalizedDescriptionKey: L10n.xxx])

// ✅ 新模式 — AppError 工厂
throw AppError.insight(L10n.xxx)
throw AppError.insight("日期计算失败", code: -2)
throw AppError.auth(domain: "GoogleAuthStrategy", code: -99, description: "...")
throw AppError.ingest("存储空间已满", code: -1)
throw AppError.synthesis("任务进行中")
throw AppError.security("签名仓库未注册")
throw AppError.exportNotSupported()
```

**已应用范围**: Insight(6处), Ingest(4处), Auth(10处), Synthesis(2处), Security(1处)

## 平台适配模式 (v2.1 更新)

### 协议驱动跨平台架构

> 完整设计见 [`Docs/Architecture/PLATFORM_PROTOCOL_ARCHITECTURE.md`](../Architecture/PLATFORM_PROTOCOL_ARCHITECTURE.md)

**核心原则**：业务层（Features/Domain）绝不使用 `#if os()` 宏。平台差异通过协议抽象 + DI 注入解决。

**协议定义** → `Core/Base/Protocols/`:
| 协议 | 能力 |
|------|------|
| `DeviceInfoProtocol` | 系统版本、设备型号、屏幕高度 |
| `URLOpenerProtocol` | 异步打开 URL |
| `ShareSheetProtocol` | 展示系统分享面板 |
| `PasteboardProtocol` | 剪贴板读写（已支持 mutation） |

**平台实现** → `Platforms/{iOS,macOS,watchOS}/Services/` (共 12 个实现类)
**DI 注册** → `Platforms/{iOS,macOS,watchOS}/Registrar/` (通过 `PlatformRegistrar` 模式)

### PlatformModifiers — View 层平台差异封装

```swift
// ❌ 旧模式 — View 文件中直接 #if os
#if !os(watchOS)
    .pickerStyle(.segmented)
#endif

// ✅ 新模式 — 语义化 View Modifier
.segmentedPickerStyleIfAvailable()    // iOS/macOS 上分段选择器
.inlineNavigationBarTitleIfAvailable() // iOS 上内联标题
.hiddenOnWatch()                       // watchOS 上隐藏
.visibleOniOSOrMac()                   // 仅非手表显示
.toolbarIfNotWatchOS()                 // 非手表上渲染工具栏
.adaptiveSidebarListStyle()            // macOS 自动 .sidebar
.skipOnWatch { $0.keyboardType(.numberPad) } // watch 上安全跳过
```

**位置**: `Shared/UIComponents/Modifiers/PlatformModifiers.swift`

### PlatformRegistrar — DI 层平台分发

```swift
// CoreModuleRegistrar 中：单一分发点替代 15 个 #if os 块
#if os(macOS)
MacPlatformRegistrar.registerServices(in: container)
#elseif os(watchOS)
WatchPlatformRegistrar.registerServices(in: container)
#else
iOSPlatformRegistrar.registerServices(in: container)
#endif
```

**各平台实现**: `Platforms/{iOS, macOS, watchOS}/{iOS, Mac, Watch}PlatformRegistrar.swift`

## DesignSystem 常量迁移模式 (v2.0 新增)

```swift
// ❌ 旧模式 — 魔鬼数字
.clipShape(RoundedRectangle(cornerRadius: 12))
.padding(16)

// ✅ 新模式 — DesignSystem 语义常量
.clipShape(RoundedRectangle(cornerRadius: DesignSystem.cardRadius))
.padding(DesignSystem.standardPadding)
```

**迁移映射表**:

| 硬编码 | DesignSystem |
|--------|-------------|
| `cornerRadius: 4` | `DesignSystem.microRadius` |
| `cornerRadius: 8` | `DesignSystem.smallRadius` |
| `cornerRadius: 10` | `DesignSystem.mediumRadius` |
| `cornerRadius: 12` | `DesignSystem.cardRadius` |
| `cornerRadius: 14` | `DesignSystem.largeRadius` |
| `cornerRadius: 24` | `Spacing.giant` |
| `padding(8)` | `DesignSystem.tightPadding` |
| `padding(16)` | `DesignSystem.standardPadding` |

## @Inject DI 模式 (v2.0 强化)

```swift
// ❌ 旧模式 — 方法内重复 resolve
func streamChat(...) {
    let llmService = ServiceContainer.shared.resolve((any LLMServiceProtocol).self)
    let logger = ServiceContainer.shared.resolve((any LoggerProtocol).self)
}

// ✅ 新模式 — 类级别 @Inject
@Inject private var llmService: any LLMServiceProtocol
@Inject private var logger: any LoggerProtocol

func streamChat(...) {
    logger.debug("[ChatService] starting...")
}
```

**Actor 跨边界传递**:
```swift
actor IngestService {
    @Inject private var dbManager: DatabaseManager
    func ingest() async {
        let manager = dbManager  // 捕获以跨 actor 边界
        await MainActor.run { manager.incrementActiveTransactions() }
    }
}
```

## 代码拆分模式 (v2.1 更新)

> 完整 SRP 方法论见 [`Docs/Guides/srp-file-organization.md`](./srp-file-organization.md) — 含 9 个实战案例、View/Service 拆分模式、编译验证流程。

### View 文件分组件拆分

当 View 文件超过 500 行且有清晰的 MARK 分区时：

```
GraphComponents.swift (592行)
  → GraphComponents.swift (336行) — 核心视图
  → GraphInfoPanel.swift (272行) — 信息面板

SystemStatsView.swift (626行)
  → SystemStatsView.swift (419行) — 主布局
  → SystemStatsChartView.swift (222行) — 图表渲染
```

### 拆分原则
- **优先 class/actor 文件**: 可安全提取为 extension 文件
- **SwiftUI struct 谨慎**: 计算属性 subview 无法安全抽取，标记为设计约束
- **有测试覆盖的文件优先**: 拆分后立即运行测试验证

## 文件头注释规范 (v2.0 新增)

```swift
//
//  FileName.swift
//  ZhiYu
//
//  Created by ... on ...
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：领域相关的具体描述，而非"提供相关的结构体或工具支撑"。
//
```

- **系统层级**: L0-L3 标识
- **核心职责**: 一句话说清本文件的职责，避免模板化表达
- 278 个文件已从模板注释更新为领域描述

## Prompt 统一集中管理与安全合规防护模式 (v2.2 新增)

### 1. 注册与渲染 (GlobalPromptRegistry)
UI 或 Service 层严禁在内部拼接或硬编码系统 Prompt 文本，必须调用：
```swift
let finalPrompt = GlobalPromptRegistry.render(
    templateKey: "synthesis.summaryReport",
    variables: ["LANGUAGE": "zh-Hans", "CONTENT": safeUserContent]
)
```

### 2. 5层摄入清洗 (IngestSanitationPipeline)
多模态文档与网页数据在提交给 LLM 前必须通过 5 层清洗流水线：

---

## AI 结构化解析与开源选型决策矩阵 (Open-Source Selection Matrix)

基于智宇 **“开源选型优先原则 (Open-Source First Policy)”**，针对 AI 合成实验室在文本解析、JSON 语法容错与 Markdown 渲染上的评估选型归档如下：

| 技术领域 | 选型方案 | 包体积 / 架构影响 | 许可 (License) | 决策理由 |
| :--- | :--- | :--- | :--- | :--- |
| **JSON 语法自愈自检** | **`JSONRepairProcessor`** (自研轻量状态机) | ~15KB (纯 Swift 零外部依赖) | MIT | 大模型输出中常出现未闭合括号 `}`、缺失引号或尾部逗号。引入自研 15KB 轻量状态机在反序列化前修复，比引入重型 CocoaPods 降低了 98% 的工程复杂度，且 100% 解决试题解码失败问题。 |
| **高质感 Markdown 渲染** | **`swift-markdown-ui`** | ~120KB (SwiftUI 原生 GFM) | MIT | GitHub 3.5k Star 成熟库。相比原生 `Text` 正则拼装，能原生渲染优雅标题分界、代码块卡片背板、Markdown 表格与双向 WikiLink 交互，全面提升深度报告排版质感。 |
| **双向链接 `[[WikiLink]]` 提取** | **`WikiLinkExtractor`** (纯 Swift 正则与提取器) | ~5KB (UFPCore 共享算子) | MIT | 统一提取 `[[页面标题]]` 与 `[[页面标题\|别名]]`，与 `Router` 推栈与 `SynthesisSourcePagesBar` 芯片形成双向联动。 |
```swift
let pipeline = IngestSanitationPipeline()
let sanitizedText = try await pipeline.sanitize(
    rawInput,
    options: [.stripControlCharacters, .normalizeUnicode, .mergeOCRLineBreaks, .stripHTMLNoise]
)
```

### 3. 三级安全拦截与脱敏 (ContentModerationEngine / PromptSecurityGuard / PIIMasker)
- **Moderation**: 政治反动/黄色色情/暴恐涉禁直接抛出 `PromptComplianceError.contentViolatesPolicy` 物理死封阻断。
- **PII 脱敏**: 敏感隐私自动中和 `PIIMasker.maskPII(text)`。
- **Anti-Injection**: 定界符中和与 XML 安全沙箱包裹 `PromptSecurityGuard.sanitize(userInput)`。

### 5. GRDB 与 ZIPFoundation 全量物理隔离模式 (v2.3 新增)

基于 **开源选型优先原则** 与 **SPM 物理包隔离卡门**：

1. **GRDB 数据库依赖收敛**：
   - 彻底移除了所有 `Sources/` 层中的 `import GRDB`
   - GRDB 物理收敛至 `Packages/UFPStorage/` 包，并由 `GRDBReexport.swift` 唯一导出（`@_exported import GRDB`）
   - 所有业务存储 Repository 与系统存储服务统一使用 `import UFPStorage`
   - `StorageConstants` 只包含通用 SQLite 引擎参数（WAL 模式阈值、超时等），严禁硬编码业务表名

2. **ZIPFoundation 压缩归档解耦**：
   - 移除 `PluginLoader` 等业务层对 `ZIPFoundation` 的直接依赖
   - 在 `Platforms/iOS/Services/ZIPFoundationArchiver.swift` 封装完整提取逻辑，包含 VULN-014 路径穿越校验
   - 依赖方统一通过 `FileArchiverProtocol` 协议进行依赖注入

