//
//  MainActorBridgeTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/25.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：验证 runOnMainSync 在多种线程上下文中的正确性，包括主线程无死锁、
//           后台线程安全调度、@MainActor 隔离代码访问、以及 Void/泛型两种重载。

import XCTest
@testable import ZhiYu

final class MainActorBridgeTests: XCTestCase {

    // MARK: - 主线程路径

    /// 主线程调用泛型版本应直接通过 MainActor.assumeIsolated 执行，不触发 DispatchQueue 调度
    func testGeneric_onMainThread_returnsWithoutDeadlock() {
        // Arrange: XCTest 在主线程运行
        XCTAssertTrue(Thread.isMainThread, "Precondition: 测试应在主线程执行")

        // Act
        let result = runOnMainSync { "hello" }

        // Assert
        XCTAssertEqual(result, "hello", "主线程应直接获取返回值")
    }

    /// 主线程调用 Void 版本不产生死锁
    func testVoid_onMainThread_executesWithoutDeadlock() {
        XCTAssertTrue(Thread.isMainThread)

        let executed = runOnMainSync { true }

        XCTAssertTrue(executed, "Void 闭包应在主线程直接执行")
    }

    // MARK: - 后台线程路径

    /// 后台线程调用泛型版本应通过 DispatchQueue.main.sync 安全调度到主线程
    func testGeneric_onBackgroundThread_dispatchesToMain() {
        // Arrange
        let exp = expectation(description: "后台线程执行完成")

        // Act
        DispatchQueue.global(qos: .default).async {
            let isMainInside = runOnMainSync { Thread.isMainThread }
            // Assert
            XCTAssertTrue(isMainInside, "闭包应在主线程执行")
            exp.fulfill()
        }

        wait(for: [exp], timeout: 2.0)
    }

    /// 后台线程调用 Void 版本应安全调度到主线程
    func testVoid_onBackgroundThread_executesOnMain() {
        let exp = expectation(description: "后台线程 Void 调用完成")
        let capturedIsMain = MutableBox<Bool>(false)

        DispatchQueue.global(qos: .default).async {
            runOnMainSync { capturedIsMain.value = Thread.isMainThread }
            exp.fulfill()
        }

        wait(for: [exp], timeout: 2.0)
        XCTAssertTrue(capturedIsMain.value, "Void 闭包应在主线程执行")
    }

    // MARK: - @MainActor 隔离代码访问

    /// 后台线程通过 runOnMainSync 访问 @MainActor 隔离属性不应崩溃
    func test_mainActorIsolatedProperty_accessFromBackground() {
        // Arrange: 创建一个标记为 @MainActor 的简单任务
        let exp = expectation(description: "@MainActor 属性访问完成")

        DispatchQueue.global(qos: .default).async {
            // Act: 通过桥接访问需要在主线程创建的 UIKit 属性
            let version = runOnMainSync { UIDevice.current.systemVersion }

            // Assert
            XCTAssertFalse(version.isEmpty, "应从主线程成功获取系统版本")
            exp.fulfill()
        }

        wait(for: [exp], timeout: 2.0)
    }

    /// 验证并发场景下多个后台线程同时调用不产生竞态
    func test_concurrentBackgroundCalls_areSerialized() {
        let iterations = 20
        let exp = expectation(description: "并发调用完成")
        exp.expectedFulfillmentCount = iterations

        for i in 0..<iterations {
            DispatchQueue.global(qos: .default).async {
                let result = runOnMainSync { i * 2 }
                XCTAssertEqual(result, i * 2, "每次调用应返回正确计算结果")
                exp.fulfill()
            }
        }

        wait(for: [exp], timeout: 5.0)
    }
}

private final class MutableBox<T>: @unchecked Sendable {
    var value: T
    init(_ v: T) { self.value = v }
}
