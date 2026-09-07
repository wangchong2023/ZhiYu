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
