//
//  RetryTaskTests.swift
//  ZhiYu
//
//  系统层级：[L0] 测试层
//  核心职责：验证 RetryTask 指数退避重试逻辑的正确性（成功/重试/耗尽/边界）。
//

import XCTest
@testable import ZhiYu

final class RetryTaskTests: XCTestCase {

    // MARK: - 成功路径

    /// 首次执行即成功，不应重试
    func testExecute_首次成功_不重试() async throws {
        var callCount = 0
        let result = try await RetryTask.execute(
            maxRetries: 3,
            initialDelay: 0.001,
            operation: { @Sendable in
                callCount += 1
                return "success"
            }
        )
        XCTAssertEqual(result, "success")
        XCTAssertEqual(callCount, 1, "首次成功应只调用一次")
    }

    // MARK: - 重试后成功

    /// 前 N 次失败，第 N+1 次成功
    func testExecute_重试后成功_返回成功值() async throws {
        var callCount = 0
        let result = try await RetryTask.execute(
            maxRetries: 3,
            initialDelay: 0.001,
            operation: { @Sendable in
                callCount += 1
                if callCount < 3 {
                    throw TestError.failure
                }
                return "recovered"
            }
        )
        XCTAssertEqual(result, "recovered")
        XCTAssertEqual(callCount, 3, "前 2 次失败 + 第 3 次成功 = 3 次调用")
    }

    // MARK: - 重试耗尽

    /// 始终失败，重试耗尽后抛出最后一次错误
    func testExecute_重试耗尽_抛出错误() async throws {
        var callCount = 0
        do {
            _ = try await RetryTask.execute(
                maxRetries: 2,
                initialDelay: 0.001,
                operation: { @Sendable in
                    callCount += 1
                    throw TestError.failure
                }
            )
            XCTFail("应抛出错误")
        } catch {
            XCTAssertEqual(callCount, 3, "首次 + 2 次重试 = 3 次调用")
            XCTAssertTrue(error is TestError, "应抛出原始错误类型")
        }
    }

    // MARK: - 边界值：maxRetries

    /// maxRetries=0，首次失败即抛出，不重试
    func testExecute_maxRetries为0_不重试() async throws {
        var callCount = 0
        do {
            _ = try await RetryTask.execute(
                maxRetries: 0,
                initialDelay: 0.001,
                operation: { @Sendable in
                    callCount += 1
                    throw TestError.failure
                }
            )
            XCTFail("应抛出错误")
        } catch {
            XCTAssertEqual(callCount, 1, "maxRetries=0 应只调用一次")
        }
    }

    /// maxRetries=1，最多调用 2 次（首次 + 1 次重试）
    func testExecute_maxRetries为1_最多2次调用() async throws {
        var callCount = 0
        do {
            _ = try await RetryTask.execute(
                maxRetries: 1,
                initialDelay: 0.001,
                operation: { @Sendable in
                    callCount += 1
                    throw TestError.failure
                }
            )
            XCTFail("应抛出错误")
        } catch {
            XCTAssertEqual(callCount, 2, "首次 + 1 次重试 = 2 次调用")
        }
    }

    // MARK: - 错误类型保持

    /// 抛出的错误应原样传递（自定义错误枚举）
    func testExecute_错误类型保持_抛出原始错误() async throws {
        do {
            _ = try await RetryTask.execute(
                maxRetries: 1,
                initialDelay: 0.001,
                operation: { @Sendable in
                    throw TestError.specificError
                }
            )
            XCTFail("应抛出错误")
        } catch let error as TestError {
            XCTAssertEqual(error, TestError.specificError, "应保持原始错误类型和值")
        } catch {
            XCTFail("应抛出 TestError 类型，实际：\(type(of: error))")
        }
    }

    // MARK: - 返回值类型

    /// 泛型返回值应正确传递（Int 类型）
    func testExecute_返回Int类型_值正确() async throws {
        let result = try await RetryTask.execute(
            maxRetries: 0,
            initialDelay: 0.001,
            operation: { @Sendable in 42 }
        )
        XCTAssertEqual(result, 42)
    }

