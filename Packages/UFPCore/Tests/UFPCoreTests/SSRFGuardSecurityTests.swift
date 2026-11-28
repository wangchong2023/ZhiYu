//
//  SSRFGuardSecurityTests.swift
//  UFPCoreTests
//
//  系统层级：[UFPCoreTests]
//  核心职责：验证 SSRFGuard 对内网/环回/链路本地/IP 编码绕过/DNS rebinding/IPv6 的防御与正常公网放行。
//

import XCTest
@testable import UFPCore

final class SSRFGuardSecurityTests: XCTestCase {

    // MARK: - 环回地址拦截测试

    func testIsSafeURL_loopbackAddresses_rejects() {
        let loopbacks = [
            "http://localhost",
            "http://localhost:8080",
            "http://127.0.0.1",
            "http://127.0.0.2",
            "http://127.255.255.255",
            "http://[::1]",
            "http://[0:0:0:0:0:0:0:1]"
        ]
        for urlStr in loopbacks {
            guard let url = URL(string: urlStr) else { continue }
            XCTAssertFalse(SSRFGuard.isSafeURL(url), "环回地址必须被拦截: \(urlStr)")
        }
    }

    // MARK: - 链路本地与云厂商元数据端点拦截测试

    func testIsSafeURL_linkLocalAndMetadata_rejects() {
        let metadataURLs = [
            "http://169.254.169.254/latest/meta-data/",
            "http://169.254.169.254/computeMetadata/v1/",
            "http://169.254.0.1"
        ]
        for urlStr in metadataURLs {
            guard let url = URL(string: urlStr) else { continue }
            XCTAssertFalse(SSRFGuard.isSafeURL(url), "链路本地/元数据地址必须被拦截: \(urlStr)")
        }
    }

    // MARK: - 私有 IPv4 地址段拦截测试 (RFC 1918 / RFC 5735 / RFC 6598)

    func testIsSafeURL_privateIPv4Ranges_rejects() {
        let privateURLs = [
            // Class A: 10.0.0.0/8
            "http://10.0.0.1",
            "http://10.255.255.255",
            // Class B: 172.16.0.0/12
            "http://172.16.0.1",
            "http://172.31.255.255",
            // Class C: 192.168.0.0/16
            "http://192.168.1.1",
            "http://192.168.254.254",
            // 0.0.0.0/8
            "http://0.0.0.0",
            "http://0.1.2.3",
            // CGNAT: 100.64.0.0/10
            "http://100.64.0.1",
            "http://100.127.255.255"
        ]
        for urlStr in privateURLs {
            guard let url = URL(string: urlStr) else { continue }
            XCTAssertFalse(SSRFGuard.isSafeURL(url), "私有 IPv4 地址必须被拦截: \(urlStr)")
        }
    }

    // MARK: - 私有与链路本地 IPv6 地址段拦截测试

    func testIsSafeURL_privateIPv6Ranges_rejects() {
        let ipv6PrivateURLs = [
            "http://[fc00::1]",
            "http://[fd12:3456:789a::1]",
            "http://[fe80::1]",
            "http://[fe90::1]",
            "http://[fea0::1]",
            "http://[feb0::1]"
        ]
        for urlStr in ipv6PrivateURLs {
            guard let url = URL(string: urlStr) else { continue }
            XCTAssertFalse(SSRFGuard.isSafeURL(url), "私有/链路本地 IPv6 必须被拦截: \(urlStr)")
        }
    }

    // MARK: - 本地域名后缀与 DNS Rebinding 服务拦截测试

    func testIsSafeURL_localDomainSuffixesAndRebinding_rejects() {
        let rejectedDomains = [
            "http://server.local",
            "http://api.internal",
            "http://dev.localhost",
            "http://127.0.0.1.nip.io",
            "http://app.sslip.io"
        ]
        for urlStr in rejectedDomains {
            guard let url = URL(string: urlStr) else { continue }
            XCTAssertFalse(SSRFGuard.isSafeURL(url), "本地域名或 DNS Rebinding 服务必须被拦截: \(urlStr)")
        }
    }

    // MARK: - IP 编码混淆绕过测试 (十进制/八进制/十六进制/省略格式)

    func testIsSafeURL_obfuscatedIPEncodings_normalizesAndRejects() {
        let obfuscated = [
            // 纯十进制整数 (2130706433 = 127.0.0.1)
            "http://2130706433",
            // 八进制段 (0177 = 127)
            "http://0177.0.0.1",
            // 十六进制段 (0x7f = 127)
            "http://0x7f.0.0.1",
            "http://0X7F.0.0.1",
            // 省略格式
            "http://127.1",
            "http://10.1"
        ]
        for urlStr in obfuscated {
            guard let url = URL(string: urlStr) else { continue }
            XCTAssertFalse(SSRFGuard.isSafeURL(url), "编码混淆的私有 IP 必须被归一化后拦截: \(urlStr)")
        }
    }

