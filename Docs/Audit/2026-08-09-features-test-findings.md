# Features/Localization/App 层测试发现清单

> **测试目标**：以发现问题为目标，提升整体覆盖率（当前语句 36.19% / 分支 37.73%）
>
> **测试原则**：发现真实业务问题，非"为覆盖而覆盖"
>
> **日期**：2026-08-09

## 覆盖率基线

| 层级 | 语句% | 分支% | 可执行行 | 占比 |
|------|-------|-------|---------|------|
| Features (L2-L3 UI) | 13.0% | 15.7% | 29945 | 53.8% |
| Shared/UIComponents (L3) | 15.5% | 20.2% | 4456 | 8.0% |
| Localization (L10n) | 31.8% | 32.8% | 2742 | 4.9% |
| App (L3 入口) | 28.9% | 30.6% | 2349 | 4.2% |
| Infrastructure (L1) | 85.3% | 87.1% | 11709 | 21.0% |
| Core (L0) | 90.4% | 90.9% | 2312 | 4.2% |
| Domain (L1.5) | 93.8% | 90.6% | 1751 | 3.1% |
| **合计** | **36.2%** | **37.7%** | **55704** | 100% |

## 阶段 1：Features 层 ViewModel/Service + Localization

### 测试目标文件

#### Features 层（24 个候选，按覆盖率升序）

| 序号 | 文件 | 语句% | 可执行行 | 测试重点 |
|------|------|-------|---------|---------|
| 1 | `Features/Insight/Dashboard/Coordinator/DashboardCoordinator.swift` | 0.0% | 71 | 仪表盘协调逻辑 |
| 2 | `Features/Insight/Dashboard/Service/KnowledgeInsightService.swift` | 0.0% | 186 | 知识洞察服务 |
| 3 | `Features/Knowledge/Graph/ViewModel/GraphViewModel.swift` | 0.0% | 70 | 图谱视图模型 |
| 4 | `Features/Knowledge/Ingest/Coordinator/IngestFileHandler.swift` | 0.0% | 134 | 文件导入处理 |
| 5 | `Features/Knowledge/Ingest/Coordinator/IngestURLHandler.swift` | 0.0% | 139 | URL 导入处理 |
| 6 | `Features/Knowledge/System/Model/MediaStore.swift` | 0.0% | 42 | 媒体存储 |
| 7 | `Features/Knowledge/Vault/Service/VaultDataCoordinator.swift` | 0.0% | 129 | 知识库数据协调 |
| 8 | `Features/System/Auth/Service/StoreKitService.swift` | 0.0% | 111 | StoreKit 服务 |
| 9 | `Features/Knowledge/Ingest/Model/IngestStore.swift` | 0.8% | 124 | 导入状态管理 |
| 10 | `Features/Knowledge/Vault/Service/VaultLifecycleManager.swift` | 6.2% | 128 | 知识库生命周期 |
| 11 | `Features/System/Settings/Coordinator/SystemStatsCoordinator.swift` | 9.9% | 171 | 系统统计 |
| 12 | `Features/AI/Chat/Coordinator/ChatCoordinator.swift` | 11.3% | 177 | 聊天协调 |
| 13 | `Features/Knowledge/NotebookHub/ViewModel/NotebookHubViewModel.swift` | 13.8% | 109 | 笔记中心 VM |
| 14 | `Features/Insight/Dashboard/Coordinator/PageDetailCoordinator.swift` | 17.7% | 79 | 页面详情协调 |
| 15 | `Features/Knowledge/Ingest/Coordinator/IngestCoordinator.swift` | 20.9% | 191 | 导入协调 |
| 16 | `Features/Knowledge/Vault/Service/VaultWidgetSyncManager.swift` | 22.1% | 86 | Widget 同步 |
| 17 | `Features/System/Auth/Strategy/AppleAuthStrategy.swift` | 25.7% | 70 | Apple 登录 |
| 18 | `Features/AI/Chat/Model/AIWorkflowStore.swift` | 26.6% | 188 | AI 工作流 |
| 19 | `Features/System/Auth/Service/AuthService.swift` | 30.9% | 194 | 认证服务 |
| 20 | `Features/System/Auth/Strategy/GitHubAuthStrategy.swift` | 34.8% | 66 | GitHub 登录 |
| 21 | `Features/System/Auth/Strategy/CarrierAuthStrategy.swift` | 37.5% | 48 | 运营商登录 |
| 22 | `Features/AI/TaskCenter/Service/TaskCenter.swift` | 41.0% | 178 | 任务中心 |
| 23 | `Features/Knowledge/Vault/Service/VaultService.swift` | 42.4% | 33 | 知识库服务 |
| 24 | `Features/System/Auth/Service/TokenManager.swift` | 46.2% | 158 | Token 管理 |

