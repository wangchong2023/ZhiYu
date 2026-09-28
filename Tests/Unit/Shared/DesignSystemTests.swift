//
//  DesignSystemTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests] 测试层 / 单元测试
//  核心职责：设计系统 Token 契约、8-Point Grid 物理步长与视觉样式合规性断言测试。
//

import XCTest
import SwiftUI
import UFPDesignSystem
@testable import ZhiYu

final class DesignSystemTests: XCTestCase {

    // MARK: - 1. 8-Point Grid 物理间距契约测试

    /// 校验 SpacingToken 物理步长与 8-pt / 4-pt 网格对齐契约
    func testSpacingToken_PhysicalValues_AlignWithGridContract() {
        XCTAssertEqual(DesignTokens.SpacingToken.atomic.value, 2.0, "atomic 步长应固定为 2pt")
        XCTAssertEqual(DesignTokens.SpacingToken.tiny.value, 4.0, "tiny 步长应固定为 4pt")
        XCTAssertEqual(DesignTokens.SpacingToken.small.value, 8.0, "small 步长应固定为 8pt (1x Grid)")
        XCTAssertEqual(DesignTokens.SpacingToken.medium.value, 12.0, "medium 步长应固定为 12pt (1.5x Grid)")
        XCTAssertEqual(DesignTokens.SpacingToken.standardPadding.value, 16.0, "standardPadding 步长应固定为 16pt (2x Grid)")
        XCTAssertEqual(DesignTokens.SpacingToken.large.value, 16.0, "large 步长应固定为 16pt (2x Grid)")
        XCTAssertEqual(DesignTokens.SpacingToken.wide.value, 20.0, "wide 步长应固定为 20pt (2.5x Grid)")
        XCTAssertEqual(DesignTokens.SpacingToken.giant.value, 24.0, "giant 步长应固定为 24pt (3x Grid)")
        XCTAssertEqual(DesignTokens.SpacingToken.huge.value, 32.0, "huge 步长应固定为 32pt (4x Grid)")
    }

    // MARK: - 2. 圆角半径契约测试

    /// 校验 RadiusToken 物理弧度值契约
    func testRadiusToken_PhysicalValues_AlignWithRadiusContract() {
        XCTAssertEqual(DesignTokens.RadiusToken.micro.value, 4.0, "micro 圆角半径应固定为 4pt")
        XCTAssertEqual(DesignTokens.RadiusToken.small.value, 8.0, "small 圆角半径应固定为 8pt")
        XCTAssertEqual(DesignTokens.RadiusToken.medium.value, 10.0, "medium 圆角半径应固定为 10pt")
        XCTAssertEqual(DesignTokens.RadiusToken.card.value, 12.0, "card 圆角半径应固定为 12pt")
        XCTAssertEqual(DesignTokens.RadiusToken.standard.value, 12.0, "standard 圆角半径应固定为 12pt")
        XCTAssertEqual(DesignTokens.RadiusToken.large.value, 16.0, "large 圆角半径应固定为 16pt")
        XCTAssertEqual(DesignTokens.RadiusToken.chip.value, 20.0, "chip 胶囊圆角半径应固定为 20pt")
    }

    // MARK: - 3. 透明度阶梯合法性测试

    /// 校验 DesignTokens.Opacity 所有离散值在 [0.0, 1.0] 有效范围内
    func testOpacityTokens_AllDiscreteValues_AreWithinValidBounds() {
        let opacities: [Double] = [
            DesignTokens.Opacity.atomic,
            DesignTokens.Opacity.faint,
            DesignTokens.Opacity.ghost,
            DesignTokens.Opacity.light,
            DesignTokens.Opacity.subtle,
            DesignTokens.Opacity.glass,
            DesignTokens.Opacity.medium,
            DesignTokens.Opacity.shadow,
            DesignTokens.Opacity.disabled,
            DesignTokens.Opacity.soft,
            DesignTokens.Opacity.dim,
            DesignTokens.Opacity.overlay,
            DesignTokens.Opacity.prominent,
            DesignTokens.Opacity.solid
        ]

        for (index, opacity) in opacities.enumerated() {
            XCTAssertGreaterThanOrEqual(opacity, 0.0, "透明度 Token 索引 [\(index)] 不能为负数")
            XCTAssertLessThanOrEqual(opacity, 1.0, "透明度 Token 索引 [\(index)] 不能超过 1.0")
        }
    }

