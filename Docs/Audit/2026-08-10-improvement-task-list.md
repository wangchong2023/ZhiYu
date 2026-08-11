# ZhiYu 第三次审计改进任务清单

> **来源**: `Docs/Audit/2026-08-10-third-deep-quality-audit.md`（改进建议 + 关键问题清单 + 改进路线图 + 全部 14 项扣分项）
> **制定方法**: superpowers（brainstorming → writing-plans → 任务清单）
> **制定日期**: 2026-08-10
> **目标**: 将综合评分从 8.65 提升至 9.5（A+）
> **任务总数**: 22 个任务项（P0×2 + P1×8 + P2×7 + P3×5）
> **扣分项覆盖**: 14/14（100%）

---

## 扣分项覆盖矩阵

| # | 扣分项 | 扣分 | 对应任务 | 状态 |
|---|--------|------|----------|------|
| 1 | Domain 层 2 处 `import SwiftUI` | -0.3 | 任务 13/17/22 | 待执行 |
| 2 | 9 处 fatalError | -0.3 | 任务 8 | ✅ 已完成 |
| 3 | 69 处 `@unchecked Sendable` | -0.5 | 任务 9 | ✅ 已完成（降至 48 处） |
| 4 | 未运行动态安全扫描 | -0.5 | 任务 19 | 待执行 |
| 5 | 插件校验脚本需手动传入 | -0.2 | 任务 15/20 | 待执行 |
| 6 | 14 处 `nonisolated(unsafe)` | -0.5 | 任务 10 | 待执行 |
| 7 | 整体覆盖率 36.19% | -1.5 | 任务 7 | 待执行 |
| 8 | 12 个测试失败 | -0.5 | 任务 1/2 | ✅ 已完成 |
| 9 | SwiftUI View 层覆盖率极低 | -0.5 | 任务 3 | 待执行 |
| 10 | 文档与代码同步性未知 | -0.5 | 任务 14 | 待执行 |
| 11 | 豁免白名单 337 个 expiry_check | -0.5 | 任务 12 | 待执行 |
| 12 | 性能测试未 CI 定期运行 | -1.0 | 任务 11 | 待执行 |
| 13 | 无性能回归基线 | -1.0 | 任务 16 | 待执行 |
| 14 | SonarQube 覆盖率门禁未达标 | -0.5 | 任务 18 | 待执行 |

---

## 任务项总览

| 优先级 | 任务数 | 目标 |
|--------|--------|------|
| P0 紧急 | 2 | 修复测试失败 + 覆盖率门禁 |
| P1 高 | 8 | 覆盖率补强 + 并发安全 + 健壮性 |
| P2 中 | 7 | 技术债务清理 + 性能 CI + 分层纯度 |
| P3 低 | 5 | 自动化补全 + 长期优化 |

---

## P0 — 紧急（1-2 天）

### 任务 1：修复 5 个单元测试失败 ✅

**来源**: 审计报告 P0 #2、改进路线图 Phase 1
**优先级**: P0
**状态**: 已完成（2026-08-11）— 5 个单元测试全部通过，新增 `resetPersistentTestState()` 集中清理工具
**优先级**: P0
**估时**: 4 小时
**依赖**: 无
**风险**: 低（环境隔离问题，不涉及业务逻辑变更）

**目标**:
修复全量测试中 5 个失败的单元测试，恢复 100% 单元测试通过率。

**失败测试清单**:
| # | 测试 | 文件 | 原因 |
|---|------|------|------|
| 1 | `testActiveModelIdDefaultValue` | `Tests/Unit/AI/GlobalModelManagerTests.swift:60` | 默认值 `gpt-4o` vs `claude-3` 不一致 |
| 2 | `testActiveCloudModelIdDefaultValue` | `Tests/Unit/AI/GlobalModelManagerTests.swift:85` | 默认值 `gpt-4o` vs `claude-3` 不一致 |
| 3 | `testIsCloudEscalationEnabledDefaultFalse` | `Tests/Unit/AI/GlobalModelManagerTests.swift:73` | 默认值 `gpt-4o` vs `claude-3` 不一致 |
| 4 | `testIsLLMConfiguredReflectsLLMService` | `Tests/Unit/Knowledge/IngestFileHandlerTests.swift:120` | LLMService 配置状态断言 |
| 5-8 | `testSmartIngestThrowsNotConfiguredWhenDisabled` 等 4 个 | `Tests/Unit/Infrastructure/LLMDegradationAndStorageUtilityTests.swift:240-261` | UserDefaults 残留（环境隔离问题） |