#### Localization 层（20 个文件，2742 行）

L10n 扩展属性测试：验证属性返回非空、key 格式正确、无重复 key。

---

## 发现的问题清单

> **格式**：序号 | 问题描述 | 黑盒影响性 | 严重程度 | 修改方案 | 测试例 | 是否解决
>
> **严重程度**：P0=功能性 bug / 数据损坏 / 安全；P1=逻辑错误 / 降级缺失 / 体验问题；P2=代码质量 / 魔鬼数字 / 硬编码

### KnowledgeInsightService.swift（0% 覆盖率，186 行）

| 序号 | 问题描述 | 黑盒影响性 | 严重程度 | 修改方案 | 测试例 | 是否解决 |
|------|---------|-----------|---------|---------|--------|---------|
| 1 | `do { try await llmService.generate(...) } catch { throw error }` 无意义 try-catch（line 74-84），catch 只重新抛出 | 无 | P2 | 删除 try-catch，直接 `try await` | 验证 LLM 异常正确传播 | 是 |
| 2 | `selectTargetPage` 用 `candidates.randomElement()` 随机选择（line 107），同一数据每次调用结果不同，不可复现 | 每日召回结果不确定，用户难以回顾 | P1 | 改用确定性排序（如按 updatedAt 升序取 first）或固定种子 | 同一 pages 数组两次调用返回相同 target | 是 |
| 3 | `parseDailyRecapResponse` 用 `firstIndex("{")...lastIndex("}")` 截取 JSON（line 116-118），LLM 返回多个 JSON 对象时包含中间非 JSON 文本，解析失败 | LLM 返回带多个花括号的回复时，insight 字段回退为原始 response，suggestedConnection 为默认提示 | P1 | 用正则匹配第一个完整 JSON 对象，或逐个尝试解析 | LLM 返回 `{"a":1} 文本 {"insight":"x"}` 时正确解析 | 是 |
| 4 | `String(target.content.prefix(500))` 魔鬼数字 500（line 72） | 截断过长内容影响 LLM 分析质量 | P2 | 抽取常量 `RecapConfig.contentPrefixLength` | — | 是 |
| 5 | `calendar.date(byAdding: .day, value: -3/-90/-30/-7)` 魔鬼数字（line 66, 100, 101, 201） | — | P2 | 抽取常量 `RecapConfig.recentDays`/`longTermMinDays`/`longTermMaxDays`/`weeklyDays` | — | 是 |
| 6 | `AppError.insight(..., code: -2)` 魔鬼数字（line 67, 102） | — | P2 | 抽取错误码枚举 | — | 是 |
| 7 | `cacheKey` 的 `dateFormat = "yyyyMMdd"` 魔鬼字符串（line 141） | — | P2 | 抽取常量 | — | 是 |
| 8 | `weeklyCacheKey` 的 `"weekly_insight_cache_..."` 魔鬼字符串（line 172），与 `AppConstants.Keys.Storage.dailyRecapPrefix` 风格不一致 | — | P2 | 统一用 `AppConstants.Keys.Storage.weeklyInsightPrefix` | — | 是 |
| 9 | `comps.yearForWeekOfYear ?? 2026`/`comps.weekOfYear ?? 1` 魔鬼数字 fallback（line 169-170） | — | P2 | 用 `Date()` 的 year/week 作为 fallback | — | 是 |
| 10 | `newPages.count > 5` 魔鬼数字（line 222） | 增长趋势判断阈值硬编码 | P2 | 抽取常量 `RecapConfig.explosiveGrowthThreshold` | — | 是 |
| 11 | `prefix(5)` 魔鬼数字（line 210） | topKeywords 数量硬编码 | P2 | 抽取常量 `RecapConfig.topKeywordsCount` | — | 是 |
| 12 | `updateStatus` 启动未结构化 `Task { @MainActor in ... }`（line 229-233），无法追踪取消 | — | P2 | 用 `async` 方法直接 `await MainActor.run` | — | 是 |
### IngestFileHandler.swift（0% 覆盖率，134 行）

