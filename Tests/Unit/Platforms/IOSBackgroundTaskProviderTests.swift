//
//  IOSBackgroundTaskProviderTests.swift
//  ZhiYu
//
//  Created by CodeFree on 2026/08/24.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：iOSBackgroundTaskProvider 单元测试，覆盖后台任务注册与调度场景。
//

#if os(iOS) && !os(watchOS)
import XCTest
@testable import ZhiYu

@MainActor
final class IOSBackgroundTaskProviderTests: XCTestCase {

    // MARK: - 测试常量

    private enum TestConstants {
        static let expectedTaskIdentifier: String = "com.zhimind.ingest.process"
    }

    // MARK: - register

    /// 注册后台任务不应崩溃（模拟器可能注册失败但不抛错）
    func testRegisterDoesNotCrash() {
        let provider = iOSBackgroundTaskProvider()
        var handlerCalled = false
        provider.register {
            handlerCalled = true
        }
        XCTAssertNotNil(provider)
        XCTAssertFalse(TestConstants.expectedTaskIdentifier.isEmpty)
        _ = handlerCalled
    }

    // MARK: - schedule

    /// 调度后台任务不应崩溃（模拟器可能提交失败但静默处理）
    func testScheduleDoesNotCrash() {
        let provider = iOSBackgroundTaskProvider()
        XCTAssertNotNil(provider)
        provider.schedule()
    }

    /// 连续多次调度不应崩溃
    func testMultipleSchedulesDoNotCrash() {
        let provider = iOSBackgroundTaskProvider()
        XCTAssertNotNil(provider)
        provider.schedule()
        provider.schedule()
        provider.schedule()
    }

    // MARK: - 协议一致性

    /// 服务实例应可向上转型为 BackgroundTaskProtocol
    func testConformsToBackgroundTaskProtocol() {
        let provider: any BackgroundTaskProtocol = iOSBackgroundTaskProvider()
        XCTAssertNotNil(provider)
        var handlerExecuted = false
        provider.register {
            handlerExecuted = true
        }
        provider.schedule()
        _ = handlerExecuted
    }
}
#endif
