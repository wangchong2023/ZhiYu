# 智宇 (ZhiYu) 单元测试设计规范指南

> **适用范围**：所有向 `Tests/Unit/`、`Tests/Integration/`、`Tests/Performance/` 贡献测试代码的工程师。
> **配套工具**：XCTest、Swift Testing（@Test 宏）、`ServiceContainer` Mock 注入。

---

## 1. 测试框架选型原则

### 1.1 XCTest（必选）
- 所有单元测试均继承自 `XCTestCase`，确保 CI/CD 流水线的统一可发现性。
- 异步测试使用 `async throws` 方法签名 + Swift 并发，禁止使用 `expectation(description:)` 旧范式。

### 1.2 Swift Testing（@Test 宏，推荐）
---

## 1.3 SPM 本地 Package 极速单测 (Swift Package Testing)

项目升级为本地 SPM 模块化后，每个 Package (`UFPCore`, `UFPStorage`, `UFPDesignSystem`, `ZhiYuDomain`, `ZhiYuAICore`, `ZhiYuFeatures`) 均支持独立的秒级命令行测试：

```bash
# 运行底层通用 Package 测试 (无需 iOS 模拟器装载)
swift test --package-path Packages/UFPCore
swift test --package-path Packages/UFPStorage
swift test --package-path Packages/UFPDesignSystem

# 运行智宇业务领域与 AI 中台 Package 测试
swift test --package-path Packages/ZhiYuDomain
swift test --package-path Packages/ZhiYuAICore
swift test --package-path Packages/ZhiYuFeatures
```

### TestMocks 共享依赖模式
各 Package 暴露独立的 `*TestMocks` Library Target（如 `UFPCoreTestMocks`、`ZhiYuDomainTestMocks`），供上层 SPM 测试套件无缝导入使用，生产产物自动拦截测试代码打包。

---

## 2. Mock 注入最佳实践（基于 `ServiceContainer` DI）

### 2.1 核心原则
**严禁在单元测试中直接使用具体实现类**（如 `SQLiteStore`、`OpenAIClient`），必须通过协议注入 Mock 对象。

### 2.2 标准 Mock 注入模式

```swift
// MARK: - Mock 服务定义
/// 实现 AnyPageStoreCapabilities 协议的内存 Mock
final class MockPageStore: AnyPageStoreCapabilities, @unchecked Sendable {
    var pages: [Page] = []
    
    func fetchAll() async throws -> [Page] { pages }
    func insert(_ page: Page) async throws { pages.append(page) }
    func delete(id: UUID) async throws { pages.removeAll { $0.id == id } }
}

// MARK: - 测试用例
final class PageServiceTests: XCTestCase {
    
    var mockStore: MockPageStore!
    var sut: PageService! // System Under Test
    
    override func setUp() async throws {
        try await super.setUp()
        mockStore = MockPageStore()
        // 在独立的 ServiceContainer 中注册 Mock，避免污染生产环境容器
        let container = ServiceContainer()
        container.register(AnyPageStoreCapabilities.self) { self.mockStore }
        sut = PageService(container: container)
    }
    
    override func tearDown() async throws {
        sut = nil
        mockStore = nil
        try await super.tearDown()
    }
    
    func testCreatePage_ShouldPersistToStore() async throws {
        // Given
        let title = "测试页面"
        
        // When
        let page = try await sut.createPage(title: title)
        
        // Then
        XCTAssertEqual(mockStore.pages.count, 1)
        XCTAssertEqual(mockStore.pages.first?.title, title)
    }
}
```

---

## 3. Swift 6 并发测试规范

### 3.1 Actor 隔离测试

```swift
// 正确：使用 @MainActor 标注需要主线程的测试
@MainActor
final class ViewModelTests: XCTestCase {
    func testUpdateTitle() async {
        let vm = KnowledgeListViewModel()
        vm.title = "新标题"
        XCTAssertEqual(vm.title, "新标题")
    }
}

// 正确：测试 actor 内部状态变更
func testActorStateIsolation() async throws {
    let store = SQLiteStore() // actor
    try await store.insert(Page(title: "Test"))
    let count = try await store.count()
    XCTAssertEqual(count, 1)
}
```

### 3.2 防死锁指南
- **严禁**在 `async` 测试体中调用 `.wait()` / `DispatchSemaphore.wait()`，会导致死锁。
- **正确做法**：`try await Task.sleep(nanoseconds:)` 或 `await withCheckedContinuation { ... }`。
- `nonisolated(unsafe)` 标记的属性在测试中可以直接访问，无需切换执行上下文。

---

## 4. 测试目录结构规范

