//
//  IPAddressUtilityTests.swift
//  UFPCoreTests
//
//  系统层级：[UFPCoreTests]
//  核心职责：验证 IPAddressUtility 通用 IP 格式识别、进制归一化、二进制解析与私有网络段判定。
//

import XCTest
@testable import UFPCore

final class IPAddressUtilityTests: XCTestCase {

    // MARK: - IPv6 格式识别 (isIPv6Format)

    func testIsIPv6Format_bracketsAndMultipleColons_identifiesAccurately() {
        XCTAssertTrue(IPAddressUtility.isIPv6Format("[2001:db8::1]"))
        XCTAssertTrue(IPAddressUtility.isIPv6Format("2001:db8::1"))
        XCTAssertTrue(IPAddressUtility.isIPv6Format("::1"))
        XCTAssertTrue(IPAddressUtility.isIPv6Format("fe80::1"))
        XCTAssertFalse(IPAddressUtility.isIPv6Format("example.com"))
        XCTAssertFalse(IPAddressUtility.isIPv6Format("192.168.1.1"))
        XCTAssertFalse(IPAddressUtility.isIPv6Format("fc-bank.com"))
    }

    // MARK: - IPv4 进制归一化 (normalizeIP)

    func testNormalizeIP_pureDecimalInteger_normalizesCorrectly() {
        // 2130706433 = 127.0.0.1
        XCTAssertEqual(IPAddressUtility.normalizeIP("2130706433"), "127.0.0.1")
        // 16843009 = 1.1.1.1
        XCTAssertEqual(IPAddressUtility.normalizeIP("16843009"), "1.1.1.1")
    }

    func testNormalizeIP_octalAndHex_normalizesCorrectly() {
        // 八进制 0177.0.0.1 -> 127.0.0.1
        XCTAssertEqual(IPAddressUtility.normalizeIP("0177.0.0.1"), "127.0.0.1")
        // 十六进制 0x7f.0.0.1 / 0X7F.0.0.1 -> 127.0.0.1
        XCTAssertEqual(IPAddressUtility.normalizeIP("0x7f.0.0.1"), "127.0.0.1")
        XCTAssertEqual(IPAddressUtility.normalizeIP("0X7F.0.0.1"), "127.0.0.1")
    }

    func testNormalizeIP_shorthandFormats_normalizesCorrectly() {
        // 2 段省略：127.1 -> 127.0.0.1
        XCTAssertEqual(IPAddressUtility.normalizeIP("127.1"), "127.0.0.1")
        // 3 段省略：10.1.2 -> 10.1.0.2
        XCTAssertEqual(IPAddressUtility.normalizeIP("10.1.2"), "10.1.0.2")
    }

    func testNormalizeIP_invalidInputs_returnsNil() {
        XCTAssertNil(IPAddressUtility.normalizeIP(""))
        XCTAssertNil(IPAddressUtility.normalizeIP("1.2.3.4.5"))
        XCTAssertNil(IPAddressUtility.normalizeIP("256.0.0.1"))
        XCTAssertNil(IPAddressUtility.normalizeIP("invalid.ip.address"))
    }

    // MARK: - 单段解析 (parseIPOctet)

    func testParseIPOctet_variousRadixes_parsesCorrectly() {
        XCTAssertEqual(IPAddressUtility.parseIPOctet("0x10"), 16)
        XCTAssertEqual(IPAddressUtility.parseIPOctet("0XFF"), 255)
        XCTAssertEqual(IPAddressUtility.parseIPOctet("010"), 8)
        XCTAssertEqual(IPAddressUtility.parseIPOctet("077"), 63)
        XCTAssertEqual(IPAddressUtility.parseIPOctet("192"), 192)
        XCTAssertNil(IPAddressUtility.parseIPOctet("not_a_number"))
    }

    // MARK: - 组合段处理 (combineOctets)

    func testCombineOctets_boundaryCases_handledSafely() {
        XCTAssertEqual(IPAddressUtility.combineOctets([127, 0, 0, 1]), "127.0.0.1")
        XCTAssertNil(IPAddressUtility.combineOctets([]))
        XCTAssertNil(IPAddressUtility.combineOctets([1, 2, 3, 4, 5]))
        XCTAssertNil(IPAddressUtility.combineOctets([192, 168, 1, 300]))
    }

    // MARK: - 私有 IPv4 判定 (isPrivateIPv4)

    func testIsPrivateIPv4_privateAndLoopbackRanges_returnsTrue() {
        XCTAssertTrue(IPAddressUtility.isPrivateIPv4("10.0.0.1"))
        XCTAssertTrue(IPAddressUtility.isPrivateIPv4("172.16.0.1"))
        XCTAssertTrue(IPAddressUtility.isPrivateIPv4("172.31.255.255"))
        XCTAssertTrue(IPAddressUtility.isPrivateIPv4("192.168.1.1"))
        XCTAssertTrue(IPAddressUtility.isPrivateIPv4("0.0.0.0"))
        XCTAssertTrue(IPAddressUtility.isPrivateIPv4("100.64.0.1"))
        XCTAssertTrue(IPAddressUtility.isPrivateIPv4("127.0.0.1"))
        XCTAssertTrue(IPAddressUtility.isPrivateIPv4("169.254.1.1"))
    }

    func testIsPrivateIPv4_publicAddresses_returnsFalse() {
        XCTAssertFalse(IPAddressUtility.isPrivateIPv4("1.1.1.1"))
        XCTAssertFalse(IPAddressUtility.isPrivateIPv4("8.8.8.8"))
        XCTAssertFalse(IPAddressUtility.isPrivateIPv4("172.15.255.255"))
        XCTAssertFalse(IPAddressUtility.isPrivateIPv4("172.32.0.1"))
        XCTAssertFalse(IPAddressUtility.isPrivateIPv4("192.169.1.1"))
    }

    // MARK: - 私有 IPv6 判定 (isPrivateIPv6)

    func testIsPrivateIPv6_privateAndLoopbackRanges_returnsTrue() {
        XCTAssertTrue(IPAddressUtility.isPrivateIPv6("::1"))
        XCTAssertTrue(IPAddressUtility.isPrivateIPv6("0:0:0:0:0:0:0:1"))
        XCTAssertTrue(IPAddressUtility.isPrivateIPv6("::"))
        XCTAssertTrue(IPAddressUtility.isPrivateIPv6("fc00::1"))
        XCTAssertTrue(IPAddressUtility.isPrivateIPv6("fd12::1"))
        XCTAssertTrue(IPAddressUtility.isPrivateIPv6("fe80::1"))
        XCTAssertTrue(IPAddressUtility.isPrivateIPv6("fe90::1"))
        XCTAssertTrue(IPAddressUtility.isPrivateIPv6("fea0::1"))
        XCTAssertTrue(IPAddressUtility.isPrivateIPv6("feb0::1"))
        XCTAssertTrue(IPAddressUtility.isPrivateIPv6("::ffff:127.0.0.1"))
    }

    func testIsPrivateIPv6_publicAddresses_returnsFalse() {
        XCTAssertFalse(IPAddressUtility.isPrivateIPv6("2001:4860:4860::8888"))
        XCTAssertFalse(IPAddressUtility.isPrivateIPv6("2606:4700:4700::1111"))
        XCTAssertFalse(IPAddressUtility.isPrivateIPv6("::ffff:8.8.8.8"))
    }
}
