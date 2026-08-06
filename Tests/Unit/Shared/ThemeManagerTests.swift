//
//  ThemeManagerTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证主题管理器的颜色名称映射逻辑与色彩方案模式枚举的映射完整性。
//

import XCTest
import SwiftUI
@testable import ZhiYu

final class ThemeManagerTests: XCTestCase {

    // MARK: - colorForName 静态映射

    func testColorForName_blue返回Blue色() {
        XCTAssertEqual(ThemeManager.colorForName("blue"), .blue)
    }

    func testColorForName_purple返回Purple色() {
        XCTAssertEqual(ThemeManager.colorForName("purple"), .purple)
    }

    func testColorForName_green返回Green色() {
        XCTAssertEqual(ThemeManager.colorForName("green"), .green)
    }

    func testColorForName_orange返回Orange色() {
        XCTAssertEqual(ThemeManager.colorForName("orange"), .orange)
    }

    func testColorForName_pink返回Pink色() {
        XCTAssertEqual(ThemeManager.colorForName("pink"), .pink)
    }

    func testColorForName_red返回Red色() {
        XCTAssertEqual(ThemeManager.colorForName("red"), .red)
    }

    func testColorForName_teal返回Teal色() {
        XCTAssertEqual(ThemeManager.colorForName("teal"), .teal)
    }

    func testColorForName_indigo返回Indigo色() {
        XCTAssertEqual(ThemeManager.colorForName("indigo"), .indigo)
    }

    // MARK: - colorForName 默认值

    func testColorForName_未知名称默认返回Blue() {
        XCTAssertEqual(ThemeManager.colorForName("unknown"), .blue)
    }

    func testColorForName_空字符串默认返回Blue() {
        XCTAssertEqual(ThemeManager.colorForName(""), .blue)
    }

    func testColorForName_大小写敏感_大写返回默认() {
        XCTAssertEqual(ThemeManager.colorForName("Blue"), .blue, "大写 B 应返回默认 blue")
        XCTAssertEqual(ThemeManager.colorForName("BLUE"), .blue, "全大写应返回默认 blue")
    }

    // MARK: - 实例方法包装

    func testColorForName_实例方法与静态方法一致() {
        let manager = ThemeManager.shared
        for name in ["blue", "purple", "green", "orange", "pink", "red", "teal", "indigo", "unknown"] {
            XCTAssertEqual(manager.colorForName(name), ThemeManager.colorForName(name),
                          "实例方法应与静态方法返回一致")
        }
    }
}

// MARK: - ColorSchemeMode 枚举测试

final class ColorSchemeModeTests: XCTestCase {

    // MARK: - CaseIterable 完整性

    func testAllCases包含3个case() {
        XCTAssertEqual(ColorSchemeMode.allCases.count, 3)
        XCTAssertTrue(ColorSchemeMode.allCases.contains(.system))
        XCTAssertTrue(ColorSchemeMode.allCases.contains(.light))
        XCTAssertTrue(ColorSchemeMode.allCases.contains(.dark))
    }

    func testRawValue正确() {
        XCTAssertEqual(ColorSchemeMode.system.rawValue, "system")
        XCTAssertEqual(ColorSchemeMode.light.rawValue, "light")
        XCTAssertEqual(ColorSchemeMode.dark.rawValue, "dark")
    }

    func testRawValue_无效值返回nil() {
        XCTAssertNil(ColorSchemeMode(rawValue: "auto"))
        XCTAssertNil(ColorSchemeMode(rawValue: ""))
    }

    // MARK: - displayName 映射

    func testDisplayName_所有case返回非空字符串() {
        for mode in ColorSchemeMode.allCases {
            XCTAssertFalse(mode.displayName.isEmpty, "displayName 不应为空")
        }
    }

    func testDisplayName_各case返回不同值() {
        let names = ColorSchemeMode.allCases.map { $0.displayName }
        XCTAssertEqual(names.count, Set(names).count, "各 case 的 displayName 应唯一")
    }

    // MARK: - icon 映射

    func testIcon_所有case返回非空字符串() {
        for mode in ColorSchemeMode.allCases {
            XCTAssertFalse(mode.icon.isEmpty, "icon 不应为空")
        }
    }

    func testIcon_各case返回不同值() {
        let icons = ColorSchemeMode.allCases.map { $0.icon }
        XCTAssertEqual(icons.count, Set(icons).count, "各 case 的 icon 应唯一")
    }

    // MARK: - preferredColorScheme 映射

    func testPreferredColorScheme_system返回nil() {
        XCTAssertNil(ColorSchemeMode.system.preferredColorScheme)
    }

    func testPreferredColorScheme_light返回Light() {
        XCTAssertEqual(ColorSchemeMode.light.preferredColorScheme, .light)
    }

    func testPreferredColorScheme_dark返回Dark() {
        XCTAssertEqual(ColorSchemeMode.dark.preferredColorScheme, .dark)
    }
}
