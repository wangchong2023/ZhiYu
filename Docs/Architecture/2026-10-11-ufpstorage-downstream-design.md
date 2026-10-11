# UFPStorage 下沉设计：GRDB 存储引擎分层重构

> **设计日期**: 2026-10-11（修订：DatabaseManager 二次拆分）
> **来源**: `Docs/superpowers/plans/2026-10-11-common-capability-extraction.md` Task A2.1（协议层重构后再全量下沉，USER 确认）
> **方法论**: superpowers（brainstorming → 设计 → 实施）
> **目标**: 将 GRDB 物理引擎（DatabaseManager + DatabaseSchemaMigrator + SQLiteStore）核心下沉 UFPStorage，消除对 Domain/App 层的反向依赖，UFPStorage 成为可复用的通用存储底座
> **方案**: 引擎层 + 业务装配层拆分 + **DatabaseManager 二次拆分**（协议层重构，USER 确认）

---

## 1. 背景与问题

### 1.1 现状

`UFPStorage` SPM 包已建立骨架：`GRDBReexport.swift`（re-export GRDB）+ `StorageConstants.swift`（纯通用常量），GRDB 依赖已配置。App 层 `Sources/Infrastructure/Storage/` 持有三个核心存储引擎：

| 文件 | 行数 | 当前层级 | 说明 |
|------|------|---------|------|
| `Persistence/DatabaseManager.swift` | 487 | App L1 | 数据库中枢，建库/连接管理/多库热切换/降级，**17 处 App Logger 调用 + 深度耦合业务符号（SecurityManager/VaultDatabaseSwitcher/L10n/AppConstants/KnowledgePage 等）** |
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

### 1.4 DatabaseManager 二次拆分障碍（implementer 实测发现）

`DatabaseManager.swift`（487 行）**并非纯物理引擎**，而是「业务安全增强 + 数据库管理」混合体，深度耦合：

| 依赖符号 | 所在模块 | 用途 |
|---------|---------|------|
| `SecurityManager.shared.verifyIntegrity/updateSignature` | App | setup/switchDatabase 完整性校验与签名 |
| `KnowledgePage.fetchCount` | Domain | countPagesInCurrentVault/countPages |
| `VaultDatabaseSwitcher` 协议 + conform | App | 整个 `extension DatabaseManager: VaultDatabaseSwitcher` |
| `AppConstants.Storage.databaseName/globalDatabaseName` | App | 默认数据库 URL |
| `L10n.Security.targetIntegrityVerificationFailed` | App | switchDatabase 错误消息 |
| App 层 `StorageConstants`（JSONKey/LogConcat/ErrorDomain） | App | 通知 userInfo/日志（**与 UFPStorage 同名 StorageConstants 冲突**） |
| `TransactionGatekeeper` / `DatabaseWriterProvider` | App | 事务门禁 / 测试协议 |

若按「整体下沉 + typealias 兼容」执行，UFPStorage 将被强制引入业务模型/协议/App 常量，**直接违反 L0-L3 单向依赖红线**。因此 DatabaseManager 也需**二次拆分**（USER 确认）。

### 1.5 测试迁移偏差

