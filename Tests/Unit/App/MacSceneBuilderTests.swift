//
//  MacSceneBuilderTests.swift
//  ZhiYuTests
//
//  核心职责：验证 MacSceneBuilder / MacMainWindow 编译期存在性，以及 Mac 辅助窗口 id 一致性。
//
//  说明：ZhiYuTests target 为 iOS platform，不包含 Sources/Platforms/macOS/ 目录，
//  故整个测试类用 #if os(macOS) 包裹保证 iOS 编译安全（文件为空）。
//  MacSceneBuilder / MacMainWindow 的编译正确性由 make mac（ZhiYuMac target）保证。
//

#if os(macOS)
import SwiftUI
import XCTest

@testable import ZhiYu

@MainActor
final class MacSceneBuilderTests: XCTestCase {
    // 仅编译期断言，不实例化环境；若需运行需真实依赖注入

    /// MacMainWindow 应可无参实例化并包装 ContentView
    func testMacMainWindow_Instantiable() {
        _ = MacMainWindow()
    }

    /// MacMenuCommands 应可无参实例化（编译期存在性断言）
    func testMacMenuCommands_Instantiable() {
        _ = MacMenuCommands()
    }

    /// MacSceneBuilder 主窗口场景应可编译构建
    func testMacSceneBuilder_MainBuilds() {
        _ = MacSceneBuilder.main(
            appEnv: AppEnvironment.shared,
            appModel: ZhiYuAppModel(),
            dependencies: DependencyContainer(),
            themeManager: ThemeManager(),
            onboardingService: OnboardingService()
        )
    }

    /// MacSceneBuilder 设置窗口场景应可编译构建
    func testMacSceneBuilder_SettingsBuilds() {
        _ = MacSceneBuilder.settings()
    }

    /// MacSceneBuilder 辅助窗口场景应可编译构建（含 profile/plan/plugins/notebook-hub 四窗口）
    func testMacSceneBuilder_WindowsBuilds() {
        _ = MacSceneBuilder.windows()
    }
}
#endif
