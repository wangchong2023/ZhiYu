//
//  ExtractedAtomicComponentsTests.swift
//  UFPDesignSystemTests
//
//  Created by Antigravity on 2026/11/26.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[UFPDesignSystemTests]
//  核心职责：验证下沉至 UFPDesignSystem 的 8 个纯 UI 原子组件的初始化参数、默认令牌、
//           交互回调与视图树构建行为。
//

import XCTest
import SwiftUI
@testable import UFPDesignSystem

@MainActor
final class ExtractedAtomicComponentsTests: XCTestCase {

    // MARK: - StatCard

    func testStatCardInitializationAndBody() {
        let card = StatCard(title: "Pages", value: "42", icon: "doc.text", color: .blue)
        XCTAssertEqual(card.title, "Pages")
        XCTAssertEqual(card.value, "42")
        XCTAssertEqual(card.icon, "doc.text")
        XCTAssertEqual(card.color, .blue)
        XCTAssertNotNil(card.body)
    }

    // MARK: - AppMetricCard

    func testAppMetricCardDefaultAndCustomParameters() {
        let defaultCard = AppMetricCard(title: "Latency", value: "12ms", icon: "bolt", color: .green)
        XCTAssertEqual(defaultCard.title, "Latency")
        XCTAssertEqual(defaultCard.value, "12ms")
        XCTAssertEqual(defaultCard.icon, "bolt")
        XCTAssertEqual(defaultCard.iconSize, DesignTokens.ComponentSpacing.huge)
        XCTAssertNotNil(defaultCard.body)

        let customCard = AppMetricCard(
            title: "Errors",
            value: "0",
            icon: "checkmark.shield",
            color: .orange,
            iconSize: DesignTokens.ComponentSpacing.buttonHeight
        )
        XCTAssertEqual(customCard.iconSize, DesignTokens.ComponentSpacing.buttonHeight)
        XCTAssertNotNil(customCard.body)
    }

    // MARK: - AccentIconBox

    func testAccentIconBoxDefaultAndCustomTokens() {
        let defaultBox = AccentIconBox(iconName: "sparkles")
        XCTAssertEqual(defaultBox.iconName, "sparkles")
        XCTAssertEqual(defaultBox.fontSize, DesignTokens.Spacing.large)
        XCTAssertEqual(defaultBox.boxSize, DesignTokens.Metrics.largeIconBoxSize)
        XCTAssertEqual(defaultBox.cornerRadius, DesignTokens.Spacing.smallRadius)
        XCTAssertEqual(defaultBox.backgroundOpacity, DesignTokens.Colors.Opacity.glassOpacity, accuracy: 0.001)
        XCTAssertNotNil(defaultBox.body)

        let customBox = AccentIconBox(
            iconName: "folder",
            fontSize: DesignTokens.SystemFontSize.title3,
            boxSize: DesignTokens.ComponentSpacing.buttonHeight,
            cornerRadius: DesignTokens.SystemRadius.small,
            backgroundOpacity: DesignTokens.SystemOpacity.glass
        )
        XCTAssertEqual(customBox.iconName, "folder")
        XCTAssertEqual(customBox.fontSize, DesignTokens.SystemFontSize.title3)
        XCTAssertEqual(customBox.boxSize, DesignTokens.ComponentSpacing.buttonHeight)
        XCTAssertEqual(customBox.cornerRadius, DesignTokens.SystemRadius.small)
        XCTAssertEqual(customBox.backgroundOpacity, DesignTokens.SystemOpacity.glass, accuracy: 0.001)
    }

    // MARK: - PanelCloseButton

    func testPanelCloseButtonInitialization() {
        let button = PanelCloseButton()
        XCTAssertNotNil(button.body)
    }

    // MARK: - GuideStepRow

    func testGuideStepRowPropertiesAndBody() {
        let row = GuideStepRow(number: 3, text: "Sync Vault", icon: "icloud")
        XCTAssertEqual(row.number, 3)
        XCTAssertEqual(row.text, "Sync Vault")
        XCTAssertEqual(row.icon, "icloud")
        XCTAssertNotNil(row.body)
    }

    // MARK: - QuickActionRow

    func testQuickActionRowPropertiesAndActionCallback() {
        var triggeredCount = 0
        let row = QuickActionRow(
            icon: "plus",
            title: "New Note",
            subtitle: "Create markdown note",
            color: .indigo,
            action: { triggeredCount += 1 }
        )
        XCTAssertEqual(row.icon, "plus")
        XCTAssertEqual(row.title, "New Note")
        XCTAssertEqual(row.subtitle, "Create markdown note")
        XCTAssertEqual(row.color, .indigo)
        XCTAssertNotNil(row.body)

        row.action()
        XCTAssertEqual(triggeredCount, 1)
    }

    // MARK: - SiriWaveformView

    func testSiriWaveformViewDefaultAndCustomMultipliers() {
        let defaultWave = SiriWaveformView()
        XCTAssertEqual(defaultWave.speedMultiplier, 1.0, accuracy: 0.001)
        XCTAssertEqual(defaultWave.amplitudeMultiplier, 1.0, accuracy: 0.001)
        XCTAssertNotNil(defaultWave.body)

        let customWave = SiriWaveformView(speedMultiplier: 1.5, amplitudeMultiplier: 0.7)
        XCTAssertEqual(customWave.speedMultiplier, 1.5, accuracy: 0.001)
        XCTAssertEqual(customWave.amplitudeMultiplier, 0.7, accuracy: 0.001)
        XCTAssertNotNil(customWave.body)
    }

    // MARK: - View+StandardShadow

    func testAppStandardShadowModifierBuildsView() {
        let shadowed = Text("Card").appStandardShadow()
        XCTAssertNotNil(shadowed)
    }
}
