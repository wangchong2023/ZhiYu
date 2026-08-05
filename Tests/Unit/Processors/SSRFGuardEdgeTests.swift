//
//  SSRFGuardEdgeTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 SSRFGuard 对内网地址、环回地址、链路本地、IP 编码绕过、DNS rebinding 域名的拦截能力。
//

import XCTest
@testable import ZhiYu

final class SSRFGuardEdgeTests: XCTestCase {

    // MARK: - 环回地址拦截

    func testIsSafeURL_localhost_rejected() {
        XCTAssertFalse(SSRFGuard.isSafeURL(URL(string: "http://localhost:8080")!))
    }

    func testIsSafeURL_127001_rejected() {
        XCTAssertFalse(SSRFGuard.isSafeURL(URL(string: "http://127.0.0.1")!))
    }

    func testIsSafeURL_127001Subnet_rejected() {
        XCTAssertFalse(SSRFGuard.isSafeURL(URL(string: "http://127.255.255.255")!))
    }

    func testIsSafeURL_ipv6Loopback_rejected() {
        XCTAssertFalse(SSRFGuard.isSafeURL(URL(string: "http://[::1]")!))
    }

    // MARK: - 链路本地地址

    func testIsSafeURL_169254_AWSMetadata_rejected() {
        XCTAssertFalse(SSRFGuard.isSafeURL(URL(string: "http://169.254.169.254/latest/meta-data/")!))
    }

    func testIsSafeURL_169254_GCPMetadata_rejected() {
        XCTAssertFalse(SSRFGuard.isSafeURL(URL(string: "http://169.254.169.254/computeMetadata/v1/")!))
    }

    // MARK: - 私有网络段

    func testIsSafeURL_10x_rejected() {
        XCTAssertFalse(SSRFGuard.isSafeURL(URL(string: "http://10.0.0.1")!))
    }

    func testIsSafeURL_17216x_rejected() {
        XCTAssertFalse(SSRFGuard.isSafeURL(URL(string: "http://172.16.0.1")!))
    }

    func testIsSafeURL_17231x_rejected() {
        XCTAssertFalse(SSRFGuard.isSafeURL(URL(string: "http://172.31.255.255")!))
    }

    func testIsSafeURL_192168_rejected() {
        XCTAssertFalse(SSRFGuard.isSafeURL(URL(string: "http://192.168.1.1")!))
    }

    func testIsSafeURL_CGNAT_10064_rejected() {
        XCTAssertFalse(SSRFGuard.isSafeURL(URL(string: "http://100.64.0.1")!))
    }

    func testIsSafeURL_CGNAT_100127_rejected() {
        XCTAssertFalse(SSRFGuard.isSafeURL(URL(string: "http://100.127.255.255")!))
    }

    // MARK: - IP 编码绕过（HIGH-5 修复验证）

    func testIsSafeURL_decimalIntegerIP_rejected() {
        // 2130706433 = 127.0.0.1
        XCTAssertFalse(SSRFGuard.isSafeURL(URL(string: "http://2130706433")!))
    }

    func testIsSafeURL_octalIP_rejected() {
        // 0177.0.0.1 = 127.0.0.1
        XCTAssertFalse(SSRFGuard.isSafeURL(URL(string: "http://0177.0.0.1")!))
    }

    func testIsSafeURL_hexIP_rejected() {
        // 0x7f.0.0.1 = 127.0.0.1
        XCTAssertFalse(SSRFGuard.isSafeURL(URL(string: "http://0x7f.0.0.1")!))
    }

    func testIsSafeURL_abbreviatedIP_1271_rejected() {
        // 127.1 = 127.0.0.1
        XCTAssertFalse(SSRFGuard.isSafeURL(URL(string: "http://127.1")!))
    }

    // MARK: - IPv6 私有地址（HIGH-4 修复验证）

    func testIsSafeURL_ipv6UniqueLocal_fc_rejected() {
        XCTAssertFalse(SSRFGuard.isSafeURL(URL(string: "http://[fc00::1]")!))
    }

    func testIsSafeURL_ipv6UniqueLocal_fd_rejected() {
        XCTAssertFalse(SSRFGuard.isSafeURL(URL(string: "http://[fd00::1]")!))
    }

    func testIsSafeURL_ipv6LinkLocal_fe80_rejected() {
        XCTAssertFalse(SSRFGuard.isSafeURL(URL(string: "http://[fe80::1]")!))
    }

    func testIsSafeURL_ipv6LinkLocal_fe8f_rejected() {
        XCTAssertFalse(SSRFGuard.isSafeURL(URL(string: "http://[fe8f::1]")!))
    }

    // MARK: - 本地域名

    func testIsSafeURL_dotLocal_rejected() {
        XCTAssertFalse(SSRFGuard.isSafeURL(URL(string: "http://myhost.local")!))
    }

    func testIsSafeURL_dotInternal_rejected() {
        XCTAssertFalse(SSRFGuard.isSafeURL(URL(string: "http://api.internal")!))
    }

    func testIsSafeURL_dotLocalhost_rejected() {
        XCTAssertFalse(SSRFGuard.isSafeURL(URL(string: "http://service.localhost")!))
    }

    // MARK: - DNS rebinding 服务域名

    func testIsSafeURL_nipIO_rejected() {
        XCTAssertFalse(SSRFGuard.isSafeURL(URL(string: "http://127.0.0.1.nip.io")!))
    }

    func testIsSafeURL_sslipIO_rejected() {
        XCTAssertFalse(SSRFGuard.isSafeURL(URL(string: "http://10.0.0.1.sslip.io")!))
    }

    func testIsSafeURL_localtestMe_rejected() {
        XCTAssertFalse(SSRFGuard.isSafeURL(URL(string: "http://127.0.0.1.localtest.me")!))
    }

    // MARK: - 合法公网地址

    func testIsSafeURL_publicDomain_accepted() {
        XCTAssertTrue(SSRFGuard.isSafeURL(URL(string: "https://example.com")!))
    }

    func testIsSafeURL_publicIP_accepted() {
        XCTAssertTrue(SSRFGuard.isSafeURL(URL(string: "http://8.8.8.8")!))
    }

    func testIsSafeURL_githubCom_accepted() {
        XCTAssertTrue(SSRFGuard.isSafeURL(URL(string: "https://github.com")!))
    }

    // MARK: - 边界情况

    func testIsSafeURL_noHost_rejected() {
        XCTAssertFalse(SSRFGuard.isSafeURL(URL(string: "file:///etc/passwd")!))
    }

    func testIsSafeURL_emptyHost_rejected() {
        let url = URL(string: "http://")
        if let url = url {
            XCTAssertFalse(SSRFGuard.isSafeURL(url))
        }
    }

    // MARK: - 0.0.0.0/8 段

    func testIsSafeURL_0000_rejected() {
        XCTAssertFalse(SSRFGuard.isSafeURL(URL(string: "http://0.0.0.0")!))
    }

    func testIsSafeURL_00255_rejected() {
        XCTAssertFalse(SSRFGuard.isSafeURL(URL(string: "http://0.255.255.255")!))
    }
}
