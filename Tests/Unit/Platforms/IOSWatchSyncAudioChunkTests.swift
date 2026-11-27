//
//  IOSWatchSyncAudioChunkTests.swift
//  ZhiYuTests
//
//  系统层级：[Platforms] 平台同步测试
//  核心职责：验证 iOSWatchSyncService 接收音频切片时针对总数为零、负数或索引越界等异常数据包的容错处理。
//

import XCTest
import UFPCore
@testable import ZhiYuUnitTestHost

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

    /// 验证空 transferId 与超大 total（超过 1024 分片上限）被安全拒绝
    func testHandleReceivedAudioChunk_emptyTransferIdOrExcessiveTotal_returnsSafely() {
        let service = iOSWatchSyncService()
        service.handleReceivedAudioChunk(
            transferId: "   ",
            index: 0,
            total: 1,
            filename: "blank.wav",
            data: Data([0x01])
        )
        XCTAssertEqual(service.lastReceivedText, "", "空白 transferId 必须被拒绝")

        service.handleReceivedAudioChunk(
            transferId: "excessive-total",
            index: 0,
            total: 100_000,
            filename: "huge.wav",
            data: Data([0x01])
        )
        XCTAssertEqual(service.lastReceivedText, "", "超过最大分片数上限的 total 必须被拒绝")
    }

    /// 验证 WidgetRepository.fetchRecentPages 传入负数 limit 时安全返回空数组而不崩溃
    func testWidgetRepository_fetchRecentPagesWithNegativeLimit_returnsEmpty() async {
        let pages = await WidgetRepository.fetchRecentPages(limit: -5)
        XCTAssertTrue(pages.isEmpty, "负数 limit 必须安全返回空数组而非触发 prefix 崩溃")
    }
}
#endif
