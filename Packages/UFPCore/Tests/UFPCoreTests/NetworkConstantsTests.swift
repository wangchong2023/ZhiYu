//
//  NetworkConstantsTests.swift
//  UFPCore
//
//  系统层级：[L0] 基础设施层测试
//  核心职责：验证 NetworkConstants 各枚举常量值符合 RFC 1918/5735/6598/3927/4291 标准。
//

import XCTest
@testable import UFPCore

final class NetworkConstantsTests: XCTestCase {

    // MARK: - IPv4 私有地址段 (RFC 1918)

    func testIPv4PrivateRangeClassA() {
        XCTAssertEqual(NetworkConstants.IPv4PrivateRange.classAFirstOctet, 10)
    }

    func testIPv4PrivateRangeClassB() {
        XCTAssertEqual(NetworkConstants.IPv4PrivateRange.classBFirstOctet, 172)
        XCTAssertEqual(NetworkConstants.IPv4PrivateRange.classBSecondOctetStart, 16)
        XCTAssertEqual(NetworkConstants.IPv4PrivateRange.classBSecondOctetEnd, 31)
    }

    func testIPv4PrivateRangeClassC() {
        XCTAssertEqual(NetworkConstants.IPv4PrivateRange.classCFirstOctet, 192)
        XCTAssertEqual(NetworkConstants.IPv4PrivateRange.classCSecondOctet, 168)
    }

    // MARK: - RFC 5735 特殊用途段

    func testRFC5735SpecialRanges() {
        XCTAssertEqual(NetworkConstants.IPv4PrivateRange.thisNetworkOctet, 0)
        XCTAssertEqual(NetworkConstants.IPv4PrivateRange.loopbackOctet, 127)
    }

    // MARK: - RFC 6598 CGNAT 段

    func testCGNATRange() {
        XCTAssertEqual(NetworkConstants.IPv4PrivateRange.cgnatFirstOctet, 100)
        XCTAssertEqual(NetworkConstants.IPv4PrivateRange.cgnatSecondOctetStart, 64)
        XCTAssertEqual(NetworkConstants.IPv4PrivateRange.cgnatSecondOctetEnd, 127)
    }

    // MARK: - RFC 3927 链路本地段

    func testLinkLocalRange() {
        XCTAssertEqual(NetworkConstants.IPv4PrivateRange.linkLocalFirstOctet, 169)
        XCTAssertEqual(NetworkConstants.IPv4PrivateRange.linkLocalSecondOctet, 254)
    }

    // MARK: - IPv4 Octet 校验

    func testIPv4OctetValidation() {
        XCTAssertEqual(NetworkConstants.IPv4Octet.maxValue, 255)
        XCTAssertEqual(NetworkConstants.IPv4Octet.fullCount, 4)
        XCTAssertEqual(NetworkConstants.IPv4Octet.minCount, 1)
        XCTAssertEqual(NetworkConstants.IPv4Octet.maxCount, 4)
    }

    // MARK: - IPv4 位运算移位量

    func testIPv4BitShift() {
        XCTAssertEqual(NetworkConstants.IPv4BitShift.octet1, 24)
        XCTAssertEqual(NetworkConstants.IPv4BitShift.octet2, 16)
        XCTAssertEqual(NetworkConstants.IPv4BitShift.octet3, 8)
        XCTAssertEqual(NetworkConstants.IPv4BitShift.octetMask, 0xFF)
    }

    // MARK: - IPv6 私有地址段 (RFC 4291)

    func testIPv6UniqueLocalPrefix() {
        XCTAssertEqual(NetworkConstants.IPv6PrivateRange.uniqueLocalPrefixFC, "fc")
        XCTAssertEqual(NetworkConstants.IPv6PrivateRange.uniqueLocalPrefixFD, "fd")
    }

    func testIPv6LinkLocalPrefix() {
        XCTAssertEqual(NetworkConstants.IPv6PrivateRange.linkLocalPrefixFE8, "fe8")
        XCTAssertEqual(NetworkConstants.IPv6PrivateRange.linkLocalPrefixFE9, "fe9")
        XCTAssertEqual(NetworkConstants.IPv6PrivateRange.linkLocalPrefixFEA, "fea")
        XCTAssertEqual(NetworkConstants.IPv6PrivateRange.linkLocalPrefixFEB, "feb")
    }

