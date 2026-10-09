# 智宇 (ZhiYu) 测试用例编写规范 (Test Case Standards)

> **适用范围**：所有向 `Tests/` 目录贡献测试代码的工程师，以及评审测试用例的 Reviewer。
> **定位**：本规范是测试用例**编写与评审的统一准则**，解决「测试用例腐化」问题。与现有文档分工如下：
>
> | 文档 | 职责 |
> |------|------|
> | `UNIT_TEST_GUIDE.md` | 框架选型、Mock 注入模式、目录结构、覆盖率指标（**工程层**） |
> | `TEST_CASES.md` | 测试用例**清单库**与 TC→XCTest 映射表 |
> | **`TEST_CASE_STANDARDS.md`（本文）** | 测试用例**设计方法论、编写准则、评审标准、腐化预防**（**方法论层**） |
> | `INTEGRATION_TEST_STRATEGY.md` | 集成测试隔离机制与防线策略 |
> | `SYSTEM_TEST_PLAN.md` | 系统级验收标准与混沌测试 |
> | `TEST_DRIVEN_FINDINGS.md` | 测试驱动发现的问题台账 |
>
> **对齐规范**：本规范严格对齐 [LAYERING_L0_L3.md](../Architecture/LAYERING_L0_L3.md)（分层依赖）、[swift-coding-style.md](../Guides/swift-coding-style.md)（命名/注释）、[development-standards.md](../Guides/development-standards.md)（DI/去魔鬼化/DesignSystem Token）、AGENTS.md 四大质量红线。

---

## 1. 总则

### 1.1 核心目标

测试用例必须满足两个根本目标：

1. **回归保护**：当生产代码被修改时，测试能捕获非预期的行为变更。
2. **缺陷发现**：测试以**发现真实缺陷**为目的，而非凑覆盖率（对齐 `TEST_DRIVEN_FINDINGS.md` 台账精神）。

> **反模式警示**：只为覆盖率而写的「绿色安慰剂」测试（如只调用方法不断言、断言恒真）是测试债务的最高危形态，评审一律打回。

### 1.2 测试代码与生产代码同等重要

- 测试代码遵循与生产代码**相同的质量标准**：命名规范、注释规范（中文）、去魔鬼化、圈复杂度 ≤ 15、函数 NBNC ≤ 100 行（对齐 `swift-coding-style.md`）。
- 测试代码纳入 SonarQube 全语言扫描与代码重复率（< 3%）卡控。
- **禁止**「测试代码可以随便写」的心态。

### 1.3 适用层级

本规范覆盖 `Tests/` 下所有测试类型：

| 类型 | 目录 | 职责 | 规范条款 |
|------|------|------|----------|
| 单元测试 | `Tests/Unit/` | 单一模块/类的隔离逻辑验证 | 第 2-14 节全部 |
| 集成测试 | `Tests/Integration/` | 跨模块/跨层有界集成 | 第 2、5-11、13 节 |
| 性能测试 | `Tests/Performance/` | 基准与回归性能度量 | 第 12 节 |
| 快照测试 | `Tests/SnapshotTests/` | SwiftUI 视图像素级回归 | 第 11 节 |
| UI 测试 | `Tests/UI/` | XCUITest 端到端自动化 | 第 13 节 |
| 边界测试 | `Tests/Boundary/` | 异常路径与边界条件 | 第 4、6 节 |

---

## 2. 测试金字塔与分层测试策略

### 2.1 测试金字塔（对齐 Mike Cohn 经典模型）

智宇采用**测试金字塔**分布，数量自下而上递减，执行速度自下而上递减，置信度自下而上递增：

```
            ╱──────────╲          UI 测试 (E2E)        ← 极少 (≤ 5%)，慢，高置信
           ╱────────────╲         快照 / 集成测试        ← 少量 (~15%)
          ╱──────────────╲        单元测试               ← 大量 (≥ 80%)，快，隔离
```

**数量分布红线**（CI `audit-test-structure.py` 度量）：

| 层级 | 目标占比 | 执行时间 | 说明 |
|------|----------|----------|------|
| 单元测试 | ≥ 80% | < 3 分钟（`make test-unit`） | 纯隔离，无 IO/网络 |
| 集成 + 快照 | ~15% | < 10 分钟 | 有界集成，真实 DB `:memory:` |
| UI (E2E) | ≤ 5% | < 20 分钟（`make test-ui`） | 模拟器驱动，允许 Flaky 容错 |

> **反金字塔警示**：若单元测试占比低于 60%，说明逻辑未被隔离测试覆盖，依赖昂贵的上层测试兜底，回归反馈慢且脆弱。CI 度量 `spm_test_coverage_ratio ≥ 0.80` 即为此红线的量化体现。

### 2.2 分层测试策略（对齐 L0-L3 架构）

测试粒度必须与架构层级对齐，**禁止跨层越权测试**：

| 被测层级 | 测试位置 | 测试策略 | 依赖处理 |
|----------|----------|----------|----------|
| **L0 底座** (`UFPCore`) | `Packages/UFPCore/Tests` | 纯单元，无 Mock | 直接实例化 |
| **L1 基础设施** (`UFPStorage`/`ZhiYuAICore`) | `Packages/*/Tests` | 单元 + `:memory:` DB | Mock 外部网络，真实 GRDB |
| **L1.5 领域** (`ZhiYuDomain`) | `Packages/ZhiYuDomain/Tests` | 纯单元，**绝对平台无关** | 全 Mock，禁止 `import UIKit/SwiftUI` |
| **L2 功能** (`ZhiYuFeatures`) | `Packages/ZhiYuFeatures/Tests` + `Tests/Unit/Features/` | 单元 + 快照 | Mock Repository/Service |
| **L3 应用** (`Sources/App/`) | `Tests/Unit/App/` | 单元 + 集成 | Mock DI 容器，`setupFullMockEnvironment` |

