//
//  StringPhoneNumberMaskingTests.swift
//  UFPCoreTests
//
//  系统层级：[UFPCoreTests]
//  核心职责：验证 String.maskedPhoneNumber 对手机号掩码脱敏与边界长度保护。
//

import XCTest
@testable import UFPCore

final class StringPhoneNumberMaskingTests: XCTestCase {

    func testMaskedPhoneNumber_standardElevenDigits_masksMiddleFour() {
        let input = "13812345678"
        let output = input.maskedPhoneNumber
        XCTAssertEqual(output, "138****5678", "11 位手机号应将第 4-7 位替换为 4 个星号")
    }

    func testMaskedPhoneNumber_minimumSevenDigits_masksMiddleFour() {
        let input = "1234567"
        let output = input.maskedPhoneNumber
        XCTAssertEqual(output, "123****", "7 位字符串满足最小脱敏长度，前 3 位保留，末尾 4 位替换为星号")

        let input8 = "12345678"
        XCTAssertEqual(input8.maskedPhoneNumber, "123****8", "8 位字符串前 3 位保留，中间 4 位星号，末尾 1 位保留")
    }

    func testMaskedPhoneNumber_lessThanSevenDigits_returnsOriginal() {
        XCTAssertEqual("".maskedPhoneNumber, "")
        XCTAssertEqual("1".maskedPhoneNumber, "1")
        XCTAssertEqual("123456".maskedPhoneNumber, "123456", "不足 7 位时应原样返回不篡改")
    }

    func testMaskedPhoneNumber_longerString_masksFromThirdToSeventhOffset() {
        let input = "+8613812345678"
        let output = input.maskedPhoneNumber
        XCTAssertTrue(output.contains("****"), "超长字符串亦应包含 ****: \(output)")
        XCTAssertEqual(output.count, input.count, "掩码替换后总长度应保持一致")
    }
}
