//
//  AsyncStatusTests.swift
//  ZhiYuDomainTests
//
//  系统层级：[ZhiYuDomainTests]
//  核心职责：验证 AsyncStatus 四态流转模型（idle/loading/success/failure）的 isLoading / errorMessage
//           判定、Equatable 相等性及边界条件，确保统一异步状态管理落地后无回归。
//

import XCTest
@testable import ZhiYuDomain

final class AsyncStatusTests: XCTestCase {

    // MARK: - isLoading 判定

    /// 验证 .loading 状态下 isLoading 为 true
    func testLoadingStateIsLoading() {
        let status: AsyncStatus<String> = .loading("加载中")
        XCTAssertTrue(status.isLoading, ".loading 状态下 isLoading 应为 true")
    }

    /// 验证 .idle 状态下 isLoading 为 false
    func testIdleStateIsNotLoading() {
        let status: AsyncStatus<String> = .idle
        XCTAssertFalse(status.isLoading, ".idle 状态下 isLoading 应为 false")
    }

    /// 验证 .success 状态下 isLoading 为 false
    func testSuccessStateIsNotLoading() {
        let status: AsyncStatus<String> = .success("完成")
        XCTAssertFalse(status.isLoading, ".success 状态下 isLoading 应为 false")
    }

    /// 验证 .failure 状态下 isLoading 为 false
    func testFailureStateIsNotLoading() {
        let status: AsyncStatus<String> = .failure("出错了")
        XCTAssertFalse(status.isLoading, ".failure 状态下 isLoading 应为 false")
    }

    // MARK: - errorMessage 提取

    /// 验证 .failure 状态下 errorMessage 返回失败原因
    func testFailureErrorMessage() {
        let status: AsyncStatus<String> = .failure("网络超时")
        XCTAssertEqual(status.errorMessage, "网络超时")
    }

    /// 验证 .loading 状态下 errorMessage 为 nil
    func testLoadingErrorMessageIsNil() {
        let status: AsyncStatus<String> = .loading("加载中")
        XCTAssertNil(status.errorMessage)
    }

    /// 验证 .idle 状态下 errorMessage 为 nil
    func testIdleErrorMessageIsNil() {
        let status: AsyncStatus<String> = .idle
        XCTAssertNil(status.errorMessage)
    }

    /// 验证 .success 状态下 errorMessage 为 nil
    func testSuccessErrorMessageIsNil() {
        let status: AsyncStatus<Int> = .success(42)
        XCTAssertNil(status.errorMessage)
    }

    // MARK: - Equatable 判定

    /// 验证相同 loading 状态相等
    func testLoadingEquality() {
        let a: AsyncStatus<String> = .loading("加载中")
        let b: AsyncStatus<String> = .loading("加载中")
        XCTAssertEqual(a, b, "相同描述的 .loading 状态应相等")
    }

    /// 验证不同 loading 描述不相等
    func testLoadingInequalityWithDifferentDescription() {
        let a: AsyncStatus<String> = .loading("加载中")
        let b: AsyncStatus<String> = .loading("请稍候")
        XCTAssertNotEqual(a, b, "不同描述的 .loading 状态不应相等")
    }

    /// 验证 success 值相等
    func testSuccessEquality() {
        let a: AsyncStatus<Int> = .success(42)
        let b: AsyncStatus<Int> = .success(42)
        XCTAssertEqual(a, b, "相同值的 .success 状态应相等")
    }

    /// 验证不同 failure 原因不相等
    func testFailureInequality() {
        let a: AsyncStatus<String> = .failure("错误A")
        let b: AsyncStatus<String> = .failure("错误B")
        XCTAssertNotEqual(a, b, "不同原因的 .failure 状态不应相等")
    }

    /// 验证 idle 与其他状态不相等
    func testIdleInequalityWithOtherStates() {
        let idle: AsyncStatus<String> = .idle
        let loading: AsyncStatus<String> = .loading("加载中")
        let success: AsyncStatus<String> = .success("完成")
        let failure: AsyncStatus<String> = .failure("出错")
        XCTAssertNotEqual(idle, loading)
        XCTAssertNotEqual(idle, success)
        XCTAssertNotEqual(idle, failure)
    }

    /// 验证 .idle 与 .idle 相等
    func testIdleEquality() {
        let a: AsyncStatus<String> = .idle
        let b: AsyncStatus<String> = .idle
        XCTAssertEqual(a, b, "两个 .idle 状态应相等")
    }

    /// 验证 .success 与 .failure 不相等
    func testSuccessInequalityWithFailure() {
        let a: AsyncStatus<String> = .success("完成")
        let b: AsyncStatus<String> = .failure("失败")
        XCTAssertNotEqual(a, b, ".success 与 .failure 不应相等")
    }
}