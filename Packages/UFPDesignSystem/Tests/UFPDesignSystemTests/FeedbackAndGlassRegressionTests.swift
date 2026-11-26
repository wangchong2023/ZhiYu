//
//  FeedbackAndGlassRegressionTests.swift
//  UFPDesignSystemTests
//
//  Created by Antigravity on 2026/11/26.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[UFPDesignSystemTests]
//  核心职责：以发现真实缺陷为目的，验证 ToastManager 计时器防泄露与非有限时长防护、
//           SiriWaveformView 零宽/NaN 除零防护、AppPulseDot/AppGlow 尺寸守卫、
//           AppEmptyState 无障碍标签清洗、Feedback 组与 GlassStyle 真实渲染及 Colors 边界。
//

import SwiftUI
import XCTest
@testable import UFPDesignSystem

@MainActor
final class FeedbackAndGlassRegressionTests: XCTestCase {

    private enum TestConstants {
        static let expectedDefaultToastDuration: Double = 3.0
        static let shortToastDuration: Double = 1.5
        static let negativeDuration: Double = -2.0
        static let zeroSize: CGFloat = 0.0
        static let negativeSize: CGFloat = -12.0
        static let validWidth: CGFloat = 200.0
        static let validHeight: CGFloat = 80.0
        static let validTime: Double = 1.25
        static let validAmplitude: Double = 0.8
        static let outOfRangeWaveIndex: Int = 99
        static let renderSize = CGSize(width: 320, height: 180)
        static let expectedToastZIndex: Double = 9999
    }

    /// 辅助：通过 ImageRenderer 真实驱动 SwiftUI body 渲染，验证无崩溃且输出合法位图
    private func assertRendersCleanly<V: View>(_ view: V, file: StaticString = #filePath, line: UInt = #line) {
        let sizedView = view.frame(width: TestConstants.renderSize.width, height: TestConstants.renderSize.height)
        let renderer = ImageRenderer(content: sizedView)
        XCTAssertNotNil(renderer.cgImage, "视图应能正常渲染为有效 CGImage", file: file, line: line)
    }

    // MARK: - 1. ToastManager 计时器防泄露与非有限时长防护（缺陷 #102 / #103）

    func testToastManagerDismissCancelsActiveTimerAndSanitizesDuration() {
        let manager = ToastManager()
        XCTAssertNil(manager.currentToast)
        XCTAssertFalse(manager.hasActiveTimer)

        // 1) AppToast 模型与 ToastManager.show 默认时长必须一致（3.0s，不得误用 spacing 令牌）
        let defaultModel = AppToast(type: .info, message: "Default")
        XCTAssertEqual(defaultModel.duration, TestConstants.expectedDefaultToastDuration)

        // 2) show 正数时长启动计时器，dismiss 必须立刻取消计时器防止泄露
        manager.show(type: .success, message: "Saved", duration: TestConstants.shortToastDuration)
        XCTAssertEqual(manager.currentToast?.type, .success)
        XCTAssertEqual(manager.currentToast?.duration, TestConstants.shortToastDuration)
        XCTAssertTrue(manager.hasActiveTimer, "正数时长展示后应持有活跃自动关闭计时器")

        manager.dismiss()
        XCTAssertNil(manager.currentToast)
        XCTAssertFalse(manager.hasActiveTimer, "dismiss 后必须立即取消并释放计时器，防止悬挂泄露")

        // 3) 非法时长（.infinity / .nan / 负数 / 0）必须钳位为 0 且不启动 Combine 定时器
        for invalidDuration in [Double.infinity, .nan, TestConstants.negativeDuration, 0.0] {
            manager.show(type: .processing, message: "Syncing", duration: invalidDuration)
            XCTAssertEqual(manager.currentToast?.duration, 0.0, "非法时长 \(invalidDuration) 必须钳位为 0")
            XCTAssertFalse(manager.hasActiveTimer, "非正/非有限时长不得启动定时关闭任务")
        }

        // 4) Toast ZIndex 令牌校验
        XCTAssertEqual(DesignTokens.ZIndex.toast, TestConstants.expectedToastZIndex)
    }