**关键规则**：
- L1.5 领域层测试**严禁**导入 `UIKit`/`AppKit`/`SwiftUI`（对齐 `LAYERING_L0_L3.md` 红线 1）。
- L2/L3 测试**严禁**直接实例化 `SQLiteStore` 写真实文件（对齐 `UNIT_TEST_GUIDE.md` 第 8 节 Anti-Patterns），必须用 `:memory:` 或 Mock。
- 跨层集成测试集中在 `Tests/Integration/`，禁止在 `Tests/Unit/` 中混入跨层真实依赖。

### 2.3 SPM 包极速单测优先

所有可下沉到 SPM 本地 Package 的逻辑，**必须**在 Package 内测试（`make test-spm PKG=包名`），享受秒级反馈，而非依赖主 App 模拟器装载。CI 度量 `spm_test_coverage_ratio ≥ 0.80` 强制卡控。

---

## 3. FIRST 原则（测试用例黄金法则）

所有测试用例必须满足 **FIRST** 五原则，这是业界公认的测试质量基石（Robert C. Martin / Kent Beck）：

| 原则 | 全称 | 要求 | 违反后果 | 智宇落地 |
|------|------|------|----------|----------|
| **F** | **Fast** 快速 | 单个用例 < 100ms，全量单测 < 3 分钟 | 反馈慢，开发者跳过跑测试 | 禁止真实网络/磁盘 IO 进单测；用 `:memory:` DB |
| **I** | **Independent** 独立 | 用例间无依赖，任意顺序执行结果一致 | 级联失败，定位困难 | 每用例 `setUp` 重建实例；禁止 `tearDown` 调 `ServiceContainer.shared.reset()`（对齐 `TEST_DRIVEN_FINDINGS.md` #42/#61） |
| **R** | **Repeatable** 可重复 | 任意次数、任意环境运行结果恒定 | Flaky 测试，CI 红灯噪音 | 禁止 `Date()` 动态时间（对齐 #60）；用确定性 Fixture |
| **S** | **Self-Validating** 自验证 | 通过/失败由断言自动判定，无需人工看日志 | 需人工判断 = 无效测试 | 每个用例必须有**至少一个断言**；禁止「只调用不断言」 |
| **T** | **Timely** 及时 | 测试与生产代码同步或先于编写（TDD） | 事后补测试质量低，难覆盖分支 | PR 必须包含对应测试；CI 度量 `test_source_file_ratio 0.5–1.5` |

> **评审第一关**：Reviewer 遇到违反 FIRST 任一原则的用例，**一律打回**，无需进入细节评审。

---

## 4. 测试用例设计技术（对齐 ISTQB 黑盒设计方法）

> 本节对齐 ISTQB 测试设计技术，结合智宇实际场景给出落地范式。**禁止仅凭直觉编写用例**，必须从下列方法中选取至少一种作为设计依据。

### 4.1 等价类划分（Equivalence Partitioning）

将输入域划分为**有效等价类**与**无效等价类**，每类取一个代表值，确保「以少量用例覆盖完整输入域」。

| 分类 | 有效等价类 | 无效等价类 |
|------|-----------|-----------|
| 页面标题长度 | 1–200 字符 | 空字符串 / > 200 字符 |
| 向量维度 | 384 / 512 / 1536 | 0 / 负数 / 与索引维度不匹配（对齐 #02） |
| 搜索查询 | 非空有意义文本 | 空字符串 / 纯空白（对齐 #25） |

**规则**：每等价类**至少 1 个用例**，无效等价类**必须**覆盖（这是缺陷高发区）。

### 4.2 边界值分析（Boundary Value Analysis, BVA）

边界是缺陷最密集的区域。对每个等价类边界取 **5 点**：`min-1, min, min+1, max-1, max`（或 `min, min+1, nom, max-1, max`）。

```swift
// 边界值分析示例：页面标题长度上限 200
func testCreatePage_TitleAtMaxLength_ShouldSucceed() async throws {
    let title = String(repeating: "a", count: 200) // max
    // ...
}
func testCreatePage_TitleExceedsMaxLength_ShouldThrow() async throws {
    let title = String(repeating: "a", count: 201) // max+1
    // ...
}
func testCreatePage_TitleEmpty_ShouldThrow() async throws {
    let title = "" // min-1 (空)
    // ...
}
```

**智宇高频边界清单**（必须覆盖）：
- 空集合 / 单元素集合 / 空字符串 / 纯空白字符串
- 索引 `0` / 索引 `count - 1` / 索引越界 `-1` / `count`（对齐 #31/#69）
- 数值 `0` / 负数 / `Int.max` / `Int.min`
- 时间区间 `start == end` / `end < start`（对齐 #56）
- 空数据库 / 首次写入 / 满容量

### 4.3 决策表测试（Decision Table）

针对多条件组合的业务逻辑（如同步冲突解决、权限校验），使用决策表枚举条件组合，每行一个用例。

**示例 — LWW 同步冲突解决决策表**（对齐 `INTEGRATION_TEST_STRATEGY.md` 3.3）：

| 条件 | 用例 1 | 用例 2 | 用例 3 | 用例 4 |
|------|--------|--------|--------|--------|
| 本地时间戳 T1 | 10:00 | 10:00 | 10:00 | (空) |
| 远程时间戳 T2 | 09:00 | 11:00 | 10:00 | 10:00 |
| T2 > T1 | 否 | 是 | 否 | 是 |
| **预期结果** | 保留本地 | 采用远程 | 保留本地(同时间保留本地) | 采用远程 |

