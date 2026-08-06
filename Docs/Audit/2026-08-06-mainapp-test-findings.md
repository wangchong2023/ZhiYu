# 主 App 测试驱动问题发现记录

> **起始日期**：2026-08-06
> **关联规格**：`Docs/superpowers/specs/2026-08-06-mainapp-coverage-design.md`
> **关联计划**：`docs/superpowers/plans/2026-08-06-mainapp-coverage.md`

## 严重程度定义

- 🔴 **P0**：数据损坏/丢失、崩溃、安全漏洞、资金损失（订阅/支付）
- 🟡 **P1**：逻辑错误、行为不一致、边界处理缺陷、错误处理缺失
- 🟢 **P2**：健壮性不足、维护负担、死代码、命名/注释问题

## 问题清单

| 序号 | 严重程度 | 文件:行号 | 问题类型 | 问题描述 | 黑盒影响 | 修改方案 | 处理状态 | 批次 |
|------|---------|----------|---------|---------|---------|---------|---------|------|
| 1 | 🟢 P2 | `Sources/Core/Base/Constants/LogAction.swift:23,35-36,40-41` | 契约不一致 | `export="action.export"`、`aiscanFailed/aiscanSkipped="log.action.aiscan.*"`、`error="ERROR"`、`unknown="unknown"` 不符合 `logAction.*` 前缀契约 | 日志分析时按 `logAction.` 前缀过滤会遗漏这些动作 | 统一改为 `logAction.export`/`logAction.aiscan.failed`/`logAction.aiscan.skipped`/`logAction.error`/`logAction.unknown` | 已修复 | 批次1 |
| 2 | 🟡 P1 | `Sources/Localization/Catalogs/Ingest.xcstrings` (`error.internalError`) | 本地化缺陷 | `error.internalError` 的值是固定 `"内部错误"`，无 `%@` 格式化占位符，导致 `ExportError.internalError(msg)` 的关联值 `msg` 被丢弃 | 用户看到"内部错误"但无法知道具体错误详情，不利于排查问题 | 在 `error.internalError` 的各语言值中添加 `%@` 占位符（如 `"内部错误：%@"`），使 `trf` 能正确注入关联值 | 已修复 | 批次1 |
| 3 | 🔴 P0 | `Sources/Core/Base/Utils/ZipUtility.swift:35,44-46,61` | 崩溃（对齐违规） | `UnsafeRawPointer.load(fromByteOffset:as:)` 用于读取 ZIP 头的 UInt16/UInt32 字段（偏移 8/18/28/30 均非对齐），在 ARM64 上触发 `EXC_BREAKPOINT` 崩溃 | 任何调用 `readZipArchive` 解析真实 ZIP 文件的场景都会崩溃（如导入 ZIP 备份） | 改用 `loadUnaligned(fromByteOffset:as:)`（iOS 15+） | 已修复 | 批次1 |
| 9 | 🔴 P0 | `Sources/Core/Base/Utils/ZipUtility.swift:44-45` | 偏移错误（ZIP 头解析） | `fileNameLength` 读取偏移 28（实际是 extra field length 位置），`extraFieldLength` 读取偏移 30（越界到文件名区域）。ZIP 规范中 file name length 在偏移 26，extra field length 在偏移 28 | 解析任何 ZIP 都会得到错误的文件名长度（0 或 extra field 长度），导致文件名解析失败、数据偏移错误，最终返回 nil | 修正偏移：fileNameLength 用 26，extraFieldLength 用 28 | 已修复 | 批次1 |
| 4 | 🟢 P2 | `Sources/Core/System/Security/JailbreakDetector.swift:22` | 可测试性 | `private init` 阻止测试构造独立实例，只能用 shared 单例无法隔离状态 | 测试无法独立构造实例验证 init 逻辑 | `private init` → `init`（internal） | 已修复 | 批次1 |
| 5 | 🟡 P1 | `Sources/Core/System/Security/JailbreakDetector.swift:50-61` | 逻辑错误（模拟器误报） | `checkCommonJailbreakFiles()` 检测 `/bin/bash`、`/usr/sbin/sshd`、`/usr/bin/ssh` 等路径，但这些在 macOS 系统自带存在。iOS 模拟器运行在 macOS 上，导致 `isJailbroken()` 在模拟器上永远返回 true | 越狱检测在模拟器/开发环境下完全失效，开发者无法信任检测结果；可能影响依赖此检测的安全逻辑 | 移除 macOS 自带路径（`/bin/bash`、`/usr/sbin/sshd`、`/usr/bin/ssh`），只保留 iOS 专属越狱路径 | 已修复 | 批次1 |
| 6 | 🟢 P2 | `Sources/Core/System/Analytics/LocalAnalyticsService.swift:20` | 可测试性 | `private init` + 硬编码 logURL 阻止测试注入临时路径 | 测试写入真实日志路径，污染用户数据 | `private init` → `init(logURL:)` 可注入 | 已修复 | 批次1 |
| 7 | 🟢 P2 | `Sources/Core/System/Workflow/WorkflowService.swift:17,20` | 可测试性 | `private init` + `@Inject` 阻止测试注入 Mock 依赖 | 测试只能用 shared 单例，无法隔离 ReminderService | `private init` → `init(reminderService:)` 可注入 | 已修复 | 批次1 |
| 8 | 🟡 P1 | `Sources/Core/System/Workflow/WorkflowService.swift:46` | 逻辑缺陷 | 任务过滤用 `line.hasPrefix("-")` 会匹配 `- [x]`（已完成任务），导致已完成任务也被同步 | 已完成事项被重复同步到系统提醒，造成冗余提醒 | 在过滤条件中排除 `hasPrefix(CoreConstants.MarkdownSyntax.taskDone)` 和 `taskDoneUpper` | 已修复 | 批次1 |
| 10 | 🟡 P1 | `Sources/Infrastructure/Processors/Graph/GraphCommunityProcessor.swift:252-310` | 算法缺陷 | Louvain 社区检测在全连通三角形图（3 节点 3 边）上无法合并社区，每个节点保持独立社区。`calculateModularityGain` 公式只计算"加入目标社区的增益"，未减去"离开当前社区的损失"，导致净增益计算错误，`bestGain` 始终为 0 | 全连通的知识图谱节点无法被识别为同一社区，社区发现功能在小规模全连通子图上失效 | 修正为标准 Louvain 净增益公式：`ΔQ = gainTarget - lossCurrent`，同时计算 `k_i_in(C_target)` 和 `k_i_in(C_current)`，以及 `Σ_tot(C_target)` 和 `Σ_tot(C_current)`（均排除节点 i 自身） | 已修复 | 批次2 |
| 11 | 🟡 P1 | `Sources/Infrastructure/LLM/OnDeviceLLMService.swift:417-438` | L10n 红线违规 | `OnDeviceError.errorDescription` 使用硬编码字符串（`"Model_not_found"`、`"Model_not_loaded"`、`"Not_supported"`、`"Inference_failed"`、`"Compilation_failed"`），违反 L10n 强约束红线（禁止硬编码文本，必须通过 `L10n.模块.属性` 强类型访问） | 端侧 LLM 错误信息无法本地化，所有语言用户看到相同的英文下划线文本 | 在 `L10n+AI.swift` 的 `OnDevice.Error` 枚举补充 `modelNotFound`/`modelNotLoaded`/`notSupported` 属性，`errorDescription` 改用 `L10n.AI.OnDevice.Error.*`（`inferenceFailed(String)` 用 `"\(L10n...): \(msg)"` 拼接） | 已修复 | 批次2 |
| 12 | 🟡 P1 | `Sources/Localization/Extensions/L10n+Watch.swift:35` | 本地化 key 缺失 | `widgetCapture` 属性引用 key `watch.widget.title`，该 key 在 `Platform.xcstrings` 中不存在，运行时返回 `[MISSING: watch.widget.title@Platform]` | watchOS Widget 标题显示为 `[MISSING: watch.widget.title@Platform]`，用户看到错误占位符而非本地化标题 | 改用已存在的语义匹配 key `watch.widget.displayName`（"ZhiYu Capture"/"智宇采集"） | 已修复 | 批次5 |
| 13 | 🟡 P1 | `Sources/Features/Knowledge/NotebookHub/Model/NotebookThemeFactory.swift:16-45` | 非确定性 bug | `semanticPalettes` 是 `Dictionary<String, [String]>`，`for...where` 遍历顺序不确定（Swift Dictionary hash 种子随机化），导致多关键词匹配时"first match wins"语义无法保证。同一输入 "tech art" 不同运行可能返回 tech 配色或 art 配色 | 笔记本主题配色非确定性，同一笔记本名称在不同启动时可能显示不同配色，用户体验不一致 | 将 `semanticPalettes` 从 `Dictionary` 改为有序数组 `[(keyword: String, colors: [String])]`，保证遍历顺序确定 | 已修复 | 批次5 |

## 处理状态说明

- **待确认**：测试发现，待用户确认
- **已确认 → 已修复**：用户确认后已修复
- **已确认 → 预期行为不修**：用户确认是预期行为，不修