    func testAppToastTypesAndModifierRenderCleanly() {
        let types: [AppToastType] = [.success, .error, .info, .processing]
        for toastType in types {
            XCTAssertFalse(toastType.icon.isEmpty)
            let toast = AppToast(type: toastType, message: "Toast message")
            assertRendersCleanly(AppToastView(toast: toast, onDismiss: {}))
        }
        assertRendersCleanly(Text("Host").appToast())
    }

    // MARK: - 2. SiriWaveformView 零宽 / NaN / 越界路径防护（缺陷 #104）

    private struct WaveInput {
        let waveIndex: Int
        let width: CGFloat
        let height: CGFloat
        let time: Double
        let amplitude: Double
    }

    func testSiriWaveformBuildPathGuardsAgainstZeroWidthAndNonFiniteValues() {
        let invalidCases: [WaveInput] = [
            WaveInput(waveIndex: 0, width: TestConstants.zeroSize, height: TestConstants.validHeight, time: TestConstants.validTime, amplitude: TestConstants.validAmplitude),
            WaveInput(waveIndex: 0, width: TestConstants.negativeSize, height: TestConstants.validHeight, time: TestConstants.validTime, amplitude: TestConstants.validAmplitude),
            WaveInput(waveIndex: 0, width: TestConstants.validWidth, height: TestConstants.zeroSize, time: TestConstants.validTime, amplitude: TestConstants.validAmplitude),
            WaveInput(waveIndex: 0, width: TestConstants.validWidth, height: TestConstants.validHeight, time: .nan, amplitude: TestConstants.validAmplitude),
            WaveInput(waveIndex: 0, width: TestConstants.validWidth, height: TestConstants.validHeight, time: TestConstants.validTime, amplitude: .infinity),
            WaveInput(waveIndex: -1, width: TestConstants.validWidth, height: TestConstants.validHeight, time: TestConstants.validTime, amplitude: TestConstants.validAmplitude),
            WaveInput(waveIndex: TestConstants.outOfRangeWaveIndex, width: TestConstants.validWidth, height: TestConstants.validHeight, time: TestConstants.validTime, amplitude: TestConstants.validAmplitude)
        ]
        for input in invalidCases {
            let path = SiriWaveformView.buildWavePath(
                waveIndex: input.waveIndex,
                width: input.width,
                height: input.height,
                time: input.time,
                amplitudeMultiplier: input.amplitude
            )
            XCTAssertTrue(path.isEmpty, "非法尺寸或非有限参数必须返回空路径，避免注入 NaN 坐标")
        }

        // 合法参数必须生成非空有限边界路径
        for waveIndex in 0..<3 {
            let path = SiriWaveformView.buildWavePath(
                waveIndex: waveIndex,
                width: TestConstants.validWidth,
                height: TestConstants.validHeight,
                time: TestConstants.validTime,
                amplitudeMultiplier: TestConstants.validAmplitude
            )
            XCTAssertFalse(path.isEmpty)
            let rect = path.boundingRect
            XCTAssertTrue(rect.origin.x.isFinite && rect.origin.y.isFinite)
            XCTAssertTrue(rect.size.width.isFinite && rect.size.height.isFinite)
        }

        assertRendersCleanly(SiriWaveformView(speedMultiplier: 1.0, amplitudeMultiplier: 0.7))
        assertRendersCleanly(SiriWaveformView(speedMultiplier: .nan, amplitudeMultiplier: .nan))
    }

    // MARK: - 3. AppFeedback 尺寸守卫与渲染（缺陷 #105）

