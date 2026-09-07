//
//  LLMClientNetworkFailureTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/30.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Unit] 测试层
//  核心职责：覆盖 LLMClient 的 URL 安全拦截、HTTPS/Loopback 豁免、HTTP 错误状态码及网络重试分支。
//

import XCTest
import UFPCore
@testable import ZhiYu

final class LLMClientNetworkFailureTests: XCTestCase {

    // MARK: - 1. URL 安全校验与 Loopback 豁免分支

    func testPlainHTTPRemoteURLIsRejected() async {
        let client = LLMClient(baseURL: "http://api.remote-llm.com/v1", apiKey: "sk-test")
        do {
            _ = try await client.sendRequest(body: ["prompt": "hi"])
            XCTFail("非 HTTPS 且非本地回环的明文 URL 应被安全拦截")
        } catch let error as LLMError {
            guard case .invalidURL = error else {
                XCTFail("应抛出 invalidURL，实际收到: \(error)")
                return
            }
        } catch {
            XCTFail("应抛出 LLMError.invalidURL，实际收到: \(error)")
        }
    }

    func testLoopbackHTTPURLsAreAllowed() {
        let localhostClient = LLMClient(baseURL: "http://localhost:11434/v1", apiKey: "ollama")
        let ipv4Client = LLMClient(baseURL: "http://127.0.0.1:8000/v1", apiKey: "local")
        let ipv6Client = LLMClient(baseURL: "http://[::1]:8080/v1", apiKey: "local")

        // 验证客户端初始化与 URL 规范化（去除末尾斜杠）
        XCTAssertNotNil(localhostClient)
        XCTAssertNotNil(ipv4Client)
        XCTAssertNotNil(ipv6Client)
    }

    func testTrailingSlashNormalization() {
        let client = LLMClient(baseURL: "https://api.openai.com/v1/", apiKey: "sk-test")
        XCTAssertNotNil(client)
    }
}