    func testIPv6LoopbackConstants() {
        XCTAssertEqual(NetworkConstants.IPv6PrivateRange.totalBytes, 16)
        XCTAssertEqual(NetworkConstants.IPv6PrivateRange.lastByteIndex, 15)
        XCTAssertEqual(NetworkConstants.IPv6PrivateRange.loopbackMarker, 0x01)
    }

    func testIPv6V4MappedConstants() {
        XCTAssertEqual(NetworkConstants.IPv6PrivateRange.v4MappedZeroPrefixCount, 10)
        XCTAssertEqual(NetworkConstants.IPv6PrivateRange.v4MappedIndex1, 10)
        XCTAssertEqual(NetworkConstants.IPv6PrivateRange.v4MappedIndex2, 11)
        XCTAssertEqual(NetworkConstants.IPv6PrivateRange.v4MappedMarker, 0xFF)
    }

    // MARK: - IP 编码前缀

    func testIPEncodingPrefixes() {
        XCTAssertEqual(NetworkConstants.IPEncoding.hexPrefixLower, "0x")
        XCTAssertEqual(NetworkConstants.IPEncoding.hexPrefixUpper, "0X")
        XCTAssertEqual(NetworkConstants.IPEncoding.octalPrefix, "0")
    }

    // MARK: - 环回与本地地址

    func testLoopbackConstants() {
        XCTAssertEqual(NetworkConstants.Loopback.localhost, "localhost")
        XCTAssertEqual(NetworkConstants.Loopback.loopbackIPv4, "127.0.0.1")
        XCTAssertEqual(NetworkConstants.Loopback.loopbackIPv6, "::1")
        XCTAssertEqual(NetworkConstants.Loopback.loopbackIPv6Bracketed, "[::1]")
        XCTAssertEqual(NetworkConstants.Loopback.linkLocalPrefix, "169.254.")
    }

    // MARK: - 本地域名后缀

    func testLocalDomainSuffixes() {
        XCTAssertEqual(NetworkConstants.LocalDomainSuffix.local, ".local")
        XCTAssertEqual(NetworkConstants.LocalDomainSuffix.internalSuffix, ".internal")
        XCTAssertEqual(NetworkConstants.LocalDomainSuffix.localhost, ".localhost")
    }

    // MARK: - DNS Rebinding 服务后缀

    func testDNSRebindingSuffixes() {
        let suffixes = NetworkConstants.DNSRebinding.suffixes
        XCTAssertTrue(suffixes.contains(".nip.io"))
        XCTAssertTrue(suffixes.contains(".sslip.io"))
        XCTAssertTrue(suffixes.contains(".localtest.me"))
        XCTAssertTrue(suffixes.contains(".xip.io"))
        XCTAssertEqual(suffixes.count, 4)
    }

    // MARK: - URL Scheme 白名单

    func testURLSchemeWhitelist() {
        XCTAssertEqual(NetworkConstants.URLScheme.http, "http")
        XCTAssertEqual(NetworkConstants.URLScheme.https, "https")
        XCTAssertTrue(NetworkConstants.URLScheme.allowed.contains("http"))
        XCTAssertTrue(NetworkConstants.URLScheme.allowed.contains("https"))
        XCTAssertEqual(NetworkConstants.URLScheme.allowed.count, 2)
    }

    // MARK: - IPv6 唯一本地地址掩码

    func testIPv6UniqueLocalMask() {
        XCTAssertEqual(NetworkConstants.IPv6PrivateRange.uniqueLocalMask, 0xFE)
        XCTAssertEqual(NetworkConstants.IPv6PrivateRange.uniqueLocalExpected, 0xFC)
    }

    // MARK: - IPv6 链路本地地址字节

    func testIPv6LinkLocalBytes() {
        XCTAssertEqual(NetworkConstants.IPv6PrivateRange.linkLocalFirstByte, 0xFE)
        XCTAssertEqual(NetworkConstants.IPv6PrivateRange.linkLocalSecondByteMask, 0xC0)
        XCTAssertEqual(NetworkConstants.IPv6PrivateRange.linkLocalSecondByteExpected, 0x80)
    }

    // MARK: - IPv6 V4 映射地址八位组索引

    func testIPv6V4MappedOctetIndices() {
        XCTAssertEqual(NetworkConstants.IPv6PrivateRange.v4MappedOctetIndex0, 12)
        XCTAssertEqual(NetworkConstants.IPv6PrivateRange.v4MappedOctetIndex1, 13)
        XCTAssertEqual(NetworkConstants.IPv6PrivateRange.v4MappedOctetIndex2, 14)
        XCTAssertEqual(NetworkConstants.IPv6PrivateRange.v4MappedOctetIndex3, 15)
    }

