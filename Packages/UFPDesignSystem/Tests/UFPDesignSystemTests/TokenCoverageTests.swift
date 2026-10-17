//
//  TokenCoverageTests.swift
//  UFPDesignSystemTests
//
//  系统层级：[UFPDesignSystemTests]
//  核心职责：验证领域布局 Token（About/Auth/Voice/Lint/Chat/Feedback）的覆盖率与值不变，
//           确保原 DesignSystem.Domain 魔法数字全部下沉为 DesignTokens.Spacing 命名空间 Token。
//

import XCTest
@testable import UFPDesignSystem

final class TokenCoverageTests: XCTestCase {

    // MARK: - 命名空间存在性

    /// DesignTokens.Spacing.About 必须存在且可访问
    func testAboutNamespaceExists() {
        let _ = DesignTokens.Spacing.About.logoSize
    }

    /// DesignTokens.Spacing.Auth 必须存在且可访问
    func testAuthNamespaceExists() {
        let _ = DesignTokens.Spacing.Auth.logoBackgroundSize
        let _ = DesignTokens.Spacing.Auth.modePickerWidth
        let _ = DesignTokens.Spacing.Auth.modePickerHeight
        let _ = DesignTokens.Spacing.Auth.guestButtonTopPadding
    }

    /// DesignTokens.Spacing.Voice 必须存在且可访问
    func testVoiceNamespaceExists() {
        let _ = DesignTokens.Spacing.Voice.recordButtonSize
        let _ = DesignTokens.Spacing.Voice.waveformHeight
        let _ = DesignTokens.Spacing.Voice.transcriptionEditorMaxHeight
    }

    /// DesignTokens.Spacing.Lint 必须存在且可访问
    func testLintNamespaceExists() {
        let _ = DesignTokens.Spacing.Lint.chartSize
        let _ = DesignTokens.Spacing.Lint.scoreFontSize
        let _ = DesignTokens.Spacing.Lint.emptyIconSize
    }

    /// DesignTokens.Spacing.AI.Chat 必须存在且可访问
    func testChatNamespaceExists() {
        let _ = DesignTokens.Spacing.AI.Chat.pulsingDotSize
        let _ = DesignTokens.Spacing.AI.Chat.bubbleIconScale
        let _ = DesignTokens.Spacing.AI.Chat.avatarSize
        let _ = DesignTokens.Spacing.AI.Chat.bubbleCornerRadius
        let _ = DesignTokens.Spacing.AI.Chat.referencePanelCornerRadius
        let _ = DesignTokens.Spacing.AI.Chat.bubbleTrailingPadding
    }

    /// DesignTokens.Spacing.Feedback 必须存在且可访问
    func testFeedbackNamespaceExists() {
        let _ = DesignTokens.Spacing.Feedback.defaultRating
        let _ = DesignTokens.Spacing.Feedback.maxRating
    }

    // MARK: - Token 值不变量

    /// About 全部值不变量
    func testAboutValues() {
        XCTAssertEqual(DesignTokens.Spacing.About.logoSize, 100)
    }

    /// Auth 全部值不变量
    func testAuthValues() {
        XCTAssertEqual(DesignTokens.Spacing.Auth.logoBackgroundSize, 60)
        XCTAssertEqual(DesignTokens.Spacing.Auth.modePickerWidth, 120)
        XCTAssertEqual(DesignTokens.Spacing.Auth.modePickerHeight, 38)
        XCTAssertEqual(DesignTokens.Spacing.Auth.getCodeButtonHorizontalPadding, 12)
        XCTAssertEqual(DesignTokens.Spacing.Auth.getCodeButtonVerticalPadding, 8)
        XCTAssertEqual(DesignTokens.Spacing.Auth.actionButtonVerticalPadding, 14)
        XCTAssertEqual(DesignTokens.Spacing.Auth.thirdPartyIconContainerSize, 50)
        XCTAssertEqual(DesignTokens.Spacing.Auth.thirdPartyIconFontSize, 24)
        XCTAssertEqual(DesignTokens.Spacing.Auth.guestButtonTopPadding, 10)
    }

    /// Voice 全部值不变量
    func testVoiceValues() {
        XCTAssertEqual(DesignTokens.Spacing.Voice.recordButtonSize, 80)
        XCTAssertEqual(DesignTokens.Spacing.Voice.waveScale, 40)
        XCTAssertEqual(DesignTokens.Spacing.Voice.recordingSectionSpacing, 14)
        XCTAssertEqual(DesignTokens.Spacing.Voice.permissionSectionSpacing, 12)
        XCTAssertEqual(DesignTokens.Spacing.Voice.statusTextSpacing, 4)
        XCTAssertEqual(DesignTokens.Spacing.Voice.statusLabelHorizontalPadding, 12)
        XCTAssertEqual(DesignTokens.Spacing.Voice.statusLabelVerticalPadding, 4)
        XCTAssertEqual(DesignTokens.Spacing.Voice.waveformHeight, 44)
        XCTAssertEqual(DesignTokens.Spacing.Voice.waveBarWidth, 5)
        XCTAssertEqual(DesignTokens.Spacing.Voice.waveBarMinHeight, 4)
        XCTAssertEqual(DesignTokens.Spacing.Voice.waveBarSpacing, 3)
        XCTAssertEqual(DesignTokens.Spacing.Voice.transcriptionEditorMinHeight, 100)
        XCTAssertEqual(DesignTokens.Spacing.Voice.transcriptionEditorMaxHeight, 200)
    }

    /// Lint 全部值不变量
    func testLintValues() {
        XCTAssertEqual(DesignTokens.Spacing.Lint.chartSize, 110)
        XCTAssertEqual(DesignTokens.Spacing.Lint.scoreFontSize, 38)
        XCTAssertEqual(DesignTokens.Spacing.Lint.emptyIconSize, 56)
    }

    /// AI.Chat 全部值不变量
    func testChatValues() {
        XCTAssertEqual(DesignTokens.Spacing.AI.Chat.pulsingDotSize, 6)
        XCTAssertEqual(DesignTokens.Spacing.AI.Chat.bubbleIconScale, 1.2)
        XCTAssertEqual(DesignTokens.Spacing.AI.Chat.avatarSize, 22)
        XCTAssertEqual(DesignTokens.Spacing.AI.Chat.bubbleCornerRadius, 18)
        XCTAssertEqual(DesignTokens.Spacing.AI.Chat.referencePanelCornerRadius, 6)
        XCTAssertEqual(DesignTokens.Spacing.AI.Chat.bubbleTrailingPadding, 48)
    }

    /// Feedback 全部值不变量
    func testFeedbackValues() {
        XCTAssertEqual(DesignTokens.Spacing.Feedback.defaultRating, 3)
        XCTAssertEqual(DesignTokens.Spacing.Feedback.maxRating, 5)
    }
}