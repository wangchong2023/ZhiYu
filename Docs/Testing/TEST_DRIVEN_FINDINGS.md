# 智宇 (ZhiYu) 测试驱动发现问题台账 (Test-Driven Findings)

> **记录说明**：本台账遵循「测试以发现真实缺陷为目的」原则，收录在全工程单元测试补全、边界变异测试、快照测试及 CI 门禁审计过程中发现的所有真实功能缺陷、架构依赖隐患、状态机并发问题及代码风格坏味道。

---

## 📋 测试驱动发现问题台账汇总

| 序号 | 问题描述 | 严重程度 | 分类 | 修改方案 | 是否解决 |
| :---: | :--- | :---: | :---: | :--- | :---: |
| **01** | `SQLiteStore` 在未初始化或未就绪状态下直接调用 `fetchAllPages()` 会静默返回空数组而非抛出异常，掩盖数据库损坏 | **High** | 功能缺陷 | 在 `SQLiteStore` 增加 `isReady` 守卫逻辑与显式状态校验，未就绪时明确抛出 `DatabaseError.notReady` | **✅ 已解决** |
| **02** | `VectorRepository` 在面对维度不匹配向量（如 1536 维输入 vs 512 维索引）时计算余弦距离引发未定义行为或内存越界 | **High** | 功能缺陷 | 在向量插入与相似度检索前增加 `vector.count == expectedDim` 强校验断言与异常抛出 | **✅ 已解决** |
| **03** | `LLMClient` 遇到 HTTP 401 鉴权失效与 503 过载时重试逻辑死循环，未向 UI 抛出明确业务错误码 | **High** | 业务逻辑 | 重构重试策略：对于 401/403 鉴权类错误立即阻断重试并向上抛出认证异常，仅对 503/429 执行指数退避重试 | **✅ 已解决** |
| **04** | `ModelDownloadManager` 在磁盘剩余空间不足时未预检直接发起流式写入，导致写入中途崩溃并残留损坏文件 | **High** | 稳定性 | 在下载前通过 `FileManager.attributesOfFileSystem` 预检磁盘配额（保留至少 100MB 缓冲区），空间不足立即终止并清理临时文件 | **✅ 已解决** |
| **05** | `KnowledgeIngestPipeline` 在解析空 Markdown 标题或极小 chunk 时产生零字节片段并写入向量库，造成向量索引污染 | **Medium** | 数据治理 | 增加切片有效性清洗管道 `IngestSanitationPipeline`，过滤低于阈值字符且无语义的碎片 chunk | **✅ 已解决** |
| **06** | `GraphLayoutEngine` 在图谱存在自环边 (`source == target`) 或强连通环路时 Louvain 社区发现算法陷入死循环或除零错误 | **High** | 核心算法 | 增加图拓扑预处理逻辑：自动剥离自环边，并在 Louvain 模块度增益计算中加入极小步长保护与最大迭代轮数阈值 | **✅ 已解决** |
| **07** | `TextChunker` 遇到未闭合 Markdown 代码块（```` ``` ```` 缺失闭合）时会跨代码块切片导致语法高亮错乱 | **Medium** | 算法边界 | 引入代码块状态机跟踪器（`inCodeBlock`），未闭合代码块自动向上就近提升为独立原子 chunk | **✅ 已解决** |
| **08** | `SynthesisStore` 在已有任务处于 `.generating` 状态时未互斥，重复点击触发并发生成导致状态机状态覆盖与多重扣费 | **High** | 状态机并发 | 在 `SynthesisStore.startSynthesis()` 入口增加并发原子互斥锁与 `guard !isGenerating` 守卫 | **✅ 已解决** |
| **09** | `SynthesisStore` 结果缓存未设容量上限，大量生成导致内存无限膨胀与 OOM | **Medium** | 性能/内存 | 增加 LRU 容量限制策略（默认最大保留 5 份最近合成结果），超出容量时自动丢弃最旧结果 | **✅ 已解决** |
| **10** | `SynthesisStore` 允许保存纯 Mermaid 骨架（无正文描述）的伪合成内容，污染知识库 | **Medium** | 业务逻辑 | 在保存知识库前增加 `MermaidSanitizer` 与最小文本长度校验，纯骨架拒绝存入 | **✅ 已解决** |
| **11** | `ChatStore` 流式输出被用户手动显式取消时，游标未重置导致下次提问产生残留消息上下文污染 | **Medium** | 状态机 | 在 `ChatCoordinator.cancelStream()` 中增加完整的回滚逻辑与选择态原子重置 | **✅ 已解决** |
| **12** | `SettingsStore` 在依赖注入容器中缺少 `KeyStoreProtocol` 时直接触发 `fatalError` 导致 App 启动崩溃 | **High** | 架构健壮性 | 增加安全降级机制：无外部 KeyStore 注入时自动 fallback 到 `UserDefaultsKeyStore.standard` | **✅ 已解决** |
| **13** | `CollaborationView` 快照测试中因子视图 `UserProfileMenu` 隐式依赖 `@Environment(ThemeManager.self)` 导致主线程断言崩溃 (SIGTRAP) | **High** | 环境依赖 | 将快照测试中的手动环境拼装全面重构为统一 `.snapshotEnvironment()`，一次性装配全量 16 大环境对象 | **✅ 已解决** |
| **14** | `SnapshotTests` 中存在硬编码尺寸魔鬼数字 `.frame(width: 390, height: 844)` 违规 | **Low** | 风格/坏味道 | 重构为引用 `DesignSystem.Metrics.snapshotPhoneWidth` 与 `SnapshotConfig` 标准常量 | **✅ 已解决** |
| **15** | 快照测试文件中出现 6 处手动 `.environment(xxx)` 注入，违反统一注入规范 | **Low** | 门禁规范 | CI 门禁硬阻断后，已全量替换为 `.snapshotEnvironment()` 规范调用并通过 `make audit` | **✅ 已解决** |
| **16** | 历史代码库中存在使用字符串拼接的原生 SQL（`"DELETE FROM ..."`），绕过 GRDB 类型安全 | **Medium** | 坏味道/安全 | 全面废除拼接原生 SQL，重构为强类型 GRDB 表达式（`PageChunk.filter(...).deleteAll(db)`） | **✅ 已解决** |
| **17** | `RetryTask` 中在并发闭包内直接突变捕获变量 `callCount`（Swift 6 并发安全警告） | **Low** | 并发安全 | 重构为使用并发安全的原子计数器或 MainActor 隔离 | **✅ 已解决** |
| **18** | `BackupService` 与 `VaultLifecycleManager` 中存在无用未读取变量（`let service = ...`） | **Low** | 编译优化 | 消除无用变量赋值，规范化为 `_ =` 或精简消除 | **✅ 已解决** |
| **19** | `TaskCenter` 缺少全局单例状态持有者，不同模块直接实例化导致异步任务状态割裂与通知丢失 | **High** | 架构设计 | 重构为通过 `@Dependency(\.taskCenter)` 进行集中式单例生命周期编排与 DI 注入 | **✅ 已解决** |
| **20** | `SynthesisDocRow` 闭包回调在编辑态与常态下存在 3 处冗余重命名/导出参数未收敛，增加视图重绘开销 | **Medium** | 坏味道/性能 | 精简 `SynthesisDocRow` 接口签名，统一由父级 `SynthesisView` 状态机接管复杂动作分发 | **✅ 已解决** |
| **21** | `Vault` 实体在部分旧代码中仍使用弃用的 `colorHex` 字段传参，导致强类型初始化编译告警 | **Low** | 风格/类型规范 | 统一清除废弃属性，规范化为引用 `themePayload` 与内置主题工厂 | **✅ 已解决** |
| **22** | 快照测试函数名中文命名违规（如 `testSecurityManager_verifyIntegrity_文件不存在_模拟器放行`） | **Low** | 命名规范 | 46 个测试方法已 100% 重构为标准纯英文驼峰命名，中文说明统一收敛至函数文档注释 | **✅ 已解决** |
| **23** | `iOSSpeechService` 在启动录音时将 MPEG4AAC 编码器错误指定为 `.mp3` 扩展名，导致 CoreAudio 抛出 1718449251 不支持格式错误并使录音初始化失败 | **High** | 核心功能缺陷 | 将文件容器扩展名从 `.mp3` 修复为标准 `.m4a` 容器扩展名 | **✅ 已解决** |
| **24** | `VaultLifecycleManager.deleteVault` 在删除当前活动保险库时未发送 `.vaultWillSwitch` 广播，导致依赖活动库的后台队列与缓存无法感知销毁而继续向已擦除沙盒写入 | **High** | 数据与生命周期一致性 | 在 `deleteVault` 释放连接前增加 `.vaultWillSwitch` 广播分发，通知全系统清空挂起任务与缓存 | **✅ 已解决** |
| **25** | `SearchStore.performAdvancedSearch` 缺少对空字符串/纯空白字符查询的防御性校验，导致空查询直接穿透至底层向量计算与混合检索 | **Medium** | 坏味道与防御性编程 | 在方法入口增加 `guard !query.trimmingCharacters(...).isEmpty` 拦截并安全重置结果 | **✅ 已解决** |
| **26** | `NotebookHubViewModel.confirmRename` 缺少对空白名称的拦截过滤，允许将笔记本名称重命名为纯空格非法字符串 | **Low** | 业务边界校验 | 在 `confirmRename` 中增加 `guard !trimmed.isEmpty` 校验，防止非法空白名称持久化 | **✅ 已解决** |
| **27** | `OAuthService.resolveAuthRequestInfo` 生产路由解析中错误引用了 `FeatureConstants.MockData.carrier` 常量而非领域级提供商常量 | **Low** | 代码风格与常量归位 | 在 `FeatureConstants.OAuthProvider` 中显式登记 `carrier` 常量，并重构业务引用对齐 | **✅ 已解决** |
| **28** | `VaultLifecycleManager` 与 `PluginMarketService` 中存在重复物理数据库切换与重复 HTTP 响应状态码校验代码块，违反 DRY 原则 | **Medium** | 代码坏味道与重复率 | 提取 `performVaultDatabaseSwitch` 与 `validateHTTPResponse` 统一函数，消除重复实现 | **✅ 已解决** |
| **29** | `MarkdownEditorView` 工具栏粗体与斜体按钮插入单边未闭合 Markdown 语法标记（`**` 和 `*`），破坏文档语法树结构 | **Medium** | UI/交互层逻辑缺陷 | 重构为插入成对闭合语法标记（粗体插入 `****`，斜体插入 `**`，双链插入 `[[]]`） | **✅ 已解决** |
| **30** | `AppBackupService.createBackup` 自动备份节流判定中未防御系统时钟微小回退（如 NTP 同步/时区调整），导致产生负数时间间隔而触发频繁多余磁盘写入 | **Medium** | 存储防御性与资源开销 | 增加时钟回退防御校验（`elapsed >= 0 && elapsed < Self.backupInterval`），消除无效 I/O | **✅ 已解决** |
| **31** | `QuizView` 题目选项索引访问与 `optionLabel` 负数偏移未做防御，AI 返回异常数据或越界索引时直接触发 Fatal Error 崩溃 | **High** | 稳定性与防御性编程 | 增加 `options.indices.contains(correctIdx)` 与 `max(0, ...)` 范围保护，消除越界隐患 | **✅ 已解决** |
| **32** | `SettingsStore` 中 iCloud 冲突策略存在硬编码 `"merge"` 字符串坏味道，未遵循去魔鬼化原则 | **Low** | 代码风格与常量归位 | 抽取并统一使用强类型常量 `AppConstants.Storage.ConflictResolution.merge` | **✅ 已解决** |
| **33** | `AppleAuthStrategy` 与 `GitHubAuthStrategy` 重复实现 9 行相同的 UIWindow 锚点获取逻辑，违反 DRY 原则 | **Medium** | 代码重复率与架构设计 | 抽取跨平台统一助手 `PlatformPresentationAnchor.keyWindow`，消除重复实现 | **✅ 已解决** |
| **34** | `DeveloperSettingsView` 压力测试 Stepper 步长与边界范围直接内联硬编码数字（`100...10000`, `100`），违反去魔鬼化原则 | **Low** | 代码风格与常量归位 | 抽取并登记 `FeatureConstants.StressTest` 强类型常量集（`minTargetCount`, `maxTargetCount`, `step`） | **✅ 已解决** |
| **35** | `ServerConfigView` 用户添加新服务器或编辑现有配置后，`onSave` 闭包仅修改内存视图数组而遗漏 `saveServers()` 调用，导致新增/编辑配置无法持久化落盘并静默丢失 | **High** | 数据丢失与生命周期一致性 | 在 `onSave` 闭包内补充 `saveServers()` 显式落盘保存，确保配置完整持久化 | **✅ 已解决** |
| **36** | `GraphComponents` 中图谱节点动态尺寸计算直接内联魔鬼数字（`32`, `18`, `30`, `20`），违反去魔鬼化原则 | **Low** | 代码风格与常量归位 | 抽取并登记 `GraphViewConstants` 强类型尺寸常量集（`selectedNodeSize`, `minNodeSize`, `maxNodeSize`, `baseNodeSize`） | **✅ 已解决** |
| **37** | `SynthesisView` 重命名文档弹窗中未防御纯空白字符串输入，缺少 `trimmingCharacters` 拦截，允许将知识合成文档重命名为空白名称 | **Low** | 业务边界校验与防御性 | 在重命名确认动作中增加 `guard !trimmed.isEmpty` 拦截与前后空白去除，防止非法名称持久化 | **✅ 已解决** |
| **38** | `UserProfileMenu` 在 Mac Catalyst 悬浮菜单窗口管理器中硬编码动画时长（`0.2`）与窗口变化轮询间隔（`0.25`），违反去魔鬼化原则 | **Low** | 代码风格与常量归位 | 抽取并登记 `CatalystFloatingConstants` 强类型时间常量（`animationDuration`, `framePollingInterval`） | **✅ 已解决** |
| **39** | `FrontmatterParser.split(content:)` 对首行与闭合行执行过度 `.trimmingCharacters(...)`，导致缩进空格开头的普通段落/水平分割线（如 `"  ---\n正文"`）被误识别为合法的 Frontmatter 头并错误截断正文 | **Medium** | 核心解析器缺陷 | 严格对齐标准 YAML Frontmatter 规范：首行与闭合行必须顶格匹配 `---` / `---json`，禁止识别包含前置缩进空格的非标准行 | **✅ 已解决** |
| **40** | `PluginRuntime.suspendPlugin` 在看门狗熔断封禁恶意/超时插件时，仅清理了命令、设置页和自定义视图，遗漏清理已挂起插件在 `registry.eventListeners` 中的监听器，导致已被封禁的插件仍可在事件总线被触发并执行 JS 回调 | **High** | 架构与安全设计缺陷 | 在 `suspendPlugin` 中显式清理 `registry.eventListeners.removeAll(where: { $0.pluginID == id })`，彻底阻断幽灵回调与并发死锁 | **✅ 已解决** |
| **41** | `setupFullMockEnvironment` 在注册核心领域服务时，对 `AuthService`、`VaultService`、`ChatService` 仅注册了抽象协议，遗漏了具体类型的双注册（`container.register(service, for: AuthService.self)`），导致通过具体类型解析的单测触发 `ServiceContainer.resolve` 致命断言崩溃 (SIGTRAP) | **High** | 架构与依赖注入缺陷 | 在 `TestMocks.swift` 补充具体类型注册，严格遵循 DIP 双注册规范 | **✅ 已解决** |
| **42** | 部分单元测试在 `tearDown` 中显式调用 `DatabaseManager.shared.reset()` 与 `ServiceContainer.shared.reset()`，导致测试进程内后续用例持有的数据库句柄与 DI 链条被意外擦除破坏，引发跨测试级联崩溃 | **High** | 状态机与生命周期 | 全量清理单测中不当的全局单例 reset 调用，遵循 `setupFullMockEnvironment` 幂等状态覆盖机制 | **✅ 已解决** |

---

## 📈 台账指标统计

- **收录问题总数**：**42 项**
- **问题分类分布**：
  - 功能缺陷与核心算法/解析器：9 项 (21.4%)
  - 状态机并发与数据生命周期：10 项 (23.8%)
  - 架构设计与安全/环境依赖：9 项 (21.4%)
  - UI/交互与防御性缺陷：4 项 (9.5%)
  - 代码坏味道与去魔鬼化/DRY 治理：10 项 (23.8%)
- **修复闭环率**：**100.0% (42/42 已修复并测试验证通过)**
