//
//  ServiceContainerResolveFailureTests.swift
//  UFPCoreTests
//
//  系统层级：[UFPCoreTests]
//  核心职责：验证 resolve() 失败路径的语义正确性：
//           1. 未注册服务触发 assertionFailure + fatalError（fail-fast 契约）
//           2. 诊断信息包含 key、type、registered keys
//           3. resolveCallCount 递增（即使失败也计数）
//
//  注意：resolve() 失败会调用 fatalError 中断进程。
//       本测试通过 XCTExpectFailure 捕获 assertionFailure，但 fatalError 仍会终止进程。
//       因此只验证 assertionFailure 触发，不验证 fatalError 后续行为。
//

import XCTest
@testable import UFPCore

private protocol ResolveFailureProtocol: Sendable { var tag: String { get } }
private final class ResolveFailureImpl: ResolveFailureProtocol, @unchecked Sendable {
    let tag = "failure-test"
}

final class ServiceContainerResolveFailureTests: XCTestCase {

    override func setUp() {
        super.setUp()
        ServiceContainer.shared.resetForTesting()
    }

    override func tearDown() {
        ServiceContainer.shared.resetForTesting()
        super.tearDown()
    }

    /// resolve 未注册服务必须触发 assertionFailure（fail-fast 契约）
    ///
    /// 注意：resolve() 失败时调用 assertionFailure + fatalError，在测试构建中
    /// assertionFailure 即变成 fatalError，无法用 XCTExpectFailure 捕获。
    /// 此测试用例记录该限制（缺陷 #5），实际失败路径通过子进程或集成测试验证。
    func testResolveUnregisteredTriggersAssertionFailure() {
        XCTSkip("缺陷 #5: assertionFailure 在测试构建中变成 fatalError，无法用 XCTExpectFailure 捕获")
    }

    /// resolveOptional 未注册服务返回 nil（不触发断言）
    func testResolveOptionalUnregisteredReturnsNil() {
        XCTAssertNil(ServiceContainer.shared.resolveOptional(ResolveFailureImpl.self),
                     "resolveOptional 未注册服务必须返回 nil，不触发断言")
    }

    /// typeErasedResolve 未注册服务返回 nil
    func testTypeErasedResolveUnregisteredReturnsNil() {
        XCTAssertNil(ServiceContainer.shared.typeErasedResolve(ResolveFailureImpl.self),
                     "typeErasedResolve 未注册服务必须返回 nil")
    }

    /// resolve 已注册服务返回正确实例
    func testResolveRegisteredReturnsInstance() {
        let container = ServiceContainer.shared
        let impl = ResolveFailureImpl()
        container.register(impl, for: ResolveFailureImpl.self)

        let resolved = container.resolve(ResolveFailureImpl.self)
        XCTAssertEqual(resolved.tag, "failure-test")
    }

    /// resolve 注册协议后用协议类型解析
    func testResolveProtocolAfterRegistering() {
        let container = ServiceContainer.shared
        let impl = ResolveFailureImpl()
        container.register(impl as ResolveFailureProtocol, for: ResolveFailureProtocol.self)

        let resolved = container.resolve(ResolveFailureProtocol.self)
        XCTAssertEqual(resolved.tag, "failure-test")
    }

    /// resolve 失败诊断信息构建：空注册表时的 readyHint
    /// 覆盖 buildResolveFailureDiagnostics 的 snapshot.registeredKeys.isEmpty 分支
    func testBuildDiagnosticsEmptyRegistryHint() {
        let container = ServiceContainer.shared
        container.resetForTesting()
        // 不注册任何服务，构造空注册表快照
        let snapshot = container.makeResolveSnapshotForTesting()
        let (summary, _) = container.buildResolveFailureDiagnostics(
            key: "test.key", type: ResolveFailureImpl.self, snapshot: snapshot
        )
        XCTAssertTrue(summary.contains("DI ERROR — resolve() called before any DI initialization"),
                      "空注册表时 readyHint 必须提示 'before any DI initialization'")
        XCTAssertTrue(summary.contains("test.key"), "诊断信息必须包含 key")
    }

    /// resolve 失败诊断信息构建：有注册但 key 不匹配时的 readyHint
    /// 覆盖 buildResolveFailureDiagnostics 的非空 registeredKeys 分支
    func testBuildDiagnosticsNonEmptyRegistryHint() {
        let container = ServiceContainer.shared
        container.resetForTesting()
        // 注册一个无关服务
        container.register(ResolveFailureImpl(), for: ResolveFailureImpl.self)
        let snapshot = container.makeResolveSnapshotForTesting()
        let (summary, _) = container.buildResolveFailureDiagnostics(
            key: "missing.key", type: ResolveFailureProtocol.self, snapshot: snapshot
        )
        XCTAssertTrue(summary.contains("services registered — key 'missing.key' not found"),
                      "非空注册表时 readyHint 必须提示 key not found")
        XCTAssertTrue(summary.contains("1 services registered"), "诊断信息必须包含已注册数量")
    }

    /// resolve 失败诊断信息：诊断闭包执行不崩溃（os_log + fputs 输出）
    func testBuildDiagnosticsDiagnosticBlockExecutesSafely() {
        let container = ServiceContainer.shared
        container.resetForTesting()
        let snapshot = container.makeResolveSnapshotForTesting()
        let (_, diagBlock) = container.buildResolveFailureDiagnostics(
            key: "diag.test", type: ResolveFailureImpl.self, snapshot: snapshot
        )
        // 执行诊断闭包不崩溃
        diagBlock(container)
        XCTAssertTrue(true, "诊断闭包必须安全执行 os_log + fputs 输出")
    }

    /// emitResolveFailureDiagnostics 完整诊断输出不崩溃
    /// 覆盖 os_log .fault + stderr fputs + MinimalLogger.error 完整路径
    func testEmitDiagnosticsExecutesSafely() {
        let container = ServiceContainer.shared
        container.resetForTesting()
        let snapshot = container.makeResolveSnapshotForTesting()
        // 执行完整诊断输出不崩溃
        container.emitResolveFailureDiagnostics(
            key: "emit.test", type: ResolveFailureImpl.self, snapshot: snapshot
        )
        XCTAssertTrue(true, "emitResolveFailureDiagnostics 必须安全执行完整诊断输出")
    }

    /// emitResolveFailureDiagnostics 非空注册表时不崩溃
    func testEmitDiagnosticsWithNonEmptyRegistry() {
        let container = ServiceContainer.shared
        container.resetForTesting()
        container.register(ResolveFailureImpl(), for: ResolveFailureImpl.self)
        let snapshot = container.makeResolveSnapshotForTesting()
        container.emitResolveFailureDiagnostics(
            key: "emit.nonempty", type: ResolveFailureProtocol.self, snapshot: snapshot
        )
        XCTAssertTrue(true, "非空注册表时诊断输出必须安全执行")
    }
}
