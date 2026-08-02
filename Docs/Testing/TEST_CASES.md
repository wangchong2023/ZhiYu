# 智宇 (KM) 详细测试用例库

本文档列出了系统的关键测试用例，涵盖单元测试 (Unit) 和集成测试 (Integration)，用于保证系统的核心功能稳定性。

---

## 0. SPM 本地 Package 单元测试矩阵 (Package Test Matrix)

| 包/模块 (SPM Package) | 测试套件 (Test Suite) | 测试场景 | 命令行执行命令 | 优先级 |
| :--- | :--- | :--- | :--- | :--- |
| **UFPCore** | `UFPCoreTests` | `ServiceContainer` 并发线程安全、未注册断言与 `Logger` 格式 | `swift test --package-path Packages/UFPCore` | P0 |
| **UFPStorage** | `UFPStorageTests` | `SQLiteStore` GRDB 封装逻辑与 `StorageConstants` 完整性 | `swift test --package-path Packages/UFPStorage` | P0 |
| **UFPDesignSystem** | `UFPDesignSystemTests` | `Spacing` Token 矩阵与 `Bundle.module` 资源包装载 | `swift test --package-path Packages/UFPDesignSystem` | P1 |
| **ZhiYuDomain** | `ZhiYuDomainTests` | `PromptConstants` 限额约束与 `MemoryEngineProtocol` 契约存根 | `swift test --package-path Packages/ZhiYuDomain` | P0 |
| **ZhiYuAICore** | `ZhiYuAICoreTests` | XML 沙箱转义、越狱拦截、`ContextReranker` 降噪重排与热切换 | `swift test --package-path Packages/ZhiYuAICore` | P0 |
| **ZhiYuFeatures** | `ZhiYuFeaturesTests` | AI / Knowledge / Insight 垂直业务模块入口与状态装载 | `swift test --package-path Packages/ZhiYuFeatures` | P1 |

---

## 1. 核心存储与检索 (AppStore & Logic)

| 用例 ID | 模块 | 测试场景 | 预期结果 | 优先级 |
| :--- | :--- | :--- | :--- | :--- |
| TC-STR-01 | AppStore | 页面创建与持久化 | 创建页面后，重启 App 或清空内存，页面数据应能从 SQLite 正确恢复。 | P0 |
| TC-STR-02 | AppStore | 数据完整性校验 | 修改数据库文件（模拟篡改），App 启动时应识别并提示错误。 | P1 |
| TC-SRC-01 | Search | 短词硬匹配 (如 "3D") | 搜索 4 字符以下短词时，标题包含该词的页面应排在最前，过滤无关语义结果。 | P0 |
| TC-SRC-02 | Search | 语义混合搜索 | 输入复杂句子，语义相似度 > 0.88 的相关页面应正确召回。 | P1 |

---

## 2. AI 助手与处理流 (AI & Ingest)

| 用例 ID | 模块 | 测试场景 | 预期结果 | 优先级 |
| :--- | :--- | :--- | :--- | :--- |
| TC-AI-01 | LLMService | 语义摘要生成 | 提供 500 字以上文本，AI 应在 10s 内返回结构化的 Markdown 摘要。 | P0 |
| TC-AI-02 | LLMService | 发送风险与并发 | 高频点击多个 AI 功能，系统应能正确排队或取消旧任务，不崩溃且 UI 不卡顿。 | P0 |
| TC-SYN-01 | Synthesis | JSON 语法缺失自愈解码 | LLM 返回缺失尾部括号或包含多余逗号的 JSON 时，`JSONRepairProcessor` 应能 100% 自动修正并生成可交互试题。 | P0 |
| TC-SYN-02 | Synthesis | `[[页面标题]]` 防转义与双向跳转 | 合成文本中的双括号不被转义为 `\[\[`，且点击 `[[页面标题]]` 能够正确触发 `Router` 导航跳转。 | P0 |
| TC-SYN-03 | Synthesis | Prompt 调控指令多语言净化 | 包含 `【篇幅要求】` 等调控参数输入时，输出的标题与正文中严禁泄露调试前缀字串。 | P0 |
| TC-ING-01 | IngestSvc | 网页抓取与 Markdown | 输入标准 URL，系统应能提取正文并转换为干净的 Markdown 格式。 | P1 |
| TC-ING-02 | IngestSvc | 多格式兼容性 | 导入包含代码块和表格的文档，渲染器应能保持结构完整。 | P1 |
| TC-ING-03 | IngestSvc | 级联式多源抓取及付费墙绕过 | 抓取具备防爬限制或付费墙的科学与新闻网页，自动通过 6 级回退策略抓取到干净正文，耗时 < 5.0s。 | P1 |