**规则**：决策表列数 = 用例数，禁止遗漏条件组合列。

### 4.4 状态转换测试（State Transition）

针对有状态机的组件（如 `SynthesisStore` 生成状态、`VaultService` 锁定状态、`ChatStore` 流式状态），使用状态转换图设计用例，覆盖**所有状态**与**所有合法转换**，并验证**非法转换被拒绝**。

**示例 — SynthesisStore 状态机**（对齐 #08）：

```
.idle ──start──▶ .generating ──success──▶ .completed
                       │                       │
                       ├──cancel──▶ .idle      ├──save──▶ .saved
                       └──error──▶ .failed
```

**必须覆盖**：
- 每条合法转换（`idle→generating`、`generating→completed` 等）
- 非法转换拒绝（`generating` 时再次 `start` 必须被互斥拦截 — 对齐 #08）
- 终态回溯（`completed→idle` 重置）

### 4.5 错误猜测（Error Guessing）

基于经验、历史缺陷台账（`TEST_DRIVEN_FINDINGS.md`）和领域知识，主动猜测易错点。**智宇高频错误模式清单**（从台账 73 项提炼）：

| 错误模式 | 台账参考 | 测试要求 |
|----------|----------|----------|
| 空集合除零 / NaN | #53/#59 | 空输入必须有用例 |
| 数组索引越界 | #31/#69 | 动态数据 ForEach 必须测越界 |
| 并发状态覆盖 | #08/#11 | 并发点击/写入必须测互斥 |
| 全局单例污染 | #42/#46/#61/#62 | 禁止 tearDown reset 单例 |
| 悬空依赖崩溃 | #12/#41/#66/#68 | 未注册服务必须安全降级 |
| 时钟回退 | #30 | 时间相关逻辑必须测回退 |
| 多字节字符截断 | #50 | CJK 文本必须测截断边界 |
| 未闭合语法 | #07/#47 | Markdown 解析必须测未闭合 |

> **规则**：新增功能 PR 必须对照上表自查，命中项必须补对应用例。

---

## 5. 测试替身分类与使用规范（Test Doubles）

> 对齐 Gerard Meszaros《xUnit Test Patterns》经典分类。**禁止混用替身概念**，每种替身有明确职责边界。

### 5.1 五种测试替身

| 替身类型 | 英文 | 职责 | 何时使用 | 智宇示例 |
|----------|------|------|----------|----------|
| **Dummy** | Test Dummy | 仅填充参数列表，从不被调用 | 接口签名需要参数但测试不关心 | 传入空的 `Logger` 给构造器 |
| **Stub** | Test Stub | 返回**预设固定值**，不验证交互 | 被测单元依赖外部返回值 | `MockLLMClient` 返回固定 stub 语料 |
| **Spy** | Test Spy | 记录调用信息（次数/参数），供事后断言 | 需验证「是否被调用」「以什么参数调用」 | `MockPageStore` 记录 `insert` 调用次数 |
| **Mock** | Test Mock | 预设期望，**调用时即时验证** | 需验证交互契约 | 验证 `onLoad` 生命周期被调用 |
| **Fake** | Test Fake | 拥有**简化但可工作的实现** | 需要真实行为但简化外部依赖 | `InMemoryPageStore` 用数组模拟数据库 |

### 5.2 智宇替身使用规则

1. **单元测试优先 Stub/Spy**：单元测试验证被测单元自身行为，依赖项用 Stub 提供返回值，用 Spy 验证交互。**禁止**在单元测试中用 Fake（Fake 本身有逻辑，会引入测试的测试）。
2. **集成测试可用 Fake**：集成测试需要跨模块协作，Fake 提供轻量可工作实现（如 `InMemoryPageStore`）。
3. **Mock 谨慎使用**：Mock 耦合交互细节，重构易碎。优先用 Spy 事后断言，而非 Mock 即时验证。
4. **Stub 禁止含分支逻辑**：Stub 只返回固定值，禁止内含 `if/switch`。需要条件返回时用 Fake。
5. **替身命名规范**：统一 `Mock` 前缀（`MockLLMClient`、`MockPageStore`），Fake 用 `InMemory`/`Fake` 前缀（`InMemoryPageStore`、`FakeEmbeddingProvider`）。禁止 `TestXxx`/`StubXxx` 混用。

### 5.3 替身存放位置

| 替身范围 | 存放位置 | 说明 |
|----------|----------|------|
| SPM 包内专用 | `Packages/*/Tests/*TestMocks/` | 各 Package 独立 TestMocks Target |
| 跨测试共享 | `Tests/Shared/TestMocks.swift` | 主 App 测试共享 Mock 工厂 |
| 单文件专用 | 测试文件内 `private` 类 | 仅该文件使用，不外泄 |

> **规则**：替身必须 `Sendable`（对齐 Swift 6 严格并发），可变状态用 `nonisolated(unsafe)` 或 actor 隔离。

---

## 6. 命名规范

> 对齐 `swift-coding-style.md` 命名约定与 `TEST_DRIVEN_FINDINGS.md` #22（中文命名违规已修复）。

### 6.1 测试方法命名

**统一格式**：`test<被测单元>_<条件/场景>_<预期结果>`

```swift
// ✅ 正确：三段式，纯英文驼峰
func testCreatePage_WithValidTitle_ShouldReturnNewPage() async throws
func testSearch_WithEmptyQuery_ShouldReturnAllPages() async throws
func testDelete_WithNonExistentID_ShouldThrowNotFoundError() async throws
func testLayout_WithSelfLoopEdges_ShouldNotDeadlock() async throws
```