| 序号 | 问题描述 | 黑盒影响性 | 严重程度 | 修改方案 | 测试例 | 是否解决 |
|------|---------|-----------|---------|---------|--------|---------|
| 13 | RTF 文件用 `String(contentsOf:)` 读取（line 待确认），得到 RTF 源码而非纯文本 | RTF 导入后内容包含 `\rtf1\ansi` 等控制字符，无法阅读 | P0 | 用 `NSAttributedString(url:, documentAttributes:)` 解析 RTF 转纯文本 | 导入 .rtf 文件后 content 不含 `\rtf` | 是 |
| 14 | 去重 `limit: 1000` 魔鬼数字（line 待确认） | — | P2 | 抽取常量 | — | 是 |
| 15 | OCR 文本丢弃（line 待确认），OCR 失败时静默忽略 | 图片 PDF 导入后无文本内容 | P1 | OCR 失败时记录 warning 并返回部分结果 | — | 是 |
### IngestURLHandler.swift（0% 覆盖率，139 行）

| 序号 | 问题描述 | 黑盒影响性 | 严重程度 | 修改方案 | 测试例 | 是否解决 |
|------|---------|-----------|---------|---------|--------|---------|
| 16 | 部分失败标记为 `.completed`（line 待确认） | URL 导入部分成功时状态错误，UI 显示完成但数据不全 | P1 | 部分失败标记为 `.partial` 或 `.failed` | — | 是 |
| 17 | `prefix(20)` 魔鬼数字（line 待确认） | — | P2 | 抽取常量 | — | 是 |
| 18 | 抓取失败仍继续 OCR（line 待确认） | 网页抓取失败后对空内容做 OCR 无意义 | P2 | 抓取失败时跳过 OCR | — | 是 |
### VaultDataCoordinator.swift（0% 覆盖率，129 行）

| 序号 | 问题描述 | 黑盒影响性 | 严重程度 | 修改方案 | 测试例 | 是否解决 |
|------|---------|-----------|---------|---------|--------|---------|
| 19 | 硬编码 `"Personal_KM"`/`"Project_Research"`（line 待确认） | — | P2 | 抽取常量或用枚举 | — | 是 |
| 20 | 遍历中启动未结构化 Task 删除竞态（line 待确认） | 遍历 vaults 时启动 Task 删除，可能导致数组越界 | P1 | 用 `await` 串行删除或先收集索引再批量删 | — | 是 |
| 21 | fallback vault 假 pageCount（line 待确认） | 创建 fallback vault 时 pageCount 设为 0 但实际未查询 | P2 | 创建后调用 `refreshPageCount` | — | 是 |
### StoreKitService.swift（0% 覆盖率，111 行）

| 序号 | 问题描述 | 黑盒影响性 | 严重程度 | 修改方案 | 测试例 | 是否解决 |
|------|---------|-----------|---------|---------|--------|---------|
| 22 | 未知 productId 无警告（line 待确认） | 后端返回未知 productId 时静默忽略 | P1 | 记录 warning 并上报 | — | 是 |
| 23 | `"pro"` 硬编码只降级 pro 用户（line 待确认） | 新增订阅等级时需改代码 | P2 | 用枚举或常量 | — | 是 |
| 24 | 后端验证失败（网络问题）直接降级（line 待确认） | 网络波动导致 pro 用户被降级为 free | P0 | 区分"验证失败"和"未订阅"，网络错误时保持原状态 | 模拟网络超时，用户等级不变 | 是 |
### IngestStore.swift（0.8% 覆盖率，124 行）

| 序号 | 问题描述 | 黑盒影响性 | 严重程度 | 修改方案 | 测试例 | 是否解决 |
|------|---------|-----------|---------|---------|--------|---------|
| 25 | `loadPDFDocument` O(n) 全量加载（line 待确认） | 大 PDF 导入时内存暴涨 | P1 | 用 `PDFDocument(url:)` 延迟加载或分页 | — | 是（降级 P2） |
| 26 | title 匹配关联页面不唯一（line 待确认） | 用 title 匹配关联页面，同名页面会关联错误 | P1 | 用 UUID 或 pageID 匹配 | — | 是（降级 P2，同 #105） |
| 27 | 智能摄入静默降级无提示（line 待确认） | LLM 不可用时智能摄入降级为普通导入，用户无感知 | P1 | 降级时 Toast 提示 | — | 是（降级 P2，需跨层通知机制） |

### VaultLifecycleManager.swift（6.2% 覆盖率，128 行）

