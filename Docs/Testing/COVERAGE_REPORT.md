# 智宇 (ZhiYu) 代码覆盖率与测试质量报告

**更新日期**: 2026-11-27
**生成方式**: SPM 包用 `coverage-spm.py`（`swift test --enable-code-coverage` + `llvm-cov`）；主 App 用 xcodebuild + `analyze_coverage_gaps.py`

> ⚠️ 本报告数值由 `Tools/CI/coverage-spm.py` 实测填充（SPM 6 包语句覆盖），主 App 分支覆盖需先跑 `make test-unit` 生成 xcresult 后用 `analyze_coverage_gaps.py` 分析。
> 以下标准对齐 AGENTS.md 四大质量红线第 1 条。

---

## 1. 核心质量红线（SonarQube Quality Gate）

| 指标 | 红线要求 | 当前值 | 状态 |
| :--- | :--- | :--- | :--- |
| **语句/行覆盖率 (Line Coverage)** | ≥ 95.0%（SPM 包门禁 ≥ 90.0%） | SPM 6 包全量达标，加权 **93.37%**（8221/8805 行） | ✅ SPM 6/6 达标 |
| **分支覆盖率 (Branch Coverage)** | ≥ 90.0% | **SPM 不可测**（swiftc 不生成 branch mapping，见下注） | ⚠️ 需主 App xccov |
| **代码重复率 (Duplicated Lines %)** | < 3.0% | Swift 重复率 **0.8%**（jscpd 实测 1025/134326 行） | ✅ 达标 |

> **⚠️ 工具链约束（重要）**：SwiftPM 的 `swiftc` coverage mapping **不包含 branch 信息**（`coverage-spm.py` 注释明确「Swift 不生成 branch mapping，Branches 列恒为 0/0/-」）。因此 **SPM 6 包只能用 llvm-cov 测语句/行覆盖，无法测分支覆盖**。分支覆盖只能通过主 App（xcodebuild 测试）的 xccov 获得，用 `analyze_coverage_gaps.py` 分析（需先跑 `make test-unit` 生成 xcresult 到 `build/DerivedData-ios`）。

---

## 2. SPM 包语句覆盖率明细（实测，2026-11-27）

> 由 `make coverage-spm`（`swift test --enable-code-coverage` + `llvm-cov`）生成，全部 6 大本地包均突破 ≥ 90% 阈值。

| 包名 | 语句覆盖 | 函数覆盖 | 状态 | 备注 |
| :--- | :--- | :--- | :--- | :--- |
| **UFPCore** | **92.96%** (1757/1890) | 227/256 | ✅ | — |
| **UFPStorage** | **90.23%** (822/911) | 107/118 | ✅ | 补齐流式下载委托生命周期测试 |
| **UFPDesignSystem** | **93.62%** (3361/3590) | 419/484 | ✅ | 修复 Toast/Waveform/DotPattern/FlowLayout 等 6 项缺陷并补齐渲染与边界回归 |
| **ZhiYuDomain** | **97.04%** (1444/1488) | 208/224 | ✅ | 修复 Thinking/Markdown 5 项缺陷并补齐回归 |
| **ZhiYuAICore** | **90.26%** (825/914) | 119/120 | ✅ | 修复多模态索引/LiteRT/Prompt 沙箱 7 项缺陷，剩余未覆盖行集中于需真实权重文件的 C++ 推理路径 |
| **ZhiYuFeatures** | **100.00%** (12/12) | 6/6 | ✅ | — |
| **总体（加权）** | **93.37%** (8221/8805) | **1086/1208** | ✅ | **6/6 全部达标** |

> **说明**：全量测试坚持「以发现问题为目的、不为凑覆盖率写无断言空测试」原则，累计发现并闭环 215 项真实生产缺陷（见 `Docs/Testing/TEST_DRIVEN_FINDINGS.md`）。

---

## 3. 测试规模

| 维度 | 数值 | 备注 |
| :--- | :--- | :--- |
| **测试文件总数** | 807 | `Tests/` 目录下 Swift 测试文件（`make audit` 实测） |
| **SPM 包单测** | 6 个包 | `make test-spm-all`（UFPCore/Storage/DesignSystem/Domain/AICore/Features） |
| **主 App 单测** | 全量 | `make test-unit`（约 3 分钟） |
| **UI 测试** | 全量 | `make test-ui` |
| **快照测试** | pointfreeco/swift-snapshot-testing | `Tests/SnapshotTests/` |

---

## 4. 测试结构度量（CI 门禁）

`Tools/CI/audit-test-structure.py` 在 `make audit` 中强制校验 6 项指标：

