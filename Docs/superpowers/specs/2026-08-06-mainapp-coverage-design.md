# 主 App 非 View 纯逻辑层测试覆盖提升

> **起始日期**：2026-08-06
> **状态**：设计已批准，待编写实现计划
> **范围**：主 App（Sources/）非 View 纯逻辑层单元测试
> **目标**：全 App 覆盖率 24.80% → ~34-35%（为后续 View 快照测试规格奠基）

---

## 1. 背景与动机

### 1.1 当前基线

全 App 覆盖率 **24.80%**（13656/55072 行可执行代码），距 SonarQube 95% 全语言门禁差 ~70 个百分点 / ~38500 行。

各层分布：

| 层 | 覆盖率 | 可执行行 | 0%文件数 | 0%行数 | 备注 |
|----|--------|---------|---------|--------|------|
| Domain | 95.10% | 1675 | 2 | 10 | ✅ 已达标 |
| Core | 58.17% | 2161 | 19 | 440 | 工具/扩展/服务 |
| Infrastructure | 52.56% | 10641 | 24 | 1810 | LLM/Storage/Processors |
| App | 28.34% | 2311 | 8 | 992 | 多为 Scene/View |
| Localization | 16.65% | 2577 | 15 | 225 | L10n 扩展 |
| Shared | 14.26% | 5394 | 58 | 3521 | UIComponents 为主 |
| Features | 11.08% | 30313 | 146 | 20740 | 最大瓶颈，多为 View |

### 1.2 范围界定

本次规格聚焦"非 View 纯逻辑层"单元测试（~5409 行 0% + 部分低覆盖文件）。View 层（~20740 行 0%）需快照测试，作为下一个独立规格。

**判定规则**：文件中可执行代码以业务逻辑/算法/数据变换为主（即使 import SwiftUI 或有少量 UI 回调）就纳入测试；纯 SwiftUI 视图体（`var body: some View`）为主的文件排除。ViewModel 纳入（测状态变换逻辑），View 排除。

### 1.3 工作原则

延续 UFPCore 测试驱动工作模式：
- **混合策略**：核心业务逻辑用问题驱动深度测试（等价类/边界值/决策表/状态转换/错误猜测）；纯工具/扩展/常量/Stub 用轻量补盲
- **问题记录**：发现问题记录到统一 findings 表格（序号/描述/黑盒影响/严重程度/修改方案/状态）
- **阶段修复**：每批次末暂停测试，统一确认 findings，集中修复，重测验证

---

## 2. 方案选择

### 2.1 攻击顺序：方案 1（按 ROI 从高到低）

按 Core → Infrastructure → Features非View → Shared非UI → Localization 分批，每批 ROI 递减但确定性递增。

**选择理由**：
1. Core 批（440 行，纯逻辑，无外部依赖）是验证混合策略的最佳试验田
2. 每批独立 commit，失败不阻塞，符合分批验证原则
3. 难文件（OnDeviceLLMService 310 行、StoreKitService 111 行等强依赖）后置到 Infrastructure/Features 批，届时方法论已成熟

### 2.2 否决方案

- **方案 2（按体量从大到小）**：Infrastructure 首批即遇 OnDeviceLLMService 等难测文件，方法论未验证就攻难点，风险高
- **方案 3（按依赖深度从浅到深）**：Localization 首批仅 225 行，覆盖率拉动 <0.5%，声势不足

---

## 3. 批次范围与目标

### 3.1 批次 1 — Core（440 行 0% → 目标 95%）

**目标文件**：
- 纯工具/扩展：`ZipUtility`(96)、`Date+Extensions`(31)、`Date+App`(5)、`String+PhoneNumber`(4)
- 服务：`WorkflowService`(76)、`JailbreakDetector`(50)、`LocalAnalyticsService`(43)、`RetryTask`(32)、`AudioSplitter`(19)
- 常量/协议/Stub：`LogAction`(34)、`ExportServiceProtocol`(10)、`StoreCapabilities`(8)、`Unsupported*Service`(共~30)、`Stub*Service`(共~12)

**问题驱动重点**：`ZipUtility`（压缩解压边界）、`JailbreakDetector`（安全检测绕过）、`RetryTask`（重试退避逻辑）、`WorkflowService`（工作流状态机）

**预期全 App 覆盖率**：~25.6%

### 3.2 批次 2 — Infrastructure（1810 行 0% → 目标 85%）