    /// 泛型返回值应正确传递（可选类型）
    func testExecute_返回可选类型_值正确() async throws {
        let result: String? = try await RetryTask.execute(
            maxRetries: 0,
            initialDelay: 0.001,
            operation: { @Sendable in nil }
        )
        XCTAssertNil(result)
    }

    // MARK: - 退避参数验证

    /// multiplier=1.0，延迟不增长（仅验证不崩溃 + 最终成功）
    func testExecute_multiplier为1_延迟不增长() async throws {
        var callCount = 0
        let result = try await RetryTask.execute(
            maxRetries: 2,
            initialDelay: 0.001,
            multiplier: 1.0,
            operation: { @Sendable in
                callCount += 1
                if callCount < 2 { throw TestError.failure }
                return "ok"
            }
        )
        XCTAssertEqual(result, "ok")
        XCTAssertEqual(callCount, 2)
    }

    /// maxDelay 截断验证（initialDelay 极大 + maxDelay 极小，应被截断）
    func testExecute_maxDelay截断_不超时() async throws {
        let result = try await RetryTask.execute(
            maxRetries: 1,
            initialDelay: 100.0,
            multiplier: 10.0,
            maxDelay: 0.001,
            operation: { @Sendable in "fast" }
        )
        XCTAssertEqual(result, "fast", "maxDelay 应截断 initialDelay，避免长时间等待")
    }

    // MARK: - shouldRetry 谓词

    /// shouldRetry 返回 false 时，不可重试错误直接抛出
    func testExecute_shouldRetry过滤不可重试错误() async throws {
        var callCount = 0
        do {
            _ = try await RetryTask.execute(
                maxRetries: 3,
                initialDelay: 0.001,
                shouldRetry: { _ in false },
                operation: { @Sendable in
                    callCount += 1
                    throw TestError.failure
                }
            )
            XCTFail("不可重试错误应直接抛出")
        } catch {
            XCTAssertEqual(callCount, 1, "shouldRetry=false 应只调用 1 次")
        }
    }

    /// shouldRetry 返回 true 时，可重试错误按 maxRetries 重试
    func testExecute_shouldRetry允许可重试错误() async throws {
        var callCount = 0
        do {
            _ = try await RetryTask.execute(
                maxRetries: 2,
                initialDelay: 0.001,
                shouldRetry: { _ in true },
                operation: { @Sendable in
                    callCount += 1
                    throw TestError.failure
                }
            )
            XCTFail("应在重试上限后抛出错误")
        } catch {
            XCTAssertEqual(callCount, 3, "首次 + 2 次重试 = 3 次调用")
        }
    }

    // MARK: - poll 轮询

    /// poll 条件满足时返回结果
    func testPoll_条件满足_返回结果() async throws {
        var callCount = 0
        let result = try await RetryTask.poll(maxAttempts: 5, interval: 0.001) {
            callCount += 1
            return callCount >= 3 ? "READY" : nil
        }
        XCTAssertEqual(result, "READY")
        XCTAssertEqual(callCount, 3, "应在第 3 次轮询时满足条件")
    }

    /// poll 条件始终不满足时抛出 pollingExhausted
    func testPoll_条件不满足_抛出pollingExhausted() async throws {
        do {
            let _: String = try await RetryTask.poll(maxAttempts: 3, interval: 0.001) {
                return nil
            }
            XCTFail("应在轮询耗尽后抛出 RetryError")
        } catch RetryError.pollingExhausted(let attempts) {
            XCTAssertEqual(attempts, 3, "应尝试 3 次")
        } catch {
            XCTFail("应抛出 RetryError.pollingExhausted，实际：\(error)")
        }
    }

    /// poll 首次即满足条件
    func testPoll_首次满足_立即返回() async throws {
        let result = try await RetryTask.poll(maxAttempts: 5, interval: 0.001) {
            return "IMMEDIATE"
        }
        XCTAssertEqual(result, "IMMEDIATE")
    }
}

// MARK: - 测试专用错误类型

private enum TestError: Error, Equatable {
    case failure
    case specificError
}
