//
//  IOSCollaborationAndWatchSyncDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/03.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests] 单元测试层
//  核心职责：深度覆盖 L3 Platforms 多端协同 MCSession 代理实现与 iOSWatchSyncService 状态机。
//

import XCTest
#if canImport(MultipeerConnectivity)
import MultipeerConnectivity
#endif
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

    // MARK: - 1. MCSessionDelegateImpl 状态机测试

    #if canImport(MultipeerConnectivity)
    func testMCSessionDelegateImpl_StateChanges() async {
        let peerID = MCPeerID(displayName: "TestDevice")
        var connectedPeer: MCPeerID?
        var disconnectedPeer: MCPeerID?
        var connectingPeer: MCPeerID?

        let expConnected = expectation(description: "onPeerConnected")
        let expDisconnected = expectation(description: "onPeerDisconnected")
        let expConnecting = expectation(description: "onStatusChange")

        let delegate = MCSessionDelegateImpl(
            onPeerConnected: { peer in
                connectedPeer = peer
                expConnected.fulfill()
            },
            onPeerDisconnected: { peer in
                disconnectedPeer = peer
                expDisconnected.fulfill()
            },
            onDataReceived: { _, _ in },
            onStatusChange: { state, peer in
                if state == .connecting {
                    connectingPeer = peer
                    expConnecting.fulfill()
                }
            }
        )

        let session = MCSession(peer: peerID)

        // 模拟连接改变事件
        delegate.session(session, peer: peerID, didChange: .connected)
        delegate.session(session, peer: peerID, didChange: .connecting)
        delegate.session(session, peer: peerID, didChange: .notConnected)

        await fulfillment(of: [expConnected, expConnecting, expDisconnected], timeout: 2.0)

        XCTAssertEqual(connectedPeer, peerID)
        XCTAssertEqual(connectingPeer, peerID)
        XCTAssertEqual(disconnectedPeer, peerID)
    }

    func testMCSessionDelegateImpl_DataAndStreams() async {
        let peerID = MCPeerID(displayName: "TestDevice")
        let testData = Data("PingData".utf8)
        var receivedData: Data?

        let expData = expectation(description: "onDataReceived")

        let delegate = MCSessionDelegateImpl(
            onPeerConnected: { _ in },
            onPeerDisconnected: { _ in },
            onDataReceived: { data, _ in
                receivedData = data
                expData.fulfill()
            },
            onStatusChange: { _, _ in }
        )

        let session = MCSession(peer: peerID)

        // 模拟接收数据与空生命周期流
        delegate.session(session, didReceive: testData, fromPeer: peerID)
        delegate.session(session, didReceive: InputStream(), withName: "testStream", fromPeer: peerID)
        delegate.session(session, didStartReceivingResourceWithName: "res", fromPeer: peerID, with: Progress())
        delegate.session(session, didFinishReceivingResourceWithName: "res", fromPeer: peerID, at: nil, withError: nil)

        await fulfillment(of: [expData], timeout: 2.0)
        XCTAssertEqual(receivedData, testData)
    }

    // MARK: - 2. MCAdvertiserDelegateImpl 广播代理测试

    func testMCAdvertiserDelegateImpl_InvitationAndError() async {
        let peerID = MCPeerID(displayName: "HostDevice")
        let contextData = Data("SecretCode".utf8)
        var invitedPeer: MCPeerID?
        var errorReported: Error?

        let expInvite = expectation(description: "onInvitation")
        let expError = expectation(description: "onError")

        let delegate = MCAdvertiserDelegateImpl(
            onInvitation: { peer, _, handler in
                invitedPeer = peer
                handler(true, nil)
                expInvite.fulfill()
            },
            onError: { error in
                errorReported = error
                expError.fulfill()
            }
        )

        let advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: "zhiyu-test")

        delegate.advertiser(advertiser, didReceiveInvitationFromPeer: peerID, withContext: contextData) { _, _ in }
        delegate.advertiser(advertiser, didNotStartAdvertisingPeer: NSError(domain: "test", code: -100))

        await fulfillment(of: [expInvite, expError], timeout: 2.0)
        XCTAssertEqual(invitedPeer, peerID)
        XCTAssertNotNil(errorReported)
    }

    // MARK: - 3. MCBrowserDelegateImpl 浏览器代理测试

    func testMCBrowserDelegateImpl_DiscoveryAndLoss() async {
        let peerID = MCPeerID(displayName: "RemotePeer")
        let info = ["version": "1.0"]
        var discoveredPeer: MCPeerID?
        var lostPeer: MCPeerID?
        var browserError: Error?

        let expFound = expectation(description: "onRoomFound")
        let expLost = expectation(description: "onRoomLost")
        let expError = expectation(description: "onError")

        let delegate = MCBrowserDelegateImpl(
            onRoomFound: { peer, _ in
                discoveredPeer = peer
                expFound.fulfill()
            },
            onRoomLost: { peer in
                lostPeer = peer
                expLost.fulfill()
            },
            onError: { error in
                browserError = error
                expError.fulfill()
            }
        )

        let browser = MCNearbyServiceBrowser(peer: peerID, serviceType: "zhiyu-test")

        delegate.browser(browser, foundPeer: peerID, withDiscoveryInfo: info)
        delegate.browser(browser, lostPeer: peerID)
        delegate.browser(browser, didNotStartBrowsingForPeers: NSError(domain: "test", code: -200))

        await fulfillment(of: [expFound, expLost, expError], timeout: 2.0)
        XCTAssertEqual(discoveredPeer, peerID)
        XCTAssertEqual(lostPeer, peerID)
        XCTAssertNotNil(browserError)
    }
    #endif

    // MARK: - 4. iOSWatchSyncService 状态机与音频分片拼装测试

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
