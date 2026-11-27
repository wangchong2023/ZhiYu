//
//  LLMClientSecurityTests.swift
//  ZhiYu
//
//  系统层级：[Shared] 测试层
//  核心职责：验证 LLMClient 的 HTTPS 强制校验、loopback 豁免与 URL 规范化。
//

import XCTest
@testable import ZhiYuUnitTestHost

final class LLMClientSecurityTests: XCTestCase {

    // MARK: - HTTPS 强制校验

    func testHTTPURLThrowsInvalidURL() async {
        let client = LLMClient(baseURL: "http://api.example.com/v1", apiKey: "sk-test")
        do {
            _ = try await client.sendRequest(body: ["model": "test"])
            XCTFail("HTTP URL 应抛出 invalidURL 错误")
        } catch LLMError.invalidURL {
            // 预期路径：VULN-013 修复，强制 HTTPS
        } catch {
            XCTFail("应抛出 LLMError.invalidURL，实际：\(error)")
        }
    }

    // MARK: - loopback 豁免

    // @flaky: 真实网络测试依赖 TCP connect，CI 环境 connect 挂起导致测试无限等待，故 CI 跳过（本地可用 xcodebuild 单独执行）
    func testLoopbackLocalhostDoesNotThrowInvalidURL() async {
        let client = LLMClient(baseURL: "http://localhost:1234/v1", apiKey: "sk-test")
        do {
            _ = try await client.sendRequest(body: ["model": "test"])
            // 预期会因连接失败抛出网络错误，但不应是 invalidURL
            XCTFail("应抛出网络连接错误而非成功")
        } catch LLMError.invalidURL {
            XCTFail("loopback localhost 应豁免 HTTPS 强制校验")
        } catch {
            // 预期：网络连接错误（NSURLErrorCannotConnectToHost 等）
        }
    }

    // @flaky: 真实网络测试依赖 TCP connect，CI 环境 connect 挂起导致测试无限等待，故 CI 跳过（本地可用 xcodebuild 单独执行）
    func testLoopback127DoesNotThrowInvalidURL() async {
        let client = LLMClient(baseURL: "http://127.0.0.1:1234/v1", apiKey: "sk-test")
        do {
            _ = try await client.sendRequest(body: ["model": "test"])
            XCTFail("应抛出网络连接错误而非成功")
        } catch LLMError.invalidURL {
            XCTFail("loopback 127.0.0.1 应豁免 HTTPS 强制校验")
        } catch {
            // 预期：网络连接错误
        }
    }

    // @flaky: 真实网络测试依赖 TCP connect，CI 环境 connect 挂起导致测试无限等待，故 CI 跳过（本地可用 xcodebuild 单独执行）
    func testLoopbackIPv6DoesNotThrowInvalidURL() async {
        let client = LLMClient(baseURL: "http://[::1]:1234/v1", apiKey: "sk-test")
        do {
            _ = try await client.sendRequest(body: ["model": "test"])
            XCTFail("应抛出网络连接错误而非成功")
        } catch LLMError.invalidURL {
            XCTFail("loopback [::1] 应豁免 HTTPS 强制校验")
        } catch {
            // 预期：网络连接错误
        }
    }

    // @flaky: 真实网络测试依赖 TCP connect，CI 环境 connect 挂起导致测试无限等待，故 CI 跳过（本地可用 xcodebuild 单独执行）
    func testLoopback0000DoesNotThrowInvalidURL() async {
        let client = LLMClient(baseURL: "http://0.0.0.0:1234/v1", apiKey: "sk-test")
        do {
            _ = try await client.sendRequest(body: ["model": "test"])
            XCTFail("应抛出网络连接错误而非成功")
        } catch LLMError.invalidURL {
            XCTFail("loopback 0.0.0.0 应豁免 HTTPS 强制校验")
        } catch {
            // 预期：网络连接错误
        }
    }

    // MARK: - 流式请求 HTTPS 强制（含 loopback 豁免）

    func testStreamingHTTPURLThrowsInvalidURL() async {
        let client = LLMClient(baseURL: "http://api.example.com/v1", apiKey: "sk-test")
        do {
            _ = try await client.sendStreamingRequest(body: ["model": "test"])
            XCTFail("HTTP URL 流式请求应抛出 invalidURL 错误")
        } catch LLMError.invalidURL {
            // 预期路径
        } catch {
            XCTFail("应抛出 LLMError.invalidURL，实际：\(error)")
        }
    }