---

## 3. 导航与交互 (UI & UX)

| 用例 ID | 模块 | 测试场景 | 预期结果 | 优先级 |
| :--- | :--- | :--- | :--- | :--- |
| TC-NAV-01 | Navigation | [[WikiLink]] 跳转 | 在正文点击维基链接，应准确跳转到对应详情页并进入导航栈。 | P0 |
| TC-NAV-02 | Navigation | 深度链接捕获 | 通过 `wikilink://` 协议打开 App，应自动跳转至指定页面。 | P1 |
| TC-UI-01 | Dashboard | 每日闪念更新 | 知识库内容更新后，点击刷新，Daily Recap 应基于最新内容重新生成。 | P2 |
| TC-DEE-06 | Navigation | 外置 CLI 触发与 Intent 调度 | 外部 AI 代理通过 Shortcuts/App Intent 发送写入指令时，系统能自动限流（10Hz 阈值内），并静默在后台完成向量化及数据持久化，保持主应用正常响应。 | P1 |

---

## 4. 安全与同步 (Security & Sync)

| 用例 ID | 模块 | 测试场景 | 预期结果 | 优先级 |
| :--- | :--- | :--- | :--- | :--- |
| TC-SEC-01 | Privacy | 生物识别解锁 | 开启隐私模式，进入受保护页面必须通过 FaceID/TouchID 或密码。 | P0 |
| TC-SEC-02 | Crypto | 敏感数据加密 | 存储在磁盘上的”私密”页面内容不应以明文形式出现在 SQLite 文件中。 | P1 |

---

## 5. 3D 图谱引擎 (Graph Engine)

| 用例 ID | 模块 | 测试场景 | 预期结果 | 优先级 |
| :--- | :--- | :--- | :--- | :--- |
| TC-GRF-01 | GraphLayout | 力导向布局计算 | 输入 100+ 节点与边，布局应在 200ms 内收敛，节点不重叠。 | P0 |
| TC-GRF-02 | GraphView | 2D/3D 模式切换 | 切换模式时无崩溃，视图平滑过渡，节点数据保持。 | P0 |
| TC-GRF-03 | GraphCanvas | 缩放与拖拽 | 双指缩放范围 0.5x-4.0x，拖拽不超出边界，手势流畅。 | P1 |
| TC-GRF-04 | GraphClustering | 语义聚类 | 相关页面自动聚合为簇，簇标签准确反映主题。 | P1 |
| TC-GRF-05 | GraphNode | 节点选中与高亮 | 点击节点后显示详情卡片，入/出边高亮，再次点击取消选中。 | P1 |
| TC-GRF-06 | GraphLayout | 孤立节点检测 | 无连接节点的页面应在图谱中显示为孤立点并被洞察系统识别。 | P2 |

---

## 6. 插件沙箱 (Plugin Sandbox)

| 用例 ID | 模块 | 测试场景 | 预期结果 | 优先级 |
| :--- | :--- | :--- | :--- | :--- |
| TC-PLG-01 | PluginRegistry | 插件加载与卸载 | `onLoad` 和 `onUnload` 生命周期完整执行，资源正确释放。 | P0 |
| TC-PLG-02 | Interception | preProcess 拦截 | 插件修改内容后，入库数据为处理后版本，原始内容不被覆盖。 | P0 |
| TC-PLG-03 | Sandbox | 插件崩溃隔离 | 单个插件 `preProcess` 抛出异常时，主程序不崩溃，插件被自动熔断。 | P0 |
| TC-PLG-04 | Permissions | 权限白名单 | 插件尝试执行未声明权限的操作时被拦截，记录操作日志。 | P1 |
| TC-PLG-05 | Interception | postProcess 渲染 | 插件在渲染前修改内容后，UI 显示处理后的 Markdown。 | P1 |
| TC-PLG-06 | Market | 插件安装与更新 | 从市场安装插件后自动激活，版本更新后 `onLoad` 重新触发。 | P2 |

---

## 7. 安全金库 (Security Vault)

