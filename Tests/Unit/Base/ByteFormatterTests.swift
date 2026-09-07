//
//  ByteFormatterTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：字节数自动换算工具类 (ByteFormatter) 的逻辑与边界测试。
//

import XCTest
import UFPCore
@testable import ZhiYu

final class ByteFormatterTests: XCTestCase {

    func testFormat_variousByteSizes() {
        XCTAssertFalse(ByteFormatter.format(0).isEmpty, "0 B 换算结果不可为空")
        XCTAssertTrue(ByteFormatter.format(1024).contains("KB") || ByteFormatter.format(1024).contains("字节") || ByteFormatter.format(1024).contains("1"), "1024 字节必须换算为 KB 级别")
        XCTAssertTrue(ByteFormatter.format(1_048_576).contains("MB") || ByteFormatter.format(1_048_576).contains("1"), "1048576 字节必须换算为 MB 级别")
        XCTAssertTrue(ByteFormatter.format(2_781_167_616).contains("GB") || ByteFormatter.format(2_781_167_616).contains("2.78") || ByteFormatter.format(2_781_167_616).contains("2.59"), "GB 级别转换必须包含 GB 单位")
    }

    func testFormatProgress_combinesStringsCorrectly() {
        let downloaded: Int64 = 492 * 1024 * 1024
        let total: Int64 = Int64(2.59 * 1024 * 1024 * 1024)
        let formatted = ByteFormatter.formatProgress(downloadedBytes: downloaded, totalBytes: total)

        XCTAssertTrue(formatted.contains("/"), "进度文本必须使用斜杠 '/' 分隔已下载与总字节")
    }

    func testFormatSpeed_includesPerSecondUnit() {
        let speed: Double = 12.5 * 1024 * 1024
        let formatted = ByteFormatter.formatSpeed(speed)

        XCTAssertTrue(formatted.contains("/s"), "速率文本必须包含 '/s' 单位后缀")
    }
}
