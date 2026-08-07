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
    func testMaskedPhoneNumber_空字符串_返回自身() {
        XCTAssertEqual("".maskedPhoneNumber, "")
    }

    /// 长度 1 → 返回自身
    func testMaskedPhoneNumber_长度1_返回自身() {
        XCTAssertEqual("1".maskedPhoneNumber, "1")
    }

    /// 长度 6（< 7 阈值）→ 返回自身
    func testMaskedPhoneNumber_长度6_返回自身() {
        XCTAssertEqual("123456".maskedPhoneNumber, "123456")
    }

    // MARK: - 边界值：长度 == 7（刚好满足阈值）

    /// 长度 7 → 掩码（前 3 + **** + 后 4 = 11 字符）
    func testMaskedPhoneNumber_长度7_执行掩码() {
        let result = "1234567".maskedPhoneNumber
        XCTAssertEqual(result.count, 11, "前3 + 4个* + 后4 = 11 字符")
        XCTAssertTrue(result.hasPrefix("123"))
        XCTAssertTrue(result.hasSuffix("4567"))
        XCTAssertTrue(result.contains("****"))
    }

    // MARK: - 标准手机号

    /// 长度 11（标准中国手机号）→ 180****6625
    func testMaskedPhoneNumber_标准手机号11位_正确掩码() {
        XCTAssertEqual("18012346625".maskedPhoneNumber, "180****6625")
    }

    /// 长度 11（不同前缀）→ 138****8888
    func testMaskedPhoneNumber_不同前缀11位_正确掩码() {
        XCTAssertEqual("13812348888".maskedPhoneNumber, "138****8888")
    }

    // MARK: - 超长号码

    /// 长度 12 → 前 3 + **** + 后 4
    func testMaskedPhoneNumber_长度12_前3后4掩码() {
        let result = "180123466256".maskedPhoneNumber
        XCTAssertEqual(result, "180****6256")
    }

    /// 长度 20 → 前 3 + **** + 后 4
    func testMaskedPhoneNumber_长度20_前3后4掩码() {
        let result = "18012345678901234567".maskedPhoneNumber
        XCTAssertEqual(result, "180****4567")
    }

    // MARK: - 非数字字符

    /// 含字母的字符串（长度 >= 7）→ 仍执行掩码逻辑
    func testMaskedPhoneNumber_含字母_执行掩码() {
        let result = "abcdefg1234".maskedPhoneNumber
        XCTAssertEqual(result, "abc****1234")
    }
}