**禁止**：
- ❌ 中文方法名（对齐 #22）：`testSecurityManager_文件不存在_模拟器放行`
- ❌ 下划线分隔被测单元：`test_create_page_with_valid_title`
- ❌ 无预期结果：`testCreatePage`（预期结果缺失）
- ❌ 无条件描述：`testCreatePageShouldWork`（条件缺失，无法判断测了什么场景）

### 6.2 命名关键词约定

| 关键词 | 语义 | 示例 |
|--------|------|------|
| `Should` | 预期正向结果 | `ShouldReturnNewPage` |
| `ShouldThrow` | 预期抛出异常 | `ShouldThrowNotFoundError` |
| `ShouldNot` | 预期负向结果 | `ShouldNotDeadlock` |
| `With` / `When` | 前置条件 | `WithEmptyQuery` / `WhenConcurrent` |
| `At` / `Exceeds` | 边界值 | `AtMaxLength` / `ExceedsMaxLength` |

### 6.3 测试类命名

**统一格式**：`<被测类名>Tests`

```swift
final class KnowledgePageManagerTests: XCTestCase { }
final class PluginSandboxTests: XCTestCase { }
final class VaultSecurityTests: XCTestCase { }
```

**规则**：
- 一个被测类对应一个测试文件，文件名 = 测试类名（去 `Tests` 后缀）+ `Tests.swift`。
- 测试文件路径必须与被测代码的架构层级/功能域对齐（对齐 `UNIT_TEST_GUIDE.md` 4.1 功能域对齐原则）。

### 6.4 TC 用例 ID 命名（文档层）

`TEST_CASES.md` 中的文档用例 ID 遵循 `<域>-<子域>-<序号>` 格式：

| 前缀 | 功能域 | 示例 |
|------|--------|------|
| `TC-STR` | 存储 (Storage) | `TC-STR-01` |
| `TC-SRC` | 搜索 (Search) | `TC-SRC-01` |
| `TC-AI` | AI 助手 | `TC-AI-01` |
| `TC-GRF` | 图谱 (Graph) | `TC-GRF-01` |
| `TC-PLG` | 插件 (Plugin) | `TC-PLG-01` |
| `TC-VLT` | 金库 (Vault) | `TC-VLT-01` |

**规则**：每个 TC 用例 ID 必须在 `TEST_CASES.md` 第 10 节「TC → XCTest 映射表」中映射到具体的 XCTest 方法，确保文档与代码双向可追溯。

---

## 7. AAA 结构（Arrange-Act-Assert）

> 对齐 Given-When-Then（BDD）范式。所有测试用例**必须**采用三段式结构，用注释显式标注。

### 7.1 标准结构

```swift
func testCreatePage_WithValidTitle_ShouldReturnNewPage() async throws {
    // Given — 准备测试数据与状态
    let mockStore = MockPageStore()
    let sut = PageService(store: mockStore)
    let title = "测试页面"

    // When — 执行被测代码
    let page = try await sut.createPage(title: title)

    // Then — 断言预期结果
    XCTAssertEqual(mockStore.pages.count, 1)
    XCTAssertEqual(mockStore.pages.first?.title, title)
    XCTAssertEqual(page.title, title)
}
```

### 7.2 结构规则

| 规则 | 说明 | 违反后果 |
|------|------|----------|
| **三段缺一不可** | Given/When/Then 必须齐全且用注释标注 | 可读性差，评审打回 |
| **When 段仅一行** | When 段只包含被测动作，禁止混合准备逻辑 | 被测行为不清晰 |
| **Then 段禁止执行被测代码** | 断言段只做验证，禁止再次调用 sut | 职责混乱 |
| **Given 段禁止断言** | 准备段不验证任何东西，断言全部在 Then | 断言分散，难定位 |
| **一个用例一个被测行为** | 禁止在一个用例中测多个不相关行为 | 失败时无法定位根因 |

### 7.3 异常测试结构

```swift
func testDelete_WithNonExistentID_ShouldThrowNotFoundError() async throws {
    // Given
    let sut = PageService(store: MockPageStore()) // 空存储

    // When & Then — 异常测试合并 When/Then
    XCTAssertThrowsError(try await sut.delete(id: UUID())) { error in
        guard case PageError.notFound = error else {
            XCTFail("预期抛出 notFound，实际: \(error)")
            return
        }
    }
}
```

> **禁止** `try?` 吞掉异常后断言 nil（对齐 `UNIT_TEST_GUIDE.md` Anti-Patterns）。必须用 `XCTAssertThrowsError` 并验证具体错误类型。

---

## 8. 断言规范

### 8.1 断言强度分级

| 强度 | 断言方式 | 适用场景 | 示例 |
|------|----------|----------|------|
| **强** | 精确值断言 | 预期确定值 | `XCTAssertEqual(count, 3)` |
| **强** | 异常类型断言 | 预期特定错误 | `XCTAssertThrowsError` + `case` 匹配 |
| **中** | 范围断言 | 预期在区间内 | `XCTAssertGreaterThanOrEqual(latency, 0)` |
| **中** | 非空断言 | 预期有值但不关心具体值 | `XCTAssertNotNil(result)` |
| **弱** | 布尔断言 | 仅判断真假 | `XCTAssertTrue(isValid)` |
| **❌ 禁止** | 恒真断言 | 无效测试 | `XCTAssertTrue(true)` |
| **❌ 禁止** | 无断言 | 无效测试 | 只调用方法不断言 |

