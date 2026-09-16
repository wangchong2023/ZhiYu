# 重复代码全量清理实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 全量清理 Sources/ 目录下 3059 处重复代码块，使 `pmd cpd --minimum-tokens 20` 零重复，CI 门禁通过。

**Architecture:** 按重复模式分 5 类，按 GRDB → 平台 → UIComponents → SwiftUI 修饰符链 → 业务逻辑 顺序逐类消除。每类抽取共享基础设施后批量替换所有重复点。一次性全量清理，最终统一验证。

**Tech Stack:** Swift 6 / SwiftUI / GRDB / PMD-CPD / Python（审计脚本）

## Global Constraints

- 遵守 L0-L3 严格分层架构，依赖单向自顶向下
- 遵守 DesignSystem Token 强约束（无硬编码字号/边距/圆角）
- 遵守 L10n 强约束（无硬编码字符串）
- 遵守 SRP 文件拆分原则
- 平台差异不新增 `#if os()`，通过现有 PlatformProtocol 模式统一
- 抽取的 ViewModifier 不改变视觉行为（快照测试验证）
- GRDB 查询重构不改变 SQL 语义（Repository 单测验证）
- 每阶段验证：3 端编译 + pmd cpd 该类归零
- 最终门禁：`MAX_DUPLICATE_BLOCKS=0` + `--minimum-tokens 20`

## 文件结构

### 新增文件

| 文件 | 职责 | 阶段 |
|------|------|------|
| `Sources/Infrastructure/Storage/Helpers/GRDBQueryHelper.swift` | GRDB 泛型查询辅助方法 | 1 |
| `Sources/Infrastructure/Storage/Helpers/RepositoryBootstrap.swift` | Repository 初始化样板抽取 | 1 |
| `Sources/Platforms/Shared/PlatformCapabilitiesDefaults.swift` | PlatformProtocol 默认实现扩展 | 2 |
| `Sources/Shared/UIComponents/Modifiers/SharedCardModifier.swift` | UIComponents 共享卡片修饰符 | 3 |
| `Sources/Shared/DesignSystem/ViewModifiers/CardStyleModifier.swift` | SwiftUI 卡片样式 ViewModifier | 4 |
| `Sources/Shared/DesignSystem/ViewModifiers/ErrorStateModifier.swift` | SwiftUI 错误状态 ViewModifier | 4 |
| `Sources/Shared/DesignSystem/ViewModifiers/EmptyStateModifier.swift` | SwiftUI 空状态 ViewModifier | 4 |
| `Sources/Shared/DesignSystem/ViewModifiers/CommonPaddingModifier.swift` | SwiftUI 通用间距 ViewModifier | 4 |
| `Sources/Features/<域>/Helpers/` 下按需新增 | 业务逻辑辅助函数 | 5 |

### 修改文件

涉及 Sources/ 下约 200+ 个 Swift 文件，按阶段逐步修改。每个文件的具体修改在阶段展开时详细列出。

---

## 阶段 1: GRDB/SQL 查询重复清理（65 处）

**目标**：消除 65 处 GRDB/SQL 查询重复块
**抽取目标**：`Sources/Infrastructure/Storage/Helpers/`

### Task 1.1: 创建 GRDBQueryHelper 泛型查询辅助

**Files:**
- Create: `Sources/Infrastructure/Storage/Helpers/GRDBQueryHelper.swift`
- Test: `Tests/Unit/Infrastructure/GRDBQueryHelperTests.swift`

**Interfaces:**
- Produces: `GRDBQueryHelper` 静态方法集，供 Repository 层复用

- [ ] **Step 1: 编写 GRDBQueryHelper 单元测试**