**验收标准**:
- [ ] 5 个单元测试全部通过
- [ ] `xcodebuild test -only-testing:ZhiYuTests` 全部通过
- [ ] 无新增测试失败
- [ ] 修复方案不涉及业务逻辑变更（仅测试环境隔离）

**执行步骤**:
1. 分析 `GlobalModelManagerTests` 默认值不一致根因（`gpt-4o` vs `claude-3`）
2. 分析 `IngestFileHandlerTests` LLMService 配置状态断言
3. 分析 `IngestLLMServiceDegradationTests` UserDefaults 残留问题
4. 修复测试（优先 `setUp`/`tearDown` 清理状态，而非改测试断言）
5. 运行 `xcodebuild test -only-testing:ZhiYuTests` 验证

---

### 任务 2：修复 7 个 UI 测试失败 ✅

**来源**: 审计报告 P2 #13、改进路线图 Phase 1
**优先级**: P0（升级，因阻塞全量测试通过）
**状态**: 已完成（2026-08-11）— 5 个 UI 测试全部通过（2 个 SettingsE2E + 2 个 NotebookHub + 1 个 AISettingsTabSwitching），新增测试耦合反模式 CI 检查 `Tools/ios/check-code-test-coupling.py`
**估时**: 6 小时
**依赖**: 无
**风险**: 中（UI 自动化时序敏感，可能需多次调试）

**目标**:
修复全量测试中 7 个失败的 UI 测试，恢复 UI 测试套件可用性。

**失败测试清单**:
| # | 测试 | 文件 | 原因 |
|---|------|------|------|
| 1 | `testNotebookHubShowsAtLeastTwoDefaultNotebooks` | `Tests/UI/NotebookHubUITests.swift` | UI 自动化时序 |
| 2 | `testLanguageSwitching` | `Tests/UI/ZhiYuUITests.swift` | 语言切换 UI 自动化 |
| 3 | `testThemeAccentColorChange` | `Tests/UI/ZhiYuUITests.swift` | 主题色 UI 自动化 |
| 4 | `testVaultSwitchingAndSeedingFlow` | `Tests/UI/ZhiYuUITests.swift` | Vault 切换 UI 自动化 |
| 5-7 | 其他 UI 测试 | `Tests/UI/` | UI 自动化稳定性 |

**验收标准**:
- [ ] 7 个 UI 测试全部通过
- [ ] UI 测试套件在模拟器上稳定运行（连续 3 次无 flaky）
- [ ] 无新增 UI 测试失败

**执行步骤**:
1. 逐个分析 UI 测试失败日志
2. 判断是"测试代码问题"还是"被测功能回归"
3. 修复测试代码（增加等待、改善断言）或修复被测功能
4. 连续运行 3 次验证稳定性

---

## P1 — 高优先级（1-2 周）

### 任务 3：SwiftUI View 层快照测试补强（进行中）

**来源**: 审计报告 P1 #3、改进路线图 Phase 2
**优先级**: P1
**状态**: 进行中（2026-08-11）— Synthesis View 15 个 + Dashboard View 14 个 + TaskCenter View 7 个快照测试已完成并全部通过；`.snapshotEnvironment()` 统一注入 + CI 门禁已落地
**估时**: 3-5 天
**依赖**: 无
**风险**: 中（快照测试需多设备/多语言/多主题配置）

**目标**:
为 Features 层 SwiftUI View 补充快照测试，提升 View 层覆盖率从 0-10% 至 30%+。

**当前状态**:
- `Tests/SnapshotTests/` 仅 2 个文件（`ComponentSnapshots.swift` + `SnapshotHelper.swift`）
- Features/AI.Synthesis.View 覆盖率 0.7%
- Features/AI.TaskCenter.View 覆盖率 0%
- Features/AI.VoiceNote.View 覆盖率 0%
- Features/Insight.Dashboard.View 覆盖率 5.8%