**规则**：
- 优先使用**强断言**，能精确值就不要用布尔断言。
- `XCTAssertNotNil` 后若需访问非空值，必须用 `guard let` 或 `XCTUnwrap`，禁止强制解包 `!`（对齐 #72 零强制转换规范）。
- 浮点数比较必须指定精度：`XCTAssertEqual(score, 0.88, accuracy: 0.001)`。

### 8.2 断言消息规范

每个断言**必须**提供失败消息，说明「预期什么、实际什么、在哪个用例」：

```swift
// ✅ 正确：带描述消息
XCTAssertEqual(mockStore.pages.count, 1, "创建页面后存储应有 1 条记录，实际: \(mockStore.pages.count)")

// ❌ 错误：无描述消息，失败时只看到 "XCTAssertEqual failed"
XCTAssertEqual(mockStore.pages.count, 1)
```

### 8.3 断言数量

| 规则 | 说明 |
|------|------|
| **最少 1 个** | 每个用例至少 1 个断言（FIRST-S 原则） |
| **建议 1-5 个** | 单用例断言数建议 1-5 个，聚焦单一行为 |
| **> 10 个需拆分** | 超过 10 个断言说明用例测了太多行为，必须拆分为多个用例 |
| **禁止零断言** | 零断言用例一律打回（「绿色安慰剂」） |

### 8.4 禁止的断言模式

| 禁止模式 | 原因 | 正确做法 |
|----------|------|----------|
| `XCTAssertTrue(true)` | 恒真，无验证价值 | 删除或改为真实断言 |
| `XCTAssertNotNil(try? sut.doSomething())` | `try?` 吞掉异常 | `XCTAssertNoThrow` + 精确断言 |
| `XCTAssertEqual(result, result)` | 自比恒真 | 与预期值比较 |
| `_ = try? sut.doSomething()` 后不断言 | 只调用不断言 | 加断言或删除用例 |
| 断言在 `async let` 内部 | 并发时序不确定 | `await` 后统一断言 |

---

## 9. 测试数据与 Fixture 管理

### 9.1 确定性原则

测试数据必须**完全确定**，禁止依赖运行时环境状态：

| 禁止 | 原因 | 正确做法 |
|------|------|----------|
| `Date()` | 跨日期运行结果漂移（对齐 #60） | `Date(timeIntervalSince1970: 1_700_000_000)` 固定时间戳 |
| `UUID().uuidString` 作为预期值 | 每次运行不同 | 用固定 UUID 或只验证格式/非空 |
| `FileManager.default.temporaryDirectory` 拼接随机名 | 路径不确定 | 显式指定 `:memory:` 或固定临时路径 |
| `TimeZone.current` | CI 与本地时区不同 | 显式 `TimeZone(identifier: "UTC")` |
| `ProcessInfo.processInfo.hostName` | 环境相关 | Mock 或固定值 |

### 9.2 Fixture 分层管理

| Fixture 范围 | 存放位置 | 示例 |
|-------------|----------|------|
| 单用例内联 | 测试方法内 `Given` 段 | `let page = KnowledgePage(title: "测试")` |
| 单文件共享 | 文件内 `private` 常量/工厂方法 | `private func makePage() -> KnowledgePage` |
| 跨文件共享 | `Tests/Shared/` 工厂方法 | `TestFactory.makePage()` |
| 大型数据集 | `Tests/Shared/Fixtures/` 资源文件 | `Fixtures/50k_pages.json` |

**规则**：
- Fixture 工厂方法命名：`make<类型>()`（如 `makePage()`、`makeMockStore()`）。
- 禁止在测试方法间共享可变 Fixture 实例（违反 FIRST-I 独立性）。
- Fixture 数据必须语义化：`"测试页面"` 优于 `"aaa"`，`"AI 摘要测试输入"` 优于 `"test"`。

### 9.3 测试数据规模

| 测试类型 | 数据规模 | 说明 |
|----------|----------|------|
| 单元测试 | 1-10 条 | 聚焦逻辑，最小数据集 |
| 集成测试 | 10-100 条 | 验证跨模块协作 |
| 性能测试 | 1,000-50,000 条 | 基准度量（对齐 `PERFORMANCE_BENCHMARK.md`） |
| 压力测试 | 50,000+ | 极限场景（对齐 `SYSTEM_TEST_PLAN.md` CH-04） |

> **规则**：单元测试禁止使用 1000+ 数据集（违反 FIRST-F 快速原则），大规模数据测试归入 `Tests/Performance/`。

---

## 10. setUp / tearDown 生命周期规范

> 对齐 `TEST_DRIVEN_FINDINGS.md` #42/#61（全局 reset 导致级联崩溃）。

### 10.1 setUp 规则

```swift
final class PageServiceTests: XCTestCase {
    var mockStore: MockPageStore!
    var sut: PageService!

    override func setUp() async throws {
        try await super.setUp()
        // 每个用例独立创建实例，确保隔离
        mockStore = MockPageStore()
        sut = PageService(store: mockStore)
    }
}
```

| 规则 | 说明 |
|------|------|
| **每用例重建** | `setUp` 中重建所有实例，禁止用例间共享 |
| **async setUp** | 需要 async 初始化时用 `override func setUp() async throws` |
| **super.setUp()** | 必须调用 `super.setUp()`，放在首行 |
| **DI 容器隔离** | 用独立 `ServiceContainer()` 而非 `.shared`，或用 `setupFullMockEnvironment` 幂等覆盖 |

### 10.2 tearDown 规则

```swift
override func tearDown() async throws {
    sut = nil
    mockStore = nil
    try await super.tearDown()
}
```