**目标文件**：
- LLM：`OnDeviceLLMService`(310)、`ChatLLMService`(131)、`InferenceParametersStore`(61)、`LLMAdapters`(54)
- Processors：`GraphCommunityProcessor`(219)、`PPTXProcessor`(154)、`DocxProcessor`(41)、`ExcelProcessor`(41)
- Storage：`DemoImageBuilder`(238)、`DemoPDFBuilder`(195)、`VaultStorageService`(51)、`FileSystemSyncService`(37)
- 其他：`PerformanceBenchmarker`(48)、`PluginSandboxError`(35)

**问题驱动重点**：`OnDeviceLLMService`（模型加载/推理失败处理）、`GraphCommunityProcessor`（社区检测算法）、`PPTXProcessor`/`DocxProcessor`（文档解析边界）

**Mock 需求**：`MockURLSession`、`MockFileSystem`、`MockModelLoader`

**预期全 App 覆盖率**：~28.9%

### 3.3 批次 3 — Features非View（1168 行 0% → 目标 85%）

**目标文件**：
- Service：`KnowledgeInsightService`(186)、`StoreKitService`(111)、`MedalService`(80)、`VaultDataCoordinator`(102)
- Coordinator/Handler：`IngestURLHandler`(139)、`IngestFileHandler`(134)、`DashboardCoordinator`(71)
- ViewModel/Model：`GraphViewModel`(70)、`ParameterPreset`(30)、`NotebookThemeFactory`(23)、`SystemStatsModels`(19)、`MediaStore`(42)

**问题驱动重点**：`IngestURLHandler`/`IngestFileHandler`（URL/文件导入边界）、`KnowledgeInsightService`（洞察计算逻辑）、`StoreKitService`（订阅状态机）

**预期全 App 覆盖率**：~31.0%

### 3.4 批次 4 — Shared非UI（~1716 行 0% → 目标 70%）

**目标文件**（从 UIComponents 中提取非 body 逻辑）：
- `AppFeedback`(133)、`TooltipManager`(50)、`DownloadProgressRing`(118，进度计算)、`AIRainbowGlowBadge`(209，动画状态)
- 纯逻辑：`DesignModifiers`(53，token 映射)

**问题驱动重点**：`AppFeedback`（反馈状态机）、`TooltipManager`（生命周期管理）

**注**：此批"主要代码"判定成本高，需逐文件确认非 body 逻辑占比

**预期全 App 覆盖率**：~34.1%

### 3.5 批次 5 — Localization（225 行 0% → 目标 95%）

**目标文件**：15 个 `L10n+XXX.swift` 扩展（Creation/Shortcuts/Tag/Insight/Watch/Widget/Schema/Action/Accessibility/Transfer/Log/Platform/Workflow/Coachmark/Reminder）

**测试方法**：轻量补盲，验证 key 存在性 + 返回值非空。纯映射，预期无问题。

**预期全 App 覆盖率**：~34.5%

---

## 4. 测试方法论

### 4.1 问题驱动测试方法（核心业务逻辑）

| 方法 | 适用场景 | 示例 |
|------|---------|------|
| 等价类划分 | 输入域划分 | `ZipUtility`：有效 zip / 损坏 zip / 空 zip / 超大 zip |
| 边界值分析 | 边界点 + 两侧 | `RetryTask`：maxRetries=0/1/N、退避间隔上下限 |
| 决策表 | 多条件组合 | `JailbreakDetector`：越狱设备+调试器+代理+文件系统 |
| 状态转换 | 状态机 | `StoreKitService`：未购买→试用→已订阅→过期→续订 |
| 错误猜测 | 易错点 | `IngestURLHandler`：恶意 URL、超长 URL、非 http(s) scheme |

### 4.2 轻量补盲测试方法（纯工具/扩展/常量/Stub）

- 调用每个公开方法/属性一次，验证返回值类型与基本正确性
- 常量/枚举：验证值唯一性、非空
- Stub：验证返回 unsupported 行为正确（如 `UnsupportedExportService` 抛错或返回空）
- 不追求分支覆盖，只求行覆盖

---

## 5. Mock 策略

### 5.1 扩展现有 Mock 模式

- 新增 Mock 集中放 `Tests/Shared/TestMocks.swift`（扩展现有文件）或按域放 `Tests/Unit/<域>/Mock*.swift`
- 命名：`Mock<被Mock对象>`（如 `MockURLSession`、`MockModelLoader`、`MockStoreKit`、`MockFileSystem`）
- 协议优先：若被测代码依赖具体类，先抽协议再 Mock（仅测试需要时抽，不预先重构）
- 外部资源 Mock：URLSession（网络）、FileManager（文件系统）、Bundle（资源）、ProcessInfo（环境）

### 5.2 测试文件组织

