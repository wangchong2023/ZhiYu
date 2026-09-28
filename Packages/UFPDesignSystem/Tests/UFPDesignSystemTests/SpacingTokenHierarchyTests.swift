//
//  SpacingTokenHierarchyTests.swift
//  UFPDesignSystemTests
//
//  系统层级：[UFPDesignSystemTests]
//  核心职责：验证 DesignTokens.Spacing 原子间距层级与组件子结构的不变量。
//           以 app 版本（atomic/tiny/small/medium/standardPadding/large/wide/giant/huge）为准。
//           注意：large 与 standardPadding 均为 16，不构成严格单调，需单独处理。
//

import XCTest
@testable import UFPDesignSystem

final class SpacingTokenHierarchyTests: XCTestCase {

    // MARK: - 原子间距层级 (Atomic Spacing Scale)

    /// 原子间距核心序列必须单调递增（剔除与 standardPadding 等值的 large）
    func testAtomicScaleMonotonicallyIncreasing() {
        let scale = [
            DesignTokens.Spacing.atomic,
            DesignTokens.Spacing.tiny,
            DesignTokens.Spacing.small,
            DesignTokens.Spacing.medium,
            DesignTokens.Spacing.standardPadding,
            DesignTokens.Spacing.wide,
            DesignTokens.Spacing.giant,
            DesignTokens.Spacing.huge
        ]
        for i in 1..<scale.count {
            XCTAssertGreaterThan(scale[i], scale[i-1],
                                 "原子间距必须单调递增：index \(i) 应大于 index \(i-1)")
        }
    }

    /// large 必须等于 standardPadding（app 版本二者均为 16，语义别名）
    func testLargeEqualsStandardPadding() {
        XCTAssertEqual(DesignTokens.Spacing.large, DesignTokens.Spacing.standardPadding,
                       "app 版本中 large 与 standardPadding 均为 16，互为语义别名")
    }

    /// 所有原子间距必须为正数
    func testAllAtomicSpacingPositive() {
        XCTAssertGreaterThan(DesignTokens.Spacing.atomic, 0)
        XCTAssertGreaterThan(DesignTokens.Spacing.tiny, 0)
        XCTAssertGreaterThan(DesignTokens.Spacing.small, 0)
        XCTAssertGreaterThan(DesignTokens.Spacing.medium, 0)
        XCTAssertGreaterThan(DesignTokens.Spacing.standardPadding, 0)
        XCTAssertGreaterThan(DesignTokens.Spacing.large, 0)
        XCTAssertGreaterThan(DesignTokens.Spacing.wide, 0)
        XCTAssertGreaterThan(DesignTokens.Spacing.giant, 0)
        XCTAssertGreaterThan(DesignTokens.Spacing.huge, 0)
    }

    /// atomic 必须是最小原子间距
    func testAtomicIsMinimum() {
        let all = [DesignTokens.Spacing.atomic, DesignTokens.Spacing.tiny,
                   DesignTokens.Spacing.small, DesignTokens.Spacing.medium,
                   DesignTokens.Spacing.standardPadding, DesignTokens.Spacing.large,
                   DesignTokens.Spacing.wide, DesignTokens.Spacing.giant,
                   DesignTokens.Spacing.huge]
        XCTAssertEqual(DesignTokens.Spacing.atomic, all.min())
    }

    /// huge 必须是最大原子间距
    func testHugeIsMaximum() {
        let all = [DesignTokens.Spacing.atomic, DesignTokens.Spacing.tiny,
                   DesignTokens.Spacing.small, DesignTokens.Spacing.medium,
                   DesignTokens.Spacing.standardPadding, DesignTokens.Spacing.large,
                   DesignTokens.Spacing.wide, DesignTokens.Spacing.giant,
                   DesignTokens.Spacing.huge]
        XCTAssertEqual(DesignTokens.Spacing.huge, all.max())
    }

    /// 间距值必须是整数（避免亚像素渲染问题）
    func testSpacingValuesAreIntegral() {
        let values = [DesignTokens.Spacing.atomic, DesignTokens.Spacing.tiny,
                      DesignTokens.Spacing.small, DesignTokens.Spacing.medium,
                      DesignTokens.Spacing.standardPadding, DesignTokens.Spacing.large,
                      DesignTokens.Spacing.wide, DesignTokens.Spacing.giant,
                      DesignTokens.Spacing.huge]
        for v in values {
            XCTAssertEqual(v.truncatingRemainder(dividingBy: 1), 0,
                           "间距值 \(v) 必须是整数，避免亚像素渲染")
        }
    }

