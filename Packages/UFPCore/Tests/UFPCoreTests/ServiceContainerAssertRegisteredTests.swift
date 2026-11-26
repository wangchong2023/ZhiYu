//
//  ServiceContainerAssertRegisteredTests.swift
//  UFPCoreTests
//
//  系统层级：[UFPCoreTests]
//  核心职责：验证 assertRegistered 启动断言的语义正确性：
//           1. 全部已注册时静默通过（不触发 assertionFailure）
//           2. 部分缺失时准确报告 missing 列表
//           3. 空列表时静默通过
//           4. 协议存在性类型（any Protocol）与具体类型的 key 区分
//

import UFPCoreTestMocks
import XCTest
import os
@testable import UFPCore

private protocol AssertServiceA: Sendable { var tag: String { get } }
private final class ImplA: AssertServiceA, @unchecked Sendable { let tag = "A" }

private protocol AssertServiceB: Sendable { var tag: String { get } }
private final class ImplB: AssertServiceB, @unchecked Sendable { let tag = "B" }

private protocol AssertServiceC: Sendable { var tag: String { get } }
private final class ImplC: AssertServiceC, @unchecked Sendable { let tag = "C" }

final class ServiceContainerAssertRegisteredTests: XCTestCase {

    override func setUp() {
        super.setUp()
        ServiceContainer.shared.resetForTesting()
    }

    override func tearDown() {
        // 清理失败处理器，避免影响其他测试
        ServiceContainer.fatalFailureHandler = nil
        ServiceContainer.shared.resetForTesting()
        super.tearDown()
    }

    /// 全部服务已注册时，assertRegistered 静默通过（无异常、无崩溃）
    func testAllRegisteredPassesSilently() {
        let container = ServiceContainer.shared
        container.register(ImplA() as AssertServiceA, for: AssertServiceA.self)
        container.register(ImplB() as AssertServiceB, for: AssertServiceB.self)

        // 不应触发失败处理器 — 若触发则 capturedMessages 非空
        let capturedMessages = OSAllocatedUnfairLock<[String]>(initialState: [])
        ServiceContainer.fatalFailureHandler = { msg in
            capturedMessages.withLock { $0.append(msg) }
        }

        container.assertRegistered(
            [AssertServiceA.self, AssertServiceB.self],
            context: "testAllRegistered"
        )
        XCTAssertTrue(capturedMessages.withLock { $0.isEmpty }, "全部已注册时不应触发失败处理器")
    }

    /// 空列表时静默通过
    func testEmptyListPassesSilently() {
        let capturedMessages = OSAllocatedUnfairLock<[String]>(initialState: [])
        ServiceContainer.fatalFailureHandler = { msg in
            capturedMessages.withLock { $0.append(msg) }
        }

        ServiceContainer.shared.assertRegistered([], context: "empty list")
        XCTAssertTrue(capturedMessages.withLock { $0.isEmpty }, "空列表应静默通过")
    }

    /// 部分缺失时，assertRegistered 必须调用失败处理器并报告缺失服务
    /// 缺陷 #5 修复：通过 fatalFailureHandler 注入非崩溃处理器，使失败路径可测试
    func testMissingServiceTriggersFailureHandler() {
        let container = ServiceContainer.shared
        container.register(ImplA() as AssertServiceA, for: AssertServiceA.self)
        // 故意不注册 AssertServiceB

        let capturedMessages = OSAllocatedUnfairLock<[String]>(initialState: [])
        ServiceContainer.fatalFailureHandler = { msg in
            capturedMessages.withLock { $0.append(msg) }
        }

        container.assertRegistered(
            [AssertServiceA.self, AssertServiceB.self],
            context: "testMissingService"
        )

        let messages = capturedMessages.withLock { $0 }
        XCTAssertEqual(messages.count, 1, "缺失服务时必须调用一次失败处理器")
        XCTAssertTrue(messages.first?.contains("AssertServiceB") == true,
                      "失败消息必须包含缺失的服务名 AssertServiceB")
        XCTAssertTrue(messages.first?.contains("testMissingService") == true,
                      "失败消息必须包含上下文 testMissingService")
    }

    /// 协议存在性类型（any Protocol）与具体类型必须用不同 key
    /// 注册了 ImplA（具体类型），断言 AssertServiceA（协议）应失败
    func testExistentialAndConcreteTypeKeyDifferentiation() {
        let container = ServiceContainer.shared
        let impl = ImplA()
        container.register(impl, for: ImplA.self)
        // 注册了具体类型 ImplA，但断言协议 AssertServiceA — key 不同应失败

        let capturedMessages = OSAllocatedUnfairLock<[String]>(initialState: [])
        ServiceContainer.fatalFailureHandler = { msg in
            capturedMessages.withLock { $0.append(msg) }
        }

        container.assertRegistered(
            [AssertServiceA.self],
            context: "testExistentialKey"
        )

        let messages = capturedMessages.withLock { $0 }
        XCTAssertEqual(messages.count, 1, "协议与具体类型 key 不同，断言协议应失败")
        XCTAssertTrue(messages.first?.contains("AssertServiceA") == true,
                      "失败消息必须包含缺失的协议名 AssertServiceA")
    }

    /// 单个服务缺失时触发失败处理器
    func testSingleMissingServiceTriggersHandler() {
        let capturedMessages = OSAllocatedUnfairLock<[String]>(initialState: [])
        ServiceContainer.fatalFailureHandler = { msg in
            capturedMessages.withLock { $0.append(msg) }
        }

        ServiceContainer.shared.assertRegistered(
            [AssertServiceC.self],
            context: "testSingleMissing"
        )

        let messages = capturedMessages.withLock { $0 }
        XCTAssertEqual(messages.count, 1, "单个服务缺失应触发失败处理器")
        XCTAssertTrue(messages.first?.contains("AssertServiceC") == true,
                      "失败消息必须包含缺失的服务名 AssertServiceC")
    }

    /// 失败消息必须包含已注册服务数量
    func testFailureMessageIncludesRegisteredCount() {
        let container = ServiceContainer.shared
        container.register(ImplA() as AssertServiceA, for: AssertServiceA.self)
        container.register(ImplB() as AssertServiceB, for: AssertServiceB.self)

        let capturedMessages = OSAllocatedUnfairLock<[String]>(initialState: [])
        ServiceContainer.fatalFailureHandler = { msg in
            capturedMessages.withLock { $0.append(msg) }
        }

        container.assertRegistered([AssertServiceC.self], context: "countTest")

        let messages = capturedMessages.withLock { $0 }
        XCTAssertTrue(messages.first?.contains("Total registered: 2") == true,
                      "失败消息必须包含已注册服务数量")
    }
}
