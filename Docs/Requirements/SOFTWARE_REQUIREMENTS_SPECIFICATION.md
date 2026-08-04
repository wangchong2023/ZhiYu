# 智宇 (ZhiYu) 软件需求规格说明书 (SRS)

## 1. 性能需求 (Performance Requirements)

| 编号 | 指标项 | 目标值 (Threshold) | 验证环境 |
| :--- | :--- | :--- | :--- |
| **PR-01** | 全文搜索 (FTS5) 响应延迟 | < 100ms (10,000 节点) | iPhone 15 Pro |
| **PR-02** | 混合检索 (RAG) 链路耗时 | < 1.5s (含向量检索与 Rerank) | iPhone 15 Pro |
| **PR-03** | UI 帧率 (FPS) | 稳恒 60 FPS (图谱操作/滚动) | iPad Pro (M4) |
| **PR-04** | AI 思考指示器 (Pulse) 启动延迟 | < 200ms | iOS/macOS |
| **PR-05** | 数据库冷启动加载时间 | < 1.0s | iPhone 15 Pro |

## 2. 安全与隐私需求 (Security & Privacy)

### 2.1 数据隔离
- **SR-01**: 所有用户原始文档严禁在未经授权的情况下上传至云端。
- **SR-02**: 向量数据库 (Vector DB) 必须存储在 App 沙盒的私有目录下。

### 2.2 身份鉴权
- **SR-03**: 金库级锁定必须集成系统 `LocalAuthentication` 框架。
- **SR-04**: 插件执行环境必须实施 API 访问白名单管控，防止沙盒逃逸。

## 3. 技术规格 (Technical Specifications)

### 3.1 核心技术栈
- **UI 框架**: SwiftUI (100% Native)
- **并发模型**: Swift Actor / Structured Concurrency (Swift 6 Ready)
- **存储引擎**: SQLite 3.35.0+ (含 FTS5 插件)
- **向量引擎**: Accelerate.framework / Metal (vDSP)

### 3.2 平台兼容性
- **iOS/iPadOS**: 最小版本 17.0
- **macOS**: 最小版本 14.0 (Catalyst 兼容)
- **watchOS**: 最小版本 10.0 (独立的语音采集逻辑)

## 4. 可靠性与稳健性 (Reliability)

- **RR-01**: 数据库事务必须满足 ACID 特性，确保在进程崩溃时数据不损坏。
- **RR-02**: 系统必须支持“混沌恢复”能力（见 `SYSTEM_TEST_PLAN.md` 4.5 节）。
- **RR-03**: 内存占用在常规运行下不得超过 300MB，防止被系统 OOM 强制终止。

## 5. 本地化需求 (Localization)
- **LR-01**: 支持中英文双语切换，所有 UI 文本必须通过 `Localized.tr()` 动态加载。
- **LR-02**: 搜索算法必须支持 CJK (中日韩) 分词增强，解决 Markdown 中的中文搜索瓶颈。

## 6. 功能性需求 (Functional Requirements)

### 6.1 数据模型 (Data Models)

核心实体 `KnowledgePage` 字段定义：

| 字段 | 类型 | 说明 |
| :--- | :--- | :--- |
| `id` | `UUID` | 页面唯一标识，跨端同步主键 |
| `title` | `String` | 页面标题，FTS5 全文索引键 |
| `type` | `PageType` | 页面类型：`.concept` / `.fact` / `.question` / `.reference` |
| `content` | `String` | Markdown 正文，经插件 preProcess 后入库 |
| `aliases` | `[String]` | 别名列表，用于搜索联想与 `[[链接]]` 解析 |
| `tags` | `[String]` | 标签数组，支持插件自动标注 |
| `status` | `PageStatus` | `.active` / `.stub` / `.archived` / `.deprecated` |
| `confidence` | `Confidence` | 可信度：`.high` / `.medium` / `.low` / `.unverified` |
| `sources` | `[String]` | 引用来源 ID 列表 |
| `relatedPageIDs` | `[UUID]` | 双向链接关联页面 |
| `contentHash` | `String?` | 内容 SHA256 哈希，用于增量同步与去重 |
| `sourceURL` | `String?` | 原始资料链接（网页/YouTube），支持溯源 |
| `lamportTimestamp` | `Int64` | Lamport 逻辑时钟，LWW 冲突解决基础 |
| `created` / `updated` | `Date` | 创建与更新时间戳 |

### 6.2 API 契约 (LLMServiceProtocol)

LLM 服务协议定义在 `Sources/Shared/Services/Core/Protocols/LLMServiceProtocol.swift`：

