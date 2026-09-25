# 智宇 (ZhiYu) 代码覆盖率与测试质量报告

**更新日期**: 2026-09-25
**生成方式**: SonarQube 全语言扫描（`sonar-scanner`）+ `make test-all`

> ⚠️ 本报告为框架性文档，具体覆盖率数值需运行 `make test-all` + SonarQube 扫描后填入。
> 以下标准对齐 AGENTS.md 四大质量红线第 1 条。

---

## 1. 核心质量红线（SonarQube Quality Gate）

| 指标 | 红线要求 | 当前值 | 状态 |
| :--- | :--- | :--- | :--- |
| **语句/行覆盖率 (Line Coverage)** | ≥ 95.0% | _待填入_ | ⏳ |
| **分支覆盖率 (Branch Coverage)** | ≥ 90.0% | _待填入_ | ⏳ |
| **代码重复率 (Duplicated Lines %)** | < 3.0% | _待填入_ | ⏳ |

> 触发方式：CI/CD 流水线中 `sonar-scanner -Dsonar.qualitygate.wait=true` 执行卡控与阻断。

---

## 2. 测试规模

| 维度 | 数值 | 备注 |
| :--- | :--- | :--- |
| **测试文件总数** | ~768 | `Tests/` 目录下 Swift 测试文件 |
| **SPM 包单测** | 6 个包 | `make test-spm-all`（UFPCore/Storage/DesignSystem/Domain/AICore/Features） |
| **主 App 单测** | 全量 | `make test-unit`（约 3 分钟） |
| **UI 测试** | 全量 | `make test-ui` |
| **快照测试** | pointfreeco/swift-snapshot-testing | `Tests/SnapshotTests/` |

---

## 3. 测试结构度量（CI 门禁）

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

## 4. 混沌工程与异常模拟

在 `CloudChaosTests` 及 `PromptDefenseTests` 等模块中验证的异常容错：

1. **Prompt Injection 防御**：模拟 `<|im_start|>`、`System:` 等标记，均被本地 NLP 脱敏拦截
2. **大流量并发 OOM**：1000 个大文件并发读写，未触发内存溢出或死锁
3. **图谱孤岛与断电恢复**：`RAGOrchestrator` 中断后孤立节点修剪，图谱幂等性保护

---

## 5. 如何生成最新覆盖率数据

```bash
# 全量 SPM 单测 + 主 App 单元测试
make test-all

# SonarQube 全语言扫描（需配置 sonar-project.properties）
sonar-scanner -Dsonar.qualitygate.wait=true

# 测试结构度量
make audit
```

---

## 6. 历史数据归档

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