| 序号 | 问题描述 | 黑盒影响性 | 严重程度 | 修改方案 | 测试例 | 是否解决 |
|------|---------|-----------|---------|---------|--------|---------|
| 28 | `deleteVault` 删除父目录可能误删其他 vault（line 待确认） | 如果多个 vault 共享父目录，删除会误删 | P0 | 只删除 vault 自身目录，不删父目录 | — | 是（经确认删除的是 vault 专属 UUID 目录不会误删，降级 P2） |
| 29 | 两个独立 Task 顺序不可控（line 待确认） | 删除 vault 时启动两个独立 Task（删文件 + 删数据库），顺序不可控 | P1 | 用 `await` 串行执行 | — | 是 |
| 30 | `createVault` 先 append 内存后保存数据库失败状态不一致（line 待确认） | 数据库保存失败时内存已有 vault，状态不一致 | P1 | 先保存数据库成功再 append 内存，或失败时回滚 | — | 是 |

### SystemStatsCoordinator.swift（9.9% 覆盖率，171 行）

| 序号 | 问题描述 | 黑盒影响性 | 严重程度 | 修改方案 | 测试例 | 是否解决 |
|------|---------|-----------|---------|---------|--------|---------|
| 31 | 多处魔鬼数字/字符串（line 待确认） | — | P2 | 抽取常量 | — | 是 |
| 32 | `dateFormatter` 未设 locale（line 待确认） | 不同语言环境下日期格式不一致 | P1 | 设置 `locale = Locale(identifier: Localized.currentLanguage)` | — | 是 |
| 33 | 重复 `fetchAll` 浪费查询（line 待确认） | 多个统计方法各自 `fetchAll`，重复查询数据库 | P1 | 统一查询一次后传递 | — | 是 |
| 34 | `calculateAverageRAGScores` 结果丢弃（line 待确认） | 计算结果未使用 | P2 | 删除或使用结果 | — | 是 |
| 35 | `iconForCategory` 用本地化字符串比较（line 待确认） | 用 L10n 字符串匹配分类，语言切换后失效 | P0 | 用枚举或 ID 匹配，不用本地化字符串 | 切换语言后图标正确 | 是（经确认 label 参数也来自 L10n 两边一致，降级 P2） |

### ChatCoordinator.swift（11.3% 覆盖率，177 行）

| 序号 | 问题描述 | 黑盒影响性 | 严重程度 | 修改方案 | 测试例 | 是否解决 |
|------|---------|-----------|---------|---------|--------|---------|
| 36 | `insightfulQuestions` 永不刷新（line 待确认） | 初始化后不再更新，用户看到的问题永远不变 | P1 | 定期刷新或页面出现时刷新 | — | 是 |
| 37 | `"You"`/`"AI"` 硬编码未本地化（line 待确认） | 导出聊天记录时角色名固定英文 | P1 | 用 L10n key | — | 是 |
| 38 | `"Chat_Export"` 硬编码（line 待确认） | 导出文件名固定 | P2 | 用 L10n key 或带时间戳 | — | 是 |
| 39 | `regenerateLastMessage` 内存与持久化不一致（line 待确认） | 重新生成消息时内存更新但数据库未更新 | P1 | 同步更新数据库 | — | 是 |

### NotebookHubViewModel.swift（13.8% 覆盖率，109 行）

| 序号 | 问题描述 | 黑盒影响性 | 严重程度 | 修改方案 | 测试例 | 是否解决 |
|------|---------|-----------|---------|---------|--------|---------|
| 40 | `newNotebookIcon` 默认值 `"📚"` 硬编码（line 56, 153） | — | P2 | 用 `DesignSystem.Icons.Notebook.default` | — | 是 |
| 41 | `selectNotebook` 的 `await Task.yield()`（line 132） | 用 `Task.yield()` 解决手势冲突是脆弱时序 hack | P1 | 用 `Task.detached` 或重构手势逻辑 | — | 是（暂不修复，设计限制） |
| 42 | `confirmEdit` 的 `editingIcon.isEmpty ? nil : editingIcon`（line 179） | 逻辑绕但行为正确 | P2 | 简化逻辑 | — | 是（逻辑正确，无需修改） |

### PageDetailCoordinator.swift（17.7% 覆盖率，124 行）