    func testAppFeedbackSizeGuardsAndRendering() {
        let zeroDot = AppPulseDot(size: TestConstants.zeroSize)
        XCTAssertEqual(zeroDot.size, DesignTokens.Spacing.small)
        let negativeDot = AppPulseDot(size: TestConstants.negativeSize)
        XCTAssertEqual(negativeDot.size, DesignTokens.Spacing.small)
        let nanDot = AppPulseDot(size: .nan)
        XCTAssertEqual(nanDot.size, DesignTokens.Spacing.small)

        let negativeGlow = AppGlow(icon: DesignTokens.Icons.sparkles, size: TestConstants.negativeSize)
        XCTAssertEqual(negativeGlow.size, DesignTokens.Spacing.huge)
        let infGlow = AppGlow(icon: DesignTokens.Icons.sparkles, size: .infinity)
        XCTAssertEqual(infGlow.size, DesignTokens.Spacing.huge)

        assertRendersCleanly(zeroDot)
        assertRendersCleanly(AppShimmer())
        assertRendersCleanly(AppSkeleton(width: TestConstants.validWidth))
        assertRendersCleanly(AppSuccessBanner(message: "Operation succeeded"))
        assertRendersCleanly(negativeGlow)
    }

    // MARK: - 4. AppEmptyState / AppErrorView / AppLoadingOverlay / AppLoadingSkeleton / L10n

    func testAppEmptyStateAccessibilityLabelAndRoles() {
        var didTap = false
        let state = AppEmptyState.withAction(
            icon: DesignTokens.Icons.sparkles,
            title: "No Documents",
            description: "   ",
            hint: "Tap below",
            actionLabel: "Import",
            actionIcon: DesignTokens.Icons.plus,
            actionRole: .primary,
            actionHandler: { didTap = true }
        )
        let label = state.buildAccessibilityLabel()
        XCTAssertFalse(label.contains(".."), "空白描述不得拼出重复句号: \(label)")
        XCTAssertTrue(label.contains("No Documents"))
        XCTAssertTrue(label.contains("Hint: Tap below"))
        XCTAssertTrue(label.contains("Action: Import"))

        state.action?.handler()
        XCTAssertTrue(didTap)

        _ = state.actionForegroundColor(for: .primary)
        _ = state.actionForegroundColor(for: .secondary)
        _ = state.actionForegroundColor(for: .destructive)
        _ = state.actionForegroundColor(for: nil)

        assertRendersCleanly(state)
        assertRendersCleanly(
            AppEmptyState.simple(
                icon: DesignTokens.Icons.info,
                title: "Empty",
                description: "Add your first note"
            )
        )
    }

    func testFeedbackL10nErrorLoadingAndSkeletonRenderCleanly() {
        XCTAssertFalse(AppFeedbackL10n.errorTitle.isEmpty)
        XCTAssertFalse(AppFeedbackL10n.retryButton.isEmpty)
        XCTAssertFalse(AppFeedbackL10n.loading.isEmpty)

        assertRendersCleanly(AppErrorView(message: "Network timeout", retryAction: {}))
        assertRendersCleanly(AppErrorView(message: "Read only error", retryAction: nil))
        assertRendersCleanly(AppLoadingOverlay(isLoading: true, message: "Indexing..."))
        assertRendersCleanly(AppLoadingOverlay(isLoading: false, message: nil))

        for skeletonType in [AppLoadingSkeleton.SkeletonType.textRow, .paragraph, .cardBlock] {
            assertRendersCleanly(AppLoadingSkeleton(type: skeletonType))
        }
    }

    // MARK: - 5. GlassStyle 与 Colors / DesignTokens 边界覆盖