- 路径：`Tests/Unit/<域>/<被测文件名>Tests.swift`（如 `Tests/Unit/Core/ZipUtilityTests.swift`）
- 命名：`<被测类型>Tests`（与现有 `AppStoreStorageTests` 一致）
- 文件头：遵循 `file-header-template.md`（系统层级 + 核心职责）
- 一个被测文件可对应多个测试文件（按方法/场景拆分，避免单文件过大）

---

## 6. 阶段修复机制

### 6.1 阶段修复流程（每批次末）

1. **暂停测试编写** — 批次测试编写完成且全绿后，停止新增测试
2. **汇总 findings** — 整理本批次 `Docs/Audit/2026-08-06-mainapp-test-findings.md` 中本批次的新增条目
3. **用户确认** — 汇报本批次发现的问题清单（序号/描述/黑盒影响/严重程度/修改方案），逐条确认：
   - `已确认 → 已修复`：按修改方案修复
   - `已确认 → 预期行为不修`：记录原因，不修
   - `待确认`：存疑问题，讨论后决定
4. **集中修复** — 对所有"已确认→已修复"问题，一次性修改源码
5. **重测验证** — `make test` 确认修复未引入回归 + 测试全绿
6. **更新 findings** — 表格状态字段更新为 `已修复`/`预期行为不修`
7. **commit** — 测试 + 修复一起提交
8. **进入下一批次**

### 6.2 findings 表格

文件：`Docs/Audit/2026-08-06-mainapp-test-findings.md`

结构：

| 字段 | 说明 |
|------|------|
| 序号 | 全局递增（跨批次连续） |
| 严重程度 | 🔴 P0 / 🟡 P1 / 🟢 P2 |
| 文件:行号 | 问题定位 |
| 问题类型 | 死代码/错误假设/不一致行为/边界缺陷/安全漏洞等 |
| 问题描述 | 根因分析 |
| 黑盒影响 | 对用户/业务的影响 |
| 修改方案 | 修复思路 |
| 处理状态 | 待确认 → 已确认 → 已修复 / 预期行为不修 |
| 批次 | Core/Infrastructure/Features非View/Shared非UI/Localization |

### 6.3 严重程度判定标准

- 🔴 **P0**：数据损坏/丢失、崩溃、安全漏洞、资金损失（订阅/支付）
- 🟡 **P1**：逻辑错误、行为不一致、边界处理缺陷、错误处理缺失
- 🟢 **P2**：健壮性不足、维护负担、死代码、命名/注释问题

### 6.4 跨批次问题处理

若某批次发现的问题涉及其他批次范围的代码，记录时标注"跨批次"，在对应批次修复。

---

## 7. 验证方式

### 7.1 编写中验证

针对性跑单个测试类（iOS Simulator，与 `make test` 一致）：

```bash
xcodebuild test -only-testing:ZhiYuTests/<测试类> \
  -project ZhiYu.xcodeproj -scheme ZhiYu \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -derivedDataPath build/DerivedData-ios \
  -disableAutomaticPackageResolution
```

### 7.2 批次末验证

`make test` 全量验证（后台运行 + 日志轮询，因耗时极长）。

### 7.3 阶段修复后验证

重跑 `make test` 确认修复未引入回归 + 测试全绿。

---

## 8. 提交规范

每批次一个 commit，格式：

```
test(<批次域>): <批次描述> + 修复 N 项测试驱动发现的问题

<批次范围说明>

发现问题 #<起始>-#<结束>:
- #<N> (P0/P1/P2): <一句话描述> — <修复/不修>

新增 X 个测试文件 Y 个用例，总计 Z 个测试 0 失败
pre-push 13 项门禁全通过
```

---

## 9. 预期终态

| 层 | 当前 | 目标 | 备注 |
|----|------|------|------|
| Domain | 95.10% | 95% | 维持 |
| Core | 58.17% | 95% | 批次 1 |
| Infrastructure | 52.56% | 85% | 批次 2 |
| Features非View | 11.08% | 85% | 批次 3（仅非 View 部分） |
| Shared非UI | 14.26% | 70% | 批次 4（仅非 UI 部分） |
| Localization | 16.65% | 95% | 批次 5 |
| **全 App** | **24.80%** | **~34-35%** | View 层快照测试作为下一规格 |

---

## 10. 后续规格（不在本次范围）

- **View 层快照测试**：~20740 行 0% SwiftUI View，使用 `swift-snapshot-testing`（已有基础设施）
- **主 App 覆盖率 35% → 95%**：结合 View 快照测试 + 剩余低覆盖文件补盲