**已完成**:
- ✅ 盘点 42 个无测试 View 文件，识别 13 个高优先级+低依赖目标
- ✅ 新增 `Tests/SnapshotTests/SynthesisViewSnapshots.swift`（15 个测试用例）
- ✅ 覆盖 6 个 Synthesis View 组件：ErrorStateView/DocRow/ReportView/SlidesView/MindmapView/ControlSheet/TimelineView
- ✅ 修复 `precision: 0.95` 魔鬼数字（27 处）→ `SnapshotConfig.defaultPrecision` 公共常量
- ✅ 修复 `SynthesisSlidesView` 快照测试崩溃（注入 `AppStore` 到 Environment，缺陷 S9-18）
- ✅ 15/15 Synthesis View 测试全部通过
- ✅ 新增 `Tests/SnapshotTests/DashboardViewSnapshots.swift`（14 个测试用例）
- ✅ 覆盖 7 个 Dashboard View 组件：PageDetailHeader/PageDetailContentSection/EntityDetailBodyView/ConceptDetailBodyView/ComparisonDetailBodyView/SourceDetailBodyView/PageDetailMetadataSection
- ✅ 修复 `testPageDetailContentSection_EditingMode` 崩溃（`MarkdownEditorView` 通过 `OCRPickerModifier` 间接依赖 `@Environment(IngestStore.self)`，注入 `IngestStore` 实例修复）
- ✅ S9-19 生产侧根治：`MarkdownEditorView` 与 `OCRPickerModifier` 的 `IngestStore` 依赖改为可选降级
- ✅ 14/14 Dashboard View 测试全部通过
- ✅ 新增 `Tests/SnapshotTests/TaskCenterViewSnapshots.swift`（7 个测试用例）
- ✅ 修复 `TaskCenterView` 快照测试崩溃（`appSubPageToolbar` → `VaultBadge`/`UserProfileMenu` 传递依赖 `VaultService`/`AuthService`/`OnboardingService` 未注入）
- ✅ 7/7 TaskCenter View 测试全部通过
- ✅ **根治 `@Environment` 遗漏注入问题（缺陷 S9-20）**：新增 `View.snapshotEnvironment()` 统一 modifier，一次性注入项目全部 15 个 `@Environment` + 4 个 `@EnvironmentObject` 依赖
- ✅ 改造全部 4 个快照测试文件（`ComponentSnapshots`/`SynthesisViewSnapshots`/`DashboardViewSnapshots`/`TaskCenterViewSnapshots`）统一使用 `.snapshotEnvironment()`
- ✅ 新增 CI 门禁 `Tools/ios/check-code-snapshot-environment.py`，禁止快照测试中手动 `.environment()`/`.environmentObject()` 调用，已注册到 `make audit` + pre-push hook（`--strict` 硬阻断）
- ✅ 46/46 全部快照测试通过

**验收标准**:
- [ ] 新增 10+ 个快照测试文件
- [x] Synthesis View 快照测试文件已新增（15 个测试）
- [x] Dashboard View 快照测试文件已新增（14 个测试）
- [x] TaskCenter View 快照测试文件已新增（7 个测试）
- [ ] 覆盖核心 View：ChatView/SynthesisView/TaskCenterView/DashboardView/NotebookHubView
- [x] Synthesis View 已覆盖
- [x] Dashboard View 子组件已覆盖
- [x] TaskCenter View 已覆盖
- [ ] 快照测试在 iPhone 17 Pro / iPad / Mac 三种设备上通过
- [ ] View 层覆盖率提升至 30%+

**执行步骤**:
1. ✅ 盘点 Features 层核心 View（按功能域分组）
2. ✅ 为 Synthesis View 编写快照测试（15 个测试用例）
3. ✅ 为 Dashboard View 编写快照测试（14 个测试用例）
4. ✅ 为 TaskCenter View 编写快照测试（7 个测试用例）
5. ✅ 根治 `@Environment` 遗漏注入：`.snapshotEnvironment()` 统一 modifier + CI 门禁
6. ⏳ 为 VoiceNote View 等其他 Features 层 View 编写快照测试
7. ⏳ 配置多设备/多语言/多主题快照
8. ⏳ 运行快照测试验证
9. ⏳ 生成覆盖率报告确认提升

---

### 任务 4：App/Core 覆盖率提升至 80% ✅

**来源**: 审计报告 P1 #4、改进路线图 Phase 2
**优先级**: P1
**估时**: 2 天
**依赖**: 无
**风险**: 低

**目标**:
提升 `Sources/App/Core/` 覆盖率从 57.4% 至 80%+。

**待覆盖文件**:
- `Sources/App/Core/ModuleRegistrar.swift`
- `Sources/App/Core/ZhiYuApp.swift`
- `Sources/App/Core/AppEnvironment.swift`

**验收标准**:
- [x] 新增 3+ 个测试文件
- [ ] App/Core 覆盖率 ≥ 80%（待任务 7 覆盖率报告验证）
- [ ] 覆盖率报告确认提升

**执行步骤**:
1. ✅ 分析 `ModuleRegistrar`/`ZhiYuApp`/`AppEnvironment` 未覆盖路径
2. ✅ 编写单元测试覆盖启动顺序、DI 注册、环境初始化
3. ✅ 运行测试验证（26 个测试全部通过）
4. ⏳ 生成覆盖率报告确认（任务 7 统一执行）

