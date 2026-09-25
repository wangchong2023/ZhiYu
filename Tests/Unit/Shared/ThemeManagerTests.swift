//
//  ThemeManagerTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证主题管理器的颜色名称映射逻辑与色彩方案模式枚举的映射完整性。
//

import XCTest
import SwiftUI
import Dependencies
@testable import ZhiYu

final class ThemeManagerTests: XCTestCase {

    @Dependency(\.themeService) var themeManager

    // MARK: - colorForName 静态映射

    func testColorForNameBlueReturnsBlue() {
        XCTAssertEqual(ThemeManager.colorForName("blue"), .blue)
    }

    func testColorForNamePurpleReturnsPurple() {
        XCTAssertEqual(ThemeManager.colorForName("purple"), .purple)
    }

    func testColorForNameGreenReturnsGreen() {
        XCTAssertEqual(ThemeManager.colorForName("green"), .green)
    }

    func testColorForNameOrangeReturnsOrange() {
        XCTAssertEqual(ThemeManager.colorForName("orange"), .orange)
    }

    func testColorForNamePinkReturnsPink() {
        XCTAssertEqual(ThemeManager.colorForName("pink"), .pink)
    }

    func testColorForNameRedReturnsRed() {
        XCTAssertEqual(ThemeManager.colorForName("red"), .red)
    }

    func testColorForNameTealReturnsTeal() {
        XCTAssertEqual(ThemeManager.colorForName("teal"), .teal)
    }

    func testColorForNameIndigoReturnsIndigo() {
        XCTAssertEqual(ThemeManager.colorForName("indigo"), .indigo)
    }

    // MARK: - colorForName 默认值

    func testColorForNameUnknownNameDefaultsToBlue() {
        XCTAssertEqual(ThemeManager.colorForName("unknown"), .blue)
    }

    func testColorForNameEmptyStringDefaultsToBlue() {
        XCTAssertEqual(ThemeManager.colorForName(""), .blue)
    }

    func testColorForNameCaseSensitiveUppercaseReturnsDefault() {
        XCTAssertEqual(ThemeManager.colorForName("Blue"), .blue, "大写 B 应返回默认 blue")
        XCTAssertEqual(ThemeManager.colorForName("BLUE"), .blue, "全大写应返回默认 blue")
    }

    // MARK: - 实例方法包装

    func testColorForNameInstanceMethodMatchesStaticMethod() {
        for name in ["blue", "purple", "green", "orange", "pink", "red", "teal", "indigo", "unknown"] {
            XCTAssertEqual(themeManager.colorForName(name), ThemeManager.colorForName(name),
                          "实例方法应与静态方法返回一致")
        }
    }
}

// MARK: - ColorSchemeMode 枚举测试

final class ColorSchemeModeTests: XCTestCase {

    // MARK: - CaseIterable 完整性

    func testAllCasesContainsThreeCases() {
        XCTAssertEqual(ColorSchemeMode.allCases.count, 3)
        XCTAssertTrue(ColorSchemeMode.allCases.contains(.system))
        XCTAssertTrue(ColorSchemeMode.allCases.contains(.light))
        XCTAssertTrue(ColorSchemeMode.allCases.contains(.dark))
    }

    func testRawValueCorrect() {
        XCTAssertEqual(ColorSchemeMode.system.rawValue, "system")
        XCTAssertEqual(ColorSchemeMode.light.rawValue, "light")
        XCTAssertEqual(ColorSchemeMode.dark.rawValue, "dark")
    }

    func testRawValueInvalidValueReturnsNil() {
        XCTAssertNil(ColorSchemeMode(rawValue: "auto"))
        XCTAssertNil(ColorSchemeMode(rawValue: ""))
    }

    // MARK: - displayName 映射

    func testDisplayNameAllCasesReturnNonEmptyString() {
        for mode in ColorSchemeMode.allCases {
            XCTAssertFalse(mode.displayName.isEmpty, "displayName 不应为空")
        }
    }

    func testDisplayNameEachCaseReturnsDifferentValue() {
        let names = ColorSchemeMode.allCases.map { $0.displayName }
        XCTAssertEqual(names.count, Set(names).count, "各 case 的 displayName 应唯一")
    }

    // MARK: - icon 映射
    // MARK: - preferredColorScheme 映射

    func testPreferredColorSchemeSystemReturnsNil() {
        XCTAssertNil(ColorSchemeMode.system.preferredColorScheme)
    }

    func testPreferredColorSchemeLightReturnsLight() {
        XCTAssertEqual(ColorSchemeMode.light.preferredColorScheme, .light)
    }

    func testPreferredColorSchemeDarkReturnsDark() {
        XCTAssertEqual(ColorSchemeMode.dark.preferredColorScheme, .dark)
    }
}