| 用例 ID | 模块 | 测试场景 | 预期结果 | 优先级 |
| :--- | :--- | :--- | :--- | :--- |
| TC-VLT-01 | VaultService | 金库锁定/解锁 | 锁定后 SQLite 连接关闭，内存缓存清空；FaceID 解锁后恢复访问。 | P0 |
| TC-VLT-02 | Privacy | #private 内容模糊 | 隐私模式下标记 `#private` 的页面在列表中显示高斯模糊，不显示摘要。 | P0 |
| TC-VLT-03 | VaultService | 后台自动锁定 | App 切换至后台后，金库在设定时间内自动锁定。 | P1 |
| TC-VLT-04 | SecurityMgr | 文件完整性校验 | 外部篡改数据库文件后，HMAC-SHA256 校验失败并提示用户。 | P1 |
| TC-VLT-05 | Audit | 敏感操作审计 | 删除金库、修改安全设置等操作被完整记录，日志不可被插件篡改。 | P2 |
| TC-VLT-06 | SecurityMgr | 物理多Vault并发热切换 | 验证在多线程高并发读写WAL事务以及桌面小组件/后台同步竞争下，金库物理热插拔切换不会发生死锁与读写冲突。 | P1 |

---

## 8. macOS Catalyst 专项测试用例

| 用例 ID | 模块 | 测试场景 | 预期结果 | 优先级 |
| :--- | :--- | :--- | :--- | :--- |
| TC-MAC-01 | MenuBar | 顶栏菜单交互 | 验证在 macOS Catalyst 下顶栏“文件”、“编辑”、“AI 实验室”等系统原生菜单存在且可被键盘快捷键呼出。 | P1 |
| TC-MAC-02 | Keyboard | 全局快捷键响应 | 验证使用 `Cmd + N` 快速新建卡片，`Cmd + F` 触发全局混合检索，功能完全对齐。 | P1 |

---

## 9. watchOS 平台专项测试用例

| 用例 ID | 模块 | 测试场景 | 预期结果 | 优先级 |
| :--- | :--- | :--- | :--- | :--- |
| TC-WAT-01 | Recorder | watchOS 语音笔记录入 | 验证手表端离线录制音频后，系统能生成本地缓存，并在 WCSession 重新连线时自动离线传输。 | P1 |
| TC-WAT-02 | Sync | 笔记卡片微缩缓存同步 | 验证手表端离线阅读列表从 iPhone 缓存拉取，支持 50+ 最热卡片热离线极速阅读。 | P1 |
| TC-WAT-03 | Capability | watchOS 能力降级校验 | 验证运行时模型编译、安全存储、生物识别鉴权等 Stub 返回符合预期的降级安全值或抛出指定异常。 | P1 |

---

## 10. TC → XCTest 映射表