    /// 间距值必须在合理范围（0 < v <= 64）
    func testSpacingValuesInRange() {
        let values = [DesignTokens.Spacing.atomic, DesignTokens.Spacing.tiny,
                      DesignTokens.Spacing.small, DesignTokens.Spacing.medium,
                      DesignTokens.Spacing.standardPadding, DesignTokens.Spacing.large,
                      DesignTokens.Spacing.wide, DesignTokens.Spacing.giant,
                      DesignTokens.Spacing.huge]
        for v in values {
            XCTAssertGreaterThan(v, 0)
            XCTAssertLessThanOrEqual(v, 64, "间距 \(v) 不应超过 64pt")
        }
    }

    // MARK: - 组件子结构存在性 (Component Substructure Existence)

    /// 验证 app 版本全部组件子结构存在（迁移完整性检查）
    func testComponentSubstructuresExist() {
        // 引用各子结构的代表性 Token，确保迁移后子结构完整
        XCTAssertEqual(DesignTokens.Spacing.Layout.maxReadWidth, 800)
        XCTAssertEqual(DesignTokens.Spacing.Action.buttonHeight, 44)
        XCTAssertEqual(DesignTokens.Spacing.Gallery.itemSize, 100)
        XCTAssertEqual(DesignTokens.Spacing.Timeline.indicatorSize, 36)
        XCTAssertEqual(DesignTokens.Spacing.Grid.standardSpacing, 16)
        XCTAssertEqual(DesignTokens.Spacing.Graph.nodeSize, 40)
        XCTAssertEqual(DesignTokens.Spacing.CompositeRow.spacing, 10)
        XCTAssertEqual(DesignTokens.Spacing.Metrics.heroValueSize, 32)
        XCTAssertEqual(DesignTokens.Spacing.Task.rowSpacing, 16)
        XCTAssertEqual(DesignTokens.Spacing.List.rowSpacing, 12)
        XCTAssertEqual(DesignTokens.Spacing.Chip.horizontalPadding, 6)
        XCTAssertEqual(DesignTokens.Spacing.Sidebar.width, 280)
        XCTAssertEqual(DesignTokens.Spacing.Vault.gridCardMin, 160)
        XCTAssertEqual(DesignTokens.Spacing.Decorator.shadowRadiusSmall, 8)
    }

    /// 验证 Graph.ThreeD 三维子结构存在
    func testGraphThreeDSubstructureExists() {
        XCTAssertEqual(DesignTokens.Spacing.Graph.ThreeD.baseNodeSize, 3.5)
        XCTAssertEqual(DesignTokens.Spacing.Graph.ThreeD.nodeLinkWeight, 0.5)
    }

    // MARK: - 跨子结构引用一致性 (Cross-Substructure Reference Consistency)

    /// Sidebar.backButtonWidth 必须引用 Action.backButtonWidth（跨子结构别名）
    func testSidebarBackButtonWidthReferencesAction() {
        XCTAssertEqual(DesignTokens.Spacing.Sidebar.backButtonWidth,
                       DesignTokens.Spacing.Action.backButtonWidth,
                       "Sidebar.backButtonWidth 应引用 Action.backButtonWidth")
    }

    /// Layout.welcomeHeaderTopPadding 必须等于 huge + small（跨 Token 组合）
    func testLayoutWelcomeHeaderTopPaddingIsComposite() {
        XCTAssertEqual(DesignTokens.Spacing.Layout.welcomeHeaderTopPadding,
                       DesignTokens.Spacing.huge + DesignTokens.Spacing.small,
                       "Layout.welcomeHeaderTopPadding 应为 huge + small 的组合值")
    }

    /// Layout.sidebarOverlayVerticalPadding 必须引用 medium
    func testLayoutSidebarOverlayVerticalPaddingReferencesMedium() {
        XCTAssertEqual(DesignTokens.Spacing.Layout.sidebarOverlayVerticalPadding,
                       DesignTokens.Spacing.medium)
    }

    /// Gallery.splashLogoBottomPadding 必须等于 huge * 2
    func testGallerySplashLogoBottomPaddingIsComposite() {
        XCTAssertEqual(DesignTokens.Spacing.Gallery.splashLogoBottomPadding,
                       DesignTokens.Spacing.huge * 2)
    }
}