| 规则 | 说明 | 违反后果 |
|------|------|----------|
| **置 nil 释放引用** | `sut = nil`、`mockStore = nil` | 内存泄漏 |
| **禁止 reset 全局单例** | 禁止 `ServiceContainer.shared.reset()` / `DatabaseManager.shared.reset()` | 级联崩溃（对齐 #42/#61） |
| **禁止 reset UserDefaults** | 禁止 `UserDefaults.standard.removePersistentDomain` | 跨用例污染 |
| **单例状态用 reset()** | 如 `TaskCenter.reset()`（对齐 #46） | 单例状态泄漏 |

### 10.3 全局状态隔离策略

针对全局单例状态污染（智宇高频问题），采用以下分层隔离策略：

| 隔离层 | 机制 | 适用场景 |
|--------|------|----------|
| **首选** | 独立实例（不依赖单例） | 单元测试 |
| **次选** | `setupFullMockEnvironment` 幂等覆盖 | 需要 DI 的测试 |
| **兜底** | 单例提供 `reset()` 方法 + setUp 调用 | TaskCenter 等有状态单例 |
| **❌ 禁止** | `ServiceContainer.shared.reset()` | 破坏后续用例依赖链 |

---

## 11. 快照测试规范（Snapshot Testing）

> 对齐 `TEST_DRIVEN_FINDINGS.md` #13/#14/#15/#43/#60/#61/#62/#70（快照测试高频问题）。

### 11.1 快照测试规则

| 规则 | 说明 | 对齐台账 |
|------|------|----------|
| **统一环境注入** | 必须用 `.snapshotEnvironment()` 一次性全量注入，禁止手动 `.environment()` | #13/#15/#43/#70 |
| **禁止魔鬼数字尺寸** | 禁止 `.frame(width: 390, height: 844)`，用 `DesignSystem.Metrics` 或 `SnapshotConfig` | #14 |
| **确定性时间** | 禁止 `Date()` 动态时间，用固定基准时间 | #60 |
| **单例状态重置** | setUp 中重置 `TaskCenter.reset()` 等单例，禁止遗留数据 | #46/#62 |
| **禁止 tearDown reset** | 禁止 `DatabaseManager.shared.reset()` / `ServiceContainer.shared.reset()` | #61 |
| **精度配置** | 用 `SnapshotConfig.relaxedPrecision` 稳定全屏动态渲染 | #61 |

### 11.2 快照测试结构

```swift
@MainActor
final class KnowledgeListViewSnapshots: XCTestCase {
    func testKnowledgeList_emptyState() {
        // Given — 确定性状态
        let store = AppStore()
        // When — 渲染视图
        let view = KnowledgeListView()
            .snapshotEnvironment() // 统一全量环境注入
        // Then — 快照断言
        assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13)))
    }
}
```

### 11.3 快照更新规范

- 快照基线变更必须**人工审查**，禁止盲目 `assertSnapshot` 自动覆盖。
- 快照文件（`.reference.png`）必须提交至 Git，禁止 `.gitignore`。
- 快照失败时优先排查**代码变更**而非**环境差异**，确认是预期变更后再更新基线。

---

## 12. 性能测试规范

> 对齐 `UNIT_TEST_GUIDE.md` 第 6 节、`PERFORMANCE_BENCHMARK.md`。

### 12.1 性能测试规则

| 规则 | 说明 |
|------|------|
| **使用 `measure` 块** | 性能测试必须用 `XCTestCase.measure` 或 `XCTMetric`，禁止手动计时 |
| **设定基线** | 必须通过 `XCTMeasureOptions` 设定迭代次数与基线，CI 检测回归 |
| **隔离 IO** | 性能测试中数据库用 `:memory:`，避免磁盘 IO 噪音 |
| **预热** | `measure` 默认运行 10 次取平均，首次冷启动噪音被消除 |
| **独立目录** | 性能测试归入 `Tests/Performance/`，禁止混入 `Tests/Unit/` |

### 12.2 性能红线（对齐 `SYSTEM_TEST_PLAN.md` 3.1）

| 指标 | 红线 | 测试方法 |
|------|------|----------|
| 冷启动 | < 1.5s | `CFAbsoluteTime` 埋点 |
| FTS5 搜索 | < 100ms | `measure` + 1000 条数据 |
| 混合搜索 | < 200ms | `measure` + 1000 条数据 |
| 图谱布局 | < 200ms (100+ 节点) | `measure` + 收敛断言 |
| UI 帧率 | > 58 FPS | `CADisplayLink` 采样 |

### 12.3 性能测试结构

```swift
final class SearchPerformanceTests: XCTestCase {
    func testHybridSearchPerformance_With1000Records_ShouldBeUnder200ms() throws {
        // Given — 预填充 1000 条数据
        let store = try SQLiteStore(path: ":memory:")
        try (0..<1000).forEach { i in
            try store.insert(Page(title: "Page \(i)", content: "Content \(i)"))
        }
        // When & Then — measure 基准
        measure {
            _ = try? store.search(query: "Content 500", limit: 10)
        }
    }
}
```

---

## 13. UI 测试与集成测试补充规范

### 13.1 UI 测试（XCUITest）规范

> 对齐 `SYSTEM_TEST_PLAN.md` 4.6（Flaky 自愈防御）。

| 规则 | 说明 |
|------|------|
| **启动参数隔离** | `XCUIApplication().launchArguments += ["-ResetUserDefaults"]` 确保 Seeding 幂等 |
| **显式等待** | 禁止 `sleep(N)` 硬等待，用 `XCUIElement.waitForExistence(timeout:)` |
| **Accessibility 标识** | UI 元素必须通过 `accessibilityIdentifier` 定位，禁止靠文本/坐标 |
| **Flaky 容错** | 旋转等操作前插入缓冲，snapshot 失败时自愈重启（对齐 4.6） |
| **独立 Runner** | UI 测试在独立 UITest Runner 进程，禁止与单元测试混编 |

