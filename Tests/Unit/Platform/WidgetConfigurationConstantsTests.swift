//
//  WidgetConfigurationConstantsTests.swift
//  ZhiYuTests
//
//  系统层级：[Platforms] 平台常量测试
//  核心职责：验证 WidgetWatch 跨端统计默认配置及 WidgetL10n 本地化键映射。
//

import XCTest
import UFPCore
@testable import ZhiYu

final class WidgetConfigurationConstantsTests: XCTestCase {

    /// 验证 WidgetWatch 统计分布常量配置
    func testWidgetWatch_distributionAndPageCountConstants_exist() {
        XCTAssertEqual(PlatformConstants.WidgetWatch.maxRecentTitles, 5)
        XCTAssertEqual(PlatformConstants.WidgetWatch.defaultPageCount, 42)
        let dist = PlatformConstants.WidgetWatch.defaultDistribution
        XCTAssertEqual(dist["Source"], 0.4)
        XCTAssertEqual(dist["Concept"], 0.3)
        XCTAssertEqual(dist["Entity"], 0.2)
        XCTAssertEqual(dist["Map"], 0.1)
    }

    /// 验证 WidgetL10n.ocr 存在且非空
    func testWidgetL10n_ocrKey_isNotEmpty() {
        let value = WidgetL10n.ocr
        XCTAssertFalse(value.isEmpty, "WidgetL10n.ocr 不应为空字符串")
    }
}