| 方法 | 用途 | 约束 |
| :--- | :--- | :--- |
| `chat(query:pages:)` | 核心对话推理 | 同步返回 `ChatMessage`，含引用溯源 |
| `chatStream(query:pages:)` | 流式对话 | `AsyncThrowingStream<String, Error>`，支持逐字渲染 |
| `generate(prompt:systemPrompt:)` | 通用文本生成 | 插件 `requestAIAccess` 底层调用 |
| `smartIngest(title:rawContent:pages:)` | 智能编译 | 提取摘要、标签、关联建议 |
| `discoverPotentialLinks(content:existingTitles:)` | 链接发现 | 基于现有标题匹配潜在 `[[链接]]` |
| `foldContent(existingContent:newContent:title:)` | 智能折叠 | 增量融合新旧内容，防止知识碎片化 |
| `analyzeForRefactoring(pages:)` | 重构分析 | 返回 `[RefactorSuggestion]`，含合并/拆分建议 |
| `rewriteQuery(_:)` | 查询改写 | 将自然语言问题优化为检索友好格式 |
| `rerank(query:candidates:)` | 语义重排 | 对 Top-K 候选精排，修正向量漂移 |

### 6.3 插件接口 (Plugin Interfaces)

插件协议定义在 `Sources/Shared/Services/Plugins/PluginProtocols.swift`：

**基础协议 `KnowledgePlugin`：**
- `manifest: PluginManifest` — 元数据（id, name, version, permissions）
- `onLoad(context: PluginContext)` — 资源初始化与钩子注册
- `onUnload()` — 资源释放与钩子注销

**拦截器协议 `InterceptionPlugin`：**
- `preProcess(content:) -> String` — 入库前拦截（清洗、标注）
- `postProcess(content:) -> String` — 渲染前拦截（自定义语法）

**插件上下文 `PluginContext`：**
- `hostVersion: String` — 宿主版本号
- `log(_:)` — 统一日志输出
- `requestAIAccess(prompt:) -> String?` — 受权限管控的 LLM 访问
- `queryPages(matching:) -> [KnowledgePage]` — 受权限管控的页面查询

**权限枚举 `PluginPermission`：**
- `.readContent` — 读取页面内容
- `.writeContent` — 修改页面内容
- `.network` — 网络访问
- `.aiAccess` — 调用 LLM 服务

**Manifest 权限字符串：** `"storage.read"`, `"storage.write"`, `"llm.invoke"`, `"network.http"`, `"pages.read"`

### 6.4 状态管理 (State Management)

- **`AppStore`**：`@MainActor @Observable` 门面类，管理页面列表、搜索状态、导航路径、隐私模式
- **`@Inject` 依赖注入**：通过 `ServiceContainer` 解析服务实例，支持测试 Mock 替换
- **`SceneStorage` 桥接**：通过自定义 Binding 包装器将 `@Observable` 状态同步到 SwiftUI `@SceneStorage`，确保多窗口状态隔离
- **`AppNotifications`**：基于 `Notification.Name` 扩展的事件总线，`SQLiteStore` 发布数据变更信号，`GraphView` 等订阅者自动刷新。

### 6.5 分布式冲突解决 (LWW Strategy)

iCloud 多端同步采用 **Lamport Last-Writer-Wins (LWW)** 策略：

- **逻辑时钟**：每个 `KnowledgePage` 携带 `lamportTimestamp: Int64`，每次写操作递增
- **冲突检测**：`AppCloudSyncService.resolveSyncConflict()` 比较本地与远程页面的 `lamportTimestamp` 和 `updated` 时间戳
- **合并策略**：高时间戳版本获胜；同时间戳但不同 UUID 的标题冲突保留本地版本
- **用户回调**：`onConflictDetected` 闭包允许 UI 层介入自定义冲突解决策略
- **决议枚举**：`SyncConflictResolution` 支持 `.keepLocal` / `.keepRemote` / `.merge`

## 7. DFX 设计要求 (Design for X: Logging, Tracing & Metrics)

为确保高可靠性与可维护性，系统必须落实以下可观察性设计：

### 7.1 日志记录 (Logging)
- 所有关键路径（如网络请求、数据库操作、AI推理开始/结束）必须记录日志，统一通过 `Logger` 服务调用。
- 日志应包含清晰的动作 (`LogAction`) 和目标 (`target`)，方便后续审计过滤。
- **强制溯源**：实现关键特性的代码模块头部或对应函数中，必须通过 `// MARK: @SR-XX` 或者 `/// @Docs/Requirements/SOFTWARE_REQUIREMENTS_SPECIFICATION.md#SR-XX` 形式引用 SRS 需求编号。

