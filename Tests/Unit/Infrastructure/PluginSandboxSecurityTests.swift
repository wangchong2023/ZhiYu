//
//  PluginSandboxSecurityTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 PluginSandboxGateway 的 DLP 审计与越权拦截开展硬核安全测试。
//

import XCTest
@testable import ZhiYu

final class PluginSandboxSecurityTests: XCTestCase {

    // MARK: - 1. 跨域与子域欺骗攻击拦截测试

    /// 验证当插件尝试向未经声明的非法域名发包时，必须精准抛出 dlpFetchBlocked 熔断
    func testAuditFetch_blockedUnauthorizedDomain() {
        let unauthorizedURL = "https://evil-attacker.com/steal-data"
        let allowedDomains = ["api.zhiyu.app", "trusted.org"]

        XCTAssertThrowsError(
            try PluginSandboxGateway.auditFetch(url: unauthorizedURL, options: nil, allowedDomains: allowedDomains, permissions: [PluginConstants.Permission.network]),
            "未授权域名发包必须被沙箱网关熔断"
        ) { error in
            guard case PluginSandboxError.dlpFetchBlocked(let blockedHost) = error else {
                XCTFail("错误类型不符合预期，收到: \(error)")
                return
            }
            XCTAssertEqual(blockedHost, "evil-attacker.com", "应精确指出被拦截的目标域名")
        }
    }

    /// 验证针对子前缀欺骗（如 trusted.org.attacker.com）时，精确后缀匹配审计能 100% 拦截
    func testAuditFetch_blockedDomainSuffixSpoofing() {
        let spoofedURL = "https://trusted.org.attacker.com/v1/data"
        let allowedDomains = ["trusted.org"]

        XCTAssertThrowsError(
            try PluginSandboxGateway.auditFetch(url: spoofedURL, options: nil, allowedDomains: allowedDomains, permissions: [PluginConstants.Permission.network]),
            "前缀伪造子域请求必须被拦截"
        ) { error in
            guard case PluginSandboxError.dlpFetchBlocked = error else {
                XCTFail("必须抛出 dlpFetchBlocked 异常")
                return
            }
        }
    }

    // MARK: - 2. 超大 Payload 内存溢出防御测试

    /// 验证当插件上传超过 5MB 的超大 Payload 时，必须精准抛出 payloadTooLarge
    func testAuditFetch_blockedPayloadTooLarge() {
        let validURL = "https://api.zhiyu.app/upload"
        let allowedDomains = ["api.zhiyu.app"]
        let hugeBody = String(repeating: "A", count: 6 * 1024 * 1024) // 6MB
        let options: [String: Any] = ["body": hugeBody, "method": "POST"]

        XCTAssertThrowsError(
            try PluginSandboxGateway.auditFetch(url: validURL, options: options, allowedDomains: allowedDomains, permissions: [PluginConstants.Permission.network]),
            "超过 5MB 的超大载荷必须被拦截"
        ) { error in
            guard case PluginSandboxError.payloadTooLarge = error else {
                XCTFail("应该抛出 payloadTooLarge 异常")
                return
            }
        }
    }

    // MARK: - 3. 持久化数据 Key 越界审计测试

    /// 验证当写入的 Key 长度超过 256 字符限制时，必须精准抛出 keyLengthExceeded
    func testAuditStorage_keyLengthExceeded() {
        let longKey = String(repeating: "K", count: 300)
        let value = "normal_value"

        XCTAssertThrowsError(
            try PluginSandboxGateway.auditStorage(key: longKey, value: value),
            "超过 256 字符的存储 Key 必须被拒绝"
        ) { error in
            guard case PluginSandboxError.keyLengthExceeded(let maxAllowed) = error else {
                XCTFail("应该抛出 keyLengthExceeded 异常")
                return
            }
            XCTAssertEqual(maxAllowed, 256, "允许的最大 key 长度应为 256")
        }
    }
}