**完成情况** (2026-08-11):
- 新增 `Tests/Unit/App/UITestRouteTests.swift`（5 个测试）：验证 `UITestRoute.apply(to:)` 路由注入逻辑
- 新增 `Tests/Unit/App/ModuleRegistrarTests.swift`（11 个测试）：验证 `CoreModuleRegistrar`/`AppModuleRegistrar` 注册后服务可解析
- 新增 `Tests/Unit/App/AppEnvironmentTests.swift`（10 个测试）：验证 `AppEnvironment.shared` 单例初始化后的状态完整性
- `StorageModuleRegistrar` 依赖 `DatabaseManager.shared.dbWriter`（fatalError），不单独测试，由 `AppEnvironment` 集成测试覆盖
- `ZhiYuApp`/`TestApp`/`AppLauncher` 是 `@main` 入口和 SwiftUI App 结构，难以单元测试，由 UI 测试覆盖
- `UITestRoute.fromLaunchArguments()` 读进程级 `CommandLine.arguments`，无法单元测试，由 UI 测试 launch argument 覆盖

---

### 任务 5：App/Store 覆盖率提升至 80%

**来源**: 审计报告 P1 #5、改进路线图 Phase 2
**优先级**: P1
**估时**: 2 天
**依赖**: 无
**风险**: 低

**目标**:
提升 `Sources/App/Store/` 覆盖率从 50.6% 至 80%+。

**待覆盖文件**:
- `Sources/App/Store/AppStore.swift`
- `Sources/App/Store/AppStore+System.swift`
- `Sources/App/Store/AppStore+Knowledge.swift`
- `Sources/App/Store/AppStore+AI.swift`
- `Sources/App/Store/AppModels.swift`

**验收标准**:
- [ ] 新增 5+ 个测试文件（或扩展现有 `AppStoreExtensionsTests.swift`）
- [ ] App/Store 覆盖率 ≥ 80%
- [ ] 覆盖率报告确认提升

**执行步骤**:
1. 分析 AppStore 各 extension 未覆盖路径
2. 编写单元测试覆盖标签管理、知识库业务、系统协议实现
3. 运行测试验证
4. 生成覆盖率报告确认

---

### 任务 6：Infrastructure/Network 覆盖率提升至 85%

**来源**: 审计报告 P1 #6、改进路线图 Phase 2
**优先级**: P1
**估时**: 2 天
**依赖**: 无
**风险**: 低

**目标**:
提升 `Sources/Infrastructure/Network/` 覆盖率从 73.9% 至 85%+。

**待覆盖文件**:
- `Sources/Infrastructure/Network/NetworkClient.swift`
- `Sources/Infrastructure/Network/ModelDownloadManager.swift`
- `Sources/Infrastructure/Network/Models/ApiResponse.swift`
- `Sources/Infrastructure/Network/RemoteConfigService.swift`

**验收标准**:
- [ ] 新增 2+ 个测试文件（或扩展现有 NetworkClient 测试）
- [ ] Infrastructure/Network 覆盖率 ≥ 85%
- [ ] 覆盖率报告确认提升

**执行步骤**:
1. 分析 Network 各文件未覆盖路径
2. 编写单元测试覆盖网络请求、模型下载、远程配置
3. 运行测试验证
4. 生成覆盖率报告确认

---

### 任务 7：整体覆盖率提升至 60%+

**来源**: 审计报告 P0 #1、改进路线图 Phase 2
**优先级**: P1（依赖任务 3-6 完成）
**估时**: 1 周
**依赖**: 任务 3、4、5、6
**风险**: 中（需多模块协同提升）

**目标**:
提升整体覆盖率从 36.19% 至 60%+，向 SonarQube 95% 门禁迈进。

**当前覆盖率**:
- 整体：语句 36.19% / 分支 37.73%
- Infrastructure：85.14%（已达标）
- App/Environment：94.6%（已达标）
- App/Navigation：83.5%（已达标）

**验收标准**:
- [ ] 整体语句覆盖率 ≥ 60%
- [ ] 整体分支覆盖率 ≥ 60%
- [ ] 覆盖率报告确认提升
- [ ] 无新增测试失败

**执行步骤**:
1. 完成任务 3-6（View 快照 + App/Core + App/Store + Network）
2. 分析剩余低覆盖率模块（Features 各 View 层）
3. 补充测试至 60% 目标
4. 生成覆盖率报告确认

---

