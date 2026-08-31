//
//  BugHuntBatch5Tests.swift
//  ZhiYuTests
//
//  系统层级：[Shared] 测试层
//  核心职责：验证 Bug #108-#119 修复的正确性，覆盖 WidgetAndWatchViews、ModelLabConfigSheet、
//            ModelLabSandboxPanel、ModelLabMetricsPanel、SubscriptionPlanView 等。
//

import XCTest
import SwiftUI
import UFPCore
@testable import ZhiYu

@MainActor
final class BugHuntBatch5Tests: XCTestCase {

    // MARK: - Bug #110: WidgetAndWatchViews 默认值魔鬼数字

    /// 验证 WidgetWatch 常量存在且值正确。
    func testBug110_WidgetWatchConstantsExist() {
        XCTAssertEqual(PlatformConstants.WidgetWatch.maxRecentTitles, 5, "Bug #110: maxRecentTitles 应为 5")
        XCTAssertEqual(PlatformConstants.WidgetWatch.defaultPageCount, 42, "Bug #110: defaultPageCount 应为 42")
        let dist = PlatformConstants.WidgetWatch.defaultDistribution
        XCTAssertEqual(dist["Source"], 0.4, "Bug #110: Source 比例应为 0.4")
        XCTAssertEqual(dist["Concept"], 0.3, "Bug #110: Concept 比例应为 0.3")
        XCTAssertEqual(dist["Entity"], 0.2, "Bug #110: Entity 比例应为 0.2")
        XCTAssertEqual(dist["Map"], 0.1, "Bug #110: Map 比例应为 0.1")
    }

    // MARK: - Bug #111: ModelLabConfigSheet customNudgeDelta > presetMatchTolerance

    /// 验证 customNudgeDelta 大于 presetMatchTolerance，确保预设匹配能正确识别自定义微调。
    func testBug111_CustomNudgeDeltaExceedsTolerance() {
        let delta = FeatureConstants.InferenceParam.customNudgeDelta
        let tolerance = FeatureConstants.InferenceParam.presetMatchTolerance
        XCTAssertGreaterThan(
            delta, tolerance,
            "Bug #111: customNudgeDelta (\(delta)) 必须大于 presetMatchTolerance (\(tolerance))，否则自定义微调会被误判为预设"
        )
    }

    /// 验证 customNudgeDelta 是正值。
    func testBug111_CustomNudgeDeltaIsPositive() {
        XCTAssertGreaterThan(
            FeatureConstants.InferenceParam.customNudgeDelta, 0,
            "Bug #111: customNudgeDelta 应为正值"
        )
    }

    // MARK: - Bug #113: audioScribe 显式 case

    /// 验证 UseCaseType.audioScribe 存在且可枚举。
    func testBug113_AudioScribeCaseExists() {
        let allCases = UseCaseType.allCases
        XCTAssertTrue(
            allCases.contains(.audioScribe),
            "Bug #113: UseCaseType.audioScribe 应存在于 allCases 中"
        )
    }

    // MARK: - Bug #118: parseColor 常量映射

    /// 验证 MockColorName 常量存在且值正确。
    func testBug118_MockColorNameConstantsExist() {
        XCTAssertEqual(FeatureConstants.MockColorName.cyan, "cyan", "Bug #118: MockColorName.cyan 应为 'cyan'")
        XCTAssertEqual(FeatureConstants.MockColorName.purple, "purple", "Bug #118: MockColorName.purple 应为 'purple'")
        XCTAssertEqual(FeatureConstants.MockColorName.blue, "blue", "Bug #118: MockColorName.blue 应为 'blue'")
        XCTAssertEqual(FeatureConstants.MockColorName.green, "green", "Bug #118: MockColorName.green 应为 'green'")
        XCTAssertEqual(FeatureConstants.MockColorName.red, "red", "Bug #118: MockColorName.red 应为 'red'")
        XCTAssertEqual(FeatureConstants.MockColorName.orange, "orange", "Bug #118: MockColorName.orange 应为 'orange'")
        XCTAssertEqual(FeatureConstants.MockColorName.yellow, "yellow", "Bug #118: MockColorName.yellow 应为 'yellow'")
    }

    // MARK: - Bug #119: SubscriptionPlanView 常量

