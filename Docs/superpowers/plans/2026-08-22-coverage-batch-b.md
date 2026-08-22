# 批次 B 实现计划：Localization/App 非View 补盲

> **起始日期**：2026-08-22
> **目标**：Localization 非View + App 非View 覆盖率从 79.17% → 95%（624 行差距）
> **范围**：34 个非 View 文件（Localization 33 个 L10n 扩展 + App 4 个非 View 文件）

---

## 覆盖率现状

| 层级 | 覆盖率 | 未覆盖行数 | 文件数 |
|------|--------|-----------|--------|
| Localization 非View | 73.38% | 732 | 40 |
| App 非View | 92.48% | 90 | 13 |
| **合计** | **79.17%** | **822** | **53** |

目标 95% = 3749 行，差距 624 行。

## 补盲策略

### 策略 1：L10n 扩展属性批量验证（Localization 层 ~580 行）

L10n 扩展文件全是 `static var` 属性，每个调用 `tr()` 或 `Localized.tr()` 返回字符串。
测试模式：调用每个属性，验证不包含 `[MISSING:` 且非空。

**重点文件**（按未覆盖行数降序）：

| 文件 | 覆盖率 | 未覆盖 | 测试策略 |
|------|--------|--------|---------|
| L10n+Common.swift | 44.11% | 185 | 调用所有未覆盖的嵌套 enum 属性（Demo/Tags/Misc/InitialNotebook/Spatial/Splash/Palette/Perf 等） |
| L10n+Dashboard.swift | 46.43% | 105 | 调用所有 Dashboard 属性 |
| L10n+AI.swift | 77.03% | 99 | 调用未覆盖的 AI 子属性 |
| L10n+Plugin.swift | 35.66% | 83 | 调用所有 Plugin 属性 |
| L10n+Ingest.swift | 59.15% | 67 | 调用未覆盖的 Ingest 属性 |
| L10n+Settings.swift | 59.66% | 48 | 调用未覆盖的 Settings 属性 |
| L10n+ICloud.swift | 25.00% | 30 | 调用所有 ICloud 属性 |
| L10n+Auth.swift | 86.47% | 18 | 调用未覆盖的 Auth 属性 |
| L10n+Collaboration.swift | 67.44% | 14 | 调用未覆盖的 Collaboration 属性 |
| L10n+Shortcuts.swift | 71.05% | 11 | 调用未覆盖的 Shortcuts 属性 |
| L10n+Onboarding.swift | 62.96% | 10 | 调用未覆盖的 Onboarding 属性 |
| L10n+Vault.swift | 80.00% | 9 | 调用未覆盖的 Vault 属性 |
| L10n+Chat.swift | 80.56% | 7 | 调用未覆盖的 Chat 属性 |
| L10n+Knowledge.swift | 89.04% | 8 | 调用未覆盖的 Knowledge 属性 |
| L10n+Graph.swift | 89.71% | 7 | 调用未覆盖的 Graph 属性 |
| L10n+Voice.swift | 86.36% | 6 | 调用未覆盖的 Voice 属性 |
| L10n+Lint.swift | 89.58% | 5 | 调用未覆盖的 Lint 属性 |
| L10n+Network.swift | 75.00% | 3 | 调用未覆盖的 Network 属性 |
| 其他 < 5 行 | — | ~15 | 批量覆盖 |

### 策略 2：App 非 View 文件补盲（~44 行）

| 文件 | 覆盖率 | 未覆盖 | 测试策略 |
|------|--------|--------|---------|
| ViewFactory.swift | 51.61% | 30 | 测试 `register` + `makeView` 兜底逻辑 + Wrapper 初始化 |
| AppWindowSceneDelegate.swift | 0.00% | 24 | 测试 scene 生命周期方法（空方法 + willConnectTo） |
| AppEnvironment.swift | 91.41% | 17 | 测试 `platformEnv` 属性 + `performSecurityCheck` 路径 |
| AppModels.swift | 0.00% | 5 | 测试 `CoachMarkType` 枚举 + `KnowledgeGrowthPoint` 构造 |
| iOSAppEnvironment.swift | 89.74% | 4 | 测试未覆盖的属性 |
| AppModel.swift | 93.62% | 3 | 测试未覆盖的分支 |

---

## 任务分解

### Task 1：L10n+Common 深度补盲（~185 行）
- 调用所有嵌套 enum 属性：Demo（Welcome/aiAgent/planning/memory/toolUse/llm 等 15 个子 enum）、Tags（18 属性）、Misc（8 属性）、InitialNotebook（PKM/Coffee/Fallback/Snippet/FileNames/Log/Tags）、Spatial（Feature 4 子 enum）、Splash、Palette、Perf（summary 子 enum）、Sidebar、Tab、Global、Empty、Log.Status
- 文件：`Tests/Unit/Localization/L10nCommonDeepTests.swift`

### Task 2：L10n+Dashboard 深度补盲（~105 行）
- 调用所有 Dashboard 属性
- 文件：`Tests/Unit/Localization/L10nDashboardDeepTests.swift`

### Task 3：L10n+Plugin 深度补盲（~83 行）
- 调用所有 Plugin 属性
- 文件：`Tests/Unit/Localization/L10nPluginDeepTests.swift`

### Task 4：L10n+AI 深度补盲（~99 行）
- 调用未覆盖的 AI 子属性
- 文件：`Tests/Unit/Localization/L10nAIDeepTests.swift`

### Task 5：L10n+Ingest+Settings+ICloud 补盲（~145 行）
- 合并 3 个中等文件
- 文件：`Tests/Unit/Localization/L10nIngestSettingsICloudDeepTests.swift`

### Task 6：L10n 中小文件批量补盲（~100 行）
- Auth/Collaboration/Shortcuts/Onboarding/Vault/Chat/Knowledge/Graph/Voice/Lint/Network + 其他 < 5 行
- 文件：`Tests/Unit/Localization/L10nMediumFilesDeepTests.swift`

### Task 7：App 非 View 补盲（~44 行）
- ViewFactory/AppWindowSceneDelegate/AppEnvironment/AppModels/iOSAppEnvironment/AppModel
- 文件：`Tests/Unit/App/AppNonViewDeepTests.swift`

### Task 8：全量验证 + 覆盖率报告
- 运行全量测试
- 生成覆盖率报告
- 验证批次 B 达到 95%
