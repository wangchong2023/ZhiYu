//
//  AppEnvironmentTests.swift
//  ZhiYu
//
//  系统层级：[Shared] 测试层
//  核心职责：验证 AppEnvironment 单例初始化后的状态完整性。
//
//  注意：AppEnvironment.shared 在进程启动时由 AppLauncher 初始化，
//  单元测试环境下走 isRunningInUnitTests 轻量路径（DI 不锁定）。
//  本测试验证 shared 实例的核心属性可访问性与非空性。
//

import XCTest
import UFPCore
@testable import ZhiYu

@MainActor
final class AppEnvironmentTests: XCTestCase {

    /// 验证 shared 单例非空
    func testShared_IsNonNil() {
        XCTAssertNotNil(AppEnvironment.shared, "AppEnvironment.shared 应为非空单例")
    }

    /// 验证 shared.store 已初始化（DI 就绪后实例化）
    func testShared_StoreIsInitialized() {
        XCTAssertNotNil(AppEnvironment.shared.store, "store 应在 DI 注册完成后初始化")
    }

    /// 验证 shared.ingestStore 已初始化
    func testShared_IngestStoreIsInitialized() {
        XCTAssertNotNil(AppEnvironment.shared.ingestStore, "ingestStore 应在 DI 注册完成后初始化")
    }

    /// 验证 shared.synthesisStore 已初始化
    func testShared_SynthesisStoreIsInitialized() {
        XCTAssertNotNil(AppEnvironment.shared.synthesisStore, "synthesisStore 应在 DI 注册完成后初始化")
    }

    /// 验证 shared.router 是 Router.shared 单例
    func testShared_RouterIsSharedSingleton() {
        XCTAssertTrue(AppEnvironment.shared.router === Router.shared, "router 应为 Router.shared 单例")
    }

    /// 验证 shared.themeManager 是 ThemeManager 实例
    func testShared_ThemeManagerIsThemeManagerInstance() {
        XCTAssertNotNil(AppEnvironment.shared.themeManager as ThemeManager?, "themeManager 应为 ThemeManager 实例")
    }

    /// 验证 shared.llmService 是 LLMService.shared 单例
    func testShared_LLMServiceIsSharedSingleton() {
        XCTAssertTrue(AppEnvironment.shared.llmService === LLMService.shared, "llmService 应为 LLMService.shared 单例")
    }

    /// 验证 shared.llmConfig 非空
    func testShared_LLMConfigIsInitialized() {
        XCTAssertNotNil(AppEnvironment.shared.llmConfig, "llmConfig 应在 DI 注册完成后初始化")
    }

    /// 验证 shared.platformEnv 可解析且返回非空
    func testShared_PlatformEnvIsAccessible() {
        let platformEnv = AppEnvironment.shared.platformEnv
        XCTAssertFalse(platformEnv.deviceName.isEmpty, "platformEnv.deviceName 不应为空")
        XCTAssertFalse(platformEnv.platformName.isEmpty, "platformEnv.platformName 不应为空")
        XCTAssertFalse(platformEnv.appVersion.isEmpty, "platformEnv.appVersion 不应为空")
    }

    /// 验证 ServiceContainer.shared 在测试环境未锁定（允许测试 reset）
    func testShared_ServiceContainerNotLockedInTestEnvironment() {
        XCTAssertFalse(ServiceContainer.shared.isProductionChainLocked, "测试环境下 ServiceContainer 不应被生产链锁定")
    }
}
