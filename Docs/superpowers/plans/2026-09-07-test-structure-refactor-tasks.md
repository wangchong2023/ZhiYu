# 测试结构重构 — 任务清单

> **来源计划**：`docs/superpowers/plans/2026-09-07-test-structure-refactor.md`
> **创建日期**：2026-09-07
> **状态约定**：`[ ]` 未开始 / `[~]` 进行中 / `[x]` 已完成 / `[!]` 阻塞

> **📋 状态说明（2026-09-25 更新）**:
> - 本任务清单中所有 37 项任务的状态标记仍为 `[ ]`（创建时基线状态）。
> - 根据 `TEST_CASES.md` 第 0 节和 `test-structure-baseline.md`，重构后 6 项度量指标的目标值已设定。
> - 运行 `make audit` 可获取最新实际度量值，验证重构是否已完成。
> - 如重构已完成但状态未更新，请运行 `python3 Tools/CI/audit-test-structure.py --verbose` 确认后更新本文件。

---

## Phase 1: 度量基线建立

| # | Task | 状态 | 优先级 | 验证方式 |
|---|------|------|--------|---------|
| 1 | 创建测试结构度量脚本 `audit-test-structure.py` | [ ] | high | `python3 Tools/CI/audit-test-structure.py --verbose` 输出 6 项指标 |
| 2 | 将度量脚本集成到 `make audit` 门禁 | [ ] | high | `make audit` 包含测试结构度量步骤 |

---

## Phase 2: 目录对齐迁移（机械移动）

> 每个 Task：迁移 → `make gen` → `make test-unit` → commit
> 迁移顺序：文件数从少到多

| # | Task | 文件数 | 迁移方向 | 状态 | 优先级 |
|---|------|--------|---------|------|--------|
| 3 | 迁移小目录（Graph/Insight/Dashboard/Subscription/Fuzz） | 9 | → Infrastructure/Features/Insight/Domain/Integration | [ ] | high |
| 4 | 迁移 Platform → Platforms | 25 | → Platforms（单复数合并） | [ ] | high |
| 5 | 迁移 Security → Core | 10 | → Core（对齐 Sources/Core/System/Security） | [ ] | high |
| 6 | 迁移 Plugins → Infrastructure + Features/System | 9 | → Infrastructure（8）+ Features/System（1） | [ ] | high |
| 7 | 迁移 Knowledge → Features/Knowledge | 20 | → Features/Knowledge | [ ] | high |
| 8 | 迁移 Processors → Infrastructure | 20 | → Infrastructure（19）+ SSRFGuard 待下沉（1） | [ ] | high |
| 9 | 迁移 System → Features/System + Infrastructure + Core + Platforms | 32 | → 4 个目录分散迁移 | [ ] | high |
| 10 | 迁移 Storage → Infrastructure + Domain + App + Platforms | 42 | → 4 个目录分散迁移 | [ ] | high |
| 11 | 迁移 AI → Features/AI + Infrastructure + Domain | 56 | → 3 个目录分散迁移（5 个 SPM 待下沉） | [ ] | high |
| 12 | 迁移 Services → 各对应目录 | 16 | → 6+ 个目录分散迁移（1 个 SPM 待下沉） | [ ] | high |
| 13 | 迁移 Base → Domain + Core + Platforms | 22 | → 3 个目录分散迁移（3 个 SPM 待下沉） | [ ] | high |

**Phase 2 完成标准**：`directory_alignment_rate` ≥ 95%

---

## Phase 3: SPM 测试下沉与去重

| # | Task | 文件数 | 下沉目标 | 状态 | 优先级 |
|---|------|--------|---------|------|--------|
| 14 | 下沉 UFPCore 重复测试 | 3 | → Packages/UFPCore/Tests/（MainActorBridge/SSRFGuard/ByteFormatter） | [ ] | medium |
| 15 | 下沉 ZhiYuAICore 重复测试 | 5 | → Packages/ZhiYuAICore/Tests/（JSONRepair/ContextReranker/PromptSecurity/MemoryEngine） | [ ] | medium |
| 16 | 下沉 UFPDesignSystem 重复测试 | 1 | → Packages/UFPDesignSystem/Tests/（DesignSystem） | [ ] | medium |
| 17 | 下沉 ServiceContainer 测试（可选） | 1 | → Packages/UFPCore/Tests/（纯单元测试部分） | [ ] | low |

**Phase 3 完成标准**：`spm_test_coverage_ratio` ≥ 80%

---

## Phase 4: 超大文件拆分（>50 用例 → ≤30 用例/文件）