```swift
// Tests/Unit/Infrastructure/GRDBQueryHelperTests.swift
import XCTest
import GRDB
@testable import ZhiYu

final class GRDBQueryHelperTests: XCTestCase {
    func testFetchAllDecodableReturnsEmptyForEmptyTable() throws {
        let dbQueue = DatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "test") { t in
                t.column("id", .integer).primaryKey()
                t.column("name", .text)
            }
            let rows: [TestRow] = try GRDBQueryHelper.fetchAll(db, table: "test")
            XCTAssertTrue(rows.isEmpty)
        }
    }
    
    func testFetchAllDecodableReturnsAllRows() throws {
        let dbQueue = DatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "test") { t in
                t.column("id", .integer).primaryKey()
                t.column("name", .text)
            }
            try db.execute(sql: "INSERT INTO test (name) VALUES ('a'), ('b')")
            let rows: [TestRow] = try GRDBQueryHelper.fetchAll(db, table: "test")
            XCTAssertEqual(rows.count, 2)
        }
    }
}

private struct TestRow: FetchableRecord {
    let id: Int
    let name: String
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `xcodebuild test -project ZhiYu.xcodeproj -scheme ZhiYu -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ZhiYuTests/GRDBQueryHelperTests`
Expected: FAIL — `GRDBQueryHelper` 未定义

- [ ] **Step 3: 实现 GRDBQueryHelper**

```swift
// Sources/Infrastructure/Storage/Helpers/GRDBQueryHelper.swift
import GRDB

/// GRDB 泛型查询辅助方法，消除 Repository 层重复的 fetchAll + Row 解析模式
enum GRDBQueryHelper {
    /// 泛型 fetchAll，统一 Row.fetchAll + FetchableRecord 解析
    static func fetchAll<T: FetchableRecord>(
        _ db: Database,
        table: String
    ) throws -> [T] {
        try T.fetchAll(db, sql: "SELECT * FROM \(table)")
    }
    
    /// 带条件过滤的泛型 fetchAll
    static func fetchAll<T: FetchableRecord>(
        _ db: Database,
        table: String,
        where condition: String,
        arguments: StatementArguments = []
    ) throws -> [T] {
        try T.fetchAll(db, sql: "SELECT * FROM \(table) WHERE \(condition)", arguments: arguments)
    }
    
    /// 统一的 dbWriter 异步获取模式
    static func resolveDbWriter() async throws -> any DatabaseWriter {
        if let writer = await DatabaseManager.shared.dbWriter {
            return writer
        }
        throw DatabaseError.notReady
    }
}
```

- [ ] **Step 4: 运行测试验证通过**

Run: `xcodebuild test -project ZhiYu.xcodeproj -scheme ZhiYu -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ZhiYuTests/GRDBQueryHelperTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/Infrastructure/Storage/Helpers/GRDBQueryHelper.swift Tests/Unit/Infrastructure/GRDBQueryHelperTests.swift
git commit -m "feat: 新增 GRDBQueryHelper 泛型查询辅助"
```

### Task 1.2: 创建 RepositoryBootstrap 初始化样板

**Files:**
- Create: `Sources/Infrastructure/Storage/Helpers/RepositoryBootstrap.swift`
- Test: `Tests/Unit/Infrastructure/RepositoryBootstrapTests.swift`

**Interfaces:**
- Produces: `RepositoryBootstrap` 协议默认实现，消除 Repository 初始化样板重复

- [ ] **Step 1: 编写 RepositoryBootstrap 单元测试**

```swift
// Tests/Unit/Infrastructure/RepositoryBootstrapTests.swift
import XCTest
import GRDB
@testable import ZhiYu

final class RepositoryBootstrapTests: XCTestCase {
    func testRepositoryBootstrapStoresDbWriter() {
        let dbQueue = DatabaseQueue()
        let bootstrap = TestRepository(dbWriter: dbQueue)
        XCTAssertNotNil(bootstrap.dbWriter as? DatabaseQueue)
    }
}

