//
//  ByteFormatterFormattingTests.swift
//  UFPCoreTests
//
//  系统层级：[UFPCoreTests]
//  核心职责：验证 ByteFormatter 字节换算、下载进度、速率文本及三档小文件格式化逻辑。
//

import XCTest
@testable import UFPCore

final class ByteFormatterFormattingTests: XCTestCase {

    // MARK: - 基础 format 方法

    func testFormat_negativeBytes_returnsZeroBytes() {
        XCTAssertEqual(ByteFormatter.format(-1), "0 B")
        XCTAssertEqual(ByteFormatter.format(-1024), "0 B")
    }

    func testFormat_zeroAndPositiveBytes_returnsFormattedStrings() {
        XCTAssertFalse(ByteFormatter.format(0).isEmpty)
        XCTAssertFalse(ByteFormatter.format(1024).isEmpty)
        XCTAssertFalse(ByteFormatter.format(1_048_576).isEmpty)
        XCTAssertFalse(ByteFormatter.format(1_073_741_824).isEmpty)
    }

    // MARK: - 下载进度 formatProgress 方法

    func testFormatProgress_givenDownloadedAndTotal_returnsCombinedString() {
        let result = ByteFormatter.formatProgress(
            downloadedBytes: 524_288,
            totalBytes: 1_048_576
        )
        XCTAssertTrue(result.contains("/"), "下载进度必须包含斜杠分隔符: \(result)")
    }

    // MARK: - 速率 formatSpeed 方法

    func testFormatSpeed_nonPositiveSpeed_returnsZeroBytesPerSec() {
        XCTAssertEqual(ByteFormatter.formatSpeed(0), "0 B/s")
        XCTAssertEqual(ByteFormatter.formatSpeed(-100.5), "0 B/s")
    }

    func testFormatSpeed_positiveSpeed_appendsPerSec() {
        let speed = ByteFormatter.formatSpeed(1_048_576)
        XCTAssertTrue(speed.hasSuffix("/s"), "速率文本必须以 /s 结尾: \(speed)")
    }

    // MARK: - 自定义精度 formatCustom 方法

    func testFormatCustom_greaterThanOrEqualOneGB_formatsAsGBWithPrecision() {
        let twoGB: Int64 = 2_147_483_648
        let result = ByteFormatter.formatCustom(twoGB, gbPrecision: 2, mbPrecision: 1)
        XCTAssertTrue(result.hasSuffix("GB"), "超过 1GB 应以 GB 为单位: \(result)")
        XCTAssertTrue(result.contains("2.00") || result.contains("2.0"), "格式化文本应呈现指定精度: \(result)")
    }

    func testFormatCustom_lessThanOneGB_formatsAsMBWithPrecision() {
        let halfGB: Int64 = 524_288_000
        let result = ByteFormatter.formatCustom(halfGB, gbPrecision: 2, mbPrecision: 1)
        XCTAssertTrue(result.hasSuffix("MB"), "小于 1GB 应以 MB 为单位: \(result)")
    }

    // MARK: - 三档换算 formatSmall 方法

    func testFormatSmall_lessThanOneKB_formatsAsBytes() {
        XCTAssertEqual(ByteFormatter.formatSmall(0), "0 B")
        XCTAssertEqual(ByteFormatter.formatSmall(512), "512 B")
        XCTAssertEqual(ByteFormatter.formatSmall(1023), "1023 B")
    }

    func testFormatSmall_betweenKBAndMB_formatsAsKB() {
        let oneKB = 1024
        let result1KB = ByteFormatter.formatSmall(oneKB)
        XCTAssertTrue(result1KB.hasSuffix("KB"), "应以 KB 为单位: \(result1KB)")
        XCTAssertTrue(result1KB.contains("1.0"), "1024 字节换算应包含 1.0: \(result1KB)")

        let halfMB = 512 * 1024
        let resultHalfMB = ByteFormatter.formatSmall(halfMB)
        XCTAssertTrue(resultHalfMB.hasSuffix("KB"), "应以 KB 为单位: \(resultHalfMB)")
    }

    func testFormatSmall_greaterThanOrEqualMB_formatsAsMB() {
        let oneMB = 1024 * 1024
        let result1MB = ByteFormatter.formatSmall(oneMB)
        XCTAssertTrue(result1MB.hasSuffix("MB"), "应以 MB 为单位: \(result1MB)")
        XCTAssertTrue(result1MB.contains("1.0"), "1MB 换算应包含 1.0: \(result1MB)")
    }
}
