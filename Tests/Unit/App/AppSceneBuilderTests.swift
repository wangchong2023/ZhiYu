//
//  AppSceneBuilderTests.swift
//  ZhiYuTests
//
//  核心职责：验证场景分发点 AppSceneBuilder / iOSSceneBuilder 编译期存在性，以及 SceneEnvironmentInjection 注入链成员完整性。
//

import SwiftUI
import XCTest

@testable import ZhiYu

@MainActor
final class AppSceneBuilderTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    /// SceneEnvironmentInjection 注入链关键成员应存在（用 Mirror 断言字段完整性）
    func testSceneEnvironmentInjection_HasAllKeyMembers() {
        let injection = SceneEnvironmentInjection(
            appEnv: AppEnvironment.shared,
            appModel: ZhiYuAppModel(),
            dependencies: DependencyContainer(),
            themeManager: ThemeManager(),
            onboardingService: OnboardingService()
        )

        let labels = Mirror(reflecting: injection).children.compactMap { $0.label }
        let requiredKeys = ["appEnv", "appModel", "dependencies", "themeManager", "onboardingService"]
        for key in requiredKeys {
            XCTAssertTrue(labels.contains(key), "SceneEnvironmentInjection 应包含注入链成员 \(key)")
        }
    }

    /// AppSceneBuilder 场景根分发类型应可编译构建（@SceneBuilder 产出 Scene）
    func testAppSceneBuilder_RootBuilds() {
        _ = AppSceneBuilder.root(
            appEnv: AppEnvironment.shared,
            appModel: ZhiYuAppModel(),
            dependencies: DependencyContainer(),
            themeManager: ThemeManager(),
            onboardingService: OnboardingService(),
            hasSeenSplash: true
        )
    }

    /// iOSSceneBuilder 主窗口场景应可编译构建
    func testiOSSceneBuilder_MainBuilds() {
        _ = iOSSceneBuilder.main(
            appEnv: AppEnvironment.shared,
            appModel: ZhiYuAppModel(),
            dependencies: DependencyContainer(),
            themeManager: ThemeManager(),
            onboardingService: OnboardingService(),
            hasSeenSplash: true
        )
    }
}