### 13.2 集成测试规范

> 对齐 `INTEGRATION_TEST_STRATEGY.md`。

| 规则 | 说明 |
|------|------|
| **有界集成** | 集成测试必须有明确边界（如 DB+Repository、LLM+RAG），禁止无边界全链路 |
| **真实 DB 用 `:memory:`** | 集成测试用内存数据库，禁止写真实文件 |
| **Mock 外部网络** | LLM/CloudKit 等外部服务必须 Mock，禁止真实网络调用 |
| **隔离机制** | 遵循 `AppLauncher` 分流 + `ServiceContainer` 重置（对齐 2.1/2.2） |
| **Golden Set 评估** | RAG 管线必须有 Golden Set 召回率断言 ≥ 90%（对齐 4.2） |

---

## 14. Swift 6 并发测试规范

> 对齐 `UNIT_TEST_GUIDE.md` 第 3 节、AGENTS.md 并发规范。

### 14.1 并发测试规则

| 规则 | 说明 | 对齐台账 |
|------|------|----------|
| **async/await** | 异步测试用 `async throws` 签名，禁止 `expectation` | — |
| **@MainActor 标注** | 测 UI/ViewModel 必须 `@MainActor` 标注测试类 | — |
| **禁止锁** | 禁止 `.wait()` / `DispatchSemaphore`，用 `Task.sleep` | UNIT_TEST_GUIDE 3.2 |
| **并发安全计数** | 并发闭包内禁止突变捕获变量，用原子计数器或 actor | #17 |
| **Sendable 替身** | Mock/Stub 必须 `Sendable`，可变状态用 `nonisolated(unsafe)` | — |

### 14.2 并发测试模式

```swift
// 并发安全性测试 — 验证 actor 隔离
func testActorStateIsolation_WhenConcurrentWrites_ShouldBeConsistent() async throws {
    let store = SQLiteStore() // actor
    // When — 并发写入
    await withTaskGroup(of: Void.self) { group in
        for i in 0..<100 {
            group.addTask { try? await store.insert(Page(title: "Page \(i)")) }
        }
    }
    // Then — 最终状态一致
    let count = try await store.count()
    XCTAssertEqual(count, 100, "100 次并发写入后应有 100 条记录")
}

// 互斥测试 — 验证状态机防重（对齐 #08）
func testStartSynthesis_WhenAlreadyGenerating_ShouldRejectDuplicate() async throws {
    let sut = SynthesisStore()
    await sut.startSynthesis() // 首次启动
    // When — 并发再次启动
    await sut.startSynthesis() // 应被互斥拦截
    // Then — 仅有 1 个生成任务
    XCTAssertEqual(sut.activeTaskCount, 1)
}
```

---

## 15. 测试用例评审清单（Code Review Checklist）

> Reviewer 审查测试代码时，必须逐项核对以下清单。**任一项不通过即打回**。

### 15.1 结构性检查（必过）

- [ ] **FIRST 原则**：快速、独立、可重复、自验证、及时（第 3 节）
- [ ] **AAA 结构**：Given/When/Then 三段齐全且注释标注（第 7 节）
- [ ] **命名规范**：`test<单元>_<条件>_<预期>` 纯英文驼峰（第 6 节）
- [ ] **至少一个断言**：禁止零断言用例（第 8.3 节）
- [ ] **断言带消息**：每个断言提供失败描述（第 8.2 节）
- [ ] **setUp/tearDown 合规**：每用例重建实例，禁止全局 reset（第 10 节）

### 15.2 设计性检查

- [ ] **设计方法明确**：等价类/边界值/决策表/状态转换至少一种（第 4 节）
- [ ] **边界值覆盖**：空、零、越界、极值至少覆盖（第 4.2 节）
- [ ] **错误猜测自查**：对照高频错误模式清单（第 4.5 节）
- [ ] **替身类型正确**：单元用 Stub/Spy，集成可用 Fake（第 5 节）
- [ ] **单一行为**：一个用例只测一个行为（第 7.2 节）

### 15.3 质量性检查

- [ ] **确定性数据**：无 `Date()`/`UUID()` 作为预期值（第 9.1 节）
- [ ] **无强制解包**：无 `!` 强制解包/转换（第 8.1 节，对齐 #72）
- [ ] **无魔鬼数字**：测试数据也去魔鬼化（对齐 AGENTS.md 红线 4）
- [ ] **中文注释**：测试代码注释中文（对齐 swift-coding-style.md）
- [ ] **Sendable 合规**：Mock/Stub 标记 Sendable（第 14 节）
- [ ] **架构对齐**：测试位置与被测代码层级对齐（第 2.2 节）

### 15.4 可追溯性检查

- [ ] **TC 映射**：文档用例 ID 映射到 XCTest 方法（第 6.4 节）
- [ ] **需求溯源**：测试覆盖对应 SR 编号（对齐 swift-coding-style.md 需求追踪）
- [ ] **台账对照**：新增用例对照 `TEST_DRIVEN_FINDINGS.md` 高频错误模式

---

## 16. 测试用例腐化预防机制（Anti-Rot）

> 测试腐化（Test Rot）是测试用例随时间推移逐渐失效、被忽视、最终被删除的过程。本节建立系统性预防机制。

### 16.1 腐化信号识别

以下信号表明测试正在腐化，必须及时干预：