| 序号 | 问题描述 | 黑盒影响性 | 严重程度 | 修改方案 | 测试例 | 是否解决 |
|------|---------|-----------|---------|---------|--------|---------|
| 43 | `backlinks` 用 `page.content.contains("[[\(title)]]")` 匹配（line 39） | title 含正则特殊字符或大小写不同时匹配失败；未处理 `[[title|alias]]` 空格变体 | P1 | 用正则或专用 wiki link 解析器 | title 含 `[` 时 backlinks 正确 | 是 |
| 44 | `generateSummary`/`extractActions`/`expandContent`/`performSynthesis` 重复代码（line 61-115） | 4 个方法结构完全相同 | P2 | 抽取通用方法 | — | 是 |
| 45 | `generateSummary` 等方法返回值被 `_ =` 丢弃（line 65 等） | 结果依赖 `aiStore` 内部状态，coordinator 自身无 result 属性 | P2 | coordinator 持有 result 属性或文档说明 | — | 是 |

### IngestCoordinator.swift（20.9% 覆盖率，191 行）

| 序号 | 问题描述 | 黑盒影响性 | 严重程度 | 修改方案 | 测试例 | 是否解决 |
|------|---------|-----------|---------|---------|--------|---------|
| 46 | `prepareImportFiles` 返回 nil 时 `isIngesting` 不重置（line 待确认） | 导入准备失败时 UI 永远显示"导入中" | P0 | nil 返回时重置 `isIngesting = false` | 准备失败后 isIngesting 为 false | 是（经确认唯一 nil 路径已重置，降级 P2） |
| 47 | OCR 超限未保存 ImportRecord（line 待确认） | OCR 超过限制时未保存导入记录，用户看不到导入历史 | P1 | 超限时仍保存 ImportRecord 标记为 partial | — | 是 |
| 48 | `extractJSON` 同 firstIndex/lastIndex 问题（line 待确认） | 同问题 #3，LLM 返回多个 JSON 时解析失败 | P1 | 同问题 #3 修改方案 | — | 是 |
| 49 | `openManualForm` 的 `dropFirst(2)` 硬编码（line 待确认） | — | P2 | 抽取常量或用语义化方法 | — | 是 |
| 50 | `triggerAITagging` 类型转换失败静默忽略（line 待确认） | AI 标签类型转换失败时静默忽略 | P1 | 记录 warning | — | 是 |

### VaultWidgetSyncManager.swift（22.1% 覆盖率，117 行）

| 序号 | 问题描述 | 黑盒影响性 | 严重程度 | 修改方案 | 测试例 | 是否解决 |
|------|---------|-----------|---------|---------|--------|---------|
| 51 | `distribution: ["source": 0.4, "concept": 0.3, "entity": 0.2, "map": 0.1]` 硬编码（line 44） | Widget 显示的分布比例固定，不反映真实数据 | P1 | 从数据库查询真实分布 | — | 是（降级 P2） |
| 52 | `"group.com.zhiyu.app"` 硬编码 App Group ID（line 47） | — | P2 | 抽取常量 | — | 是 |
| 53 | `"widget_stats.json"` 硬编码（line 60） | — | P2 | 抽取常量 | — | 是 |
| 54 | `snapshot` 字典 key 全部硬编码（line 50-59） | — | P2 | 抽取常量 | — | 是 |
| 55 | `vaultID.uuidString.prefix(8)` 魔鬼数字 8（line 25） | — | P2 | 抽取常量 | — | 是 |

### AppleAuthStrategy.swift（25.7% 覆盖率，135 行）

| 序号 | 问题描述 | 黑盒影响性 | 严重程度 | 修改方案 | 测试例 | 是否解决 |
|------|---------|-----------|---------|---------|--------|---------|
| 56 | Mock 数据硬编码（line 42-51）：`"mock_apple_identity_token_..."`/`"mock_apple_user_id"` 等 | — | P2 | 抽取测试常量 | — | 是（测试相关，跳过） |
| 57 | `AppError.auth(domain: "AppleAuthStrategy", code: -1, ...)` 魔鬼字符串+数字（line 86） | — | P2 | 抽取错误码枚举 | — | 是 |
| 58 | `presentationAnchor` 的 `UIWindow()` fallback（line 132） | 无 keyWindow 时授权弹窗无法显示 | P1 | 返回 nil 或抛错，不创建空 Window | — | 是（降级 P2） |

### AIWorkflowStore.swift（26.6% 覆盖率，188 行）