| 指标 | 阈值 | 说明 |
| :--- | :--- | :--- |
| `directory_alignment_rate` | ≥ 0.95 | `Tests/Unit/` 子目录与架构层级/功能域对齐率 |
| `spm_test_coverage_ratio` | ≥ 0.80 | SPM 包测试用例占 SPM 相关测试总用例比例 |
| `test_source_file_ratio` | 0.5–1.5 | 测试文件与源文件比例 |
| `median_cases_per_file` | 5–20 | 每文件用例数中位数 |
| `oversized_file_ratio` | < 0.05 | 用例数 > 50 的文件比例 |
| `empty_file_ratio` | = 0.0 | 空测试文件比例（Mock/Helper 文件豁免） |

> **基线说明**：2026-09-07 重构前基线见 `test-structure-baseline.md`（4 项未达标）。
> 重构后目标值见 `TEST_CASES.md` 第 0 节。运行 `make audit` 获取最新度量值。

---

## 5. 混沌工程与异常模拟

在 `CloudChaosTests` 及 `PromptDefenseTests` 等模块中验证的异常容错：

1. **Prompt Injection 防御**：模拟 `<|im_start|>`、`System:` 等标记，均被本地 NLP 脱敏拦截
2. **大流量并发 OOM**：1000 个大文件并发读写，未触发内存溢出或死锁
3. **图谱孤岛与断电恢复**：`RAGOrchestrator` 中断后孤立节点修剪，图谱幂等性保护

---

## 5.5 主 App 语句+分支覆盖率实测基线（xcodebuild xccov）

> 数据来源：`make test-unit`（全量，skip 快照/性能类）→ `analyze_coverage_gaps.py`。这是**首次建立的主 App 分支覆盖基线**（SPM 无法测分支，见第 2 节工具链约束）。实测时间 2026-11-02。

| 模块（`Sources/`） | 语句覆盖 | 分支覆盖 |
| :--- | :---: | :---: |
| **主 App 合计** | **63.8%** | **61.5%** |
| Domain | 90.0% | 71.2% |
| Localization | 97.3% | 64.6% |
| Infrastructure | 91.3% | 65.4% |
| Core | 85.5% | 65.2% |
| Shared | 74.9% | 62.9% |
| App | 66.2% | 61.0% |
| Features | 59.6% | 59.3% |
| Platforms | 46.3% | 51.2% |

> 注：`SnapshotTesting` / `ZIPFoundation` 为第三方依赖源码，已统计但不计入主 App 业务合计。
> 分支覆盖严重不足主要集中于 Features（UI/状态机）与 Platforms；业务逻辑层（Domain/Infrastructure/Core）分支约 65–71%。
> 已补测 GraphCommunityProcessor 边界（孤立边/重复边/自环/孤立节点）4 例，分支 68.8%→69.1%，验证算法健壮、未发现缺陷。

---

## 6. 如何生成最新覆盖率数据

```bash
# SPM 6 包语句覆盖率（实测本报告数值）
source Config/.env.local && python3 Tools/CI/coverage-spm.py

# 主 App 语句+分支覆盖率（先跑单测生成 xcresult，再分析缺口）
make test-unit
python3 Tools/CI/analyze_coverage_gaps.py   # 需 xcresult 位于 build/DerivedData-ios 下

# 全量 SPM 单测 + 主 App 单元测试
make test-all

# SonarQube 全语言扫描（需配置 sonar-project.properties）
sonar-scanner -Dsonar.qualitygate.wait=true

# 测试结构度量
make audit
```

---

## 7. 历史数据归档

> 以下为 2026-05-29 旧版覆盖率数据（基于 xcodebuild coverage / slather），已被 SonarQube 全语言扫描取代，仅作历史参考。

<details>
<summary>📊 2026-05-29 旧版覆盖率明细（已过时，点击展开）</summary>

- 全工程整体行覆盖率：74.8%
- L1.5 领域层行覆盖率：87.2%（旧标准 85% 红线已达标）
- 测试用例总数：241 个
- Domain/Models：94.5% / 91.0%
- Domain/RAG：86.3% / 82.4%
- Domain/Services：85.1% / 80.2%
- Infrastructure/Storage：78.4% / 75.0%
- Infrastructure/LLM：76.2% / 72.8%
- Features (L2 UI)：58.9% / 51.5%

</details>

> **标准变更说明**：AGENTS.md 第 1 条红线已将覆盖率要求从 85% 提升至 95%（行覆盖）和 90%（分支覆盖），
> 并新增重复率 < 3% 要求。旧版数据不适用新标准。