    // @flaky: 真实网络测试依赖 TCP connect，CI 环境 connect 挂起导致测试无限等待，故 CI 跳过（本地可用 xcodebuild 单独执行）
    func testStreamingLoopbackDoesNotThrowInvalidURL() async {
        // sendStreamingRequest 豁免 loopback（与非流式一致），支持本地 LLM 流式对话
        let client = LLMClient(baseURL: "http://localhost:1234/v1", apiKey: "sk-test")
        do {
            _ = try await client.sendStreamingRequest(body: ["model": "test"])
            XCTFail("应抛出网络连接错误而非成功")
        } catch LLMError.invalidURL {
            XCTFail("流式请求 loopback 应豁免 HTTPS 强制校验")
        } catch {
            // 预期：网络连接错误（NSURLErrorCannotConnectToHost 等）
        }
    }

    // @flaky: 真实网络测试依赖 TCP connect，CI 环境 connect 挂起导致测试无限等待，故 CI 跳过（本地可用 xcodebuild 单独执行）
    func testStreamingLoopback127DoesNotThrowInvalidURL() async {
        // sendStreamingRequest 豁免 127.0.0.1（与非流式一致）
        let client = LLMClient(baseURL: "http://127.0.0.1:1234/v1", apiKey: "sk-test")
        do {
            _ = try await client.sendStreamingRequest(body: ["model": "test"])
            XCTFail("应抛出网络连接错误而非成功")
        } catch LLMError.invalidURL {
            XCTFail("流式请求 127.0.0.1 应豁免 HTTPS 强制校验")
        } catch {
            // 预期：网络连接错误
        }
    }

    // MARK: - URL 规范化（尾部斜杠）

    // @flaky: 真实网络测试依赖 TCP connect，CI 环境 connect 挂起导致测试无限等待，故 CI 跳过（本地可用 xcodebuild 单独执行）
    func testTrailingSlashNormalized() async {
        let client = LLMClient(baseURL: "http://localhost:1234/v1/", apiKey: "sk-test")
        do {
            _ = try await client.sendRequest(body: ["model": "test"])
            XCTFail("应抛出网络连接错误而非成功")
        } catch LLMError.invalidURL {
            XCTFail("loopback 应豁免 HTTPS 强制校验（尾部斜杠应被规范化）")
        } catch {
            // 预期：网络连接错误，说明 URL 规范化后通过了 HTTPS 校验
        }
    }

    // MARK: - HTTPS 正常路径（连接失败但通过校验）

    // @flaky: 真实网络测试依赖 TCP connect，CI 环境 connect 挂起导致测试无限等待，故 CI 跳过（本地可用 xcodebuild 单独执行）
    func testHTTPSURLPassesSecurityCheck() async {
        let client = LLMClient(baseURL: "https://api.example.com/v1", apiKey: "sk-test")
        do {
            _ = try await client.sendRequest(body: ["model": "test"])
            XCTFail("应抛出网络连接错误而非成功")
        } catch LLMError.invalidURL {
            XCTFail("HTTPS URL 应通过安全校验")
        } catch {
            // 预期：网络连接错误（DNS 解析失败等），说明通过了 HTTPS 校验
        }
    }

    // MARK: - 空 URL

    func testEmptyBaseURLThrowsInvalidURL() async {
        let client = LLMClient(baseURL: "", apiKey: "sk-test")
        do {
            _ = try await client.sendRequest(body: ["model": "test"])
            XCTFail("空 URL 应抛出 invalidURL")
        } catch LLMError.invalidURL {
            // 预期路径
        } catch {
            // 也可能因 URL 构造失败抛出其他错误
        }
    }

    // MARK: - Loopback 子串欺骗防御（#142）

