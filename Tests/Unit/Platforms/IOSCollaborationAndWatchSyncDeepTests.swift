//
//  IOSCollaborationAndWatchSyncDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/03.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests] 单元测试层
//  核心职责：深度覆盖 L3 Platforms 多端协同 Network Framework 实现与 iOSWatchSyncService 状态机。
//

import XCTest
import Network
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif
@testable import ZhiYu
import UFPCore

@MainActor
final class IOSCollaborationAndWatchSyncDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. MultipeerCollaborationProvider Network Framework 测试

    func testMultipeerCollaborationProvider_StartHosting() {
        let provider = MultipeerCollaborationProvider()
        let delegate = MockCollaborationDelegate()
        provider.delegate = delegate

        provider.startHosting(roomName: "测试房间", userName: "测试主机")
        XCTAssertTrue(delegate.statuses.contains(L10n.Collaboration.Status.hosting), "启动 Hosting 后应上报状态")

        provider.stop()
        XCTAssertTrue(delegate.statuses.contains(L10n.Collaboration.Status.disconnected), "停止后状态应变为 disconnected")
    }

    func testMultipeerCollaborationProvider_StartBrowsing() {
        let provider = MultipeerCollaborationProvider()
        let delegate = MockCollaborationDelegate()
        provider.delegate = delegate

        provider.startBrowsing(userName: "测试客户端")
        XCTAssertTrue(delegate.statuses.contains(L10n.Collaboration.Status.searching), "启动 Browsing 后应上报 searching 状态")

        provider.stop()
    }

    func testMultipeerCollaborationProvider_BroadcastNoPeers() {
        let provider = MultipeerCollaborationProvider()
        // 无连接 peer 时广播安全不崩溃
        provider.broadcast(data: Data("test".utf8))
        XCTAssertNotNil(provider)
    }

    // MARK: - 2. iOSWatchSyncService 状态机与音频分片拼装测试

    #if os(iOS) && !os(watchOS)
    func testIOSWatchSyncService_LifecycleAndActions() {
        let service = iOSWatchSyncService()
        XCTAssertNotNil(service)

        // 空预留方法覆盖
        service.requestDailyBriefing()
        service.handleBriefingResponse("briefing text")

        // 默认未激活状态发送降级
        service.sendContent("同步页面内容")
    }

    func testIOSWatchSyncService_UserInfoReceiving() async {
        let service = iOSWatchSyncService()
        let session = WCSession.default

        // 1. 测试普通文本内容更新
        let expContent = expectation(description: "didReceiveWatchContent")
        let observer = NotificationCenter.default.addObserver(
            forName: .didReceiveWatchContent,
            object: nil,
            queue: .main
        ) { _ in
            expContent.fulfill()
        }

        service.session(session, didReceiveUserInfo: ["content": "手表创建的随手记"])
        await fulfillment(of: [expContent], timeout: 2.0)
        NotificationCenter.default.removeObserver(observer)
        XCTAssertEqual(service.lastReceivedText, "手表创建的随手记")

        // 2. 测试 new_page 类型
        service.session(session, didReceiveUserInfo: ["type": "new_page", "content": "新笔记内容"])

        // 3. 测试 request_briefing 类型
        service.session(session, didReceiveUserInfo: ["type": "request_briefing"])

        // 4. 测试生命周期回调
        service.session(session, activationDidCompleteWith: .activated, error: nil)
        service.session(session, activationDidCompleteWith: .notActivated, error: NSError(domain: "watch", code: -1))
        service.sessionDidBecomeInactive(session)
    }

    func testIOSWatchSyncService_AudioChunkAssembly() {
        let service = iOSWatchSyncService()
        let transferID = "audio-test-tx-\(UUID().uuidString)"
        let filename = "memo.m4a"

        // 1. 无效参数防御
        service.handleReceivedAudioChunk(transferId: transferID, index: -1, total: 2, filename: filename, data: Data())
        service.handleReceivedAudioChunk(transferId: transferID, index: 2, total: 2, filename: filename, data: Data())
        service.handleReceivedAudioChunk(transferId: transferID, index: 0, total: 0, filename: filename, data: Data())

        // 2. 正常分片拼装
        let chunk0 = Data("ChunkZeroData".utf8)
        let chunk1 = Data("ChunkOneData".utf8)

        service.handleReceivedAudioChunk(transferId: transferID, index: 0, total: 2, filename: filename, data: chunk0)
        service.handleReceivedAudioChunk(transferId: transferID, index: 1, total: 2, filename: filename, data: chunk1)

        XCTAssertTrue(service.lastReceivedText.hasPrefix("audio:\(filename)"))
    }
    #endif
}