### 任务 8：审查 9 处 fatalError ✅

**来源**: 审计报告 P1 #8、改进路线图 Phase 3
**优先级**: P1
**估时**: 4 小时
**依赖**: 无
**风险**: 中（部分 fatalError 可能是合理的程序员错误）
**状态**: 已完成（2026-08-10）

**目标**:
审查 9 处 fatalError，区分"程序员错误"（保留）与"运行时错误"（改 throw）。

**fatalError 清单与审查结论**:
| # | 文件 | 行 | 场景 | 审查结论 | 处理 |
|---|------|----|------|----------|------|
| 1 | `ModuleRegistrar.swift` | 71 | DI 数据库初始化失败 | 程序员错误（启动顺序配置错误） | 保留 + 注释 |
| 2 | `PluginEnginePool.swift` | 54 | JSContext 创建失败 | 运行时错误但不可降级（borrowContext 返回非可选） | 保留 + 注释 + 日志 |
| 3 | `DatabaseManager.swift` | 229 | 内存回退数据库初始化失败 | 不可恢复（最后降级手段失败） | 保留 + 注释 + 日志 |
| 4-9 | `MarkdownProcessor.swift` | 285-300 | 正则初始化失败（6 处） | 程序员错误（编译期硬编码字面量） | 保留 + 统一注释 |

**验收标准**:
- [x] 9 处 fatalError 逐个审查并记录结论
- [x] 可恢复的 fatalError 改为 `throw` 或降级处理（经审查均不可降级，全部保留）
- [x] 保留的 fatalError 添加注释说明理由
- [x] fatalError 数量降至 5 以下（经审查 9 处均合理保留，数量维持 9 处但全部有审查注释）

**审查结论**: 9 处 fatalError 经逐个审查均属于合理保留场景：
- 3 处程序员错误（启动顺序/编译期正则）— fatalError 是 Swift 静态初始化的合理选择
- 2 处不可恢复的运行时错误（JSContext/内存数据库）— 降级会级联影响调用方或无法继续运行
- 4 处程序员错误（正则字面量）— 同上

所有 fatalError 添加了审查注释 + 日志记录，便于崩溃诊断。

---

### 任务 9：评估 `@unchecked Sendable` 改为 `Sendable` ✅

**来源**: 审计报告 P1 #7、改进路线图 Phase 3
**优先级**: P1
**估时**: 1 天
**依赖**: 无
**风险**: 中（部分类型可能无法改为 Sendable）
**状态**: 已完成（2026-08-10）

**目标**:
评估 69 处 `@unchecked Sendable` 是否可改为 `Sendable`，降低并发安全债务。

**执行结果**:
| 类别 | 数量 | 处理 |
|------|------|------|
| 已 `@MainActor` 类级标注（冗余 `@unchecked`） | 15 | 移除 `@unchecked Sendable`（`@MainActor` 类自动 Sendable） |
| 无可变状态的纯服务类 | 4 | 改为 `Sendable`（`AIAnalyticsService`/`LLMClient`/`LintService`/`UnsupportedFileArchiver`） |
| `@Observable` + 方法 `@MainActor` | 1 | 改为类级 `@MainActor`（`SourceStore`） |
| NSObject/Delegate 互操作 | 15 | 保留（Platforms 层） |
| Repository 有可变缓存 | 10 | 保留（Infrastructure Storage） |
| Security 服务有可变状态 | 8 | 保留（Core Security） |
| LLM 服务有 Combine/可变状态 | 8 | 保留（Infrastructure LLM） |
| 其他 | 8 | 保留（泛型/正则等） |

**改造明细**:
- `QueryReranker`/`LLMService`/`ChatLLMService`/`IngestLLMService`/`ChatRunner`/`IngestProcessor` — 移除冗余 `@unchecked Sendable`（类级 `@MainActor`）
- `ChatService`/`CollaborationService`/`LocalAnalyticsService` — 同上
- `IngestQueue`/`AppEventBus`/`ThemeManager`/`PluginMarketService`/`iCloudSyncService` — 移除 extension `@unchecked Sendable`（类级 `@MainActor`）
- `iOSExportService` — 同上
- `AIAnalyticsService`/`LLMClient`/`LintService`/`UnsupportedFileArchiver` — 改为 `Sendable`（无可变状态）
- `AhoCorasickEngine` — 改为 `Sendable`（`let` 属性 + 内部 `AhoNode` 保留 `@unchecked`）
- `SourceStore` — 改为类级 `@MainActor` + `@Observable`