> 每个 Task：按 MARK 分段 → 创建新文件 → 删除原文件 → `make gen` → `make test-unit` → commit

| # | Task | 原用例数 | 拆分后文件数 | 拆分主题 | 状态 | 优先级 |
|---|------|---------|------------|---------|------|--------|
| 18 | SecurityAndRerankerPureLogicTests | 98 | 3 | 越狱检测/沙箱/重排序 | [ ] | medium |
| 19 | DomainProtocolsSupplementTests | 89 | 2 | NoOpLLMServices/NoOpRepository | [ ] | medium |
| 20 | ModelLabManagerDeepTests | 88 | 3 | UseCaseType/ParamTips/Simulation | [ ] | medium |
| 21 | PluginSandboxAndMarketTests | 80 | 3 | GatewayAudit/Manifest/MarketService | [ ] | medium |
| 22 | SynthesisStoreDeepTests | 80 | 3 | Type属性/正常路径/失败路径 | [ ] | medium |
| 23 | AIWorkflowStoreDeepTests | 77 | 3 | State/LintHealth/Suggestions | [ ] | medium |
| 24 | GlobalModelManagerDeepTests | 74 | 3 | Persistence/Routing/Download | [ ] | medium |
| 25 | InfrastructureConstantsAndModelsTests | 71 | 3 | LLMConstants/PluginConstants/Models | [ ] | medium |
| 26 | CoreConstantsAndUtilitiesTests | 71 | 3 | Constants/DocumentFormat/Utility | [ ] | medium |
| 27 | SystemStatsCoordinatorDeepTests | 66 | 3 | Load/Fetch/Cleanup | [ ] | medium |
| 28 | LLMAuxiliarySupplementTests | 64 | 4 | PromptService/MemoryEngine/Config/LLMService | [ ] | medium |
| 29 | AISynthesisServiceDeepTests | 64 | 3 | Summarize/Generate/Facade | [ ] | medium |
| 30 | StorageSupplementTests | 58 | 3 | Services/VaultStorage/SQLiteStore | [ ] | medium |
| 31 | ProcessorsSupplementTests | 57 | 4 | ImageExtractor/DocExtraction/GraphLayout/TextChunker | [ ] | medium |
| 32 | IngestImportDeepTests | 56 | 3 | FileImport/RawContent/URLDocument | [ ] | medium |
| 33 | AuthServiceDeepTests | 55 | 3 | StateGuest/Login/ProfilePurchase | [ ] | medium |
| 34 | ZhiYuServiceTests | 52 | 10 | 按服务完全拆分（聚合测试） | [ ] | medium |
| 35 | FrontmatterParserTests | 51 | 3 | SplitParse/ModelsCodable/Integration | [ ] | medium |

**Phase 4 完成标准**：`oversized_file_ratio` < 5%

---

## Phase 5: 最终验证与文档更新

| # | Task | 状态 | 优先级 | 验证方式 |
|---|------|------|--------|---------|
| 36 | 运行全量测试 + SPM 测试 + audit 验证 | [ ] | high | `make test` + `make test-spm-all` + `make audit` 全部通过 |
| 37 | 更新文档（UNIT_TEST_GUIDE / TEST_CASES / AGENTS / 度量说明） | [ ] | medium | 文档反映新结构 |

---

## 度量指标追踪

| 指标 | 基线值 | 目标值 | 当前进度 |
|------|--------|--------|---------|
| `directory_alignment_rate` | ~53% (8/15) | ≥ 95% | 基线 |
| `median_cases_per_file` | 6 | 5-20 | ✅ 已达标 |
| `oversized_file_ratio` | 7.3% (47/643) | < 5% | 基线 |
| `empty_file_ratio` | 0.9% (6/643) | 0% | 基线 |
| `spm_test_coverage_ratio` | ~33% | ≥ 80% | 基线 |
| `test_source_file_ratio` | 0.97 | 0.5-1.5 | ✅ 已达标 |

---

## 风险与缓解

| 风险 | 缓解措施 |
|------|---------|
| 迁移后测试文件名冲突 | 迁移前检查目标目录是否已有同名文件 |
| 分散迁移分类错误 | 每个文件通过 `@testable import` + 被测类型位置双重确认 |
| SPM 下沉后用例丢失 | 合并前逐用例对比，主 App 独有用例追加到 SPM 包 |
| 拆分后 import 缺失 | 新文件复制原文件全部 import 声明 |
| 全量测试耗时过长 | Phase 2-4 每个 Task 用 `make test-unit`（~3min），仅 Phase 5 用 `make test`（~70min） |
