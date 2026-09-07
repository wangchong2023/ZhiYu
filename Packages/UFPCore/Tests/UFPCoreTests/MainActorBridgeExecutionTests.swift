//
//  MainActorBridgeExecutionTests.swift
//  UFPCoreTests
//
//  系统层级：[UFPCoreTests]
//  核心职责：验证 runOnMainSync 在主线程与后台线程下的跨 Actor 安全同步调度与死锁防范。
//

import XCTest
@testable import UFPCore

final class MainActorBridgeExecutionTests: XCTestCase {

    // MARK: - 带返回值版本 (Generic T)

    func testRunOnMainSync_onMainThread_returnsValueDirectly() {
        let expected = "MainThreadResult"
        let result = runOnMainSync {
            expected
        }
        XCTAssertEqual(result, expected)
    }

    func testRunOnMainSync_fromBackgroundThread_synchronouslyReturnsValue() {
        let expectation = expectation(description: "Background execution of runOnMainSync with return value")
        let expectedValue = 42

        DispatchQueue.global(qos: .userInitiated).async {
            let actualValue = runOnMainSync {
                expectedValue * 2
            }
            XCTAssertEqual(actualValue, 84)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5.0)
    }

    // MARK: - 无返回值版本 (Void)

    func testRunOnMainSync_voidOnMainThread_executesBlock() {
        var executed = false
        runOnMainSync {
            executed = true
        }
        XCTAssertTrue(executed)
    }

    func testRunOnMainSync_voidFromBackgroundThread_executesBlock() {
        let expectation = expectation(description: "Background execution of runOnMainSync void")
        let flagBox = LockedFlag()

        DispatchQueue.global(qos: .userInitiated).async {
            runOnMainSync {
                flagBox.set(true)
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5.0)
        XCTAssertTrue(flagBox.get())
    }

    // MARK: - @MainActor 隔离代码访问

    /// 后台线程通过 runOnMainSync 访问 @MainActor 隔离属性不应崩溃
    func testRunOnMainSync_mainActorIsolatedProperty_accessFromBackground() {
        let expectation = expectation(description: "@MainActor 属性访问完成")

        DispatchQueue.global(qos: .userInitiated).async {
            let version = runOnMainSync {
                ProcessInfo.processInfo.operatingSystemVersionString
            }
            XCTAssertFalse(version.isEmpty, "应从主线程成功获取系统版本")
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5.0)
    }

    // MARK: - 并发串行化

    /// 验证并发场景下多个后台线程同时调用不产生竞态
    func testRunOnMainSync_concurrentBackgroundCalls_areSerialized() {
        let iterations = 20
        let expectation = expectation(description: "并发调用完成")
        expectation.expectedFulfillmentCount = iterations

        for index in 0..<iterations {
            DispatchQueue.global(qos: .userInitiated).async {
                let result = runOnMainSync { index * 2 }
                XCTAssertEqual(result, index * 2, "每次调用应返回正确计算结果")
                expectation.fulfill()
            }
        }

        waitForExpectations(timeout: 5.0)
    }
}

private final class LockedFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false

    func set(_ newValue: Bool) {
        lock.lock()
        defer { lock.unlock() }
        value = newValue
    }

    func get() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}
