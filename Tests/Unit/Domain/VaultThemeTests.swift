//
//  VaultThemeTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/13.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：提供对金库视觉主题模型 VaultTheme 预设资源、默认值实例化、Equatable 比较和 Codable 的单元测试覆盖。
//

import XCTest
@testable import ZhiYu

final class VaultThemeTests: XCTestCase {

    /// 测试 VaultTheme 构造参数的解析与默认渐变样式
    func testVaultThemeInitialization() {
        // Arrange & Act
        let theme = VaultTheme(
            id: "custom_theme",
            name: "Custom Theme",
            primaryColors: ["#111111", "#222222"],
            accentColor: "#FF0000"
        )

        // Assert
        XCTAssertEqual(theme.id, "custom_theme", "id 应当正确赋值")
        XCTAssertEqual(theme.name, "Custom Theme", "name 应当正确赋值")
        XCTAssertEqual(theme.style, "linear", "默认渲染样式应当为 linear")
        XCTAssertEqual(theme.primaryColors, ["#111111", "#222222"], "primaryColors 应当正确赋值")
        XCTAssertEqual(theme.accentColor, "#FF0000", "accentColor 应当正确赋值")

        // 测试显式指定 style
        let meshTheme = VaultTheme(
            id: "mesh_theme",
            name: "Mesh",
            style: "mesh",
            primaryColors: ["#000"],
            accentColor: "#FFF"
        )
        XCTAssertEqual(meshTheme.style, "mesh", "显式指定的样式应当正确赋值")
    }

    /// 测试 3 个预置静态常量主题的完整参数属性
    func testPresetThemes() {
        // 1. 标准极简蓝
        let standard = VaultTheme.standard
        XCTAssertEqual(standard.id, "default_blue")
        XCTAssertEqual(standard.style, "linear")
        XCTAssertEqual(standard.primaryColors, ["#007AFF", "#5AC8FA"])
        XCTAssertEqual(standard.accentColor, "#007AFF")
        XCTAssertFalse(standard.name.isEmpty, "标准主题名不应为空")

        // 2. 落日橙红
        let sunset = VaultTheme.sunset
        XCTAssertEqual(sunset.id, "sunset_glow")
        XCTAssertEqual(sunset.style, "linear")
        XCTAssertEqual(sunset.primaryColors, ["#FF9500", "#FF2D55"])
        XCTAssertEqual(sunset.accentColor, "#FF2D55")
        XCTAssertFalse(sunset.name.isEmpty, "落日主题名不应为空")

        // 3. 霓虹深紫
        let neonPurple = VaultTheme.neonPurple
        XCTAssertEqual(neonPurple.id, "neon_purple")
        XCTAssertEqual(neonPurple.style, "mesh")
        XCTAssertEqual(neonPurple.primaryColors, ["#5856D6", "#AF52DE"])
        XCTAssertEqual(neonPurple.accentColor, "#AF52DE")
        XCTAssertFalse(neonPurple.name.isEmpty, "霓虹深紫主题名不应为空")
    }

    /// 测试 VaultTheme 的 Codable 解析
    func testVaultThemeCodable() throws {
        // Arrange
        let theme = VaultTheme(
            id: "json_theme",
            name: "JSON Theme",
            style: "radial",
            primaryColors: ["#ABCDEF"],
            accentColor: "#FEDCBA"
        )

        // Act - Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(theme)

        // Act - Decode
        let decoder = JSONDecoder()
        let decodedTheme = try decoder.decode(VaultTheme.self, from: data)

        // Assert
        XCTAssertEqual(decodedTheme.id, theme.id)
        XCTAssertEqual(decodedTheme.name, theme.name)
        XCTAssertEqual(decodedTheme.style, theme.style)
        XCTAssertEqual(decodedTheme.primaryColors, theme.primaryColors)
        XCTAssertEqual(decodedTheme.accentColor, theme.accentColor)
    }

    /// 测试 Equatable 判定
    func testVaultThemeEquatable() {
        // Arrange
        let themeA = VaultTheme(id: "t1", name: "Theme1", primaryColors: ["#000"], accentColor: "#FFF")
        let themeB = VaultTheme(id: "t1", name: "Theme1", primaryColors: ["#000"], accentColor: "#FFF")
        let themeC = VaultTheme(id: "t2", name: "Theme1", primaryColors: ["#000"], accentColor: "#FFF")

        // Act & Assert
        XCTAssertEqual(themeA, themeB, "两只完全相同的视觉主题应当被判定为相等")
        XCTAssertNotEqual(themeA, themeC, "id 不同的视觉主题应当被判定为不相等")
    }
}
