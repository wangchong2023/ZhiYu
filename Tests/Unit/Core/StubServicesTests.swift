//
//  StubServicesTests.swift
//  ZhiYu
//
//  系统层级：[L0] 测试层
//  核心职责：验证 3 个 Stub 桩服务的行为（空操作/不崩溃/delegate 回调）。
//

import XCTest
@testable import ZhiYu

@MainActor
final class StubServicesTests: XCTestCase {

    // MARK: - StubBackgroundTaskProvider

    /// register 应不崩溃（空实现）
    func testStubBackgroundTaskProviderRegisterNoCrash() {
        let provider = StubBackgroundTaskProvider()
        provider.register(handler: { })
    }

    /// schedule 应不崩溃（空实现）
    func testStubBackgroundTaskProviderScheduleNoCrash() {
        let provider = StubBackgroundTaskProvider()
        provider.schedule()
    }

    // MARK: - StubWatchSyncService

    /// 初始 lastReceivedText 应为空字符串
    func testStubWatchSyncServiceLastReceivedTextInitiallyEmpty() {
        let service = StubWatchSyncService()
        XCTAssertEqual(service.lastReceivedText, "")
    }

    /// 初始 latestBriefing 应为 nil
    func testStubWatchSyncServiceLatestBriefingInitiallyNil() {
        let service = StubWatchSyncService()
        XCTAssertNil(service.latestBriefing)
    }

    /// 初始 isBriefingLoading 应为 false
    func testStubWatchSyncServiceIsBriefingLoadingInitiallyFalse() {
        let service = StubWatchSyncService()
        XCTAssertFalse(service.isBriefingLoading)
    }

    /// sendContent 应不崩溃（空实现）    /// requestDailyBriefing 应不崩溃    /// handleBriefingResponse 应不崩溃    // MARK: - StubCollaborationProvider

    /// delegate 可设置
    func testStubCollaborationProviderDelegateSettable() {
        let provider = StubCollaborationProvider()
        let delegate = MockCollaborationProviderDelegate()
        provider.delegate = delegate
        XCTAssertTrue(provider.delegate === delegate)
    }

    /// startHosting 应触发 delegate.providerDidUpdateStatus（simulatorNotSupported）
    func testStubCollaborationProviderStartHostingTriggersDelegateStatus() {
        let provider = StubCollaborationProvider()
        let delegate = MockCollaborationProviderDelegate()
        provider.delegate = delegate

        provider.startHosting(roomName: "test-room", userName: "test-user")

        XCTAssertEqual(delegate.didUpdateStatusCallCount, 1)
        XCTAssertEqual(delegate.lastStatusMessage, L10n.Collaboration.Status.simulatorNotSupported)
    }

    /// startBrowsing 应触发 delegate.providerDidUpdateStatus（simulatorNotSupported）
    func testStubCollaborationProviderStartBrowsingTriggersDelegateStatus() {
        let provider = StubCollaborationProvider()
        let delegate = MockCollaborationProviderDelegate()
        provider.delegate = delegate

        provider.startBrowsing(userName: "test-user")

        XCTAssertEqual(delegate.didUpdateStatusCallCount, 1)
        XCTAssertEqual(delegate.lastStatusMessage, L10n.Collaboration.Status.simulatorNotSupported)
    }

    /// joinRoom 应不崩溃（空实现，不触发 delegate）
    func testStubCollaborationProviderJoinRoomNoCrash() {
        let provider = StubCollaborationProvider()
        let delegate = MockCollaborationProviderDelegate()
        provider.delegate = delegate

        let room = DiscoveredRoom(
            id: "test-id",
            platformPeer: "peer" as AnyHashable,
            roomName: "test-room",
            owner: "test-owner"
        )
        provider.joinRoom(room)

        XCTAssertEqual(delegate.didDiscoverRoomCallCount, 0, "joinRoom 不应触发 didDiscoverRoom")
    }

    /// stop 应触发 delegate.providerDidUpdateStatus（disconnected）
    func testStubCollaborationProviderStopTriggersDelegateDisconnect() {
        let provider = StubCollaborationProvider()
        let delegate = MockCollaborationProviderDelegate()
        provider.delegate = delegate

        provider.stop()

        XCTAssertEqual(delegate.didUpdateStatusCallCount, 1)
        XCTAssertEqual(delegate.lastStatusMessage, L10n.Collaboration.Status.disconnected)
    }

    /// broadcast 应不崩溃（空实现）
    func testStubCollaborationProviderBroadcastNoCrash() {
        let provider = StubCollaborationProvider()
        provider.broadcast(data: Data([0x01, 0x02]))
    }

    /// 无 delegate 时所有方法应不崩溃
    func testStubCollaborationProviderNoDelegateNoCrash() {
        let provider = StubCollaborationProvider()
        provider.startHosting(roomName: "test", userName: "user")
        provider.startBrowsing(userName: "user")
        provider.stop()
        provider.broadcast(data: Data())
    }
}
