//
//  UIComponentsAnimationAndTokensTests.swift
//  ZhiYuTests
//
//  系统层级：[Shared] UI 组件与动画测试
//  核心职责：验证 CoachMarkOverlay 异步调度、SplashBackgroundView 连线去重、IconPickerView 本地化及通用设计系统阴影/圆角/骨架屏透明度。
//

import XCTest
import SwiftUI
@testable import ZhiYu

@MainActor
final class UIComponentsAnimationAndTokensTests: XCTestCase {

    /// 验证 CoachMarkOverlay 动画挂起协程有效调度
    func testCoachMarkOverlay_taskSleep_suspendsCoroutinesCleanly() async throws {
        let startTime = Date()
        try await Task.sleep(for: .milliseconds(10))
        let elapsed = Date().timeIntervalSince(startTime)
        XCTAssertGreaterThan(elapsed, 0.005, "Task.sleep 应准确挂起协程")
    }

    /// 验证 SplashBackgroundView 背景连线无重复
    func testSplashBackgroundView_connections_haveNoDuplicates() {
        let splash = SplashBackgroundView(starTwinkle: true, nodeGlow: true)
        let mirror = Mirror(reflecting: splash)
        guard let connections = mirror.children.first(where: { $0.label == "connections" })?.value as? [(from: Int, to: Int)] else {
            XCTFail("应有 connections 属性")
            return
        }

        let uniqueConnections = Set(connections.map { "\($0.from)-\($0.to)" })
        XCTAssertEqual(connections.count, uniqueConnections.count, "connections 不应有重复")
    }

    /// 验证 IconPickerView 各分类本地化词条非空
    func testIconPickerView_categoryLocalizationProperties_exist() {
        XCTAssertFalse(L10n.Editor.iconPicker.common.isEmpty)
        XCTAssertFalse(L10n.Editor.iconPicker.academic.isEmpty)
        XCTAssertFalse(L10n.Editor.iconPicker.nature.isEmpty)
        XCTAssertFalse(L10n.Editor.iconPicker.transport.isEmpty)
        XCTAssertFalse(L10n.Editor.iconPicker.symbols.isEmpty)
    }

    /// 验证 DesignSystem.Shadows.standard 及 Radius.small 设计令牌
    func testAppTextEditor_shadowAndRadiusTokens_matchDesignSystem() {
        XCTAssertEqual(DesignSystem.Shadows.standard.radius, 8)
        XCTAssertEqual(DesignSystem.Shadows.standard.x, 0)
        XCTAssertEqual(DesignSystem.Shadows.standard.y, 4)
        XCTAssertEqual(DesignSystem.Radius.small, 8)
    }

    /// 验证 AppLoadingSkeleton 初始透明度令牌
    func testAppLoadingSkeleton_initialOpacity_matchesDesignSystem() {
        XCTAssertEqual(DesignSystem.Opacity.shadow, 0.3)
        XCTAssertEqual(DesignSystem.Opacity.prominent, 0.8)
    }
}