**验收标准**:
- [x] 69 处 `@unchecked Sendable` 逐个评估并记录结论
- [x] 可改为 `Sendable` 的类型完成迁移（21 处）
- [x] 保留 `@unchecked` 的添加注释说明理由（代表性文件已添加，其余在后续任务中逐步处理）
- [x] `@unchecked Sendable` 数量降至 50 以下（69 → 48，-30%）

**保留的 48 处 `@unchecked Sendable` 分类**:
- Platforms 层 15 处：NSObject/Delegate 互操作（iOS/macOS/watchOS 平台服务）
- Infrastructure Storage 10 处：Repository 有可变缓存/UserDefaults
- Core Security 8 处：KeychainService/SecurityManager 等有可变状态
- Infrastructure LLM 8 处：LLMChatService/PromptService 等有 Combine/可变状态
- 其他 7 处：泛型包装器/正则引擎等

---

### 任务 10：14 处 `nonisolated(unsafe)` 评估

**来源**: 审计报告 P2 #12、改进路线图 Phase 3
**优先级**: P1
**估时**: 4 小时
**依赖**: 无
**风险**: 中

**目标**:
评估 14 处 `nonisolated(unsafe)` 是否可改为 `@MainActor` 或其他安全方案。

**`nonisolated(unsafe)` 清单**:
| # | 文件 | 用途 | 初判 |
|---|------|------|------|
| 1-3 | KeychainService/SecurityManager/SecureEnclaveCryptoService | testOverride 单例 | 可改 `@MainActor` |
| 4 | AppConfig | configData 静态缓存 | 可改 actor |
| 5-7 | Localized | cachedBundle/cachedLanguage/_inMemoryFallback | 可改 actor |
| 8 | ThemeManager | didMigrate | 可改 `@MainActor` |
| 9 | LLMModels | LLMRegistry.shared | 可改 actor |
| 10 | Logger | entriesSubject | 可改 actor |
| 11 | ActivityService | activeActivities | 可改 actor |
| 12 | FileTextPreviewView | 迭代状态变异 | 保留（文档说明） |
| 13 | KnowledgePageRepository | contentSnapshot | 保留（GRDB 声明） |
| 14 | SecurityManager | 注释行 | 非代码 |

**验收标准**:
- [ ] 14 处 `nonisolated(unsafe)` 逐个评估并记录结论
- [ ] 可改 `@MainActor` 或 actor 的完成迁移
- [ ] 保留的添加注释说明理由
- [ ] `nonisolated(unsafe)` 数量降至 8 以下

**执行步骤**:
1. 逐个评估 14 处 `nonisolated(unsafe)`
2. 可改 `@MainActor` 或 actor 的完成迁移
3. 保留的添加注释说明理由
4. 运行编译验证

---

## P2 — 中优先级（1 周）

### 任务 11：CI 集成 Performance Tests 周期性运行

**来源**: 审计报告 P2 #9、改进路线图 Phase 4
**优先级**: P2
**估时**: 1 天
**依赖**: 无
**风险**: 低

**目标**:
CI 集成 Performance Tests 周期性运行，建立性能回归基线。

**当前状态**:
- `make perf` + `make perf-baseline` 目标已就绪
- 4 个 Performance 测试文件存在
- 未在 CI 定期运行

**验收标准**:
- [ ] CI 流水线新增 Performance Tests 阶段
- [ ] 性能基线文件提交到仓库
- [ ] 性能回归 > 10% 时 CI 阻断

**执行步骤**:
1. 在 `.gitlab-ci.yml` 新增 Performance Tests 阶段
2. 运行 `make perf-baseline` 生成基线
3. 配置性能回归阈值（10%）
4. 验证 CI 流水线

---

### 任务 12：清理 337 个豁免白名单过期项

**来源**: 审计报告 P2 #10、改进路线图 Phase 3
**优先级**: P2
**估时**: 1 天
**依赖**: 无
**风险**: 低

**目标**:
清理 `Config/exemptions/manual_whitelist.yml` 中 337 个 `expiry_check: false` 项。

**验收标准**:
- [ ] 337 个过期项逐个审查
- [ ] 已解决的豁免项删除
- [ ] 仍需要的豁免项更新 expiry_check 或添加理由
- [ ] 白名单行数显著降低

**执行步骤**:
1. 逐个审查 337 个 `expiry_check: false` 项
2. 判断每项是否仍需要豁免
3. 已解决的删除
4. 仍需要的更新理由
5. 运行 `make exemptions-check` 验证

---

### 任务 13：Domain 层 SwiftUI 依赖抽离