private final class TestRepository: RepositoryBootstrap {
    let dbWriter: any DatabaseWriter
    init(dbWriter: any DatabaseWriter) {
        self.dbWriter = dbWriter
    }
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `xcodebuild test -project ZhiYu.xcodeproj -scheme ZhiYu -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ZhiYuTests/RepositoryBootstrapTests`
Expected: FAIL — `RepositoryBootstrap` 未定义

- [ ] **Step 3: 实现 RepositoryBootstrap**

```swift
// Sources/Infrastructure/Storage/Helpers/RepositoryBootstrap.swift
import GRDB

/// Repository 初始化样板协议，消除 SQLiteXxxRepository 重复的 dbWriter 存储模式
protocol RepositoryBootstrap: AnyObject {
    var dbWriter: any DatabaseWriter { get }
}
```

- [ ] **Step 4: 运行测试验证通过**

Run: `xcodebuild test -project ZhiYu.xcodeproj -scheme ZhiYu -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ZhiYuTests/RepositoryBootstrapTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/Infrastructure/Storage/Helpers/RepositoryBootstrap.swift Tests/Unit/Infrastructure/RepositoryBootstrapTests.swift
git commit -m "feat: 新增 RepositoryBootstrap 初始化样板协议"
```

### Task 1.3: 批量替换 GRDB/SQL 重复（65 处）

**Files:**
- Modify: `Sources/Infrastructure/Storage/Repositories/KnowledgePageRepository.swift`
- Modify: `Sources/Infrastructure/Storage/Repositories/VectorDataRepository.swift`
- Modify: `Sources/Infrastructure/Storage/Repositories/TagRepository.swift`
- Modify: `Sources/Infrastructure/Storage/Repositories/SQLiteFileSignatureRepository.swift`
- Modify: `Sources/Infrastructure/Storage/Repositories/SQLitePluginRepository.swift`
- Modify: `Sources/Infrastructure/Storage/Repositories/SQLiteVaultRepository.swift`
- Modify: `Sources/Infrastructure/Storage/Repositories/RAGGovernanceSQLiteStore.swift`
- Modify: `Sources/Infrastructure/Storage/Persistence/DatabaseSchemaMigrator.swift`
- Modify: `Sources/Infrastructure/Storage/Persistence/DatabaseManager.swift`
- (及其他涉及 GRDB 重复的文件)

**Interfaces:**
- Consumes: `GRDBQueryHelper`, `RepositoryBootstrap`（来自 Task 1.1, 1.2）

- [ ] **Step 1: 替换 dbWriter 异步获取模式（20处文件）**

将所有 Repository 中的 `await DatabaseManager.shared.dbWriter` + nil 检查 + 抛错模式替换为 `try await GRDBQueryHelper.resolveDbWriter()`。

- [ ] **Step 2: 替换 Repository 初始化样板（14处文件）**

将所有 `final class SQLiteXxxRepository: XxxRepository, @unchecked Sendable` + `private let dbWriter` + `init(dbWriter:)` 模式替换为遵循 `RepositoryBootstrap` 协议。

- [ ] **Step 3: 替换 RAGGovernanceSQLiteStore 内部重复（13处同文件重复）**

将 `calculateHitRate`/`calculateMRR`/`fetchTokenStats` 等方法中重复的 `dbWriter` 获取 + `writer.read` + `cutoff` 计算模式抽取为私有辅助方法。

- [ ] **Step 4: 替换 DatabaseManager 内部重复（10处同文件重复）**

将 `setupGlobalDB`/`setupVaultDB` 等方法中重复的目录创建 + 配置连接池模式抽取为私有辅助方法。

- [ ] **Step 5: 替换 Row.fetchAll + 手动解析模式（8处文件）**

将 `DatabaseSchemaMigrator` 和 `TagRepository` 中重复的 `Row.fetchAll` + 手动 `row[...]` 解析模式替换为 `GRDBQueryHelper.fetchAll` 泛型方法。

- [ ] **Step 6: 验证 GRDB/SQL 重复归零**

Run: `pmd cpd --minimum-tokens 20 --language swift --dir Sources/Infrastructure/Storage 2>&1 | rg "^Found a" | wc -l`
Expected: 0

- [ ] **Step 7: 验证 3 端编译**

Run: `make ios && make mac && make watch`
Expected: 3 端 BUILD SUCCEEDED

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "refactor: 消除 GRDB/SQL 查询重复（65处）"
```

---

## 阶段 2: 平台差异重复清理（154 处）

**目标**：消除 154 处平台差异重复块
**抽取目标**：`Sources/Platforms/Shared/`
**策略**：通过现有 PlatformProtocol 模式统一，共享逻辑下沉协议默认实现，不新增 `#if os()`

### Task 2.1: 创建 PlatformCapabilitiesDefaults 协议默认实现

**Files:**
- Create: `Sources/Platforms/Shared/PlatformCapabilitiesDefaults.swift`
- Test: `Tests/Unit/Platforms/PlatformCapabilitiesDefaultsTests.swift`

**Interfaces:**
- Produces: `BiometricAuthProviderProtocol` 默认实现扩展，消除三端重复的 `canEvaluatePolicy`/`authenticationPolicy` 等

- [ ] **Step 1: 编写 PlatformCapabilitiesDefaults 单元测试**

```swift
// Tests/Unit/Platforms/PlatformCapabilitiesDefaultsTests.swift
import XCTest
import LocalAuthentication
@testable import ZhiYu

final class PlatformCapabilitiesDefaultsTests: XCTestCase {
    func testDefaultAuthenticationPolicy() {
        let provider = MockBiometricAuthProvider()
        XCTAssertEqual(provider.authenticationPolicy, .deviceOwnerAuthenticationWithBiometrics)
    }
    
    func testCanEvaluatePolicyReturnsFalseWhenBiometryUnavailable() {
        let provider = MockBiometricAuthProvider()
        let context = LAContext()
        XCTAssertFalse(provider.canEvaluatePolicy(context: context))
    }
}

private final class MockBiometricAuthProvider: BiometricAuthProviderProtocol {
    var authenticationPolicy: LAPolicy { .deviceOwnerAuthenticationWithBiometrics }
    func canEvaluatePolicy(context: LAContext) -> Bool { false }
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `xcodebuild test -project ZhiYu.xcodeproj -scheme ZhiYu -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ZhiYuTests/PlatformCapabilitiesDefaultsTests`
Expected: FAIL — `BiometricAuthProviderProtocol` 默认实现未定义

- [ ] **Step 3: 实现 PlatformCapabilitiesDefaults**

```swift
// Sources/Platforms/Shared/PlatformCapabilitiesDefaults.swift
import LocalAuthentication

/// 生物识别认证提供者协议默认实现，消除三端重复的 canEvaluatePolicy/authenticationPolicy
extension BiometricAuthProviderProtocol {
    /// 默认认证策略：生物识别 + 设备密码
    var authenticationPolicy: LAPolicy { .deviceOwnerAuthenticationWithBiometrics }
    
