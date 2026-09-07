//
//  PluginSandboxGatewaySecurityTests.swift
//  ZhiYuTests
//
//  系统层级：[L1] 基础设施测试 - 插件系统
//  核心职责：验证 PluginSandboxGateway 在审计网络请求时对 file://、data: scheme、危险 header 以及非法 HTTP 方法的拦截与权限校验。
//

import XCTest
import Foundation
@testable import ZhiYu

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
}
