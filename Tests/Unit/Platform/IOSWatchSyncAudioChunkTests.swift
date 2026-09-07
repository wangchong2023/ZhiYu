//
//  IOSWatchSyncAudioChunkTests.swift
//  ZhiYuTests
//
//  系统层级：[Platforms] 平台同步测试
//  核心职责：验证 iOSWatchSyncService 接收音频切片时针对总数为零、负数或索引越界等异常数据包的容错处理。
//

import XCTest
import UFPCore
@testable import ZhiYu

#if os(iOS) && !os(watchOS)
@MainActor
final class IOSWatchSyncAudioChunkTests: XCTestCase {

    /// 验证 total=0 时不触发空合并并安全返回
    func testHandleReceivedAudioChunk_totalZero_returnsSafely() {
        let service = iOSWatchSyncService()
        service.handleReceivedAudioChunk(
            transferId: "test-zero",
            index: 0,
            total: 0,
            filename: "test.wav",
            data: Data([0x01])
        )
        XCTAssertNotEqual(service.lastReceivedText, "audio:test.wav:1", "total=0 时不应触发合并")
    }

    /// 验证 total 负数时不崩溃且安全返回
    func testHandleReceivedAudioChunk_totalNegative_returnsSafely() {
        let service = iOSWatchSyncService()
        service.handleReceivedAudioChunk(
            transferId: "test-negative",
            index: 0,
            total: -1,
            filename: "test.wav",
            data: Data([0x01])
        )
        XCTAssertNotEqual(service.lastReceivedText, "audio:test.wav:1", "total=-1 时不应触发合并")
    }

    /// 验证 index 越界时安全返回
    func testHandleReceivedAudioChunk_indexOutOfRange_returnsSafely() {
        let service = iOSWatchSyncService()
        service.handleReceivedAudioChunk(
            transferId: "test-out-of-range",
            index: 5,
            total: 3,
            filename: "test.wav",
            data: Data([0x01])
        )
        XCTAssertNotEqual(service.lastReceivedText, "audio:test.wav:1", "index 越界时不应触发合并")
    }
}
#endif
