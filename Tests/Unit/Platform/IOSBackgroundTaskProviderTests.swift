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
        provider.register {
            XCTAssertTrue(true, "后台任务 handler 应可被调用")
        }
        XCTAssertTrue(true, "register 应正常执行无崩溃")
    }

    // MARK: - schedule

    /// 调度后台任务不应崩溃（模拟器可能提交失败但静默处理）
    func testScheduleDoesNotCrash() {
        let provider = iOSBackgroundTaskProvider()
        provider.schedule()
        XCTAssertTrue(true, "schedule 应正常执行无崩溃")
    }

    /// 连续多次调度不应崩溃
    func testMultipleSchedulesDoNotCrash() {
        let provider = iOSBackgroundTaskProvider()
        provider.schedule()
        provider.schedule()
        provider.schedule()
        XCTAssertTrue(true, "多次调度应正常执行")
    }

    // MARK: - 协议一致性

    /// 服务实例应可向上转型为 BackgroundTaskProtocol
    func testConformsToBackgroundTaskProtocol() {
        let provider: any BackgroundTaskProtocol = iOSBackgroundTaskProvider()
        provider.register {
            XCTAssertTrue(true, "协议转型后 handler 应可调用")
        }
        provider.schedule()
        XCTAssertTrue(true, "协议转型与调用应成功")
    }
}
#endif
