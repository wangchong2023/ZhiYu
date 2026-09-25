//
//  StringPhoneNumberTests.swift
//  ZhiYu
//
//  系统层级：[L0] 测试层
//  核心职责：验证 String.maskedPhoneNumber 手机号掩码的正确性（长度边界/标准/超长）。
//

import XCTest
import UFPCore
@testable import ZhiYu

final class StringPhoneNumberTests: XCTestCase {

    // MARK: - 边界值：长度 < 7（返回自身）

    /// 空字符串 → 返回空字符串
    func testMaskedPhoneNumberEmptyStringReturnsSelf() {
        XCTAssertEqual("".maskedPhoneNumber, "")
    }

    /// 长度 1 → 返回自身
    func testMaskedPhoneNumberLength1ReturnsSelf() {
        XCTAssertEqual("1".maskedPhoneNumber, "1")
    }

    /// 长度 6（< 7 阈值）→ 返回自身
    func testMaskedPhoneNumberLength6ReturnsSelf() {
        XCTAssertEqual("123456".maskedPhoneNumber, "123456")
    }

    // MARK: - 边界值：长度 == 7（刚好满足阈值）

    /// 长度 7 → 掩码（前 3 + **** + 空 suffix = 7 字符）
    /// 注：长度 7 时 index 7 = endIndex，suffix 为空，结果为 "123****"
    func testMaskedPhoneNumberLength7Masks() {
        let result = "1234567".maskedPhoneNumber
        XCTAssertEqual(result, "123****", "前3 + 4个* + 空 suffix（index 7 = endIndex）")
    }

    // MARK: - 标准手机号

    /// 长度 11（标准中国手机号）→ 180****6625
    func testMaskedPhoneNumberStandard11DigitMasksCorrectly() {
        XCTAssertEqual("18012346625".maskedPhoneNumber, "180****6625")
    }

    /// 长度 11（不同前缀）→ 138****8888
    func testMaskedPhoneNumberDifferentPrefix11DigitMasksCorrectly() {
        XCTAssertEqual("13812348888".maskedPhoneNumber, "138****8888")
    }

    // MARK: - 超长号码

    /// 长度 12 → 前 3 + **** + 后 5（index 7 到末尾）
    func testMaskedPhoneNumberLength12Prefix3Suffix5Mask() {
        let result = "180123466256".maskedPhoneNumber
        XCTAssertEqual(result, "180****66256", "前3 + 4个* + suffix(index 7..12)=66256")
    }

    /// 长度 20 → 前 3 + **** + 后 13（index 7 到末尾）
    func testMaskedPhoneNumberLength20Prefix3Suffix13Mask() {
        let result = "18012345678901234567".maskedPhoneNumber
        XCTAssertEqual(result, "180****5678901234567", "前3 + 4个* + suffix(index 7..20)")
    }

    // MARK: - 非数字字符

    /// 含字母的字符串（长度 >= 7）→ 仍执行掩码逻辑
    func testMaskedPhoneNumberWithLettersMasks() {
        let result = "abcdefg1234".maskedPhoneNumber
        XCTAssertEqual(result, "abc****1234")
    }
}