    func testLoopbackSpoofedHostAndNonHTTPSchemeThrowInvalidURL() async {
        let spoofedURLs = [
            "http://localhost.evil.com/v1",
            "http://127.0.0.1.attacker.io/v1",
            "http://evil.com/?redirect=http://localhost:1234",
            "file://localhost/etc/passwd"
        ]
        for url in spoofedURLs {
            let client = LLMClient(baseURL: url, apiKey: "sk-secret")
            XCTAssertFalse(client.isLoopbackURL(url), "伪造 loopback URL \(url) 绝不能通过 isLoopbackURL 判定")
            do {
                _ = try await client.sendRequest(body: ["model": "test"])
                XCTFail("伪造 loopback URL \(url) 必须抛出 invalidURL")
            } catch LLMError.invalidURL {
                // 预期拦截
            } catch {
                XCTFail("伪造 loopback URL \(url) 应抛出 LLMError.invalidURL，实际：\(error)")
            }
        }
    }

    // MARK: - 缺陷 #206 回归：多斜杠/空白 URL 规范化与流式状态码精确映射

    func testNormalizedBaseURL_trimsWhitespaceAndMultipleTrailingSlashes() {
        let client = LLMClient(baseURL: "  https://api.example.com/v1///  ", apiKey: "sk-test")
        XCTAssertEqual(client.normalizedBaseURL, "https://api.example.com/v1")
    }

    func testMapHTTPStatusError_mapsUnauthorizedAndRateLimitedConsistently() {
        XCTAssertNil(LLMClient.mapHTTPStatusError(statusCode: 200))
        if case .unauthorized = LLMClient.mapHTTPStatusError(statusCode: 401) {
            // 预期行为
        } else {
            XCTFail("401 必须映射为 LLMError.unauthorized")
        }
        if case .rateLimited = LLMClient.mapHTTPStatusError(statusCode: 429) {
            // 预期行为
        } else {
            XCTFail("429 必须映射为 LLMError.rateLimited")
        }
        if case .httpError(503) = LLMClient.mapHTTPStatusError(statusCode: 503) {
            // 预期行为
        } else {
            XCTFail("503 必须映射为 LLMError.httpError(503)")
        }
    }

    // MARK: - 缺陷 #249 回归：5xx JSON 响应保持可重试、URL host/query/fragment 校验与 API Key 防 CRLF 注入

    func testMapResponseError_retryable5xxWithJSONBodyRemainsRetryable() throws {
        let overloadedBody = Data(#"{"error":{"message":"server overloaded"}}"#.utf8)
        let err503 = try XCTUnwrap(LLMClient.mapResponseError(statusCode: 503, data: overloadedBody))
        XCTAssertTrue(LLMClient.isRetryableError(err503), "503 带 JSON 错误体时必须保持可重试，不得被 .apiError 吞掉")

        let badReqBody = Data(#"{"error":{"message":"invalid model"}}"#.utf8)
        let err400 = try XCTUnwrap(LLMClient.mapResponseError(statusCode: 400, data: badReqBody))
        XCTAssertFalse(LLMClient.isRetryableError(err400), "400 客户端错误不应重试")
        if case .apiError(let msg) = err400 {
            XCTAssertEqual(msg, "invalid model")
        } else {
            XCTFail("400 带 JSON 错误体应解析为 .apiError")
        }
    }

    func testMakeLLMRequest_rejectsMalformedBaseURLAndSanitizesAPIKeyCRLF() throws {
        let invalidURLs = [
            "https:///v1",
            "https://api.example.com/v1?token=1",
            "https://api.example.com/v1#section"
        ]
        for badURL in invalidURLs {
            let client = LLMClient(baseURL: badURL, apiKey: "sk-test")
            XCTAssertThrowsError(try client.makeLLMRequest(bodyData: Data("{}".utf8), timeout: 10)) { error in
                guard case LLMError.invalidURL = error else {
                    XCTFail("非法 baseURL \(badURL) 应抛出 LLMError.invalidURL，实际：\(error)")
                    return
                }
            }
        }

        let client = LLMClient(baseURL: "https://api.example.com/v1", apiKey: "sk-abc\r\nX-Injected: evil")
        let request = try client.makeLLMRequest(bodyData: Data("{}".utf8), timeout: 10)
        let authHeader = request.value(forHTTPHeaderField: "Authorization") ?? ""
        XCTAssertFalse(authHeader.contains("\r") || authHeader.contains("\n"), "Authorization Header 绝不能包含 CRLF 注入")
        XCTAssertEqual(authHeader, "Bearer sk-abcX-Injected: evil")
    }
}