    // MARK: - 常量值不可变性回归保护

    func testIPv4PrivateRangeAllOctetsMatchRFC() {
        XCTAssertEqual(NetworkConstants.IPv4PrivateRange.classAFirstOctet, 10)
        XCTAssertEqual(NetworkConstants.IPv4PrivateRange.classBFirstOctet, 172)
        XCTAssertEqual(NetworkConstants.IPv4PrivateRange.classCFirstOctet, 192)
        XCTAssertEqual(NetworkConstants.IPv4PrivateRange.loopbackOctet, 127)
        XCTAssertEqual(NetworkConstants.IPv4PrivateRange.thisNetworkOctet, 0)
    }

    func testIPv6AddressStructureConsistency() {
        XCTAssertEqual(NetworkConstants.IPv6PrivateRange.totalBytes, 16)
        XCTAssertEqual(NetworkConstants.IPv6PrivateRange.lastByteIndex, 15)
        XCTAssertEqual(NetworkConstants.IPv6PrivateRange.v4MappedOctetIndex3, 15)
        XCTAssertEqual(NetworkConstants.IPv6PrivateRange.lastByteIndex, NetworkConstants.IPv6PrivateRange.v4MappedOctetIndex3)
    }

    func testLoopbackAddressStringRepresentations() {
        XCTAssertEqual(NetworkConstants.Loopback.loopbackIPv4, "127.0.0.1")
        XCTAssertEqual(NetworkConstants.Loopback.loopbackIPv6, "::1")
        XCTAssertEqual(NetworkConstants.Loopback.localhost, "localhost")
        XCTAssertNotEqual(NetworkConstants.Loopback.loopbackIPv4, NetworkConstants.Loopback.loopbackIPv6)
    }

    // MARK: - DNS Rebinding 与本地域名后缀完整性

    func testLocalDomainAndDNSRebindingDisjoint() {
        let localSuffixes = [
            NetworkConstants.LocalDomainSuffix.local,
            NetworkConstants.LocalDomainSuffix.internalSuffix,
            NetworkConstants.LocalDomainSuffix.localhost,
        ]
        let dnsSuffixes = NetworkConstants.DNSRebinding.suffixes
        for ls in localSuffixes {
            XCTAssertFalse(dnsSuffixes.contains(ls), "本地后缀不应出现在 DNS rebinding 列表中: \(ls)")
        }
    }

    func testURLSchemeAllowedSetIsHttpAndHttpsOnly() {
        let allowed = NetworkConstants.URLScheme.allowed
        XCTAssertEqual(allowed, Set([NetworkConstants.URLScheme.http, NetworkConstants.URLScheme.https]))
        XCTAssertFalse(allowed.contains("ftp"))
        XCTAssertFalse(allowed.contains("file"))
    }

    // MARK: - IPEncoding 前缀唯一性

    func testIPEncodingPrefixesAreDistinct() {
        XCTAssertNotEqual(NetworkConstants.IPEncoding.hexPrefixLower, NetworkConstants.IPEncoding.hexPrefixUpper)
        XCTAssertNotEqual(NetworkConstants.IPEncoding.hexPrefixLower, NetworkConstants.IPEncoding.octalPrefix)
        XCTAssertNotEqual(NetworkConstants.IPEncoding.hexPrefixUpper, NetworkConstants.IPEncoding.octalPrefix)
    }

    // MARK: - IPv4 BitShift 组合验证

    func testIPv4BitShiftOctetMaskCoversFullOctet() {
        let mask = NetworkConstants.IPv4BitShift.octetMask
        XCTAssertEqual(mask, 0xFF)
        XCTAssertEqual(mask & 0xFF, 0xFF)
    }

    // MARK: - Loopback linkLocalPrefix 与 RFC 3927 一致性

    func testLoopbackLinkLocalPrefixMatchesRFC3927() {
        XCTAssertEqual(NetworkConstants.Loopback.linkLocalPrefix, "169.254.")
        XCTAssertEqual(NetworkConstants.IPv4PrivateRange.linkLocalFirstOctet, 169)
        XCTAssertEqual(NetworkConstants.IPv4PrivateRange.linkLocalSecondOctet, 254)
    }
}
