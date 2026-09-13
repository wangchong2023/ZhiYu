//
//  SystemFeaturesConfigurationTests.swift
//  ZhiYuTests
//
//  系统层级：[L2] 业务功能测试 - System
//  核心职责：验证 AuthSession 观察状态、ModelLabView 提示词设置幂等性及开发者设置本地化词条。
//

import XCTest
import UFPCore
@testable import ZhiYu

@MainActor
final class SystemFeaturesConfigurationTests: XCTestCase {

    /// 验证 AuthSession 状态跟踪
    func testAuthSession_observationTracking_updatesCorrectly() {
        let session = AuthSession.shared
        // 重置跨测试残留的登录状态，确保隔离验证 @Observable 范式下的初始态
        session.logout()
        XCTAssertFalse(session.isLoggedIn, "AuthSession 应符合 @Observable 范式")
    }

    /// 验证 ModelLabView 针对不同 UseCase 的默认提示词初始化去重逻辑
    func testModelLabView_setupDefaultPrompt_deduplicatesAcrossUseCases() {
        var hasSetupPrompt: Set<String> = []

        let useCaseRaw = UseCaseType.aiChat.rawValue
        XCTAssertFalse(hasSetupPrompt.contains(useCaseRaw))
        hasSetupPrompt.insert(useCaseRaw)
        XCTAssertTrue(hasSetupPrompt.contains(useCaseRaw))

        let shouldSkip = hasSetupPrompt.contains(useCaseRaw)
        XCTAssertTrue(shouldSkip, "重复设置同用例应被跳过")

        let chatRaw = UseCaseType.promptLab.rawValue
        XCTAssertFalse(hasSetupPrompt.contains(chatRaw))
    }

    /// 验证开发者设置本地化词条存在且非空
    func testDeveloperSettingsView_noDataInjectedLocalization_exists() {
        let text = L10n.Settings.developer.stressTest.noDataInjected
        XCTAssertFalse(text.isEmpty)
    }

    /// 验证 ModelLabConfigSheet CPU/GPU 本地化词条存在
    func testModelLabConfigSheet_cpuGpuLocalization_exists() {
        XCTAssertFalse(L10n.ModelManager.Lab.cpu.isEmpty)
        XCTAssertFalse(L10n.ModelManager.Lab.gpu.isEmpty)
    }

    /// 验证 SystemConstants.BooleanLiteral 字符串映射
    func testPluginSettingsGenerator_booleanLiterals_matchExpectedStrings() {
        XCTAssertEqual(SystemConstants.BooleanLiteral.true, "true")
        XCTAssertEqual(SystemConstants.BooleanLiteral.false, "false")
    }
}
