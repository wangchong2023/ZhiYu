//
//  ModuleRegistrarTests.swift
//  ZhiYu
//
//  系统层级：[Shared] 测试层
//  核心职责：验证 CoreModuleRegistrar 与 AppModuleRegistrar 的 DI 注册正确性。
//
//  注意：StorageModuleRegistrar 依赖 DatabaseManager.shared.dbWriter，
//  缺失时 fatalError，故不在此测试（由 AppEnvironment 集成测试覆盖）。
//

import XCTest
import UFPCore
@testable import ZhiYu

@MainActor
final class ModuleRegistrarTests: XCTestCase {

    private var container: ServiceContainer!

    override func setUp() async throws {
        try await super.setUp()
        ServiceContainer.shared.resetForTesting()
        container = ServiceContainer.shared
    }

    override func tearDown() async throws {
        ServiceContainer.shared.resetForTesting()
        container = nil
        try await super.tearDown()
    }

    // MARK: - CoreModuleRegistrar

    /// 验证 CoreModuleRegistrar 注册后 LoggerProtocol 可解析
    func testCoreRegistrar_RegistersLoggerProtocol() {
        CoreModuleRegistrar.register(in: container)
        let logger = container.resolveOptional((any LoggerProtocol).self)
        XCTAssertNotNil(logger, "LoggerProtocol 应在 CoreModuleRegistrar 注册后可解析")
    }

    /// 验证 CoreModuleRegistrar 注册后 KeyStoreProtocol 可解析
    func testCoreRegistrar_RegistersKeyStoreProtocol() {
        CoreModuleRegistrar.register(in: container)
        let keyStore = container.resolveOptional((any KeyStoreProtocol).self)
        XCTAssertNotNil(keyStore, "KeyStoreProtocol 应在 CoreModuleRegistrar 注册后可解析")
    }

    /// 验证 CoreModuleRegistrar 注册后 DeepLinkService 可解析
    func testCoreRegistrar_RegistersDeepLinkService() {
        CoreModuleRegistrar.register(in: container)
        let service = container.resolveOptional(DeepLinkService.self)
        XCTAssertNotNil(service, "DeepLinkService 应在 CoreModuleRegistrar 注册后可解析")
    }

    /// 验证 CoreModuleRegistrar 注册后 PerformanceService 可解析
    func testCoreRegistrar_RegistersPerformanceService() {
        CoreModuleRegistrar.register(in: container)
        let service = container.resolveOptional(PerformanceService.self)
        XCTAssertNotNil(service, "PerformanceService 应在 CoreModuleRegistrar 注册后可解析")
    }

    /// 验证 CoreModuleRegistrar 注册后 AccessibilityService 可解析
    func testCoreRegistrar_RegistersAccessibilityService() {
        CoreModuleRegistrar.register(in: container)
        let service = container.resolveOptional(AccessibilityService.self)
        XCTAssertNotNil(service, "AccessibilityService 应在 CoreModuleRegistrar 注册后可解析")
    }

    /// 验证 CoreModuleRegistrar 注册后 SnapshotService 可解析
    func testCoreRegistrar_RegistersSnapshotService() {
        CoreModuleRegistrar.register(in: container)
        let service = container.resolveOptional(SnapshotService.self)
        XCTAssertNotNil(service, "SnapshotService 应在 CoreModuleRegistrar 注册后可解析")
    }

    /// 验证 CoreModuleRegistrar 注册后 WorkflowService 可解析
    func testCoreRegistrar_RegistersWorkflowService() {
        CoreModuleRegistrar.register(in: container)
        let service = container.resolveOptional(WorkflowService.self)
        XCTAssertNotNil(service, "WorkflowService 应在 CoreModuleRegistrar 注册后可解析")
    }

    /// 验证 CoreModuleRegistrar 注册前服务不可解析（隔离性基线）
    func testCoreRegistrar_BeforeRegistration_ServiceUnresolvable() {
        let logger = container.resolveOptional((any LoggerProtocol).self)
        XCTAssertNil(logger, "注册前 LoggerProtocol 不应可解析")
    }

    // MARK: - AppModuleRegistrar

    /// 验证 AppModuleRegistrar 注册后 Router 可解析
    func testAppRegistrar_RegistersRouter() {
        AppModuleRegistrar.register(in: container)
        let router = container.resolveOptional(Router.self)
        XCTAssertNotNil(router, "Router 应在 AppModuleRegistrar 注册后可解析")
    }

    /// 验证 AppModuleRegistrar 注册的 Router 是 shared 单例
    func testAppRegistrar_RegistersSharedRouterInstance() {
        AppModuleRegistrar.register(in: container)
        let resolved = container.resolve(Router.self)
        XCTAssertTrue(resolved === Router.shared, "注册的 Router 应为 Router.shared 单例")
    }

    /// 验证 AppModuleRegistrar 注册前 Router 不可解析（隔离性基线）
    func testAppRegistrar_BeforeRegistration_RouterUnresolvable() {
        let router = container.resolveOptional(Router.self)
        XCTAssertNil(router, "注册前 Router 不应可解析")
    }
}
