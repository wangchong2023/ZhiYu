# UFPStorage 下沉设计：GRDB 存储引擎分层重构

> **设计日期**: 2026-10-11
> **来源**: `Docs/superpowers/plans/2026-10-11-common-capability-extraction.md` Task A2.1（协议层重构后再全量下沉，USER 确认）
> **方法论**: superpowers（brainstorming → 设计 → 实施）
> **目标**: 将 GRDB 物理引擎（DatabaseManager + DatabaseSchemaMigrator + SQLiteStore）完整下沉 UFPStorage，消除 SQLiteStore 对 Domain/App 层的反向依赖，UFPStorage 成为可复用的通用存储底座
> **方案**: 引擎层 + 业务装配层拆分（协议层重构，USER 确认）

---

## 1. 背景与问题

### 1.1 现状

`UFPStorage` SPM 包已建立骨架：`GRDBReexport.swift`（re-export GRDB）+ `StorageConstants.swift`（纯通用常量），GRDB 依赖已配置。App 层 `Sources/Infrastructure/Storage/` 持有三个核心存储引擎：

| 文件 | 行数 | 当前层级 | 说明 |
|------|------|---------|------|
| `Persistence/DatabaseManager.swift` | 487 | App L1 | 数据库中枢，建库/连接管理/多库热切换/降级，**17 处 App Logger 调用** |
| `Persistence/DatabaseSchemaMigrator.swift` | 428 | App L1 | Schema 迁移执行器，20 处 GRDB 引用 |
| `Engine/SQLiteStore.swift` | 374 | App L1 | `public actor SQLiteStore: AnyPageStoreCapabilities`，装配各 Repository |

### 1.2 问题：SQLiteStore 深度耦合 Domain/App 层

`SQLiteStore` 是 actor，作为**业务装配层**，依赖：

- **Domain(L1.5) 协议**：`AnyPageStoreCapabilities`（= `AnyPageStore & VectorIndexableStore`）、`KnowledgeRepository`、`VectorRepository`、`RAGGovernanceRepository`
- **App(L1) Repository 实现**：`KnowledgePageRepository`、`VectorDataRepository`、`RAGGovernanceSQLiteStore`
- **App Logger**（`DatabaseManager` 17 处 `Logger.shared.*`）

**核心矛盾**：若把 `SQLiteStore` 整体下沉到 UFPStorage(L1)，则 UFPStorage 必须引用 Domain 协议（L1.5）与 App Repository（L1）——形成 **L1 → L1.5 / L1 同层** 的非法反向依赖，严重违反 L0-L3 分层红线（`LAYERING_L0_L3.md` 8 条红线）。

### 1.3 协议下沉的深层障碍

Domain 协议 `AnyPageStoreCapabilities`/`KnowledgeRepository`/`VectorRepository`/`RAGGovernanceRepository` 引用**业务领域模型**：

- `KnowledgePage`（`Sources/Domain/Models/KnowledgePage.swift`）
- `PageChunk`、`RAGEvaluation`、`AverageRAGScores`、`TokenStats` 等

若将协议整体下沉到 UFPStorage，这些业务模型也必须下沉——把通用存储底座污染成业务库，违背 UFPStorage「与业务完全无关」的设计初衷（见 `StorageConstants.swift` 注释）。

---

## 2. 目标架构（分层重构终态）

核心思路：**把 SQLiteStore 拆成两层**——纯通用引擎下沉，业务契约与模型留在上层。

```
┌────────────────────────────────────────────────────────────────┐
│  L1.5 Domain（ZhiYuDomain）                                      │
│  AnyPageStoreCapabilities / KnowledgeRepository / ...           │
│  KnowledgePage / PageChunk / RAGEvaluation（业务模型）           │
│      ▲                                                           │
│  L1   App（ZhiYu）—— 业务装配层                                   │
│  SQLiteStore（薄 actor）：实现 Domain 协议，注入 App Repository  │
│  KnowledgePageRepository / VectorDataRepository / ...           │
│      ▲ 依赖通用引擎                                              │
│  L1   UFPStorage（通用存储底座，与业务完全无关）                  │
│  DatabaseManager / DatabaseSchemaMigrator / GenericSQLiteEngine │
│  GRDBReexport / StorageConstants                                │
└────────────────────────────────────────────────────────────────┘
```

**关键原则**：
1. **UFPStorage 只含通用能力**，零业务协议/模型引用，零 App 层依赖
2. **DatabaseManager + DatabaseSchemaMigrator** 纯 GRDB 物理引擎，无业务耦合，**直接下沉**（唯一需处理：Logger 适配）
3. **SQLiteStore 不下沉为整体**，拆为「通用 GRDB 引擎骨架（入 UFPStorage）+ 业务装配（留 App 层）」

---

## 3. 方案分解

### 3.1 引擎层下沉（纯物理，无协议障碍）

`DatabaseManager` + `DatabaseSchemaMigrator` 迁移到 `Packages/UFPStorage/Sources/UFPStorage/Engine/`：

