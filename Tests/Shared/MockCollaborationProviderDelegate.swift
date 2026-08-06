//
//  MockCollaborationProviderDelegate.swift
//  ZhiYuTests
//
//  系统层级：[L0] 测试层
//  核心职责：协作 provider delegate spy，记录所有回调调用供测试断言。
//

import Foundation
@testable import ZhiYu

@MainActor
final class MockCollaborationProviderDelegate: CollaborationProviderDelegate {

    // MARK: - 调用记录

    var didUpdateStatusCallCount = 0
    var lastStatusMessage: String?

    var didDiscoverRoomCallCount = 0
    var lastDiscoveredRoom: DiscoveredRoom?

    var didLoseRoomCallCount = 0
    var lastLostRoomId: String?

    var didConnectPeerCallCount = 0
    var lastConnectedPeer: CollabUser?

    var didDisconnectPeerCallCount = 0
    var lastDisconnectedPeerId: String?

    var didReceiveDataCallCount = 0
    var lastReceivedData: Data?
    var lastReceivedDataFromUserId: String?

    var didEncounterErrorCallCount = 0
    var lastErrorMessage: String?

    // MARK: - CollaborationProviderDelegate 实现

    func providerDidUpdateStatus(_ message: String) {
        didUpdateStatusCallCount += 1
        lastStatusMessage = message
    }

    func providerDidDiscoverRoom(_ room: DiscoveredRoom) {
        didDiscoverRoomCallCount += 1
        lastDiscoveredRoom = room
    }

    func providerDidLoseRoom(id: String) {
        didLoseRoomCallCount += 1
        lastLostRoomId = id
    }

    func providerDidConnectPeer(_ user: CollabUser) {
        didConnectPeerCallCount += 1
        lastConnectedPeer = user
    }

    func providerDidDisconnectPeer(id: String) {
        didDisconnectPeerCallCount += 1
        lastDisconnectedPeerId = id
    }

    func providerDidReceiveData(_ data: Data, from userID: String) {
        didReceiveDataCallCount += 1
        lastReceivedData = data
        lastReceivedDataFromUserId = userID
    }

    func providerDidEncounterError(_ error: String) {
        didEncounterErrorCallCount += 1
        lastErrorMessage = error
    }

    // MARK: - 重置

    func reset() {
        didUpdateStatusCallCount = 0
        lastStatusMessage = nil
        didDiscoverRoomCallCount = 0
        lastDiscoveredRoom = nil
        didLoseRoomCallCount = 0
        lastLostRoomId = nil
        didConnectPeerCallCount = 0
        lastConnectedPeer = nil
        didDisconnectPeerCallCount = 0
        lastDisconnectedPeerId = nil
        didReceiveDataCallCount = 0
        lastReceivedData = nil
        lastReceivedDataFromUserId = nil
        didEncounterErrorCallCount = 0
        lastErrorMessage = nil
    }
}