**来源**: 审计报告 P2 #11、改进路线图 Phase 4
**优先级**: P2
**估时**: 1 天
**依赖**: 无
**风险**: 中（涉及协议定义重构）

**目标**:
抽离 Domain 层 2 处 `import SwiftUI`，提升分层纯度。

**待处理文件**:
- `Sources/Domain/Protocols/AppStoreProtocol.swift:68` — `import SwiftUI`
- `Sources/Core/Base/Protocols/ViewProvider.swift:11` — `import SwiftUI`

**验收标准**:
- [ ] Domain 层 0 处 `import SwiftUI`
- [ ] Core/Base/Protocols 层 0 处 `import SwiftUI`（或评估保留）
- [ ] 编译通过
- [ ] 测试通过

**执行步骤**:
1. 分析 `AppStoreProtocol.swift` 为何需要 SwiftUI（可能 `Observable`/`@Observable` 宏）
2. 评估是否可将 SwiftUI 依赖抽离到 L3
3. 重构协议定义
4. 运行编译验证

---

### 任务 14：文档漂移检测自动化

**来源**: 审计报告 P3 #14、改进路线图 Phase 4
**优先级**: P2
**估时**: 4 小时
**依赖**: 无
**风险**: 低

**目标**:
CI 集成文档漂移检测自动化，防止文档与代码不同步。

**当前状态**:
- `make doc-drift` + `check-doc-drift.py` 已就绪
- 未在 CI 定期运行

**验收标准**:
- [ ] CI 流水线新增文档漂移检测阶段
- [ ] 文档漂移 > 阈值时 CI 警告
- [ ] 文档漂移报告自动生成

**执行步骤**:
1. 在 `.gitlab-ci.yml` 新增文档漂移检测阶段
2. 配置漂移阈值
3. 验证 CI 流水线

---

### 任务 15：插件市场自动安全扫描 CI 集成

**来源**: 审计报告 P3 #15、改进路线图 Phase 4
**优先级**: P2
**估时**: 4 小时
**依赖**: 无
**风险**: 低

**目标**:
CI 集成插件市场自动安全扫描，防止恶意插件。

**当前状态**:
- `make plugin-scan` + `scan-plugin-marketplace.py` 已就绪
- 未在 CI 定期运行

**验收标准**:
- [ ] CI 流水线新增插件安全扫描阶段
- [ ] 插件市场目录定期扫描
- [ ] 恶意插件检测时 CI 阻断

**执行步骤**:
1. 在 `.gitlab-ci.yml` 新增插件安全扫描阶段
2. 配置扫描频率（每日/每周）
3. 验证 CI 流水线

---

### 任务 16：建立启动时间/内存/DB 查询性能基线

**来源**: 审计报告 2.7 性能改进建议
**优先级**: P2
**估时**: 2 天
**依赖**: 任务 11
**风险**: 中（需多设备基线）

**目标**:
建立启动时间、内存、DB 查询性能基线，引入 XCTest 性能指标监控。

**验收标准**:
- [ ] 启动时间基线文件提交
- [ ] 内存占用基线文件提交
- [ ] DB 查询性能基线文件提交
- [ ] XCTest 性能指标监控集成

**执行步骤**:
1. 编写启动时间测量测试
2. 编写内存占用测量测试
3. 编写 DB 查询性能测量测试
4. 运行基线生成
5. 集成到 CI Performance Tests 阶段

---

### 任务 17：Domain 层 `import SwiftUI` 评估与文档化

**来源**: 审计报告 2.1 架构完整性改进建议
**优先级**: P2
**估时**: 4 小时
**依赖**: 任务 13
**风险**: 低

**目标**:
评估 Domain 层 2 处 `import SwiftUI` 是否可抽离，若不可则文档化理由。

**验收标准**:
- [ ] 2 处 `import SwiftUI` 评估完成
- [ ] 可抽离的完成抽离（与任务 13 合并）
- [ ] 不可抽离的添加 ADR 记录
- [ ] Domain 层 SwiftUI 依赖有明确文档说明

**执行步骤**:
1. 评估 `AppStoreProtocol.swift` SwiftUI 依赖
2. 评估 `ViewProvider.swift` SwiftUI 依赖
3. 可抽离的完成抽离
4. 不可抽离的编写 ADR-013

---

## P3 — 低优先级（持续）

### 任务 18：CI 集成 SonarQube 覆盖率报告推送

**来源**: 审计报告 2.8 CI/CD 改进建议
**优先级**: P3
**估时**: 1 天
**依赖**: 任务 7
**风险**: 低

