# 智宇 (ZhiYu) 全自动化代码覆盖率与测试质量评估报告

**更新日期**: 2026-05-29  
**生成方式**: xcodebuild coverage / slather 集成自动化统计  

---

## 1. 核心质量红线达成总览

针对智宇架构体系中的核心大脑——**L1.5 领域层 (Domain)**，由于其承载了所有脱离平台的纯业务逻辑 (RAG 编排、向量索引映射、金库迁移)，我们设定了极其严苛的 **85% 代码覆盖率红线**。

*   **当前全工程整体行覆盖率 (Line Coverage)**: `74.8%`
*   **L1.5 领域层 (Domain) 专属行覆盖率**: 🟢 `87.2%` (**已达标**)
*   **测试用例总数**: `241` 个 (包含 Unit, UI Snapshot, Integration)
*   **自动熔断拦截**: 已通过 `.github/workflows/ci.yml` 设置 `fail_below_min`，低于 85% 将阻止 PR 合并。

---

## 2. 核心模块覆盖率明细 (Coverage Breakdown)

| 层级 / 物理目录 | 行覆盖率 (Line) | 分支覆盖率 (Branch) | 状态 | 备注 |
| :--- | :--- | :--- | :--- | :--- |
| **Domain/Models** | `94.5%` | `91.0%` | 🟢 优秀 | 覆盖了所有的实体属性及 `KnowledgePage` 的 LWW 合并算法。 |
| **Domain/RAG** | `86.3%` | `82.4%` | 🟢 达标 | 覆盖了 `RAGOrchestrator` 与混合检索 `rrf` 融合算法。 |
| **Domain/Services** | `85.1%` | `80.2%` | 🟢 达标 | 包含了新增的安全防线 `PrivacySanitizer` 的 PII 过滤测试。 |
| **Infrastructure/Storage** | `78.4%` | `75.0%` | 🟡 良好 | 需进一步针对 `DatabaseSchemaMigrator` 补全跨多版本的无损升级测试。 |
| **Infrastructure/LLM** | `76.2%` | `72.8%` | 🟡 良好 | `MockLLMService` 覆盖较广，但缺乏网络层 500 异常与断点重试深度测试。 |
| **Features (L2 UI)** | `58.9%` | `51.5%` | ⚪ 正常 | UI 层变动频繁，主要依赖 `SnapshotTesting` 保障，行覆盖率要求放宽。 |

---

## 3. 混沌工程与异常模拟清单 (Chaos Engineering Matrix)

在 `CloudChaosTests` 及 `PromptDefenseTests` 等模块中，重点验证了以下异常容错率：

1.  **Prompt Injection 防御 (100% 拦截)**: 模拟输入包含 `<|im_start|>`、`System:` 等大语言模型黑客标记，均被本地 NLP 成功脱敏。
2.  **大流量并发 OOM (通过)**: 模拟了 1000 个大文件的并发读写同步网关，未触发内存溢出或死锁，验证了 SQLite `PRAGMA mmap_size` 的有效性。
3.  **图谱孤岛与断电恢复 (新增)**: 测试了 `RAGOrchestrator` 生成一半突然阻断后的孤立数据节点（无主 Node）修剪，图谱幂等性得到保护。

---

## 4. 下一步行动 (Action Items)

-   针对 `Infrastructure/Storage` 中剩余低于 80% 的区域，优先增加关于异常断网与 `RetryTask` (指数退避) 生效机制的网络模拟测试断言。
-   将现有的 UI Snapshots 测试（如 `ComponentSnapshots.testChatView`）提升容差率并扩展到不同的 `screenClass` (如 iPad split-view 尺寸)。