    /// 验证 SubscriptionQuota 常量存在且值正确。
    func testBug119_SubscriptionQuotaConstantsExist() {
        XCTAssertGreaterThan(
            FeatureConstants.SubscriptionQuota.defaultMaxVaults, 0,
            "Bug #119: defaultMaxVaults 应为正值"
        )
        XCTAssertGreaterThan(
            FeatureConstants.SubscriptionQuota.defaultMaxPages, 0,
            "Bug #119: defaultMaxPages 应为正值"
        )
        XCTAssertGreaterThan(
            FeatureConstants.SubscriptionQuota.defaultMaxPlugins, 0,
            "Bug #119: defaultMaxPlugins 应为正值"
        )
        XCTAssertEqual(
            FeatureConstants.SubscriptionQuota.unlimitedSymbol, "∞",
            "Bug #119: unlimitedSymbol 应为 '∞'"
        )
    }

    /// 验证 dangerRatioThreshold 在合理范围 (0, 1)。
    func testBug119_DangerRatioThresholdInRange() {
        let threshold = FeatureConstants.SubscriptionQuota.dangerRatioThreshold
        XCTAssertGreaterThan(threshold, 0, "Bug #119: dangerRatioThreshold 应大于 0")
        XCTAssertLessThanOrEqual(threshold, 1, "Bug #119: dangerRatioThreshold 应不超过 1")
    }

    // MARK: - Bug #108: WidgetAndWatchViews 硬编码 "OCR"

    /// 验证 WidgetL10n.ocr 属性存在且映射到 xcstrings。
    func testBug108_WidgetL10nOcrExists() {
        let value = WidgetL10n.ocr
        XCTAssertFalse(value.isEmpty, "Bug #108: WidgetL10n.ocr 不应为空字符串")
    }

    // MARK: - Bug #117: ModelLabMetricsPanel 阴影半径常量

    /// 验证 SystemShadow.radiusSmall 常量存在且为正值。
    func testBug117_SystemShadowRadiusSmallExists() {
        XCTAssertGreaterThan(
            SystemShadow.radiusSmall, 0,
            "Bug #117: SystemShadow.radiusSmall 应为正值"
        )
    }

    // MARK: - Bug #115: ModelLabSandboxPanel simulationTask

    /// 验证 ModelLabView 有 simulationTask 状态属性（通过反射检查）。
    func testBug115_SimulationTaskPropertyExists() {
        let view = ModelLabView(embedInScrollView: false, onGoToStore: {})
        let mirror = Mirror(reflecting: view)
        let hasSimulationTask = mirror.children.contains { label, _ in
            label?.contains("simulationTask") == true
        }
        XCTAssertTrue(
            hasSimulationTask,
            "Bug #115: ModelLabView 应包含 simulationTask 状态属性以支持 Task cancel"
        )
    }

    // MARK: - Color.theme 令牌完整性

    /// 验证 Color.theme 包含所有审计脚本检测的颜色令牌。
    func testColorThemeTokensComplete() {
        let theme = Color.theme
        // 触发各颜色属性，确保不崩溃
        _ = theme.red
        _ = theme.orange
        _ = theme.yellow
        _ = theme.green
        _ = theme.blue
        _ = theme.purple
        _ = theme.pink
        _ = theme.gray
        _ = theme.teal
        _ = theme.cyan
        _ = theme.indigo
        _ = theme.mint
        _ = theme.brown
    }

    // MARK: - FeatureConstants.Decorator 完整性

    /// 验证 FeatureConstants.Decorator 包含所有 UI 装饰符号。
    func testFeatureConstantsDecoratorComplete() {
        XCTAssertEqual(FeatureConstants.Decorator.middleDot, "·", "Decorator.middleDot 应为 '·'")
        XCTAssertEqual(FeatureConstants.Decorator.hash, "#", "Decorator.hash 应为 '#'")
        XCTAssertEqual(FeatureConstants.Decorator.percent, "%", "Decorator.percent 应为 '%'")
        XCTAssertEqual(FeatureConstants.Decorator.dash, "--", "Decorator.dash 应为 '--'")
    }

    // MARK: - FeatureConstants.Placeholder 完整性

    /// 验证 FeatureConstants.Placeholder 包含输入占位符。
    func testFeatureConstantsPlaceholderComplete() {
        XCTAssertFalse(FeatureConstants.Placeholder.apiBaseURL.isEmpty, "Placeholder.apiBaseURL 不应为空")
        XCTAssertFalse(FeatureConstants.Placeholder.modelName.isEmpty, "Placeholder.modelName 不应为空")
    }

    // MARK: - AppConstants.displayName 完整性

    /// 验证 AppConstants.displayName 存在且为 "ZhiYu"。
    func testAppConstantsDisplayNameExists() {
        XCTAssertEqual(AppConstants.displayName, "ZhiYu", "AppConstants.displayName 应为 'ZhiYu'")
    }
}
