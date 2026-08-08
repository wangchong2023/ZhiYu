//
//  PluginFetchPermissionTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/08.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：验证插件 fetch 网关的 network 权限校验（问题 #16 回归测试）。
//

import XCTest
@testable import ZhiYu

final class PluginFetchPermissionTests: XCTestCase {

    // MARK: - 权限校验（问题 #16 回归）

    /// 验证未声明 network 权限的插件发起 fetch 请求时，必须被 permissionDenied 熔断
    func testAuditFetch_withoutNetworkPermissionThrowsPermissionDenied() {
        let url = "https://api.github.com/repos/test"
        let allowedDomains = ["api.github.com"]

        XCTAssertThrowsError(
            try PluginSandboxGateway.auditFetch(
                url: url,
                options: nil,
                allowedDomains: allowedDomains,
                permissions: []
            ),
            "未声明 network 权限的插件发起 fetch 必须被拒绝"
        ) { error in
            guard case PluginSandboxError.permissionDenied(let permission) = error else {
                XCTFail("错误类型应为 permissionDenied，实际为: \(error)")
                return
            }
            XCTAssertEqual(permission, PluginConstants.Permission.network, "被拒绝的权限应为 network")
        }
    }

    /// 验证仅有 writeContent 权限（无 network）的插件发起 fetch 请求时，仍被拒绝
    func testAuditFetch_withOnlyWriteContentPermissionThrowsPermissionDenied() {
        let url = "https://api.github.com/repos/test"
        let allowedDomains = ["api.github.com"]

        XCTAssertThrowsError(
            try PluginSandboxGateway.auditFetch(
                url: url,
                options: nil,
                allowedDomains: allowedDomains,
                permissions: [PluginConstants.Permission.writeContent]
            ),
            "仅有 writeContent 权限的插件不能发起网络请求"
        ) { error in
            guard case PluginSandboxError.permissionDenied = error else {
                XCTFail("错误类型应为 permissionDenied，实际为: \(error)")
                return
            }
        }
    }

    /// 验证声明了 network 权限且域名在白名单内时，请求正常放行
    func testAuditFetch_withNetworkPermissionAndAllowedDomainPasses() {
        let url = "https://api.github.com/repos/test"
        let allowedDomains = ["api.github.com"]

        XCTAssertNoThrow(
            try PluginSandboxGateway.auditFetch(
                url: url,
                options: nil,
                allowedDomains: allowedDomains,
                permissions: [PluginConstants.Permission.network]
            ),
            "声明 network 权限且域名在白名单内时应放行"
        )
    }

    /// 验证权限检查优先于域名白名单检查——即使域名不在白名单，也应先抛出 permissionDenied
    func testAuditFetch_permissionCheckPrecedesDomainCheck() {
        let url = "https://evil.com/exfiltrate"
        let allowedDomains = ["api.github.com"]

        XCTAssertThrowsError(
            try PluginSandboxGateway.auditFetch(
                url: url,
                options: nil,
                allowedDomains: allowedDomains,
                permissions: []
            ),
            "权限检查应优先于域名检查"
        ) { error in
            // 应该是 permissionDenied，而非 dlpFetchBlocked
            guard case PluginSandboxError.permissionDenied = error else {
                XCTFail("权限检查应优先，错误类型应为 permissionDenied，实际为: \(error)")
                return
            }
        }
    }

    /// 验证有 network 权限但域名不在白名单时，抛出 dlpFetchBlocked（权限检查通过后的域名拦截）
    func testAuditFetch_withNetworkPermissionButUnauthorizedDomainThrowsDLP() {
        let url = "https://evil.com/exfiltrate"
        let allowedDomains = ["api.github.com"]

        XCTAssertThrowsError(
            try PluginSandboxGateway.auditFetch(
                url: url,
                options: nil,
                allowedDomains: allowedDomains,
                permissions: [PluginConstants.Permission.network]
            ),
            "有 network 权限但域名不在白名单时应抛出 dlpFetchBlocked"
        ) { error in
            guard case PluginSandboxError.dlpFetchBlocked(let host) = error else {
                XCTFail("错误类型应为 dlpFetchBlocked，实际为: \(error)")
                return
            }
            XCTAssertEqual(host, "evil.com", "应精确指出被拦截的域名")
        }
    }

    /// 验证 permissions 默认参数为空数组（未传 permissions 时等同于无权限）
    func testAuditFetch_defaultPermissionsIsEmptyArray() {
        let url = "https://api.github.com/repos/test"
        let allowedDomains = ["api.github.com"]

        XCTAssertThrowsError(
            try PluginSandboxGateway.auditFetch(
                url: url,
                options: nil,
                allowedDomains: allowedDomains
            ),
            "未传 permissions 参数时应等同于无 network 权限"
        ) { error in
            guard case PluginSandboxError.permissionDenied = error else {
                XCTFail("未传 permissions 应抛出 permissionDenied，实际为: \(error)")
                return
            }
        }
    }

    // MARK: - permissionDenied 错误属性

    /// 验证 permissionDenied 错误的 statusCode 为 403
    func testPermissionDeniedStatusCodeIs403() {
        XCTAssertEqual(PluginSandboxError.permissionDenied("network").statusCode, 403)
    }

    /// 验证 permissionDenied 错误的 errorDescription 非空
    func testPermissionDeniedErrorDescriptionIsNonEmpty() {
        let error = PluginSandboxError.permissionDenied("network")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("network") == true || error.errorDescription?.isEmpty == false)
    }
}