| 迁移目标 | 内容 | 适配点 |
|---------|------|--------|
| `Engine/DatabaseManager.swift` | 建库/连接池/WAL/多库热切换/降级 | `Logger.shared`(17处) → `UFPCore.MinimalLogger`；`TestStateResettable`(UFPCore已有) |
| `Engine/DatabaseSchemaMigrator.swift` | Schema 迁移 | 纯 GRDB，无 App 依赖 |

- **Logger 适配**：App `Logger.error(_:error:)` 带 error 参数，UFPCore `MinimalLogger.error(_:)` 无 error 参数——把 error 拼进 message（复用 A1.1/A1.4 经验）
- **SQL 资源**：`global_schema.sql` / `init_schema.sql` 迁入 UFPStorage，需确认是否含业务表（若含，拆分通用表 vs 业务表）
- **App 层**：`Sources/Infrastructure/Storage/Persistence/DatabaseManager.swift` / `DatabaseSchemaMigrator.swift` 改 typealias 兼容层，`StorageModuleRegistrar` 引用同步

### 3.2 SQLiteStore 拆分（协议层重构，USER 确认的方向）

SQLiteStore 拆为两层，**目标是把"通用 CRUD/事务/检索骨架"下沉**：

**A. UFPStorage 新增通用引擎骨架**（无业务模型依赖）：
- `GenericSQLiteEngine`（或 `Engine/GRDBStore.swift`）：基于 GRDB 的**泛型** CRUD/事务/查询封装，通过 Codable 泛型操作，不引用任何业务类型
- `StorageConstants` 扩展：事务、批量、分页等通用常量（复用现有 `defaultBatchInsertLimit`/`defaultPageLimit`）

**B. App 层 SQLiteStore 改为薄装配层**：
- 保留 actor，conform `AnyPageStoreCapabilities`（Domain 协议，位置不变）
- 内部改为**基于 UFPStorage 通用引擎**实现，而非直接操作 GRDB
- 各业务 Repository（`KnowledgePageRepository` 等）继续留 App 层，可基于通用引擎重构（后续任务 C 阶段可再收敛）

**拆分收益**：
- UFPStorage 获得**无业务耦合**的可复用存储能力（任何 App 可用）
- 业务协议/模型/Repository 留在 Domain/App，分层方向保持正确
- SQLiteStore 依赖从「直接 GRDB」收敛为「依赖 UFPStorage 通用引擎」

> ⚠️ **注意**：`AnyPageStoreCapabilities` 等协议**不物理下沉**到 UFPStorage（因引用业务模型）。协议重构的本质是：**把 SQLiteStore 的通用实现下沉，业务契约留在原地**——避免为下沉而强制搬移业务模型。

### 3.3 分层影响与红线校验

| 红线 | 校验 |
|------|------|
| L0-L3 单向依赖 | ✅ UFPStorage 只依赖 UFPCore + GRDB，零业务引用 |
| Domain 不导入 UI 框架 | ✅ 不受影响 |
| UFPStorage 与业务无关 | ✅ 通用引擎泛型化，无业务模型 |

---

## 4. 实施步骤

> 本设计文档化后，A2.1 按其执行。分阶段，每阶段验证。

- [ ] **Step 0**：探查 SQL 资源（`global_schema.sql`/`init_schema.sql`）是否含业务表，确定拆分边界（通用表随引擎下沉，业务表留 App 层迁移）
- [ ] **Step 1**：下沉 DatabaseManager + DatabaseSchemaMigrator 到 UFPStorage（Logger 适配 MinimalLogger），App 层 typealias 兼容 + 迁移**引擎测试**（DatabaseManagerLifecycle/Degradation、MigratorTests/Edge 共 4 个文件迁 UFPStorage）
- [ ] **Step 2**：UFPStorage 新增 `GenericSQLiteEngine`（泛型 CRUD/事务骨架，无业务依赖）
- [ ] **Step 3**：重构 App 层 SQLiteStore 为薄装配层（基于 GenericSQLiteEngine），保持 `AnyPageStoreCapabilities` conform；**SQLiteStore 3 个测试（Supplement/FailureEdge/TransactionConcurrency）留 App 层**（装配层测试，依赖 Domain 协议/业务模型）
- [ ] **Step 4**：`make test-spm PKG=UFPStorage` + `make ios` + 存储相关测试回归
- [ ] **Step 5**：提交 `refactor: 下沉 GRDB 存储引擎到 UFPStorage`

---

## 5. 风险与缓解

| 风险 | 缓解 |
|------|------|
| DatabaseManager 单例 + 204 次测试引用（旧设计文档已提） | 保留单例 + typealias 兼容层；测试迁移而非改动 |
| SQL 资源含业务表导致 UFPStorage 被污染 | Step 0 先行拆分：通用表下沉，业务表留 App 层迁移 |
| SQLiteStore 重构引入行为回归 | 迁移测试先行 + 存储相关测试全量回归 |
| Logger 语义丢失（MinimalLogger 无持久化） | 引擎层日志降级为诊断日志可接受；业务持久化日志仍走 App Logger |

---

## 6. 参考文档

- `Docs/Architecture/LAYERING_L0_L3.md`（8 条红线）
- `Docs/Architecture/INFRASTRUCTURE.md`（存储层现状）
- `Docs/Architecture/2026-08-12-appmodel-migration-design.md`（既有迁移设计模板）
- `AGENTS.md` 四大红线