| 信号 | 严重度 | 干预措施 |
|------|--------|----------|
| 用例被 `@Skip`/`XCTSkip` 长期跳过 | 高 | 7 天内修复或删除，禁止永久跳过 |
| 用例被注释掉 | 高 | 立即删除或恢复，禁止注释代码 |
| Flaky 用例（偶发失败） | 高 | 48 小时内修复或隔离至 `Tests/Flaky/` |
| 用例断言被弱化（强→弱） | 中 | 评审打回，恢复强断言 |
| 用例无变更但被测代码大改 | 中 | 审查测试是否仍有效 |
| 测试文件超过 50 个用例 | 中 | 拆分文件（CI `oversized_file_ratio < 0.05`） |
| 测试文件 0 个用例（非 Mock） | 高 | 删除或补充用例（CI `empty_file_ratio = 0`） |

### 16.2 腐化预防制度

| 制度 | 频率 | 责任人 | 内容 |
|------|------|--------|------|
| **测试健康巡检** | 每周 | 模块负责人 | 检查 Skip/Flaky/注释用例 |
| **覆盖率趋势监控** | 每次 PR | CI 自动 | SonarQube 覆盖率不得下降 |
| **测试结构审计** | 每次 PR | CI 自动 | `make audit` 6 项指标 |
| **台账回顾** | 每月 | QA | `TEST_DRIVEN_FINDINGS.md` 新增问题分析 |
| **死测试清理** | 每季度 | 全员 | 删除长期失效/无价值用例 |

### 16.3 测试债务管理

- 测试债务（Test Debt）与代码债务同等管理，纳入 PR 描述。
- 新增功能 PR 若引入测试债务，必须在 PR body 标注 `Tech-Debt: Test` 并创建 Issue 跟踪。
- 测试债务不允许跨版本累积，每版本至少清理 80%。

---

## 17. CI 门禁集成

> 本规范通过以下 CI 门禁自动化执行，对齐 AGENTS.md 四大质量红线。

### 17.1 测试质量门禁

| 门禁 | 工具 | 触发命令 | 阈值 | 对齐条款 |
|------|------|----------|------|----------|
| 测试结构审计 | `audit-test-structure.py` | `make audit` | 6 项指标 | 第 2、6 节 |
| 覆盖率 | `assert-test-coverage.py` | CI 阶段 | 行 ≥ 95%, 分支 ≥ 90% | 第 2.1 节 |
| 代码重复率 | SonarQube CPD | `sonar-scanner` | < 3% | 第 1.2 节 |
| 命名规范 | `check-code-localization.py` | 编译期 | 纯英文驼峰 | 第 6 节 |
| 魔鬼数字 | `audit-*.py` | pre-push | 零容忍 | 第 9 节 |
| 强制解包 | 静态分析 | CI | 零容忍 | 第 8.1 节 |

### 17.2 PR 准入条件

PR 合并前必须满足：

1. ✅ `make test-unit` 全量绿通（0 Unexpected Failures）
2. ✅ `make audit` 6 项结构指标达标
3. ✅ 新增/修改代码有对应测试（`test_source_file_ratio 0.5–1.5`）
4. ✅ 覆盖率不下降（SonarQube Quality Gate）
5. ✅ 测试代码通过评审清单（第 15 节）
6. ✅ 无 `@Skip`/注释/Flaky 用例（或已标注 Issue 跟踪）

---

## 18. 规范演进与版本管理

### 18.1 规范更新原则

- 本规范随测试体系演进持续维护，每次更新需在下方修订记录中登记。
- 规范变更需经模块负责人评审，重大变更（如新增门禁阈值）需团队共识。
- 规范条款与 CI 门禁脚本必须同步更新，确保「规范即代码」。

### 18.2 与其他文档的同步关系

```
TEST_CASE_STANDARDS.md (本文 — 方法论)
    ├── 对齐 → UNIT_TEST_GUIDE.md (工程层 — 框架/目录/覆盖率)
    ├── 对齐 → TEST_CASES.md (用例库 — TC 清单与映射)
    ├── 对齐 → INTEGRATION_TEST_STRATEGY.md (集成策略)
    ├── 对齐 → SYSTEM_TEST_PLAN.md (系统验收)
    ├── 对齐 → TEST_DRIVEN_FINDINGS.md (问题台账 — 经验输入)
    ├── 对齐 → LAYERING_L0_L3.md (架构分层)
    ├── 对齐 → swift-coding-style.md (编码风格)
    └── 对齐 → development-standards.md (开发标准)
```

### 18.3 修订记录

| 版本 | 日期 | 变更内容 | 作者 |
|------|------|----------|------|
| v1.0 | 2026-10-09 | 初始版本：建立 18 节完整测试用例编写规范，涵盖 FIRST 原则、ISTQB 设计技术、测试替身分类、AAA 结构、断言规范、Fixture 管理、生命周期、快照/性能/UI/集成/并发测试、评审清单、腐化预防、CI 门禁 | CodeFree-O |

---

*相关文档：*
- *`UNIT_TEST_GUIDE.md` — 单元测试工程规范（框架选型、Mock 注入、目录结构、覆盖率）*
- *`TEST_CASES.md` — 测试用例清单库与 TC→XCTest 映射表*
- *`TEST_DRIVEN_FINDINGS.md` — 测试驱动发现问题台账（73 项经验输入）*
- *`INTEGRATION_TEST_STRATEGY.md` — 集成测试隔离机制与防线策略*
- *`SYSTEM_TEST_PLAN.md` — 系统级验收标准与混沌测试*
- *`COVERAGE_REPORT.md` — 代码覆盖率与测试质量报告*
- *`PERFORMANCE_BENCHMARK.md` — 性能基准报告*