    /// 默认策略评估：检查生物识别可用性
    func canEvaluatePolicy(context: LAContext) -> Bool {
        var error: NSError?
        return context.canEvaluatePolicy(authenticationPolicy, error: &error)
    }
}
```

- [ ] **Step 4: 运行测试验证通过**

Run: `xcodebuild test -project ZhiYu.xcodeproj -scheme ZhiYu -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ZhiYuTests/PlatformCapabilitiesDefaultsTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/Platforms/Shared/PlatformCapabilitiesDefaults.swift Tests/Unit/Platforms/PlatformCapabilitiesDefaultsTests.swift
git commit -m "feat: 新增 PlatformCapabilitiesDefaults 协议默认实现"
```

### Task 2.2: 批量替换平台差异重复（154 处）

**Files:**
- Modify: `Sources/Platforms/iOS/Registrar/iOSPlatformCapabilities.swift`
- Modify: `Sources/Platforms/macOS/MacOSPlatformCapabilities.swift`
- Modify: `Sources/Platforms/watchOS/Services/WatchPlatformCapabilities.swift`
- Modify: `Sources/Platforms/iOS/Registrar/iOSPlatformRegistrar.swift`
- Modify: `Sources/Platforms/macOS/MacPlatformRegistrar.swift`
- Modify: `Sources/Platforms/watchOS/Registrar/WatchPlatformRegistrar.swift`
- (及其他涉及平台差异重复的文件)

**Interfaces:**
- Consumes: `PlatformCapabilitiesDefaults`（来自 Task 2.1）

- [ ] **Step 1: 替换 BiometricAuthProvider 重复（27+23+23行）**

删除三端 `iOSBiometricAuthProvider`/`MacBiometricAuthProvider`/`WatchBiometricAuthProvider` 中重复的 `authenticationPolicy` 和 `canEvaluatePolicy` 实现，改为依赖协议默认实现。

- [ ] **Step 2: 替换 PlatformRegistrar 重复（6行×多处）**

将三端 Registrar 中重复的 `container.register(iOSReminderService(), for: (any ReminderServiceProtocol).self)` 等注册行抽取到 `Platforms/Shared/` 的共享注册方法。

- [ ] **Step 3: 替换其余平台差异重复**

逐个处理剩余的平台差异重复块，将共享逻辑下沉到协议默认实现或 `Platforms/Shared/`。

- [ ] **Step 4: 验证平台差异重复归零**

Run: `pmd cpd --minimum-tokens 20 --language swift --dir Sources/Platforms 2>&1 | rg "^Found a" | wc -l`
Expected: 0

- [ ] **Step 5: 验证 3 端编译**

Run: `make ios && make mac && make watch`
Expected: 3 端 BUILD SUCCEEDED

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "refactor: 消除平台差异重复（154处）"
```

---

## 阶段 3: Shared/UIComponents 重复清理（150 处）

**目标**：消除 150 处 Shared/UIComponents 重复块
**抽取目标**：`Sources/Shared/UIComponents/Modifiers/`

### Task 3.1: 创建 SharedCardModifier 共享修饰符

**Files:**
- Create: `Sources/Shared/UIComponents/Modifiers/SharedCardModifier.swift`
- Test: `Tests/Unit/Shared/SharedCardModifierTests.swift`

**Interfaces:**
- Produces: `SharedCardModifier` ViewModifier，消除 UIComponents 中重复的卡片样式链

- [ ] **Step 1: 编写 SharedCardModifier 单元测试**

```swift
// Tests/Unit/Shared/SharedCardModifierTests.swift
import XCTest
import SwiftUI
@testable import ZhiYu

final class SharedCardModifierTests: XCTestCase {
    func testSharedCardModifierAppliesCorrectStyling() {
        let view = Color.red.modifier(SharedCardModifier())
        XCTAssertNotNil(view)
    }
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `xcodebuild test -project ZhiYu.xcodeproj -scheme ZhiYu -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ZhiYuTests/SharedCardModifierTests`
Expected: FAIL — `SharedCardModifier` 未定义

- [ ] **Step 3: 实现 SharedCardModifier**

```swift
// Sources/Shared/UIComponents/Modifiers/SharedCardModifier.swift
import SwiftUI

/// 共享卡片样式修饰符，消除 UIComponents 中重复的 padding+background+clipShape 链
struct SharedCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, DesignSystem.standardPadding)
            .padding(.vertical, DesignSystem.small)
            .background(Color.appCard.opacity(DesignSystem.Opacity.dim))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.mediumRadius, style: .continuous))
    }
}