    // MARK: - 正常公网安全地址放行测试

    func testIsSafeURL_legitimatePublicAddresses_allows() {
        let safeURLs = [
            "https://example.com",
            "https://www.apple.com/swift",
            "https://1.1.1.1",
            "https://8.8.8.8",
            "https://100.63.1.1", // 略低于 CGNAT 起点 100.64.0.0
            "https://100.128.1.1", // 略高于 CGNAT 终点 100.127.255.255
            "https://172.15.1.1", // 低于 172.16.0.0
            "https://172.32.1.1", // 高于 172.31.255.255
            "https://192.169.1.1", // 非 192.168.0.0/16
            "https://fc-bank.com" // fc 开头的合法域名，非 IPv6 格式
        ]
        for urlStr in safeURLs {
            guard let url = URL(string: urlStr) else { continue }
            XCTAssertTrue(SSRFGuard.isSafeURL(url), "合法公网地址必须放行: \(urlStr)")
        }
    }

    func testIsSafeURL_nilHostURL_returnsFalse() {
        let fileURL = URL(fileURLWithPath: "/tmp/test.txt")
        XCTAssertFalse(SSRFGuard.isSafeURL(fileURL), "无 host 的文件 URL 必须判定为不安全")
    }

    func testIsSafeURL_allRebindingSuffixes_rejects() {
        for suffix in NetworkConstants.DNSRebinding.suffixes {
            guard let url = URL(string: "http://malicious\(suffix)") else { continue }
            XCTAssertFalse(SSRFGuard.isSafeURL(url), "DNS Rebinding 后缀 \(suffix) 必须被拦截")
        }
    }

    // MARK: - 缺陷 #204 回归：IPv4-mapped IPv6、未指定地址 :: 与 FQDN 尾随点绕过拦截

    func testIsSafeURL_ipv4MappedIPv6UnspecifiedAndTrailingDot_rejects() {
        let bypassURLs = [
            "http://[::ffff:127.0.0.1]/admin",
            "http://[::ffff:7f00:1]/admin",
            "http://[::ffff:169.254.169.254]/latest/meta-data/",
            "http://[::ffff:10.0.0.1]/internal",
            "http://[::]/",
            "http://[0:0:0:0:0:0:0:0]/",
            "http://localhost./api",
            "http://server.local./status"
        ]
        for urlStr in bypassURLs {
            guard let url = URL(string: urlStr) else {
                XCTFail("测试 URL 构造失败: \(urlStr)")
                continue
            }
            XCTAssertFalse(SSRFGuard.isSafeURL(url), "SSRF 绕过地址必须被拦截: \(urlStr)")
        }

        // 公网 IPv4-mapped IPv6（如 1.1.1.1）与公网 FQDN 尾点（example.com.）应正常放行
        XCTAssertTrue(SSRFGuard.isSafeURL(URL(string: "https://[::ffff:1.1.1.1]/")!))
        XCTAssertTrue(SSRFGuard.isSafeURL(URL(string: "https://example.com./")!))
    }

    // MARK: - 缺陷 #276 回归：Zone ID 绕过、IPv4 兼容/NAT64 IPv6、组播/广播与缩写溢出阻断

    func testIsSafeURL_zoneIDCompatibleNAT64MulticastAndOverflow_rejects() throws {
        let bypassURLs = [
            "http://[::1%25lo0]/admin",
            "http://[fe80::1%25en0]/secret",
            "http://[::127.0.0.1]/admin",
            "http://[::169.254.169.254]/latest/meta-data/",
            "http://[64:ff9b::127.0.0.1]/admin",
            "http://[64:ff9b::10.0.0.1]/internal",
            "http://224.0.0.1/multicast",
            "http://255.255.255.255/broadcast"
        ]
        for urlStr in bypassURLs {
            let url = try XCTUnwrap(URL(string: urlStr))
            XCTAssertFalse(SSRFGuard.isSafeURL(url), "新型 SSRF 绕过向量必须被拦截: \(urlStr)")
        }

        // 合法公网 NAT64（64:ff9b::1.1.1.1）仍应允许；缩写段位宽溢出走私必须返回 nil
        XCTAssertTrue(SSRFGuard.isSafeURL(try XCTUnwrap(URL(string: "https://[64:ff9b::1.1.1.1]/"))))
        XCTAssertNil(IPAddressUtility.normalizeIP("127.16777217"), "2 段缩写尾段超过 24 位上限必须拒绝")
        XCTAssertNil(IPAddressUtility.normalizeIP("10.1.70000"), "3 段缩写尾段超过 16 位上限必须拒绝")
    }
}