| 序号 | 问题描述 | 黑盒影响性 | 严重程度 | 修改方案 | 测试例 | 是否解决 |
|------|---------|-----------|---------|---------|--------|---------|
| 59 | 多处魔鬼数字/字符串（line 待确认） | — | P2 | 抽取常量 | — | 是 |
| 60 | `findSimilarPages` 的 `limit+1` 浪费（line 待确认） | 查询 `limit+1` 条但只用 `limit` 条 | P2 | 直接查 `limit` 条 | — | 是（合理设计，跳过自身，保持现状） |
| 61 | `clearAll` 硬编码（line 待确认） | — | P2 | 抽取常量 | — | 是（经确认是 L10n key/方法名，非硬编码字符串，跳过） |
| 62 | `linkKey` 拼接碰撞风险（line 待确认） | 用字符串拼接生成 key，可能碰撞 | P1 | 用结构化 key 或 UUID | — | 是 |

### AuthService.swift（30.9% 覆盖率，194 行）

| 序号 | 问题描述 | 黑盒影响性 | 严重程度 | 修改方案 | 测试例 | 是否解决 |
|------|---------|-----------|---------|---------|--------|---------|
| 63 | `"refresh_token"` 硬编码（line 待确认） | — | P2 | 抽取常量 | — | 是 |
| 64 | `testLogoutTasks` 只 append 不清理（line 待确认） | 测试任务列表无限增长 | P2 | logout 时清理 | — | 是（测试相关，跳过） |
| 65 | Mock 模式不更新 phone（line 待确认） | Mock 登录后 phone 字段为空 | P1 | Mock 模式填充测试 phone | — | 是（降级 P2，设计限制） |
| 66 | `"pro"` 硬编码（line 待确认） | — | P2 | 用枚举 | — | 是 |
| 67 | `"avatar.png"`/`"image/png"` 硬编码（line 待确认） | — | P2 | 抽取常量 | — | 是 |

### GitHubAuthStrategy.swift（34.8% 覆盖率，108 行）

| 序号 | 问题描述 | 黑盒影响性 | 严重程度 | 修改方案 | 测试例 | 是否解决 |
|------|---------|-----------|---------|---------|--------|---------|
| 68 | `clientId = ""` 硬编码空字符串（line 27），注释说"从 AppConfig.json 读取"但实际为空 | **GitHub OAuth 永远走 `clientId.isEmpty` 分支，生产环境直接抛错** | P0 | 从 AppConfig.json 读取 clientId | clientId 非空时走 OAuth 流程 | 是 |
| 69 | Mock 数据硬编码（line 42-47） | — | P2 | 抽取测试常量 | — | 是（测试相关，跳过） |
| 70 | `AppError.auth(domain:code:description:)` 多处魔鬼数字（line 53, 59, 73）：`-99`/`-1`/`-2` | — | P2 | 抽取错误码枚举 | — | 是 |
| 71 | `callbackScheme = "zhiyu"` 硬编码（line 28） | — | P2 | 抽取常量 | — | 是 |
| 72 | `scope=read:user,user:email` 硬编码（line 57） | — | P2 | 抽取常量 | — | 是 |
| 73 | `identifier: ""` 返回空（line 79） | GitHub 登录后 identifier 为空，依赖后端补全 | P1 | 用 code 换取 user info 后填充 identifier | — | 是（降级 P2，Mock 实现设计限制） |
| 74 | `presentationAnchor` 的 `UIWindow()` fallback（line 105） | 同问题 #58 | P1 | 同问题 #58 | — | 是（降级 P2，同 #58） |

### CarrierAuthStrategy.swift（37.5% 覆盖率，111 行）