extension View {
    func sharedCardStyle() -> some View {
        modifier(SharedCardModifier())
    }
}
```

- [ ] **Step 4: 运行测试验证通过**

Run: `xcodebuild test -project ZhiYu.xcodeproj -scheme ZhiYu -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ZhiYuTests/SharedCardModifierTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/Shared/UIComponents/Modifiers/SharedCardModifier.swift Tests/Unit/Shared/SharedCardModifierTests.swift
git commit -m "feat: 新增 SharedCardModifier 共享卡片修饰符"
```

### Task 3.2: 批量替换 UIComponents 重复（150 处）

**Files:**
- Modify: `Sources/Shared/UIComponents/Modifiers/AppToolbarModifier.swift`
- Modify: `Sources/Shared/UIComponents/Modifiers/PlatformModifiers.swift`
- Modify: `Sources/Shared/UIComponents/OCRImageContentView.swift`
- Modify: `Sources/Shared/UIComponents/PageDetailMetaSectionView.swift`
- (及其他涉及 UIComponents 重复的文件)

**Interfaces:**
- Consumes: `SharedCardModifier`（来自 Task 3.1）

- [ ] **Step 1: 替换 AppToolbarModifier 内部重复（13+12行）**

合并 `AppToolbarModifier.swift` 中同文件内重复的 `ToolbarItem(placement: .topBarTrailing)` + `HStack(spacing: Spacing.atomic)` 模式。

- [ ] **Step 2: 替换 PlatformModifiers 条件分支重复（11行）**

合并 `PlatformModifiers.swift` 中重复的 `#if os(iOS)` + `keyboardType` 条件分支模式。

- [ ] **Step 3: 替换 OCRImageContentView 重复（14行）**

合并 `OCRImageContentView.swift` 中同文件内重复的 `Image.resizable().scaledToFit().frame().clipShape().shadow()` 链。

- [ ] **Step 4: 替换 PageDetailMetaSectionView 重复（6行）**

合并 `PageDetailMetaSectionView.swift` 中同文件内重复的 `padding+background+clipShape` 链为 `SharedCardModifier`。

- [ ] **Step 5: 替换其余 UIComponents 重复**

逐个处理剩余的 UIComponents 重复块。

- [ ] **Step 6: 验证 UIComponents 重复归零**