| 文档用例 ID | XCTest 类 | XCTest 方法 |
| :--- | :--- | :--- |
| TC-STR-01 | `AppStoreTests` (Tests/Shared) | `testAddPage` |
| TC-STR-02 | `DatabaseIntegrityTests` (Tests/Unit/Storage) | `testDatabaseIntegrityCheckOnCorruptedFile` |
| TC-SRC-01 | `SearchPerformanceTests` | `testFTSSearchShortWordPriority` |
| TC-SRC-02 | `SearchPerformanceTests` | `testHybridSearchRecallRate` |
| TC-AI-01 | `LLMServiceTests` | `testSemanticSummaryGeneration` |
| TC-AI-02 | `LLMServiceTests` | `testHighConcurrencyQueueStability` |
| TC-ING-01 | `IngestQueueTests` | `testWebIngestAndMarkdownParsing` |
| TC-ING-02 | `IngestQueueTests` | `testMultiFormatIngestCompatibility` |
| TC-NAV-01 | `ZhiYuUITests` (Tests/UI) | `testWikiLinkNavigationStack` |
| TC-NAV-02 | `KnowledgeBaseUITests` (Tests/UI) | `testDeepLinkRoutingAction` |
| TC-UI-01 | `RecapTests` (Tests/Unit) | `testDailyRecapRefreshRecalculation` |
| TC-SEC-01 | `ZhiYuUITests` (Tests/UI) | `testBiometricUnlockAuthSimulation` |
| TC-SEC-02 | `KnowledgeRepositoryTests` (Tests/Unit/Storage) | `testPrivatePageContentIsEncryptedInDB` |
| TC-GRF-01 | `GraphLayoutEngineTests` (Tests/Unit/Graph) | `testLayoutMultiplePagesCreatesNodesForAll`, `testLayoutNodePositionsAreDistinct` |
| TC-GRF-02 | `KnowledgeBaseUITests` | `testNavigateTo3DGraph` |
| TC-GRF-03 | `GraphCanvasUITests` | `testGraphCanvasZoomAndPan` |
| TC-GRF-04 | `GraphClusteringServiceTests` | `testGraphClusteringStability` |
| TC-GRF-05 | `GraphNodeUITests` | `testGraphNodeSelectionAndHighlight` |
| TC-GRF-06 | `GraphLayoutEngineTests` (Tests/Unit/Graph) | `testLayoutIsolatedNodeHasNoEdges` |
| TC-PLG-01 | `PluginSandboxTests` (Tests/Unit/Plugins) | `testLoadPluginRegistersAndCallsOnLoad`, `testUnloadPluginRemovesAndCallsOnUnload` |
| TC-PLG-02 | `PluginSandboxTests` (Tests/Unit/Plugins) | `testInterceptionPluginIsRegisteredAsInterceptor` |
| TC-PLG-03 | `PluginSandboxTests` (Tests/Unit/Plugins) | `testPluginExceptionDoesNotCrashRegistry` |
| TC-PLG-04 | `PluginSandboxTests` (Tests/Unit/Plugins) | `testPluginUnauthorizedAccessIntercepted` |
| TC-PLG-05 | `PluginSandboxTests` (Tests/Unit/Plugins) | `testPostProcessRenderModifiedMarkdown` |
| TC-PLG-06 | `PluginSandboxTests` (Tests/Unit/Plugins) | `testPluginMarketInstallationAndUpgrade` |
| TC-VLT-01 | `VaultSecurityTests` (Tests/Unit/Security) | `testLockSetsIsLockedToTrue`, `testLockUnlockCycle` |
| TC-VLT-02 | `VaultSecurityTests` (Tests/Unit/Security) | `testPrivateContentBlurFilter` |
| TC-VLT-03 | `VaultSecurityTests` (Tests/Unit/Security) | `testMultipleLockCallsStayLocked` |
| TC-VLT-04 | `SecurityIntegrityTests` (Tests/Unit/Security) | `testHMACCalculationAndVerification`, `testHMACIntegrityCheck` |
| TC-VLT-05 | `AuditLoggerTests` | `testAuditLogsForSensitiveOperations` |
| TC-MAC-01 | `MacCatalystTests` | `testMacMenuBarExists` |
| TC-MAC-02 | `MacCatalystTests` | `testMacKeyboardShortcuts` |
| TC-WAT-01 | `WatchSyncTests` (Tests/Platforms) | `testWatchVoiceRecorderSync` |
| TC-WAT-02 | `WatchSyncTests` (Tests/Platforms) | `testWatchMicroRecapCacheSync` |
| TC-WAT-03 | `WatchPlatformTests` (Tests/Platforms) | `testWatchModelCompilerThrows`, `testWatchSecurityScopedStorageStub`, `testWatchBiometricAuthProviderInterface` |
| TC-WID-01 | `KnowledgeStatsWidgetTests` (Tests/Unit/System) | `testWidgetSnapshotEntryCalculation` |
| TC-WID-02 | `KnowledgeStatsWidgetTests` (Tests/Unit/System) | `testWidgetTimelinePolicyCalculation` |
| TC-DEE-05 | `DeepLinkTests` (Tests/Unit/Services) | `testWidgetCreateActionDeepLinkResolution`, `testWidgetEmptySearchDeepLinkSafetyGrace` |
| TC-VLT-06 | `MultiVaultSwitchTests` (Tests/Integration) | `testConcurrentVaultSwitchAndDeadlockAvoidance`, `testVaultSwitchNotificationBroadcast` |
| TC-ING-03 | `IngestQueueTests` (Tests/Unit/RAG) | `testCascadeGrabAndPaywallBypass` (Pending) |
| TC-DEE-06 | `DeepLinkTests` (Tests/Unit/Services) | `testAgentIntentsIntegrationAndRateLimit` (Pending) |

---

## 9.5 iOS 静态小组件与 Deep Link 专项测试用例

| 用例 ID | 模块 | 测试场景 | 预期结果 | 优先级 |
| :--- | :--- | :--- | :--- | :--- |
| TC-WID-01 | Widget | 桌面小组件卡片刷新 | 验证 `KnowledgeStatsWidget` 的 Small, Medium, Large 卡片计算策略生成正常，对未来指定刷新节点精确断言。 | P0 |
| TC-WID-02 | Widget | 小组件 Timeline 数据源检索 | 验证 Widget 刷新时能够正常拉起数据并生成 `WidgetEntry`，且时间轴策略返回 `.atEnd`。 | P0 |
| TC-DEE-05 | Navigation | 小组件 Deep Link 容灾解析 | 验证主应用对于 `zhiyu://create` 快捷创建 and `zhiyu://search` 空白搜索参数的 Deep Link 具备高宽限安全解析与 Tab 降级。 | P0 |

> 提示：本映射表覆盖的所有测试用例已全部和系统的 XCTest 自动化测试防线（Tests/）进行完美对齐。