| 序号 | 问题描述 | 黑盒影响性 | 严重程度 | 修改方案 | 测试例 | 是否解决 |
|------|---------|-----------|---------|---------|--------|---------|
| 75 | `AuthError.errorDescription` 全部硬编码英文（line 29-34），未通过 L10n | 运营商登录错误消息固定英文 | P1 | 用 L10n key | 切换语言后错误消息本地化 | 是 |
| 76 | **`"mock_carrier_token_\\(UUID().uuidString)"` 字符串字面量 bug**（line 65, 83）— `\\(` 被转义，实际返回字面字符串而非动态 token | Mock 模式下每次返回相同的字面字符串 | P0 | 改为 `"mock_carrier_token_\(UUID().uuidString)"`（单 `\`） | 两次调用返回不同 token | 是 |
| 77 | `acquireCredentials` 即使 `isInitialized` 也返回 Mock（line 83-93） | 真实 SDK 未接入，`isInitialized` 检查形同虚设 | P1 | 接入真实 SDK 或明确标注为 Mock | — | 是（降级 P2，Mock 实现设计限制） |
| 78 | watchOS fallback `NSError(domain:code:userInfo:)` 魔鬼字符串+数字（line 106） | — | P2 | 用 `AppError` 或 `AuthError` | — | 是 |
| 79 | `"mock_zhiyu_app_key"`/`"privacyConsent": "true"` 硬编码（line 72-73, 90-91） | — | P2 | 抽取测试常量 | — | 是（测试相关，跳过） |

### TaskCenter.swift（41.0% 覆盖率，178 行）

| 序号 | 问题描述 | 黑盒影响性 | 严重程度 | 修改方案 | 测试例 | 是否解决 |
|------|---------|-----------|---------|---------|--------|---------|
| 80 | `subLogs.count > 50` 魔鬼数字（line 待确认） | — | P2 | 抽取常量 | — | 是 |
| 81 | `removeFirst()` O(n)（line 待确认） | 频繁删除首元素性能差 | P2 | 用 `ArraySlice` 或双端队列 | — | 是（保持现状，降级） |
| 82 | `DispatchQueue.main.async` 在 `@MainActor` 类中多余（line 待确认） | — | P2 | 直接调用 | — | 是（保持现状更安全，降级） |
| 83 | 硬编码 SF Symbol/颜色（line 待确认） | — | P2 | 抽取常量 | — | 是 |

### VaultService.swift（42.4% 覆盖率，89 行）

| 序号 | 问题描述 | 黑盒影响性 | 严重程度 | 修改方案 | 测试例 | 是否解决 |
|------|---------|-----------|---------|---------|--------|---------|
| 84 | `VaultService.shared` 单例 + `private init()` 调用 `loadVaults()`（line 54-62） | 测试隔离困难，init 时 mock 仓储未注册就加载 | P1 | 改为 DI 注入或延迟加载 | — | 是（降级 P2，已有 XCTestCase 检查） |
| 85 | `isUITesting` 检查逻辑反直觉（line 58-61）：`XCTestCase == nil || isUITesting` 才加载 | 逻辑绕，单元测试时不加载但 UITesting 时加载 | P2 | 简化条件并加注释 | — | 是 |
| 86 | `getVaultDatabaseURL` 的 `force_unwrapping`（line 70） | 违反 SwiftLint 规则 | P2 | 用 `guard let` + fallback | — | 是（已有 swiftlint 注释，applicationSupportDirectory 总是存在，保持现状） |
| 87 | `saveVaultToDatabase` 的 `Task { }` 未结构化，`throws` 签名误导（line 81-87） | 调用方 `try` 永远不会捕获错误 | P1 | 改为 `async throws` 或删除 `throws` | — | 是 |

### TokenManager.swift（46.2% 覆盖率，158 行）

| 序号 | 问题描述 | 黑盒影响性 | 严重程度 | 修改方案 | 测试例 | 是否解决 |
|------|---------|-----------|---------|---------|--------|---------|
| 88 | Mock 用户硬编码（line 待确认） | — | P2 | 抽取测试常量 | — | 是（测试相关，跳过） |
| 89 | `"refresh_token"` 硬编码（line 待确认） | — | P2 | 抽取常量 | — | 是 |
| 90 | `"/api/v1/..."` 硬编码与 `AppConstants` 风格不一致（line 待确认） | — | P2 | 统一用 `AppConstants.URLs` | — | 是 |
| 91 | `"free"` 硬编码（line 待确认） | — | P2 | 用枚举 | — | 是 |
| 92 | `RefreshProfileResponse` 缺 phone 字段（line 待确认） | 刷新 profile 后 phone 丢失 | P1 | 添加 phone 字段 | — | 是 |
| 93 | 空字符串 email 覆盖本地（line 待确认） | 后端返回空 email 时覆盖本地非空 email | P0 | 空字符串不覆盖 | 后端返回空 email 时本地 email 不变 | 是 |

### GraphViewModel.swift（0% 覆盖率，113 行）

| 序号 | 问题描述 | 黑盒影响性 | 严重程度 | 修改方案 | 测试例 | 是否解决 |
|------|---------|-----------|---------|---------|--------|---------|
| 94 | `iterationTemp` 魔鬼数字 `500`/`0.02`/`0.08`（line 82） | — | P2 | 抽取常量 | — | 是 |
| 95 | `Task.sleep(for: .nanoseconds(16_000_000))` 魔鬼数字（line 103） | — | P2 | 抽取常量 `SimulationConfig.frameInterval` | — | 是 |
| 96 | `startSimulation` 在 `@MainActor` 类中 `await MainActor.run` 多余（line 95） | — | P2 | 直接更新 | — | 是（保持现状更安全，降级） |
| 97 | `isAnimating` didSet 启动 Task，快速切换可能竞态（line 25-33） | 快速 true/false 切换可能启动多个仿真 | P1 | 用 `guard simulationTask == nil` 已有，但需确保 stop 后 nil | — | 是（降级 P2，@MainActor 保证串行） |

### MediaStore.swift（0% 覆盖率，88 行）

| 序号 | 问题描述 | 黑盒影响性 | 严重程度 | 修改方案 | 测试例 | 是否解决 |
|------|---------|-----------|---------|---------|--------|---------|
| 98 | `attachmentsDirectoryName = "Attachments"` 硬编码（line 21） | — | P2 | 抽取常量 | — | 是 |
| 99 | `String(format: "%02hhx", $0)` 魔鬼字符串（line 58） | — | P2 | 抽取常量 | — | 是 |
| 100 | `saveMedia` 用 `Insecure.MD5` 命名（line 57） | MD5 虽用于去重非安全用途，但名字暗示应迁移 | P2 | 评估用 SHA256 或保持 MD5 加注释 | — | 是（保持 MD5，加注释说明非安全用途） |
| 101 | `loadMedia` 用 `try?` 吞错（line 75） | 文件读取失败静默返回 nil，无法区分"不存在"和"读取失败" | P1 | 用 `throws` 或返回 `Result` | — | 是 |

### DashboardCoordinator.swift（0% 覆盖率，111 行）

| 序号 | 问题描述 | 黑盒影响性 | 严重程度 | 修改方案 | 测试例 | 是否解决 |
|------|---------|-----------|---------|---------|--------|---------|
| 102 | `prefix(5)` 魔鬼数字（line 91） | Top 5 密度数据硬编码 | P2 | 抽取常量 | — | 是 |
| 103 | `logger.debug(" [Dashboard] : \(links) , \(density.count) ")` 日志格式混乱（line 98） | — | P2 | 规范日志格式 | — | 是 |
| 104 | `refreshInsights` 状态同步，异常时 `isGeneratingInsights` 永远 true（line 52-62） | `aiStore.generateDailyRecap` 抛异常时状态不重置 | P1 | 用 `defer { isGeneratingInsights = false }` | 异常后 isGeneratingInsights 为 false | 是 |
| 105 | `calculateStats` 的 `backlinkMap[page.title]` 用 title 作 key（line 86） | 同名 page 会导致计数错误 | P1 | 用 UUID 或 pageID 作 key | 同名 page 反链计数正确 | 是（降级 P2，wiki link 用 title 引用是固有限制） |

---

## 问题统计

| 严重程度 | 数量 | 占比 |
|---------|------|------|
| P0（功能性 bug/数据损坏/安全） | 8 | 7.6% |
| P1（逻辑错误/降级缺失/体验问题） | 38 | 36.2% |
| P2（代码质量/魔鬼数字/硬编码） | 59 | 56.2% |
| **合计** | **105** | 100% |

### P0 问题清单（重新评估后 5 个，需优先修复）

> **重新评估说明**：原 8 个 P0 中，#28（deleteVault 删父目录）经确认删除的是 vault 专属 UUID 目录不会误删，降级 P2；#35（iconForCategory 本地化比较）经确认 label 参数也来自 L10n 两边一致，降级 P2；#46（prepareImportFiles nil 不重置）经确认唯一 nil 路径已重置，降级 P2。

| 序号 | 文件 | 问题 | 修复状态 |
|------|------|------|---------|
| 13 | IngestFileHandler | RTF 用 `String(contentsOf:)` 读取得到源码非纯文本 | ✅ 已修复 |
| 24 | StoreKitService | 后端验证失败（网络问题）直接降级 pro 用户 | ✅ 已修复 |
| 68 | GitHubAuthStrategy | `clientId = ""` 硬编码，GitHub OAuth 生产环境直接抛错 | ✅ 已修复 |
| 76 | CarrierAuthStrategy | `"mock_carrier_token_\\(UUID().uuidString)"` 字符串字面量 bug（`\\(` 被转义） | ✅ 已修复 |
| 93 | TokenManager | 空字符串 email 覆盖本地非空 email | ✅ 已修复 |

---

## 测试记录

### 第一批：KnowledgeInsightService（0% → ?）

（待测试后记录）
