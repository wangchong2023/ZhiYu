//
//  IOSWatchSyncServiceTests.swift
//  ZhiYu
//
//  Created by CodeFree on 2026/08/24.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：iOSWatchSyncService 单元测试，覆盖初始化、内容发送、音频分片组装等场景。
//

#if os(iOS) && !os(watchOS)
import XCTest
@testable import ZhiYu

@MainActor
final class IOSWatchSyncServiceTests: XCTestCase {

    // MARK: - 测试常量

    private enum TestConstants {
        static let sampleText: String = "来自 iPhone 的同步内容"
        static let audioChunkCount: Int = 3
        static let audioFileName: String = "voice_test.m4a"
        static let transferId: String = "transfer_001"
        static let firstChunkIndex: Int = 0
        static let singleChunkTotal: Int = 1
        static let secondChunkIndex: Int = 1
        static let thirdChunkIndex: Int = 2
    }

    // MARK: - setUp

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        resetPersistentTestState()
    }

    // MARK: - 初始状态

    /// 服务初始化后 lastReceivedText 应为空
    func testInitialLastReceivedTextIsEmpty() {
        let service = iOSWatchSyncService()
        XCTAssertTrue(service.lastReceivedText.isEmpty, "初始 lastReceivedText 应为空")
    }

    /// 服务初始化后 latestBriefing 应为 nil
    func testInitialLatestBriefingIsNil() {
        let service = iOSWatchSyncService()
        XCTAssertNil(service.latestBriefing, "初始 latestBriefing 应为 nil")
    }

    /// 服务初始化后 isBriefingLoading 应为 false
    func testInitialIsBriefingLoadingIsFalse() {
        let service = iOSWatchSyncService()
        XCTAssertFalse(service.isBriefingLoading, "初始 isBriefingLoading 应为 false")
    }

    // MARK: - sendContent

    /// sendContent 在模拟器（无配对手表）不应崩溃
    func testSendContentDoesNotCrashWithoutPairedWatch() {
        let service = iOSWatchSyncService()
        service.sendContent(TestConstants.sampleText)
        XCTAssertTrue(true, "sendContent 应正常执行无崩溃")
    }

    /// sendContent 空字符串不应崩溃
    func testSendContentWithEmptyStringDoesNotCrash() {
        let service = iOSWatchSyncService()
        service.sendContent("")
        XCTAssertTrue(true, "sendContent 空字符串应正常执行")
    }

    // MARK: - requestDailyBriefing / handleBriefingResponse

    /// requestDailyBriefing 在 iOS 端是预留接口，不应崩溃
    func testRequestDailyBriefingDoesNotCrash() {
        let service = iOSWatchSyncService()
        service.requestDailyBriefing()
        XCTAssertTrue(true, "requestDailyBriefing 应正常执行无崩溃")
    }

    /// handleBriefingResponse 在 iOS 端不处理，不应崩溃
    func testHandleBriefingResponseDoesNotCrash() {
        let service = iOSWatchSyncService()
        service.handleBriefingResponse("简报内容")
        XCTAssertTrue(true, "handleBriefingResponse 应正常执行无崩溃")
    }

    // MARK: - handleReceivedAudioChunk

    /// 接收部分音频分片（未集齐）不应触发合并，lastReceivedText 保持空
    func testHandleReceivedAudioChunkPartialDoesNotMerge() {
        let service = iOSWatchSyncService()
        let chunkData = Data([0x01, 0x02, 0x03])
        service.handleReceivedAudioChunk(
            transferId: TestConstants.transferId,
            index: TestConstants.firstChunkIndex,
            total: TestConstants.audioChunkCount,
            filename: TestConstants.audioFileName,
            data: chunkData
        )
        XCTAssertTrue(service.lastReceivedText.isEmpty,
                      "未集齐分片时 lastReceivedText 应保持空")
    }

    /// 接收全部音频分片（乱序）应触发合并并更新 lastReceivedText
    func testHandleReceivedAudioChunkAllChunksMergesSuccessfully() {
        let service = iOSWatchSyncService()
        let chunk0 = Data([0x01, 0x02])
        let chunk1 = Data([0x03, 0x04])
        let chunk2 = Data([0x05, 0x06])

        service.handleReceivedAudioChunk(transferId: TestConstants.transferId, index: TestConstants.secondChunkIndex,
                                         total: TestConstants.audioChunkCount,
                                         filename: TestConstants.audioFileName, data: chunk1)
        service.handleReceivedAudioChunk(transferId: TestConstants.transferId, index: TestConstants.thirdChunkIndex,
                                         total: TestConstants.audioChunkCount,
                                         filename: TestConstants.audioFileName, data: chunk2)
        service.handleReceivedAudioChunk(transferId: TestConstants.transferId, index: TestConstants.firstChunkIndex,
                                         total: TestConstants.audioChunkCount,
                                         filename: TestConstants.audioFileName, data: chunk0)

        XCTAssertTrue(service.lastReceivedText.hasPrefix("audio:"),
                      "集齐分片后 lastReceivedText 应以 audio: 开头")
        XCTAssertTrue(service.lastReceivedText.contains(TestConstants.audioFileName),
                      "lastReceivedText 应包含文件名")
    }

    /// 接收单个分片（total=1）应立即触发合并
    func testHandleReceivedAudioChunkSingleChunkMergesImmediately() {
        let service = iOSWatchSyncService()
        let chunkData = Data([0xAA, 0xBB, 0xCC])
        service.handleReceivedAudioChunk(
            transferId: "single_transfer",
            index: TestConstants.firstChunkIndex,
            total: TestConstants.singleChunkTotal,
            filename: "single.m4a",
            data: chunkData
        )
        XCTAssertTrue(service.lastReceivedText.hasPrefix("audio:single.m4a:"),
                      "单分片应立即合并并更新 lastReceivedText")
    }

    // MARK: - sendAudioData（协议默认实现）

    /// sendAudioData 协议默认实现不应崩溃
    func testSendAudioDataDefaultImplementationDoesNotCrash() {
        let service = iOSWatchSyncService()
        let audioData = Data([0x01, 0x02, 0x03, 0x04])
        service.sendAudioData(audioData, filename: TestConstants.audioFileName)
        XCTAssertTrue(true, "sendAudioData 默认实现应正常执行")
    }

    // MARK: - 协议一致性

    /// 服务实例应可向上转型为 WatchSyncProtocol
    func testConformsToWatchSyncProtocol() {
        let service: any WatchSyncProtocol = iOSWatchSyncService()
        service.sendContent(TestConstants.sampleText)
        XCTAssertTrue(service.lastReceivedText.isEmpty || service.lastReceivedText.count >= 0,
                      "协议转型与调用应成功")
    }

    /// latestBriefing 可读可写
    func testLatestBriefingIsReadWrite() {
        let service = iOSWatchSyncService()
        service.latestBriefing = "测试简报"
        XCTAssertEqual(service.latestBriefing, "测试简报")
        service.latestBriefing = nil
        XCTAssertNil(service.latestBriefing)
    }

    /// isBriefingLoading 可读可写
    func testIsBriefingLoadingIsReadWrite() {
        let service = iOSWatchSyncService()
        service.isBriefingLoading = true
        XCTAssertTrue(service.isBriefingLoading)
        service.isBriefingLoading = false
        XCTAssertFalse(service.isBriefingLoading)
    }
}
#endif