    func testGlassStyleModifiersAndColorsCoverage() {
        assertRendersCleanly(Text("Glass").appGlassCardStyle())
        assertRendersCleanly(Text("Card").appCardStyle())
        assertRendersCleanly(Text("Container").appContainer(padding: true))
        assertRendersCleanly(Text("ContainerNoPad").appContainer(padding: false))
        assertRendersCleanly(Text("Metric").appMetricCardStyle(color: .appAccent))
        assertRendersCleanly(Text("Row").appListRowBackground())
        assertRendersCleanly(AppListRowBackground())

        // 验证 accentColorResolver 可安全替换并还原
        let originalResolver = Color.accentColorResolver
        defer { Color.accentColorResolver = originalResolver }
        Color.accentColorResolver = { .purple }
        _ = Color.appAccent

        // 验证 8 位 ARGB、6 位 RGB 与非法 hex 均安全解析
        _ = Color(hex: "#80FF00AA")
        _ = Color(hex: "34C759")
        _ = Color(hex: "INVALID_HEX")
        _ = Color(hex: "")

        // 验证 DesignTokens.Colors.Opacity 与 Color.theme / ShapeStyle 语义映射
        _ = DesignTokens.Colors.Opacity.shadowColor
        _ = DesignTokens.Colors.Opacity.glassShadowColor
        _ = DesignTokens.Colors.Opacity.deepShadowColor
        _ = DesignTokens.Colors.containerBackground
        _ = DesignTokens.Colors.containerBorder
        _ = Color.appGloss
        _ = Color.appRecording
        _ = Color.appAlert
        _ = Color.appSource
        _ = Color.appConcept
        _ = Color.appEntity
        _ = Color.appMap
        _ = Color.appComparison
        _ = Color.theme.accent
        _ = Color.theme.background
        _ = Color.theme.card
        _ = Color.theme.text
        _ = Color.theme.secondaryText
        _ = Color.theme.border
        _ = Color.theme.cyan
        _ = Color.theme.yellow
        _ = Color.theme.pink
        _ = Color.theme.indigo
        _ = Color.theme.mint
        _ = Color.theme.brown
        _ = Color.theme.teal
        _ = Color.theme.gray
        _ = Color.theme.black
        _ = Color.theme.white
    }

    // MARK: - 6. AppDotPattern / FlowLayout / Cards / Modifiers / Typography & Animation 回归（缺陷 #106 / #107）

    func testAppDotPatternGuardsNonPositiveSpacingAndDotSize() {
        let zeroSpacing = AppDotPattern(spacing: TestConstants.zeroSize, dotSize: TestConstants.zeroSize)
        XCTAssertEqual(zeroSpacing.spacing, DesignTokens.Spacing.wide)
        XCTAssertEqual(zeroSpacing.dotSize, DesignTokens.Spacing.atomic)

        let negativeSpacing = AppDotPattern(spacing: TestConstants.negativeSize, dotSize: TestConstants.negativeSize)
        XCTAssertEqual(negativeSpacing.spacing, DesignTokens.Spacing.wide)
        XCTAssertEqual(negativeSpacing.dotSize, DesignTokens.Spacing.atomic)

        let nanSpacing = AppDotPattern(spacing: .nan, dotSize: .infinity)
        XCTAssertEqual(nanSpacing.spacing, DesignTokens.Spacing.wide)
        XCTAssertEqual(nanSpacing.dotSize, DesignTokens.Spacing.atomic)

        assertRendersCleanly(AppDotPattern())
        assertRendersCleanly(zeroSpacing)
    }