`DatabaseManagerLifecycleTests`(18) + `DegradationTests`(4) = 22 用例，但核心断言依赖业务符号（`FeedbackEntry.databaseTableName`、`KnowledgePage`、`VaultDatabaseSwitcher` countPages、App 层 `StorageConstants`/`DatabaseError`）。**只有物理引擎相关用例（reset/事务计数/排空/降级状态）可迁 UFPStorage**，业务断言（FeedbackEntry 表、countPages）留 App 或改写为通用断言。

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
│  DatabaseManager 业务扩展（SecurityManager 适配/               │
│   VaultDatabaseSwitcher conform/countPages/L10n/AppConstants）  │
│      ▲ 依赖通用引擎                                              │
│  L1   UFPStorage（通用存储底座，与业务完全无关）                  │
│  GenericDatabaseManager（纯物理）/ GenericSchemaMigrator /      │
│  GenericSQLiteEngine / GRDBReexport / StorageConstants          │
└────────────────────────────────────────────────────────────────┘
```

**关键原则**：
1. **UFPStorage 只含通用能力**，零业务协议/模型引用，零 App 层依赖
2. **DatabaseManager 二次拆分**：UFPStorage 下沉 `GenericDatabaseManager` 纯物理引擎（建库/连接/WAL/降级骨架，完整性校验闭包注入、文件名注入，零业务符号）；App 层保留业务扩展（SecurityManager 适配、VaultDatabaseSwitcher conform、countPages、L10n/AppConstants）
3. **Migrator 拆两层**：UFPStorage 通用执行器（GRDB `DatabaseMigrator` 机制，无业务 schema）+ App 业务 schema（v1-v13+全局，setup 注入）
4. **SQLiteStore 不下沉为整体**，拆为「通用 GRDB 引擎骨架（入 UFPStorage）+ 业务装配（留 App 层）」

---

## 3. 方案分解

### 3.1 引擎层下沉（二次拆分，无协议障碍）

`DatabaseManager` **二次拆分**：物理引擎下沉，业务扩展留 App。

| 迁移目标 | 内容 | 适配点 |
|---------|------|--------|
| `Engine/GenericDatabaseManager.swift` | **纯物理引擎**：建库/连接池/WAL/多库热切换/降级骨架 | `Logger.shared`(17处) → `UFPCore.MinimalLogger`；完整性校验闭包注入、数据库文件名注入；`TestStateResettable`(UFPCore已有) |
| `Engine/GenericSchemaMigrator.swift` | GRDB 迁移执行器机制（无业务 schema） | 拆两层：通用执行器下沉，业务 schema 留 App |

- **Logger 适配**：App `Logger.error(_:error:)` 带 error 参数，UFPCore `MinimalLogger.error(_:)` 无 error 参数——把 error 拼进 message（复用 A1.1/A1.4 经验）
- **DatabaseManager 二次拆分（USER 确认）**：UFPStorage 只含 `GenericDatabaseManager` 纯物理引擎（零业务符号，完整性校验/文件名通过闭包注入）；App 层保留 `SecurityManager` 适配、`VaultDatabaseSwitcher` conform、`countPages`（依赖 KnowledgePage）、`L10n`/`AppConstants`/App 层 `StorageConstants`
- **Migrator 拆两层（USER 确认）**：`DatabaseSchemaMigrator` 内嵌业务 schema（`registerMigration` 闭包，17 处业务表 pages/links/tags 等）。拆分——
  - **UFPStorage 下沉**：通用迁移执行器（GRDB `DatabaseMigrator` 机制封装，不含业务 schema）
  - **App 层保留**：业务 schema 迁移定义（v1-v13 + 全局），在 `DatabaseManager.setup` 时作为 migrator 闭包注入
- **SQL 资源**：`global_schema.sql` / `init_schema.sql` 为 bundled 资源（pbxproj Resources），供参考/审计，**不随引擎迁移**；实际 schema 在 Migrator 代码（业务部分留 App）
- **App 层**：`Sources/Infrastructure/Storage/Persistence/DatabaseManager.swift` 保留业务扩展并基于 UFPStorage `GenericDatabaseManager`；`DatabaseSchemaMigrator.swift` 保留业务 schema 并基于通用执行器；`StorageModuleRegistrar` 引用同步

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

## 3.4 测试用例迁移与优化

> **原则**：测试跟随代码下沉（`Tests/Unit` → SPM 包 `Tests/`），但只迁移**纯引擎层测试**；装配层测试因引用 Domain 协议/业务模型，留 App 层。

### 3.4.1 测试迁移映射表

按拆分设计，7 个存储测试文件分为两类：

| 类别 | 测试文件 | 迁移目标 | 迁移原因 |
|------|---------|---------|---------|
| **引擎测试（迁移）** | `DatabaseManagerLifecycleTests.swift`、`DatabaseManagerDegradationTests.swift`（共 2 个文件的**物理引擎用例**：reset/事务计数/排空/降级状态） | `Packages/UFPStorage/Tests/UFPStorageTests/GenericDatabaseManagerTests.swift` | 测 GenericDatabaseManager 纯物理引擎（建库/连接/降级骨架） |
| **装配/业务测试（留 App 层）** | `DatabaseSchemaMigratorTests.swift`、`DatabaseSchemaMigratorEdgeTests.swift`（测业务 schema，断言 pages/links/tags + KnowledgePage）、`SQLiteStoreSupplementTests.swift`、`SQLiteStoreFailureEdgeTests.swift`、`SQLiteTransactionConcurrencyStressTests.swift` + **DatabaseManager 业务用例**（FeedbackEntry 表断言、countPages、VaultDatabaseSwitcher，留原文件或抽 `DatabaseManagerBusinessTests`） | **不迁移**，保留在 `Tests/Unit/Infrastructure/` | 依赖业务 schema/模型/Domain 协议/App 常量，UFPStorage 无法承载 |

> **22 用例内部分流**：仅物理引擎用例迁 UFPStorage；业务断言（FeedbackEntry 表、countPages）留 App（或改写为通用表断言后迁）。迁移用例数以 implementer 实拆为准，报告说明。

### 3.4.2 迁移后的优化要点

1. **import 调整**：`@testable import ZhiYu` → `@testable import UFPStorage`；GRDB 相关 import 保留（UFPStorage 已 `GRDBReexport` re-export GRDB，测试无需直接 `import GRDB`）
2. **去掉对已删 App 符号的引用**：迁移后若测试仍引用 App 层已删符号（如 `Logger`、业务常量），须改为 UFPStorage/UFPCore 等价物或删除对应断言
3. **Logger 断言适配**：引擎测试若断言 `Logger` 输出，改适配 MinimalLogger 或移除（MinimalLogger 无持久化，仅诊断日志）
4. **单例测试隔离**：`DatabaseManager.shared` 依赖 `TestStateResettable`（UFPCore 已有）重置，迁移后保持 `resetStateForTesting()` 隔离逻辑

### 3.4.3 一致性校验（对齐 C5.1 Step 1b）

- 迁移后 `grep -rn "@testable import ZhiYu" Packages/UFPStorage/Tests/` 应无残留
- 引擎测试迁移的物理引擎用例数守恒：`DatabaseManagerLifecycleTests`/`DegradationTests` 中的**物理引擎用例**全量迁入 UFPStorage（reset/事务计数/排空/降级状态；业务断言留 App）。迁移数量以实拆为准，报告中说明守恒核对
- 原 `Tests/Unit/Infrastructure/` 下 DatabaseManager 引擎测试文件（或拆分后的物理引擎测试文件）须从 `ZhiYuTests` target 移除（防 `@testable import ZhiYu` 引用已删符号导致编译失败）
- 5 个装配/业务 schema 测试文件 + DatabaseManager 业务用例**保持**在 App 层，不得删除

---

## 4. 实施步骤

> 本设计文档化后，A2.1 按其执行。分阶段，每阶段验证。

- [ ] **Step 0**：拆分 Migrator 两层（通用执行器下沉 UFPStorage，业务 schema 留 App）+ 拆分 DatabaseManager 二次（物理引擎下沉，业务扩展留 App）。`global_schema.sql`/`init_schema.sql` 为 bundled 参考，不迁移
- [ ] **Step 1**：迁移 DatabaseManager 物理引擎测试到 UFPStorage（reset/事务计数/排空/降级状态用例，`@testable import UFPStorage`），业务断言用例留 App；从 ZhiYuTests target 移除已迁物理引擎测试文件
- [ ] **Step 2**：UFPStorage 新增 `GenericDatabaseManager`（纯物理引擎，完整性校验/文件名闭包注入）+ `GenericSchemaMigrator`（通用迁移执行器）+ `GenericSQLiteEngine`（泛型 CRUD/事务骨架，无业务依赖）
- [ ] **Step 3**：App 层重构——`DatabaseManager` 保留业务扩展（SecurityManager 适配/VaultDatabaseSwitcher conform/countPages）基于 GenericDatabaseManager；`DatabaseSchemaMigrator` 保留业务 schema 基于 GenericSchemaMigrator；`SQLiteStore` 改薄装配层基于 GenericSQLiteEngine，conform 不变；更新 StorageModuleRegistrar
- [ ] **Step 4**：`make test-spm PKG=UFPStorage` + `make ios` + 存储相关测试回归
- [ ] **Step 5**：提交 `refactor: 下沉 GRDB 存储引擎到 UFPStorage`

---

## 5. 风险与缓解

| 风险 | 缓解 |
|------|------|
| DatabaseManager 单例 + 204 次测试引用（旧设计文档已提） | 保留单例语义 + 业务扩展留 App；测试分流而非大改 |
| DatabaseManager 深度耦合业务符号（SecurityManager/VaultDatabaseSwitcher/L10n/AppConstants/App 版 StorageConstants） | 二次拆分：UFPStorage 只下沉 `GenericDatabaseManager` 纯物理引擎（校验/文件名闭包注入），业务扩展留 App（USER 确认） |
| Migrator 内嵌业务 schema 污染 UFPStorage | Migrator 拆两层：通用执行器下沉，业务 schema 留 App（USER 确认） |
| SQLiteStore 重构引入行为回归 | 迁移测试先行 + 存储相关测试全量回归 |
| Logger 语义丢失（MinimalLogger 无持久化） | 引擎层日志降级为诊断日志可接受；业务持久化日志仍走 App Logger |
| App 层 `StorageConstants` 与 UFPStorage 同名冲突 | 二次拆分后 UFPStorage 用自身 `StorageConstants`，App 层业务扩展继续用 App 版 `StorageConstants`，互不干扰 |

---

## 6. 参考文档

- `Docs/Architecture/LAYERING_L0_L3.md`（8 条红线）
- `Docs/Architecture/INFRASTRUCTURE.md`（存储层现状）
- `Docs/Architecture/2026-08-12-appmodel-migration-design.md`（既有迁移设计模板）
- `AGENTS.md` 四大红线