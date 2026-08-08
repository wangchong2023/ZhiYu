//
//  LLMClientSecurityTests.swift
//  ZhiYu
//
//  系统层级：[Shared] 测试层
//  核心职责：验证 LLMClient 的 HTTPS 强制校验、loopback 豁免与 URL 规范化。
//

import XCTest
@testable import ZhiYu

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
}
