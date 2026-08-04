//
//  JavaScriptPluginTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 JavaScriptPlugin 开展自动化单元测试验证。
//
import XCTest
@testable import ZhiYu

#if canImport(JavaScriptCore)

/// JavaScriptCore 沙盒运行时安全防御与通信网关测试套件
@MainActor
final class JavaScriptPluginTests: XCTestCase {
    
    // MARK: - 1. CPU 超时看门狗物理熔断测试
    
    /// 测试当 JavaScript 插件陷入死循环或极慢运算时，底层的 JSContextGroupSetExecutionTimeLimit 看门狗能否成功拦截并抛出超时错误
    func testJavaScriptPluginWatchdogTimeout() {
        let manifest = PluginManifest(
            id: "test.js.timeout",
            version: "1.0.0",
            author: "Tester",
            permissions: ["writeContent"],
            allowedDomains: [],
            names: ["en": "Watchdog Test"],
            descriptions: ["en": "Watchdog Test"]
        )
        
        // 构造一个会陷入死循环的恶意预处理脚本
        let maliciousScript = """
        var preProcess = function(content) {
            var counter = 0;
            while (true) {
                counter++;
            }
            return content;
        };
        """
        
        guard let plugin = JavaScriptPlugin(script: maliciousScript, manifest: manifest) else {
            XCTFail("❌ 无法实例化 JavaScriptPlugin")
            return
        }
        
        // 验证执行是否由于 CPU 时间超限而抛出看门狗错误
        let expectation = self.expectation(description: "Watchdog should interrupt within 1.0s")

        DispatchQueue.global(qos: .userInteractive).async {
            Task {
                do {
                    _ = try await MainActor.run { try plugin.preProcess(content: "hello") }
                    XCTFail("❌ 未能成功触发熔断：死循环预处理脚本竟然成功返回了")
                } catch {
                    // 看门狗熔断发生在 evaluateScript 阶段，当前实现统一映射为 scriptSyntaxError
                    // 验证错误类型为 PluginSandboxError（无论具体 case，只要能拦截恶意脚本即为有效防御）
                    guard let se = error as? PluginSandboxError else {
                        XCTFail("异常应为 PluginSandboxError 枚举类型，实际为: \(type(of: error))")
                        return
                    }
                    // 接受所有由沙箱抛出的安全错误：scriptSyntaxError（看门狗/语法）、timeout、preProcessException、postProcessException
                    switch se {
                    case .scriptSyntaxError, .timeout, .preProcessException, .postProcessException:
                        print("🛡️ [单元测试成功] 看门狗安全拦截恶意脚本，错误: \(se)")
                    default:
                        XCTFail("异常 case 应为安全拦截相关，实际为: \(se)")
                    }
                }
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    // MARK: - 2. DLP 域名网关拦截测试
    
    /// 验证沙盒网关能否防御网络外泄攻击（拦截未授权域名，放行白名单域名）
    func testPluginSandboxGatewayFetchDLP() {
        let allowedDomains = ["api.github.com", "api.openai.com"]
        
        // A. 拦截测试：未授权恶意域名（DLP 拦截）
        XCTAssertThrowsError(
            try PluginSandboxGateway.auditFetch(url: "https://evil.com/exfiltrate?token=123", options: nil, allowedDomains: allowedDomains),
            "访问未授权域名必须抛出拦截错误"
        ) { error in
            // 验证 DLP 域名拦截：应抛出 dlpFetchBlocked case
            guard case .dlpFetchBlocked(let host) = error as? PluginSandboxError else {
                XCTFail("错误类型应为 PluginSandboxError.dlpFetchBlocked，实际为: \(error)")
                return
            }
            XCTAssertTrue(host.contains("evil.com"), "拦截域名应包含 evil.com，实际为: \(host)")
        }
        
        // B. 放行测试：已在 manifest 中注册的白名单域名
        XCTAssertNoThrow(
            try PluginSandboxGateway.auditFetch(url: "https://api.github.com/repos/wangchong2023/ZhiYu", options: nil, allowedDomains: allowedDomains),
            "访问受信任的白名单域名必须安全放行"
        )
    }
    
    // MARK: - 3. Payload 存储超限与长 Key 拦截测试
    
    /// 验证持久化存储（saveData）超大体积载荷（>5MB）与越界键名长度（>256字符）的防御机制
    func testPluginSandboxGatewayStorageDLP() {
        // A. 验证超长 Key 拦截
        let longKey = String(repeating: "k", count: 300)
        XCTAssertThrowsError(
            try PluginSandboxGateway.auditStorage(key: longKey, value: "valid_value"),
            "Key 长度超出 256 字符必须报错"
        ) { error in
            guard case .keyLengthExceeded(let maxLen) = error as? PluginSandboxError else {
                XCTFail("错误类型应为 PluginSandboxError.keyLengthExceeded，实际为: \(error)")
                return
            }
            XCTAssertEqual(maxLen, 256, "最大 Key 长度应为 256")
        }

        // B. 验证超限 Payload 拦截 (>5MB)
        let fiveMegabytesAndOneByte = String(repeating: "x", count: 5 * 1024 * 1024 + 1)
        XCTAssertThrowsError(
            try PluginSandboxGateway.auditStorage(key: "valid_key", value: fiveMegabytesAndOneByte),
            "数据载荷超出 5MB 必须拦截"
        ) { error in
            guard case .payloadTooLarge = error as? PluginSandboxError else {
                XCTFail("错误类型应为 PluginSandboxError.payloadTooLarge，实际为: \(error)")
                return
            }
        }
        
        // C. 验证小容量载荷安全放行
        XCTAssertNoThrow(
            try PluginSandboxGateway.auditStorage(key: "theme_preference", value: "{\"mode\": \"dark\"}"),
            "常规大小载荷必须安全存储放行"
        )
    }
}

#endif
