//
//  PluginSandboxGatewaySecurityTests.swift
//  ZhiYuTests
//
//  系统层级：[L1] 基础设施测试 - 插件系统
//  核心职责：验证 PluginSandboxGateway 在审计网络请求时对 file://、data: scheme、危险 header 以及非法 HTTP 方法的拦截与权限校验。
//

import XCTest
import Foundation
@testable import ZhiYuUnitTestHost

@MainActor
final class PluginSandboxGatewaySecurityTests: XCTestCase {

    /// 验证 file:// scheme 请求被安全网关拦截
    func testAuditFetch_fileScheme_isRejected() {
        XCTAssertThrowsError(
            try PluginSandboxGateway.auditFetch(
                url: "file:///etc/passwd",
                options: nil,
                allowedDomains: ["evil.com"],
                permissions: [PluginConstants.Permission.network]
            )
        ) { error in
            if case PluginSandboxError.invalidURL = error { return }
            if case PluginSandboxError.dlpFetchBlocked = error { return }
            XCTFail("file:// scheme 应被拒绝，但抛出了其他错误: \(error)")
        }
    }

    /// 验证 data: scheme 请求被安全网关拦截
    func testAuditFetch_dataScheme_isRejected() {
        XCTAssertThrowsError(
            try PluginSandboxGateway.auditFetch(
                url: "data:text/html,<script>evil</script>",
                options: nil,
                allowedDomains: ["evil.com"],
                permissions: [PluginConstants.Permission.network]
            )
        ) { error in
            if case PluginSandboxError.invalidURL = error { return }
            if case PluginSandboxError.dlpFetchBlocked = error { return }
            XCTFail("data: scheme 应被拒绝，但抛出了其他错误: \(error)")
        }
    }

    /// 验证危险请求头（如 Authorization/Cookie）被过滤并拒绝
    func testAuditFetch_dangerousHeaders_areFilteredAndRejected() {
        XCTAssertThrowsError(
            try PluginSandboxGateway.auditFetch(
                url: "https://api.example.com/data",
                options: [
                    "method": "GET",
                    "headers": [
                        "Authorization": "Bearer stolen-host-token",
                        "Cookie": "session=evil"
                    ]
                ],
                allowedDomains: ["api.example.com"],
                permissions: [PluginConstants.Permission.network]
            )
        ) { error in
            if case PluginSandboxError.permissionDenied = error { return }
            XCTFail("危险 header 应被过滤并抛出 permissionDenied，但抛出了: \(error)")
        }
    }

    /// 验证未在白名单的 HTTP Method（如 DELETE）被拒绝
    func testAuditFetch_disallowedHTTPMethod_isRestricted() {
        XCTAssertThrowsError(
            try PluginSandboxGateway.auditFetch(
                url: "https://api.example.com/data",
                options: ["method": "DELETE"],
                allowedDomains: ["api.example.com"],
                permissions: [PluginConstants.Permission.network]
            )
        ) { error in
            if case PluginSandboxError.permissionDenied = error { return }
            XCTFail("DELETE 方法应被拒绝并抛出 permissionDenied，但抛出了: \(error)")
        }
    }

    /// 验证小写/混合大小写危险 Header（如 authorization / cOoKiE / x-api-key）无法绕过黑名单
    func testAuditFetch_caseInsensitiveBlockedHeaders_areRejected() {
        let variants = [
            ("authorization", "Bearer stolen"),
            ("cOoKiE", "sid=123"),
            ("x-api-key", "sk-secret"),
            ("PROXY-AUTHORIZATION", "Basic abc")
        ]
        for (headerKey, headerValue) in variants {
            XCTAssertThrowsError(
                try PluginSandboxGateway.auditFetch(
                    url: "https://api.example.com/data",
                    options: ["method": "GET", "headers": [headerKey: headerValue]],
                    allowedDomains: ["api.example.com"],
                    permissions: [PluginConstants.Permission.network]
                ),
                "危险 header 变体 \(headerKey) 必须被拦截"
            ) { error in
                if case PluginSandboxError.permissionDenied = error { return }
                XCTFail("\(headerKey) 应抛出 permissionDenied，实际为: \(error)")
            }
        }
    }

    /// 验证即使 host 命中白名单，非 HTTP(S) 协议（file://、ftp://）仍被严格拒绝
    func testAuditFetch_nonHTTPSchemeWithAllowedHost_isRejected() {
        let dangerousURLs = [
            "file://api.example.com/etc/passwd",
            "ftp://api.example.com/secret.txt"
        ]
        for url in dangerousURLs {
            XCTAssertThrowsError(
                try PluginSandboxGateway.auditFetch(
                    url: url,
                    options: nil,
                    allowedDomains: ["api.example.com"],
                    permissions: [PluginConstants.Permission.network]
                ),
                "非 HTTP(S) URL \(url) 必须被拒绝"
            ) { error in
                if case PluginSandboxError.invalidURL = error { return }
                XCTFail("\(url) 应抛出 invalidURL，实际为: \(error)")
            }
        }
    }

    // MARK: - 缺陷 #197 回归：SSRF 强制拦截与空白包裹危险 Header 拦截

    /// 验证即使插件 manifest 将 127.0.0.1 / localhost / 内网元数据地址加入 allowedDomains，仍被 SSRF 硬防线阻断
    func testAuditFetch_ssrfHostsBlockedEvenWhenAllowlisted() {
        let ssrfCases: [(url: String, domain: String)] = [
            ("http://127.0.0.1:8080/admin", "127.0.0.1"),
            ("http://localhost/secret", "localhost"),
            ("http://169.254.169.254/latest/meta-data/", "169.254.169.254"),
            ("http://192.168.1.1/router", "192.168.1.1")
        ]
        for item in ssrfCases {
            XCTAssertThrowsError(
                try PluginSandboxGateway.auditFetch(
                    url: item.url,
                    options: nil,
                    allowedDomains: [item.domain],
                    permissions: [PluginConstants.Permission.network]
                ),
                "SSRF 目标 \(item.url) 即使在白名单中也必须被阻断"
            ) { error in
                if case PluginSandboxError.dlpFetchBlocked = error { return }
                XCTFail("\(item.url) 应抛出 dlpFetchBlocked，实际为: \(error)")
            }
        }
    }

    /// 验证带前后空白的危险 Header（如 " Authorization "）或空 Header 名称无法绕过黑名单
    func testAuditFetch_whitespacePaddedBlockedHeader_isRejected() {
        let paddedHeaders = [" Authorization ", "\tCookie\n", "  "]
        for key in paddedHeaders {
            XCTAssertThrowsError(
                try PluginSandboxGateway.auditFetch(
                    url: "https://api.example.com/data",
                    options: ["method": "GET", "headers": [key: "stolen"]],
                    allowedDomains: ["api.example.com"],
                    permissions: [PluginConstants.Permission.network]
                ),
                "空白包裹或空 Header 键 \(key.debugDescription) 必须被拒绝"
            ) { error in
                if case PluginSandboxError.permissionDenied = error { return }
                XCTFail("应抛出 permissionDenied，实际为: \(error)")
            }
        }
    }
}