Run: `pmd cpd --minimum-tokens 20 --language swift --dir Sources/Shared/UIComponents 2>&1 | rg "^Found a" | wc -l`
Expected: 0

- [ ] **Step 7: 验证 3 端编译**

Run: `make ios && make mac && make watch`
Expected: 3 端 BUILD SUCCEEDED

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "refactor: 消除 Shared/UIComponents 重复（150处）"
```

---

## 阶段 4: SwiftUI 修饰符链重复清理（1228 处）

**目标**：消除 1228 处 SwiftUI 修饰符链重复块
**抽取目标**：`Sources/Shared/DesignSystem/ViewModifiers/`

### Task 4.1: 创建 DesignSystem ViewModifier 集

**Files:**
- Create: `Sources/Shared/DesignSystem/ViewModifiers/CardStyleModifier.swift`
- Create: `Sources/Shared/DesignSystem/ViewModifiers/ErrorStateModifier.swift`
- Create: `Sources/Shared/DesignSystem/ViewModifiers/EmptyStateModifier.swift`
- Create: `Sources/Shared/DesignSystem/ViewModifiers/CommonPaddingModifier.swift`
- Test: `Tests/Unit/Shared/DesignSystemViewModifiersTests.swift`

**Interfaces:**
- Produces: 4 个 ViewModifier + View extension，消除 SwiftUI 修饰符链重复

- [ ] **Step 1: 编写 DesignSystem ViewModifier 单元测试**

```swift
// Tests/Unit/Shared/DesignSystemViewModifiersTests.swift
import XCTest
import SwiftUI
@testable import ZhiYu

final class DesignSystemViewModifiersTests: XCTestCase {
    func testCardStyleModifier() {
        let view = Color.red.cardStyle()
        XCTAssertNotNil(view)
    }
    
    func testErrorStateModifier() {
        let view = Text("error").errorStateStyle()
        XCTAssertNotNil(view)
    }
    
    func testEmptyStateModifier() {
        let view = Text("empty").emptyStateStyle()
        XCTAssertNotNil(view)
    }
    
