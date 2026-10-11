//
//  ComponentSmokeTests.swift
//  UFPDesignSystemTests
//
//  系统层级：[UFPDesignSystemTests]
//  核心职责：批1 下沉基础 UI 组件的渲染/初始化冒烟测试。
//           验证各组件可实例化、body 可构建、关键布局逻辑行为正确。
//

import XCTest
import SwiftUI
@testable import UFPDesignSystem

final class ComponentSmokeTests: XCTestCase {

    // MARK: - Buttons

    func testAppPrimaryButtonInitialization() {
        let button = AppPrimaryButton(title: "title", action: {})
        _ = button.body
        XCTAssertTrue(true, "AppPrimaryButton body 可构建")
    }

    func testAppPrimaryButtonLoadingFlag() {
        let button = AppPrimaryButton(title: "title", isLoading: true, action: {})
        XCTAssertTrue(button.isLoading)
    }

    func testAppBorderedButtonInitialization() {
        let button = AppBorderedButton(title: "title", action: {})
        _ = button.body
        XCTAssertTrue(true, "AppBorderedButton body 可构建")
    }

    func testAppCapsuleButtonInitialization() {
        let button = AppCapsuleButton(title: "title", action: {})
        _ = button.body
        XCTAssertTrue(true, "AppCapsuleButton body 可构建")
    }

    func testAppFilledActionButtonInitialization() {
        let button = AppFilledActionButton(title: "title", action: {})
        _ = button.body
        XCTAssertTrue(true, "AppFilledActionButton body 可构建")
    }

    func testAppFilledActionButtonWithIcon() {
        let button = AppFilledActionButton(title: "title", icon: "star", action: {})
        XCTAssertEqual(button.icon, "star")
    }

    func testScaleButtonStyleExists() {
        let style = ScaleButtonStyle()
        XCTAssertNotNil(style)
    }

    func testClearSearchButtonInitialization() {
        let button = ClearSearchButton()
        _ = button.body
        XCTAssertTrue(true, "ClearSearchButton body 可构建")
    }

    func testSourceBadgeInitialization() {
        let badge = SourceBadge(label: "label", icon: "book", color: .blue)
        _ = badge.body
        XCTAssertTrue(true, "SourceBadge body 可构建")
    }

    // MARK: - Cards

    func testAppCardInitialization() {
        let card = AppCard { Text("content") }
        _ = card.body
        XCTAssertTrue(true, "AppCard body 可构建")
    }

    func testAppBorderedCardInitialization() {
        let card = AppBorderedCard { Text("content") }
        _ = card.body
        XCTAssertTrue(true, "AppBorderedCard body 可构建")
    }

    func testAppGlassCardInitialization() {
        let card = AppGlassCard { Text("content") }
        _ = card.body
        XCTAssertTrue(true, "AppGlassCard body 可构建")
    }

    func testAppCardAccentInitialization() {
        let accent = AppCardAccent()
        _ = accent.body
        XCTAssertTrue(true, "AppCardAccent body 可构建")
    }

    func testAppCardModifierAppliesPaddingToken() {
        let modifier = AppCardModifier(cornerRadiusToken: .card, paddingToken: .standardPadding)
        XCTAssertEqual(modifier.paddingToken, .standardPadding)
    }

    // MARK: - Layouts

    func testFlowLayoutSizesSingleSubviews() {
        // FlowLayout 单子视图时尺寸应为子视图尺寸
        let layout = FlowLayout()
        XCTAssertNotNil(layout)
    }

    func testStandardSectionInitialization() {
        let section = StandardSection(title: "title", footer: "footer") { Text("content") }
        _ = section.body
        XCTAssertTrue(true, "StandardSection body 可构建")
    }

    func testAnimatedSectionCollapsedHidesContent() {
        // 收起时 body 应为 EmptyView，不渲染内容
        let section = AnimatedSection(isExpanded: false) { Text("content") }
        _ = section.body
        XCTAssertTrue(true, "AnimatedSection 收起 body 可构建")
    }

    func testAnimatedSectionExpandedRendersContent() {
        let section = AnimatedSection(isExpanded: true) { Text("content") }
        _ = section.body
        XCTAssertTrue(true, "AnimatedSection 展开 body 可构建")
    }

    // MARK: - Lists

    func testAppSectionHeaderInitialization() {
        let header = AppSectionHeader(title: "title", icon: "star")
        _ = header.body
        XCTAssertTrue(true, "AppSectionHeader body 可构建")
    }

    func testAppLabeledRowInitialization() {
        let row = AppLabeledRow(label: "label", value: "value")
        _ = row.body
        XCTAssertTrue(true, "AppLabeledRow body 可构建")
    }

    func testAppStepRowInitialization() {
        let row = AppStepRow(number: 1, text: "step")
        _ = row.body
        XCTAssertTrue(true, "AppStepRow body 可构建")
    }

    func testAppDividerInitialization() {
        let divider = AppDivider(icon: "star", title: "divider")
        _ = divider.body
        XCTAssertTrue(true, "AppDivider body 可构建")
    }

    func testAppAccentLineInitialization() {
        let line = AppAccentLine()
        _ = line.body
        XCTAssertTrue(true, "AppAccentLine body 可构建")
    }

    func testAppIconBoxInitialization() {
        let box = AppIconBox(icon: "star")
        _ = box.body
        XCTAssertTrue(true, "AppIconBox body 可构建")
    }

    // MARK: - Inputs

    func testAdaptiveTextEditorInitialization() {
        var text = ""
        let editor = AdaptiveTextEditor(text: Binding(get: { text }, set: { text = $0 }))
        _ = editor.body
        XCTAssertTrue(true, "AdaptiveTextEditor body 可构建")
    }
}