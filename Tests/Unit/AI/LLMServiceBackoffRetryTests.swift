//
//  LLMServiceBackoffRetryTests.swift
//  ZhiYu
//
//  系统层级：[Shared] 测试层
//  核心职责：验证 LLMService.executeWithBackoffRetry 的指数退避重试语义。
//

import XCTest
import UFPCore
@testable import ZhiYu

@MainActor
final class LLMServiceBackoffRetryTests: XCTestCase {

    private var config: LLMConfigManager!

    override func setUp() async throws {
        try await super.setUp()
        ServiceContainer.shared.reset()
        config = LLMConfigManager()
        ServiceContainer.shared.register(config, for: LLMConfigManager.self)
    }

    override func tearDown() async throws {
        config = nil
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - 成功路径

    func testBackoffRetrySucceedsOnFirstAttempt() async throws {
        let service = LLMService()
        let result = try await service.executeWithBackoffRetry(maxAttempts: 3, initialDelaySeconds: 0.001) {
            return "OK"
        }
        XCTAssertEqual(result, "OK")
    }

    func testBackoffRetrySucceedsOnSecondAttempt() async throws {
        let service = LLMService()
        let counter = AsyncCounter()
        let result = try await service.executeWithBackoffRetry(maxAttempts: 3, initialDelaySeconds: 0.001) {
            await counter.increment()
            let count = await counter.value
            if count == 1 {
                throw LLMError.rateLimited
            }
            return "RECOVERED"
        }
        let calls = await counter.value
        XCTAssertEqual(calls, 2, "应在第 2 次尝试时成功")
        XCTAssertEqual(result, "RECOVERED")
    }

    // MARK: - 失败路径

    func testBackoffRetryThrowsAfterMaxAttempts() async {
        let service = LLMService()
        let counter = AsyncCounter()
        do {
            _ = try await service.executeWithBackoffRetry(maxAttempts: 3, initialDelaySeconds: 0.001) {
                await counter.increment()
                throw LLMError.rateLimited
            }
            XCTFail("应在上限尝试后抛出错误")
        } catch LLMError.rateLimited {
            let calls = await counter.value
            XCTAssertEqual(calls, 3, "应恰好调用 3 次（maxAttempts）")
        } catch {
            XCTFail("应抛出 LLMError.rateLimited，实际：\(error)")
        }
    }

    func testBackoffRetryThrowsOriginalErrorNotGeneric() async {
        let service = LLMService()
        struct CustomError: Error, Equatable { let tag: String }
        let expected = CustomError(tag: "custom")
        do {
            _ = try await service.executeWithBackoffRetry(maxAttempts: 2, initialDelaySeconds: 0.001) {
                throw expected
            }
            XCTFail("应在重试上限后抛出原始错误")
        } catch let error as CustomError {
            XCTAssertEqual(error, expected, "应抛出原始 CustomError 而非 LLMError.apiError")
        } catch {
            XCTFail("应抛出 CustomError，实际：\(error)")
        }
    }

    func testBackoffRetryWithMaxAttemptsOneNoRetry() async {
        let service = LLMService()
        let counter = AsyncCounter()
        do {
            _ = try await service.executeWithBackoffRetry(maxAttempts: 1, initialDelaySeconds: 0.001) {
                await counter.increment()
                throw LLMError.invalidResponse
            }
            XCTFail("maxAttempts=1 时应直接抛出错误")
        } catch LLMError.invalidResponse {
            let calls = await counter.value
            XCTAssertEqual(calls, 1, "maxAttempts=1 时应只调用 1 次，无重试")
        } catch {
            XCTFail("应抛出 LLMError.invalidResponse，实际：\(error)")
        }
    }

    // MARK: - 边界：maxAttempts <= 0

    func testBackoffRetryWithMaxAttemptsZeroThrowsImmediately() async {
        let service = LLMService()
        let counter = AsyncCounter()
        do {
            _ = try await service.executeWithBackoffRetry(maxAttempts: 0, initialDelaySeconds: 0.001) {
                await counter.increment()
                return "OK"
            }
            XCTFail("maxAttempts=0 时应抛出错误而非执行操作")
        } catch LLMError.apiError {
            let calls = await counter.value
            XCTAssertEqual(calls, 0, "maxAttempts=0 时操作不应被执行")
        } catch {
            XCTFail("应抛出 LLMError.apiError，实际：\(error)")
        }
    }

    func testBackoffRetryWithNegativeMaxAttemptsThrowsImmediately() async {
        let service = LLMService()
        do {
            _ = try await service.executeWithBackoffRetry(maxAttempts: -1, initialDelaySeconds: 0.001) {
                return "OK"
            }
            XCTFail("maxAttempts=-1 时应抛出错误")
        } catch LLMError.apiError {
            // 预期路径：guard maxAttempts > 0 前置校验
        } catch {
            XCTFail("应抛出 LLMError.apiError，实际：\(error)")
        }
    }
}

/// 线程安全的异步计数器，用于跨 actor 记录调用次数
actor AsyncCounter {
    private(set) var value = 0
    func increment() { value += 1 }
}