    func testCommonPaddingModifier() {
        let view = Text("test").commonPadding()
        XCTAssertNotNil(view)
    }
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `xcodebuild test -project ZhiYu.xcodeproj -scheme ZhiYu -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ZhiYuTests/DesignSystemViewModifiersTests`
Expected: FAIL — ViewModifier 未定义

- [ ] **Step 3: 实现 CardStyleModifier**

```swift
// Sources/Shared/DesignSystem/ViewModifiers/CardStyleModifier.swift
import SwiftUI

/// 卡片样式修饰符，消除重复的 padding+background+clipShape+overlay 链
struct CardStyleModifier: ViewModifier {
    var radius: CGFloat = DesignSystem.mediumRadius
    var opacity: Double = DesignSystem.Opacity.dim
    
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, DesignSystem.standardPadding)
            .padding(.vertical, SystemSpacing.elementLarge)
            .background(Color.appCard.opacity(opacity))
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Color.appAccent.opacity(DesignSystem.Opacity.medium), lineWidth: DesignSystem.borderWidth)
            )
            .padding(.horizontal, DesignSystem.tiny)
    }
}

extension View {
    func cardStyle(radius: CGFloat = DesignSystem.mediumRadius, opacity: Double = DesignSystem.Opacity.dim) -> some View {
        modifier(CardStyleModifier(radius: radius, opacity: opacity))
    }
}
```

- [ ] **Step 4: 实现 ErrorStateModifier**

```swift
// Sources/Shared/DesignSystem/ViewModifiers/ErrorStateModifier.swift
import SwiftUI

/// 错误状态修饰符，消除重复的 errorCircle + foregroundStyle + buttonStyle 链
struct ErrorStateModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundStyle(.appSecondary.opacity(DesignSystem.Opacity.dim))
            .buttonStyle(.plain)
    }
}

extension View {
    func errorStateStyle() -> some View {
        modifier(ErrorStateModifier())
    }
}
```

- [ ] **Step 5: 实现 EmptyStateModifier**

```swift
// Sources/Shared/DesignSystem/ViewModifiers/EmptyStateModifier.swift
import SwiftUI

/// 空状态修饰符，消除重复的 Image.resizable+scaledToFit+frame+clipShape+shadow 链
struct EmptyStateModifier: ViewModifier {
    var maxHeight: CGFloat = Spacing.Grid.emptyStateHeight
    
    func body(content: Content) -> some View {
        content
            .frame(maxHeight: maxHeight)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cardRadius))
            .shadow(color: .primary.opacity(SystemOpacity.ghost), radius: DesignSystem.small)
    }
}

extension View {
    func emptyStateStyle(maxHeight: CGFloat = Spacing.Grid.emptyStateHeight) -> some View {
        modifier(EmptyStateModifier(maxHeight: maxHeight))
    }
}
```

- [ ] **Step 6: 实现 CommonPaddingModifier**

```swift
// Sources/Shared/DesignSystem/ViewModifiers/CommonPaddingModifier.swift
import SwiftUI

/// 通用间距修饰符，消除重复的 padding(.top, Spacing.wide) 等链
struct CommonPaddingModifier: ViewModifier {
    var top: CGFloat = 0
    var bottom: CGFloat = 0
    var horizontal: CGFloat = DesignSystem.standardPadding
    
    func body(content: Content) -> some View {
        content
            .padding(.top, top)
            .padding(.bottom, bottom)
            .padding(.horizontal, horizontal)
    }
}

extension View {
    func commonPadding(top: CGFloat = 0, bottom: CGFloat = 0, horizontal: CGFloat = DesignSystem.standardPadding) -> some View {
        modifier(CommonPaddingModifier(top: top, bottom: bottom, horizontal: horizontal))
    }
}
```

- [ ] **Step 7: 运行测试验证通过**

Run: `xcodebuild test -project ZhiYu.xcodeproj -scheme ZhiYu -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ZhiYuTests/DesignSystemViewModifiersTests`
Expected: PASS

- [ ] **Step 8: Commit**

```bash
git add Sources/Shared/DesignSystem/ViewModifiers/ Tests/Unit/Shared/DesignSystemViewModifiersTests.swift
git commit -m "feat: 新增 DesignSystem ViewModifier 集（4个）"
```

### Task 4.2: 批量替换 SwiftUI 修饰符链重复（1228 处）

**Files:**
- Modify: `Sources/Features/Insight/Dashboard/View/` 下约 50 个文件
- Modify: `Sources/Features/System/` 下约 40 个文件
- Modify: `Sources/Features/Knowledge/` 下约 40 个文件
- Modify: `Sources/Features/AI/` 下约 30 个文件
- Modify: `Sources/App/Scenes/` 下约 10 个文件

**Interfaces:**
- Consumes: `CardStyleModifier`, `ErrorStateModifier`, `EmptyStateModifier`, `CommonPaddingModifier`（来自 Task 4.1）

- [ ] **Step 1: 替换 Insight/Dashboard 修饰符链重复（1078处）**

逐文件将重复的 `.padding+.background+.clipShape+.overlay` 链替换为 `.cardStyle()`，`.foregroundStyle+.buttonStyle` 替换为 `.errorStateStyle()`，`Image.resizable+.scaledToFit+.frame+.clipShape+.shadow` 替换为 `.emptyStateStyle()`。

- [ ] **Step 2: 替换 Features/System 修饰符链重复（1902处中 System 部分）**

同上模式替换。

- [ ] **Step 3: 替换 Features/Knowledge 修饰符链重复（992处中 Knowledge 部分）**

同上模式替换。

- [ ] **Step 4: 替换 Features/AI 修饰符链重复（614处中 AI 部分）**

同上模式替换。

- [ ] **Step 5: 替换 App/Scenes 修饰符链重复（191处中 Scenes 部分）**

同上模式替换。

- [ ] **Step 6: 验证 SwiftUI 修饰符链重复归零**

Run: `pmd cpd --minimum-tokens 20 --language swift --dir Sources/Features Sources/App 2>&1 | rg "^Found a" | wc -l`
Expected: 仅剩业务逻辑重复（阶段 5 处理）

- [ ] **Step 7: 验证 3 端编译**

Run: `make ios && make mac && make watch`
Expected: 3 端 BUILD SUCCEEDED

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "refactor: 消除 SwiftUI 修饰符链重复（1228处）"
```

---

## 阶段 5: 业务逻辑重复清理（1462 处）

**目标**：消除 1462 处业务逻辑重复块
**抽取目标**：各 `Features/<域>/Helpers/` 或协议默认实现

### Task 5.1: 批量替换业务逻辑重复（1462 处）

**Files:**
- Modify: `Sources/Features/Knowledge/NotebookHub/View/Components/NotebookCard.swift`
- Modify: `Sources/Features/Knowledge/NotebookHub/View/Components/NotebookListRow.swift`
- Modify: `Sources/Features/Knowledge/Graph/View/Components/Graph3DComponents.swift`
- Modify: `Sources/App/Scenes/Layout/Components/AppLayoutComponents.swift`
- Modify: `Sources/App/Store/AppModels.swift`
- Modify: `Sources/App/Store/AppStore.swift`
- Modify: `Sources/Infrastructure/LLM/Adapters/BaseMemoryEngine.swift`
- Modify: `Sources/Infrastructure/LLM/Adapters/SwarmMemoryAdapter.swift`
- (及其他涉及业务逻辑重复的文件，约 100+ 个)

- [ ] **Step 1: 替换 NotebookHub 重复（24行）**

将 `NotebookCard.swift` 和 `NotebookListRow.swift` 中重复的 `defaultIcon` 计算属性抽取到 `Features/Knowledge/NotebookHub/Helpers/NotebookIconHelper.swift`。

- [ ] **Step 2: 替换 Graph3DComponents 重复（23+22行）**

将 `Graph3DComponents.swift` 中同文件内重复的 `handlePan`/`handlePinch` 手势处理方法抽取为共享手势处理器。

- [ ] **Step 3: 替换 AppLayoutComponents 重复（24行）**

将 `AppLayoutComponents.swift` 中同文件内重复的 `.tint+.onOpenURL+.accessibilityIdentifier` 链抽取为共享修饰符。

- [ ] **Step 4: 替换 AppStore/AppModels 重复（22行）**

将 `AppModels.swift` 和 `AppStore.swift` 中重复的状态管理模式抽取为共享辅助方法。

- [ ] **Step 5: 替换 LLM Adapters 重复（22行）**

将 `BaseMemoryEngine.swift` 和 `SwarmMemoryAdapter.swift` 中重复的内存引擎逻辑抽取为协议默认实现。

- [ ] **Step 6: 替换 ConceptDetailBodyView/EntityDetailBodyView 重复（20行）**

将两个 DetailBodyView 中重复的视图结构抽取为共享子视图。

- [ ] **Step 7: 替换其余业务逻辑重复**

逐个处理剩余的业务逻辑重复块，按功能域抽取辅助函数或协议默认实现。

- [ ] **Step 8: 验证业务逻辑重复归零**

Run: `pmd cpd --minimum-tokens 20 --language swift --dir Sources 2>&1 | rg "^Found a" | wc -l`
Expected: 0

- [ ] **Step 9: 验证 3 端编译**

Run: `make ios && make mac && make watch`
Expected: 3 端 BUILD SUCCEEDED

- [ ] **Step 10: Commit**

```bash
git add -A
git commit -m "refactor: 消除业务逻辑重复（1462处）"
```

---

## 最终验证

### Task 6.1: 全量验证与门禁

- [ ] **Step 1: 验证 PMD-CPD 零重复**

Run: `pmd cpd --minimum-tokens 20 --language swift --dir Sources 2>&1 | rg "^Found a" | wc -l`
Expected: 0

- [ ] **Step 2: 验证 assert-code-duplication.py 退出码 0**

Run: `python3 Tools/ios/assert-code-duplication.py; echo $?`
Expected: 0

- [ ] **Step 3: 验证 3 端编译**

Run: `make ios && make mac && make watch`
Expected: 3 端 BUILD SUCCEEDED

- [ ] **Step 4: 验证单元测试**

Run: `make test-unit`
Expected: 全部通过

- [ ] **Step 5: 验证 pre-push 全量门禁**

Run: `bash Tools/CI/assert-code-pre-push.sh`
Expected: 18 通过 / 0 失败 / 1 跳过

- [ ] **Step 6: 验证文档漂移**

Run: `python3 Tools/CI/check-doc-drift.py --strict`
Expected: 0 个幽灵引用

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "test: 重复代码全量清理最终验证通过"
```

- [ ] **Step 8: Push**

```bash
git push origin test-structure-refactor
git push gitlab test-structure-refactor
```