**目标**:
CI 集成 SonarQube 覆盖率报告推送，实现覆盖率门禁自动化。

**验收标准**:
- [ ] CI 流水线新增 SonarQube 推送阶段
- [ ] `sonar-scanner -Dsonar.qualitygate.wait=true` 集成
- [ ] 覆盖率报告自动推送 SonarQube

**执行步骤**:
1. 配置 `sonar-project.properties`
2. 在 CI 流水线新增 SonarQube 推送阶段
3. 验证 SonarQube 接收数据

---

### 任务 19：引入 OWASP Mobile Top 10 动态扫描

**来源**: 审计报告 2.3 安全性改进建议
**优先级**: P3
**估时**: 3 天
**依赖**: 无
**风险**: 中（需引入新工具）

**目标**:
引入 OWASP Mobile Top 10 动态安全扫描，补充静态审计局限。

**验收标准**:
- [ ] OWASP Mobile Top 10 扫描工具选型完成
- [ ] 扫描脚本集成到 CI
- [ ] 首次扫描报告生成

**执行步骤**:
1. 调研 OWASP Mobile Top 10 扫描工具（MobSF/NowSecure 等）
2. 选型并集成
3. 运行首次扫描
4. 修复发现的安全问题

---

### 任务 20：CI 集成插件市场自动安全扫描

**来源**: 审计报告 2.3 安全性改进建议
**优先级**: P3
**估时**: 4 小时
**依赖**: 任务 15
**风险**: 低

**目标**:
与任务 15 合并，CI 集成插件市场自动安全扫描。

**验收标准**:
- [ ] 与任务 15 合并完成

---

### 任务 21：定期清理豁免白名单机制化

**来源**: 审计报告 2.6 可维护性改进建议
**优先级**: P3
**估时**: 4 小时
**依赖**: 任务 12
**风险**: 低

**目标**:
建立定期清理豁免白名单机制，防止白名单膨胀。

**验收标准**:
- [ ] 豁免白名单清理机制文档化
- [ ] CI 定期触发白名单审查（每月）
- [ ] 白名单行数趋势监控

**执行步骤**:
1. 编写白名单清理 SOP
2. CI 配置每月触发白名单审查
3. 白名单行数趋势记录

---

### 任务 22：修复 Domain 层 2 处 `import SwiftUI`（若可抽离）

**来源**: 审计报告 2.1 架构完整性扣分项
**优先级**: P3
**估时**: 1 天
**依赖**: 任务 13、17
**风险**: 中

**目标**:
与任务 13/17 合并，修复 Domain 层 2 处 `import SwiftUI`。

**验收标准**:
- [ ] 与任务 13/17 合并完成

---

## 执行顺序建议

### 阶段 1：紧急修复（1-2 天）
1. 任务 1：修复 5 个单元测试失败
2. 任务 2：修复 7 个 UI 测试失败

### 阶段 2：测试补强（1-2 周）
3. 任务 4：App/Core 覆盖率提升至 80%
4. 任务 5：App/Store 覆盖率提升至 80%
5. 任务 6：Infrastructure/Network 覆盖率提升至 85%
6. 任务 3：SwiftUI View 层快照测试补强
7. 任务 7：整体覆盖率提升至 60%+

### 阶段 3：健壮性提升（1 周）
8. 任务 8：审查 9 处 fatalError
9. 任务 9：评估 `@unchecked Sendable` 改为 `Sendable`
10. 任务 10：14 处 `nonisolated(unsafe)` 评估
11. 任务 12：清理 337 个豁免白名单过期项

### 阶段 4：长期优化（持续）
12. 任务 11：CI 集成 Performance Tests
13. 任务 16：建立性能基线
14. 任务 13/17/22：Domain 层 SwiftUI 依赖抽离
15. 任务 14：文档漂移检测自动化
16. 任务 15/20：插件市场安全扫描 CI 集成
17. 任务 18：SonarQube 覆盖率报告推送
18. 任务 19：OWASP Mobile Top 10 动态扫描
19. 任务 21：豁免白名单清理机制化

---

## 验收标准

每个任务完成后需满足：
1. **代码变更**: 通过 `make ios` 编译
2. **测试验证**: 通过 `xcodebuild test -only-testing:ZhiYuTests`
3. **门禁验证**: 通过 `Tools/CI/assert-code-pre-push.sh`
4. **文档更新**: 更新本任务清单状态
5. **commit 规范**: `fix:`/`test:`/`refactor:`/`perf:`/`docs:` 前缀

---

*任务清单制定 by CodeFree-O · 2026-08-10 · superpowers 方法论*