    func testFlowLayoutSanitizesSpacingAndLayoutsAndCardsRenderCleanly() {
        let invalidFlow = FlowLayout(spacing: TestConstants.negativeSize)
        XCTAssertEqual(invalidFlow.spacing, DesignTokens.Spacing.small)
        let nanFlow = FlowLayout(spacing: .nan)
        XCTAssertEqual(nanFlow.spacing, DesignTokens.Spacing.small)

        assertRendersCleanly(
            FlowLayout(spacing: DesignTokens.Spacing.small) {
                Text("Alpha Tag")
                Text("Beta Long Tag Item")
                Text("Gamma Another Tag")
                Text("Delta Final Tag")
            }
        )

        assertRendersCleanly(
            StandardSection(title: "General", footer: "Footer hint") {
                Text("Row 1").appListRowStyle(showDivider: true)
                Text("Row 2").appListRowStyle(showDivider: false)
            }
        )
        assertRendersCleanly(AnimatedSection(isExpanded: true) { Text("Expanded") })
        assertRendersCleanly(AnimatedSection(isExpanded: false) { Text("Collapsed") })

        // Cards 家族全分支渲染与 CGFloat 兼容构造映射
        assertRendersCleanly(AppCard { Text("Default Card") })
        assertRendersCleanly(
            AppCard(cornerRadius: DesignTokens.Spacing.smallRadius, padding: DesignTokens.Spacing.tiny) {
                Text("Compat Card")
            }
        )
        assertRendersCleanly(AppBorderedCard { Text("Bordered") })
        assertRendersCleanly(AppGlassCard(isHighlighted: true) { Text("Highlighted Glass") })
        assertRendersCleanly(AppGlassCard(isHighlighted: false) { Text("Normal Glass") })
        assertRendersCleanly(AppCardAccent())
        assertRendersCleanly(Text("CardMod").appCard(cornerRadius: DesignTokens.Spacing.microRadius, padding: DesignTokens.Spacing.atomic))
        assertRendersCleanly(Text("CardMod2").appCard(cornerRadius: DesignTokens.Spacing.mediumRadius, padding: DesignTokens.Spacing.small))
        assertRendersCleanly(Text("CardMod3").appCard(cornerRadius: DesignTokens.Spacing.largeRadius, padding: DesignTokens.Spacing.medium))
        assertRendersCleanly(Text("CardMod4").appCard(cornerRadius: DesignTokens.Spacing.chipRadius, padding: DesignTokens.Spacing.giant))
        assertRendersCleanly(Text("CardMod5").appCard(cornerRadius: TestConstants.validWidth, padding: DesignTokens.Spacing.huge))
        assertRendersCleanly(Text("CardMod6").appCard(cornerRadius: TestConstants.validWidth, padding: TestConstants.validWidth))
    }

    func testModifiersTypographyAndAnimationTokens() {
        assertRendersCleanly(Text("Border").gradientBorderCardStyle())
        assertRendersCleanly(Text("Touch").higTouchTarget())
        assertRendersCleanly(Text("Capsule").accentCapsuleStyle())
        assertRendersCleanly(Text("Container").containerCardStyle())
        assertRendersCleanly(Text("Gradient").accentGradientCardStyle())
        assertRendersCleanly(Text("Card").cardStyle())
        assertRendersCleanly(Text("BorderedCard").borderedCardStyle())
        assertRendersCleanly(Text("InfoCard").infoCardStyle())
        assertRendersCleanly(Text("SmallBorder").smallCardBorder())
        assertRendersCleanly(Text("Padding").commonContentPadding())
        assertRendersCleanly(Text("SubtleCapsule").accentSubtleCapsule())
        assertRendersCleanly(Text("Clip").appCardClip(cornerRadius: DesignTokens.Spacing.cardRadius, backgroundOpacity: DesignTokens.Opacity.glass))

        // 验证 HeadingLevel 字号严格单调递减（h1 > h2 > h3 > h4 > h5 > h6）
        let levels: [DesignTokens.Typography.HeadingLevel] = [.h1, .h2, .h3, .h4, .h5, .h6]
        for index in 0..<(levels.count - 1) {
            XCTAssertGreaterThan(levels[index].size, levels[index + 1].size, "标题等级字号必须严格递减")
        }
        for level in levels {
            _ = level.font
            _ = level.weight
            XCTAssertGreaterThan(level.topPadding, 0)
        }

        _ = DesignTokens.Typography.captionFont
        _ = DesignTokens.Typography.caption2Font
        _ = DesignTokens.Typography.secondaryFont
        _ = DesignTokens.Typography.titleFont

        // 动效令牌验证
        _ = DesignTokens.Animation.standard
        _ = DesignTokens.Animation.prominent
        _ = DesignTokens.Animation.fast
        _ = DesignTokens.Animation.Config.prominentSpring
    }
}