### 7.2 性能度量 (Metrics)
- 核心耗时路径（见 **1. 性能需求**，如 PR-01, PR-02, PR-05）需通过 `PerformanceService` 追踪耗时，提供指标上报或输出到终端统计图表。

## 8. 代码规范补充要求

为达成高质量交付目标，系统必须遵守《Swift 编码风格指南》：
- **高内聚低耦合 (SOLID)**: 职责分离，跨模块需通过 Protocol 注入，禁止使用单例的隐藏依赖；UI 和业务逻辑完全解耦 (MVVM 演进或独立 Service)。
- **圈复杂度**: 函数内部圈复杂度严禁超过 15。
- **函数长度控制**: 单个函数的非空非注释行数 (NBNC) 严禁超过 100 行。超出则必须重构拆分。
- **中文注释完备性**: 模块文件头、关键类、结构体、枚举和算法函数均需配备清晰的中文注释，说明其意图、输入和副作用。
- **反“魔鬼数字/字符串”**: 杜绝将魔法值散落在逻辑代码中。颜色、间距等 UI 布局属性存放到 `Shared/DesignSystem/Tokens/` 目录下；专用布局模板存放于 `Shared/UIComponents/Layouts/` 目录下；业务常量存放于 `AppConstants.swift`。
- **UI 布局定制**: 重构时必须保持既有布局效果不变。全局公共标准存放在 DesignSystem 中，特定业务界面的布局定制模板应存放到 `Shared/UIComponents/Layouts/` 目录下。

## 9. 遗留技术规格与未来演进需求 (Legacy Technical Specifications & Backlogs)

基于近期系统的并发安全审计及竞品增强演进，定义以下后续版本需强制满足的技术规格指标：

### 9.1 并发与架构加固规格
- **SR-05 (线程安全隔离)**：`ServiceContainer` 全局依赖注入容器在多端并发（特别是 macOS 多窗口及 App Extension 小组件同时读取）时，必须 Actor 化或以自旋锁/读写锁进行物理隔离保护，防止发生竞态覆盖。
- **SR-06 (并发非阻塞规范)**：`DatabaseManager` 在执行 `switchDatabase` 或 `setup` 初始化连接池时，绝对禁止使用 `semaphore.wait()` 等同步阻塞主线程机制，必须彻底转换为 Swift Structured Concurrency 的 `async throws` / `await` 异步控制。
- **SR-07 (DIP 契约规范)**：业务功能层（Features L2）的 `KnowledgeStore` 严禁隐式注入或直接拉起基础设施层（Infra L1）的具体 SQLite 连接及行为，必须全部转换为对领域层（Domain L1.5）定义的 `Repository` 协议契约进行操作。

### 9.2 安全硬化规格
- **SR-08 (Keychain 降级强制物理隔离)**：通过宏定义 `#if DEBUG` 限定 Keychain 在模拟器无签名时的降级写 UserDefaults 行为。在 Release、Ad-Hoc 或是 TestFlight 打包编译时，Keychain 写入失败必须强行抛出 Crash 阻断，绝对禁止降级明文存储数据库密钥。
- **SR-09 (JSC 沙箱安全防御)**：插件执行的 `JSContext` 虚拟机中必须拦截并封禁 `eval`、`Function` 等具有动态生成代码能力的 JS 接口，对传入插件沙箱的 Swift 实体对象仅暴露只读值类型复制，杜绝引用传递造成的内存篡改。
- **SR-10 (数据库池确定性释放)**：在销毁或热切换 `DatabasePool` 连接池之前，必须显式调用底层的 `close()` 关闭句柄、中断所有活跃事务并强制将 WAL 写入主数据库，以防止在多金库切换时出现 `vnode unlinked while in use` 的 SQLite 驱动警告。

### 9.3 自动化与抓取演进规格
- **SR-11 (多源级联防爬与音频转写规格)**：
  - 级联防爬引擎（CaptureCascadeEngine）处理包含防爬和付费墙的新闻或科学站点时，提取的 Markdown 正文解析延迟不得超过 5.0s。
  - watchOS 离线麦克风音频采集必须以系统 `AVAudioRecorder` 物理落盘为 AAC-LC、单声道、16KHz 采样率格式，传输至 iOS 宿主后，后台 Whisper 处理吞吐率需满足 $1.5\times$ 播放速度。
- **SR-12 (外置 Agent 自动化总线规格)**：
  - 外置 AI 代理（如 Cursor/Claude Code）通过 App Intent 或者是 Local Socket 发起命令批量写入时，系统总线层必须实装限流（Throttling）保护，高频请求阈值限制为 $10\text{Hz}$，超出必须丢弃或拒绝连接以保护主进程资源。

---
*本规范受架构 4+1 视图约束，是系统验收的最高技术依据。*