    // MARK: - 4. 阴影结构单源契约测试

    /// 校验 DesignTokens.Shadows 阴影 Token 配置非空且半径合法
    func testShadowTokens_ValidConfiguration_PassesContract() {
        let glassShadow = DesignTokens.Shadows.glass
        let standardShadow = DesignTokens.Shadows.standard
        let deepShadow = DesignTokens.Shadows.deep

        XCTAssertGreaterThan(glassShadow.radius, 0, "glass 阴影模糊半径应大于 0")
        XCTAssertGreaterThan(standardShadow.radius, 0, "standard 阴影模糊半径应大于 0")
        XCTAssertGreaterThan(deepShadow.radius, 0, "deep 阴影模糊半径应大于 0")
    }

    // MARK: - 5. 颜色语义角色 (Color Theme) 契约测试

    /// 校验 Color.theme 所有核心语义角色与 HIG 功能色非空且符合自适应规范
    func testColorTheme_SemanticRoles_AreConfiguredNonNil() {
        let theme = Color.theme
        XCTAssertNotNil(theme.accent, "主题强调色应正常配置")
        XCTAssertNotNil(theme.background, "背景色应正常配置")
        XCTAssertNotNil(theme.card, "卡片底色应正常配置")
        XCTAssertNotNil(theme.text, "正文字体颜色应正常配置")
        XCTAssertNotNil(theme.secondaryText, "次要字体颜色应正常配置")
        XCTAssertNotNil(theme.border, "边框颜色应正常配置")

        // 校验 HIG 功能适配色
        XCTAssertNotNil(theme.red, "HIG 适配红色应正常配置")
        XCTAssertNotNil(theme.green, "HIG 适配绿色应正常配置")
        XCTAssertNotNil(theme.orange, "HIG 适配橙色应正常配置")
        XCTAssertNotNil(theme.blue, "HIG 适配蓝色应正常配置")
        XCTAssertNotNil(theme.purple, "HIG 适配紫色应正常配置")
        XCTAssertNotNil(theme.cyan, "HIG 适配青色应正常配置")
        XCTAssertNotNil(theme.yellow, "HIG 适配黄色应正常配置")
    }

    // MARK: - 6. 字体字阶 (Typography Scale) 契约测试

    /// 校验 Typography.HeadingLevel 各标题等级映射至 HIG 语义 Dynamic Type 字体
    func testTypography_HeadingLevels_MapToSemanticDynamicType() {
        XCTAssertEqual(DesignTokens.Typography.HeadingLevel.h1.size, 28, "h1 参考字号应为 28pt")
        XCTAssertEqual(DesignTokens.Typography.HeadingLevel.h2.size, 22, "h2 参考字号应为 22pt")
        XCTAssertEqual(DesignTokens.Typography.HeadingLevel.h3.size, 20, "h3 参考字号应为 20pt")
        XCTAssertEqual(DesignTokens.Typography.HeadingLevel.h4.size, 18, "h4 参考字号应为 18pt")
        XCTAssertEqual(DesignTokens.Typography.HeadingLevel.h5.size, 16, "h5 参考字号应为 16pt")
        XCTAssertEqual(DesignTokens.Typography.HeadingLevel.h6.size, 14, "h6 参考字号应为 14pt")

        // 校验 Dynamic Type 字体构造有效性
        XCTAssertNotNil(DesignTokens.Typography.HeadingLevel.h1.font, "h1 字体映射应非空")
        XCTAssertNotNil(DesignTokens.Typography.HeadingLevel.h6.font, "h6 字体映射应非空")
    }

    // MARK: - 7. 变异与反向路径断言

    /// 反向变异断言：校验非法 Hex 颜色初始化能安全降级（防 Crash）
    func testColorHex_InvalidHexStrings_FallsBackSafelyWithoutCrashing() {
        let invalidHex = Color(hex: "INVALID_HEX_STRING_123")
        XCTAssertNotNil(invalidHex, "传入非法 Hex 字符串时应触发安全降级机制，不能导致应用崩溃")
    }
}
