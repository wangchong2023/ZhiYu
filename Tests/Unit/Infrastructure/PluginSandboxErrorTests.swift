//
//  PluginSandboxErrorTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证插件沙箱错误枚举的 statusCode 映射、errorDescription 本地化与关联值携带语义。
//

import XCTest
@testable import ZhiYu

final class PluginSandboxErrorTests: XCTestCase {

    // MARK: - statusCode 映射

    func testStatusCode_invalidURL_returns400() {
        XCTAssertEqual(PluginSandboxError.invalidURL("bad").statusCode, 400)
    }

    func testStatusCode_scriptSyntaxError_returns400() {
        XCTAssertEqual(PluginSandboxError.scriptSyntaxError("err").statusCode, 400)
    }

    func testStatusCode_keyLengthExceeded_returns400() {
        XCTAssertEqual(PluginSandboxError.keyLengthExceeded(256).statusCode, 400)
    }

    func testStatusCode_dlpFetchBlocked_returns403() {
        XCTAssertEqual(PluginSandboxError.dlpFetchBlocked("evil.com").statusCode, 403)
    }

    func testStatusCode_invalidSignature_returns403() {
        XCTAssertEqual(PluginSandboxError.invalidSignature.statusCode, 403)
    }

    func testStatusCode_timeout_returns408() {
        XCTAssertEqual(PluginSandboxError.timeout.statusCode, 408)
    }

    func testStatusCode_preProcessException_returns408() {
        XCTAssertEqual(PluginSandboxError.preProcessException("fail").statusCode, 408)
    }

    func testStatusCode_postProcessException_returns408() {
        XCTAssertEqual(PluginSandboxError.postProcessException("fail").statusCode, 408)
    }

    func testStatusCode_payloadTooLarge_returns413() {
        XCTAssertEqual(PluginSandboxError.payloadTooLarge.statusCode, 413)
    }

    // MARK: - errorDescription 非空

    func testErrorDescription_invalidURL_containsURL() {
        let desc = PluginSandboxError.invalidURL("https://bad.com").errorDescription
        XCTAssertNotNil(desc, "errorDescription 不应为 nil")
        XCTAssertTrue(desc?.contains("https://bad.com") == true, "应包含传入的 URL")
    }

    func testErrorDescription_dlpFetchBlocked_containsHost() {
        let desc = PluginSandboxError.dlpFetchBlocked("evil.com").errorDescription
        XCTAssertNotNil(desc)
        XCTAssertTrue(desc?.contains("evil.com") == true, "应包含被拦截的域名")
    }

    func testErrorDescription_payloadTooLarge_notNil() {
        XCTAssertNotNil(PluginSandboxError.payloadTooLarge.errorDescription)
    }

    func testErrorDescription_keyLengthExceeded_containsLimit() {
        let desc = PluginSandboxError.keyLengthExceeded(256).errorDescription
        XCTAssertNotNil(desc)
        XCTAssertTrue(desc?.contains("256") == true, "应包含最大长度值")
    }

    func testErrorDescription_timeout_notNil() {
        XCTAssertNotNil(PluginSandboxError.timeout.errorDescription)
    }

    func testErrorDescription_preProcessException_containsReason() {
        let desc = PluginSandboxError.preProcessException("timeout").errorDescription
        XCTAssertNotNil(desc)
        XCTAssertTrue(desc?.contains("timeout") == true, "应包含异常原因")
    }

    func testErrorDescription_postProcessException_containsReason() {
        let desc = PluginSandboxError.postProcessException("crash").errorDescription
        XCTAssertNotNil(desc)
        XCTAssertTrue(desc?.contains("crash") == true, "应包含异常原因")
    }

    func testErrorDescription_invalidSignature_notNil() {
        XCTAssertNotNil(PluginSandboxError.invalidSignature.errorDescription)
    }

    func testErrorDescription_scriptSyntaxError_containsDetail() {
        let desc = PluginSandboxError.scriptSyntaxError("unexpected token").errorDescription
        XCTAssertNotNil(desc)
        XCTAssertTrue(desc?.contains("unexpected token") == true, "应包含语法错误详情")
    }

    // MARK: - Error 协议一致性

    func testPluginSandboxError_conformsToError() {
        let error: Error = PluginSandboxError.timeout
        XCTAssertNotNil(error, "应遵循 Error 协议")
    }

    func testPluginSandboxError_conformsToLocalizedError() {
        let error: LocalizedError = PluginSandboxError.payloadTooLarge
        XCTAssertNotNil(error.errorDescription, "应遵循 LocalizedError 协议并提供 errorDescription")
    }

    // MARK: - 关联值携带

    func testInvalidURL_associatedValuePreserved() {
        let error = PluginSandboxError.invalidURL("https://test.example.com/path")
        guard case .invalidURL(let url) = error else {
            XCTFail("应能提取关联值")
            return
        }
        XCTAssertEqual(url, "https://test.example.com/path")
    }

    func testKeyLengthExceeded_associatedValuePreserved() {
        let error = PluginSandboxError.keyLengthExceeded(512)
        guard case .keyLengthExceeded(let limit) = error else {
            XCTFail("应能提取关联值")
            return
        }
        XCTAssertEqual(limit, 512)
    }
}
