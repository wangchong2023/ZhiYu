# 批次 D 实现计划 — View + Shared UIComponents + Platforms 快照测试

> **起始日期**：2026-08-23
> **目标**：View + Shared UIComponents + Platforms 覆盖率 → 95%（语句）
> **当前基线**：
> - Features/View: 35.92% (24470/68123), 143 文件, 62 个 0%
> - Shared/UIComponents: 38.30% (3660/9555), 56 文件, 23 个 0%
> - Platforms/iOS: 6.01% (315/5242), 37 文件, 18 个 0%
> - Platforms/Shared: 2.43% (15/618), 2 文件, 1 个 0%
> - **合计**: ~35.5% (28160/84138), ~238 文件
> **目标差距**: ~56000 行需覆盖

## 策略

### 快照测试为主，单元测试为辅

- **SwiftUI View** → 快照测试（`assertSnapshot(of:as:.image)`），验证视觉一致性
- **UIComponents** → 快照测试 + 交互逻辑单元测试
- **Platforms Services** → 单元测试（非 UI 逻辑）
- **Widget** → 快照测试（WidgetKit 预览）

### 优先级排序

1. **高价值 0% 文件**（≥400 行）：100 个 0% 文件中前 40 个，覆盖 ~20000 行
2. **低覆盖率文件提升**（<50%）：42 个文件，覆盖 ~15000 行
3. **Platforms Services**：iOS Services 单元测试
4. **剩余 0% 文件**：中小文件批量快照

## 任务分解

### Task 1: 快照测试基础设施强化
- 检查 `SnapshotConfig` / `DesignSystem.Metrics` 快照尺寸常量
- 确认 `snapshotEnvironment()` 修饰符覆盖所有依赖
- 创建 `SnapshotTestHelper` 统一 setup 模式
- **验证**：现有 16 个快照测试文件全部通过

### Task 2: Features/System View 快照（最大模块 28809 行）
- 0% 大文件：ServerConfigView(915)、OnDeviceLLMSettingsView(911)、RawStorageListView(877)、PluginStatsSection(750)、InferenceParametersView(629)、ModelLabConfigSheet(611)、PerformanceDashboardView(558)、ModelLabSandboxPanel(533)、ModelLabMetricsPanel(526)、LocalPluginDetailView(479)、RAGBenchmarkPanel(479)、SystemStatsChartView(381)
- 低覆盖率：SystemStatsView(0.5%, 1778)、DeveloperSettingsView(0.5%, 556)、PluginCenterView(0.7%, 1292)、BackupView(0.8%, 536)
- **目标**：每个文件至少 2 个快照（默认状态 + 交互/数据状态）

### Task 3: Features/Knowledge View 快照（19559 行）
- 0% 大文件：SearchSheets(1971)、GraphInfoPanel(964)、Graph3DComponents(908)、NotebookFormSheet(715)、Graph3DView(663)、VoiceAudioPlayerView(554)、PDFComponents(511)、FormattedMarkdownText(483)、ZoomableOCRImageView(420)、PDFReaderView(380)
- 低覆盖率：SearchView(2.5%, 1247)、FileTextPreviewView(13.6%, 391)
- **目标**：每个文件至少 2 个快照

### Task 4: Features/Insight View 快照（16051 行）
- 0% 大文件：WeeklyInsightCard(731)、TagCloudSubViews(517)、PageHistoryView(479)、TagBubbleCloudCanvas(416)、TagCloudMainContent(412)、LintRuleManager(410)
- 低覆盖率：PageDetailAISection(1.1%, 272)、ComparisonDetailBodyView(23.1%, 568)
- **目标**：每个文件至少 2 个快照

### Task 5: Features/AI View 快照（11239 行）
- 0% 大文件：无（仅 1 个 0% 文件）
- 低覆盖率：PromptWorkshopView(1.6%, 365)、SynthesisReportView(7.5%, 358)、ChatComponents(9.0%, 1306)、VoiceNoteComponents(21.8%, 298)
- **目标**：补充快照 + 交互逻辑测试

### Task 6: Shared/UIComponents 快照（9555 行）
- 0% 大文件：AIRainbowGlowBadge(529)、LockOverlayView(473)
- 低覆盖率：OnboardingOverlay(1.2%, 168)、AppInputs(4.8%, 252)、AIProcessingStatusBanner(9.6%, 178)、AppCard(10.1%, 129)、AppLoadingOverlay(11.8%, 68)、AppRows(20.8%, 168)、UserProfileMenu(24.9%, 690)
- **目标**：每个组件至少 2 个快照（默认 + 变体状态）

### Task 7: Platforms/iOS Services 单元测试（5242 行）
- 0% 文件：ActivityService(117, 1.7%)、iOSPDFService(147, 4.8%)、iOSWatchSyncService(181, 6.6%)、ZIPFoundationArchiver(37, 8.1%)、iOSExportService(311, 16.7%)、iOSSpeechService(108, 24.1%)
- Widget：KnowledgeStatsWidget(736)、AIProcessingActivityWidget(455)、DailyInsightWidget(380)、LiveActivityView(474)
- **目标**：Services 单元测试 + Widget 快照测试

### Task 8: 批次 D 全量验证 + 覆盖率报告
- 全量测试 0 失败
- View + Shared UIComponents + Platforms 覆盖率 ≥ 95%
- 发现的问题写入 findings 文档

## 验证标准

- 全量测试 0 失败
- View + Shared UIComponents + Platforms 语句覆盖率 ≥ 95%
- 快照测试以发现问题为目的，发现的问题写入 findings 文档