```
Tests/
├── Unit/                    # 纯业务逻辑单元测试（无 IO 依赖）
│   ├── AI/                  # RAGOrchestrator、EmbeddingManager 测试
│   │   └── RAGOrchestratorTests.swift
│   ├── Domain/              # 领域服务测试（PageService、VaultService 等）
│   └── Infrastructure/      # 存储引擎 Mock 注入测试
├── Integration/             # 集成测试（真实 DB 或网络的有界集成）
├── Performance/             # 基准测试（XCTest measureBlock）
│   └── SearchPerformanceTests.swift
├── UI/                      # XCUITest UI 自动化（独立 UITest Runner 进程）
├── Boundary/                # 边界条件与异常路径
├── SnapshotTests/           # SwiftUI 快照测试（需 SnapshotTesting 库）
└── Shared/                  # 测试共享工具（Mock 工厂、Fixture 数据）
    └── TestFixtures.swift
```

---

## 5. 代码覆盖率指标与红线

| 层级 | 路径 | 覆盖率要求 | 说明 |
| :--- | :--- | :--- | :--- |
| **领域层 (L1.5)** | `Sources/Domain/` | **≥ 85%**（红线熔断） | 由 `Tools/ci/assert-test-coverage.py` CI 阶段强制校验 |
| **基础设施层 (L1)** | `Sources/Infrastructure/` | ≥ 70%（目标） | 含 SQLite、LLM 适配、向量引擎 |
| **基础层 (L0)** | `Sources/Core/Base/` | ≥ 60%（目标） | DI 容器、协议定义 |
| **UI 层 (L2)** | `Sources/Features/` | 不强制指标 | 由 UI 自动化测试覆盖 |

### 覆盖率豁免规则
以下文件类型豁免于覆盖率计算（在 `assert-test-coverage.py` 中配置 `exclude_suffixes`）：
- `*Models.swift`：纯数据结构无分支逻辑
- `*Schema.swift`：GRDB 表结构定义
- `*Status.swift`：枚举状态定义

---

## 6. FTS5 搜索基准测试方法

```swift
final class SearchPerformanceTests: XCTestCase {
    
    /// 基准测试：1000 条记录下 FTS5 混合检索响应时间需 < 200ms
    func testHybridSearchPerformance() throws {
        let store = try SQLiteStore(path: ":memory:")
        // 预填充 1000 条测试数据
        try (0..<1000).forEach { i in
            try store.insert(Page(title: "Page \(i)", content: "Content \(i)"))
        }
        
        measure {
            // measureBlock 默认运行 10 次，取平均值
            let results = try? store.search(query: "Content 500", limit: 10)
            XCTAssertNotNil(results)
        }
        
        // 额外：验证 P99 延迟（自定义 XCTMetric）
        let options = XCTMeasureOptions()
        options.iterationCount = 20
        measure(options: options) {
            _ = try? store.vectorSearch(embedding: [0.1, 0.2], topK: 5)
        }
    }
}
```

---

## 7. 命名规范与 GIVEN-WHEN-THEN 约定

```swift
// 格式：test<功能描述>_<条件>_<预期结果>
func testCreatePage_WithValidTitle_ShouldReturnNewPage() async throws { }
func testSearch_WithEmptyQuery_ShouldReturnAllPages() async throws { }
func testDelete_WithNonExistentID_ShouldThrowNotFoundError() async throws { }

// 测试体内部三段注释
func testSomeFeature() async throws {
    // Given（准备测试数据与状态）
    let input = "..."
    
    // When（执行被测代码）
    let result = try await sut.doSomething(with: input)
    
    // Then（断言预期结果）
    XCTAssertEqual(result.status, .success)
}
```

---

## 8. 禁止事项 (Anti-Patterns)

| 禁止行为 | 正确做法 |
| :--- | :--- |
| 测试中直接实例化 `SQLiteStore`（会写真实文件） | 使用 `:memory:` 路径或 Mock 实现 |
| 在单元测试中调用真实 LLM API | 使用 `MockLLMClient` 返回固定 stub 数据 |
| `XCTAssert` 嵌套 `try?` 忽略错误 | 使用 `XCTAssertNoThrow { try ... }` |
| 测试方法中包含 `sleep` 或 `DispatchQueue.async` | 使用 `async/await` 或 `Task` |
| 测试之间共享全局状态（单例） | 每个测试在 `setUp` 创建独立实例 |

---

*本文档是 2026-05-21 P1 重构阶段新增的测试规范文件，应随测试体系演进持续维护。*
*相关文档：`Docs/Testing/SYSTEM_TEST_PLAN.md`、`Docs/Testing/PERFORMANCE_BENCHMARK.md`。*
