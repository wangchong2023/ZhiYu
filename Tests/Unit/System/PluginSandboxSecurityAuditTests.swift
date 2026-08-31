//
//  PluginSandboxSecurityAuditTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 测试层
//  核心职责：验证 PluginSandboxGateway 安全沙箱网络 DLP 审计、存储边界、未授权 HTTP 方法拦截与常量时间签名比对分支。
//

import XCTest
import UFPCore
@testable import ZhiYu

@MainActor
final class PluginSandboxSecurityAuditTests: XCTestCase {

    // MARK: - 1. 网络权限缺失审计分支

    func testAuditFetch_WhenNetworkPermissionMissing_ThrowsPermissionDenied() {
        XCTAssertThrowsError(
            try PluginSandboxGateway.auditFetch(
                url: "https://api.openai.com/v1/models",
                options: nil,
                allowedDomains: ["openai.com"],
                permissions: [] // 缺少 "network" 权限
            )
        ) { error in
            guard case PluginSandboxError.permissionDenied(let perm) = error else {
                return XCTFail("预期抛出 permissionDenied(network) 错误，实际得到: \(error)")
            }
            XCTAssertEqual(perm, PluginConstants.Permission.network)
        }
    }

    // MARK: - 2. 域名允许列表精确匹配与子域审计分支

    func testAuditFetch_WhenDomainNotInAllowedList_ThrowsDLPBlocked() {
        XCTAssertThrowsError(
            try PluginSandboxGateway.auditFetch(
                url: "https://malicious.attacker.com/leak",
                options: nil,
                allowedDomains: ["api.zhiyu.app", "openai.com"],
                permissions: [PluginConstants.Permission.network]
            )
        ) { error in
            guard case PluginSandboxError.dlpFetchBlocked(let host) = error else {
                return XCTFail("预期抛出 dlpFetchBlocked 错误，实际得到: \(error)")
            }
            XCTAssertEqual(host, "malicious.attacker.com")
        }
    }

    // MARK: - 3. 存储 Key 与 Payload 限制分支

    func testAuditStorage_WhenKeyLengthExceeded_ThrowsKeyLengthExceeded() {
        let longKey = String(repeating: "k", count: 300)

        XCTAssertThrowsError(
            try PluginSandboxGateway.auditStorage(key: longKey, value: "value")
        ) { error in
            guard case PluginSandboxError.keyLengthExceeded(let maxLen) = error else {
                return XCTFail("预期抛出 keyLengthExceeded 错误，实际得到: \(error)")
            }
            XCTAssertEqual(maxLen, 256)
        }
    }

    // MARK: - 4. 常量时间字节比对分支

    func testConstantTimeCompare_IdentifiesEqualityAndDifferences() {
        let dataA = Data([0x01, 0x02, 0x03, 0x04])
        let dataB = Data([0x01, 0x02, 0x03, 0x04])
        let dataC = Data([0x01, 0x02, 0x03, 0x05])
        let dataD = Data([0x01, 0x02])

        XCTAssertTrue(PluginLoader.constantTimeCompare(dataA, b: dataB), "相同字节数据应当返回 true")
        XCTAssertFalse(PluginLoader.constantTimeCompare(dataA, b: dataC), "不同字节数据应当返回 false")
        XCTAssertFalse(PluginLoader.constantTimeCompare(dataA, b: dataD), "不同长度数据应当返回 false")
    }
}
