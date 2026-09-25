# 测试结构度量基线

> **度量日期**：2026-09-07
> **度量脚本**：`Tools/CI/audit-test-structure.py`
> **分支**：`test-structure-refactor`（重构前基线）
> **说明**：本文件记录测试结构重构前的基线值，用于与重构后目标值对比。重构后目标值见 `TEST_CASES.md` 第 0 节。

---

## 基线值

| 指标 | 基线值 | 目标值 | 达标 | 备注 |
|------|--------|--------|------|------|
| `directory_alignment_rate` | 0.3478 (8/23) | ≥ 0.95 | ❌ | 15 个子目录无对应 Sources/ 目录 |
| `median_cases_per_file` | 6 | 5-20 | ✅ | 已达标 |
| `oversized_file_ratio` | 0.0747 (48/643) | < 0.05 | ❌ | 48 个文件 > 30 用例 |
| `empty_file_ratio` | 0.0093 (6/643) | 0 | ❌ | 6 个空文件 |
| `spm_test_coverage_ratio` | 0.7876 (408/518) | ≥ 0.80 | ❌ | 接近目标，需下沉少量测试 |
| `test_source_file_ratio` | 0.8461 (643/760) | 0.5-1.5 | ✅ | 已达标 |

---

## 未对齐目录清单（15 个）

| 目录 | 文件数 | 迁移目标 |
|------|--------|---------|
| AI | 56 | Features/AI + Infrastructure + Domain |
| Base | 22 | Domain + Core + Platforms |
| Dashboard | 3 | Insight |
| Fuzz | 1 | Integration |
| Graph | 2 | Infrastructure |
| Insight | 2 | Insight |
| Knowledge | 20 | Features/Knowledge |
| Platform | 25 | Platforms（单复数合并） |
| Plugins | 9 | Infrastructure + Features/System |
| Processors | 20 | Infrastructure |
| Security | 10 | Core |
| Services | 16 | 各对应目录 |
| Storage | 42 | Infrastructure + Domain + App + Platforms |
| Subscription | 1 | Domain |
| System | 32 | Features/System + Infrastructure + Core + Platforms |

---

## 超大文件清单（48 个，用例数 > 30）

> 完整清单见 `python3 Tools/CI/audit-test-structure.py --json` 输出

Top 10 最大文件：
1. SecurityAndRerankerPureLogicTests — 98 用例
2. DomainProtocolsSupplementTests — 89 用例
3. ModelLabManagerDeepTests — 88 用例
4. PluginSandboxAndMarketTests — 80 用例
5. SynthesisStoreDeepTests — 80 用例
6. AIWorkflowStoreDeepTests — 77 用例
7. GlobalModelManagerDeepTests — 74 用例
8. InfrastructureConstantsAndModelsTests — 71 用例
9. CoreConstantsAndUtilitiesTests — 71 用例
10. SystemStatsCoordinatorDeepTests — 66 用例

---

## 空文件清单（6 个）

> 用例数 = 0 的测试文件，需在 Phase 2/3 迁移过程中清理或补充用例

---

## 重构目标

通过 37 个 Task 的执行，将 4 项不达标指标全部提升至目标值：
- `directory_alignment_rate`: 0.3478 → ≥ 0.95（Phase 2 目录对齐迁移）
- `oversized_file_ratio`: 0.0747 → < 0.05（Phase 4 超大文件拆分）
- `empty_file_ratio`: 0.0093 → 0（Phase 2/3 清理空文件）
- `spm_test_coverage_ratio`: 0.7876 → ≥ 0.80（Phase 3 SPM 测试下沉）
