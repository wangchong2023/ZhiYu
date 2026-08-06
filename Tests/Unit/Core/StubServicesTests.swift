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
    func testStubBackgroundTaskProvider_register_不崩溃() {
        let provider = StubBackgroundTaskProvider()
        provider.register(handler: { })
    }

    /// schedule 应不崩溃（空实现）
    func testStubBackgroundTaskProvider_schedule_不崩溃() {
        let provider = StubBackgroundTaskProvider()
        provider.schedule()
    }

    // MARK: - StubWatchSyncService

    /// 初始 lastReceivedText 应为空字符串
    func testStubWatchSyncService_lastReceivedText_初始为空() {
        let service = StubWatchSyncService()
        XCTAssertEqual(service.lastReceivedText, "")
    }

    /// 初始 latestBriefing 应为 nil
    func testStubWatchSyncService_latestBriefing_初始为nil() {
        let service = StubWatchSyncService()
        XCTAssertNil(service.latestBriefing)
    }

    /// 初始 isBriefingLoading 应为 false
    func testStubWatchSyncService_isBriefingLoading_初始为false() {
        let service = StubWatchSyncService()
        XCTAssertFalse(service.isBriefingLoading)
    }

    /// sendContent 应不崩溃（空实现）
    func testStubWatchSyncService_sendContent_不崩溃() {
        let service = StubWatchSyncService()
        service.sendContent("test")
    }

    /// requestDailyBriefing 应不崩溃
    func testStubWatchSyncService_requestDailyBriefing_不崩溃() {
        let service = StubWatchSyncService()
        service.requestDailyBriefing()
    }

    /// handleBriefingResponse 应不崩溃
    func testStubWatchSyncService_handleBriefingResponse_不崩溃() {
        let service = StubWatchSyncService()
        service.handleBriefingResponse("briefing text")
    }

    // MARK: - StubCollaborationProvider

    /// delegate 可设置
    func testStubCollaborationProvider_delegate可设置() {
        let provider = StubCollaborationProvider()
        let delegate = MockCollaborationProviderDelegate()
        provider.delegate = delegate
        XCTAssertTrue(provider.delegate === delegate)
    }

    /// startHosting 应触发 delegate.providerDidUpdateStatus（simulatorNotSupported）
    func testStubCollaborationProvider_startHosting_触发delegate状态() {
        let provider = StubCollaborationProvider()
        let delegate = MockCollaborationProviderDelegate()
        provider.delegate = delegate

        provider.startHosting(roomName: "test-room", userName: "test-user")

        XCTAssertEqual(delegate.didUpdateStatusCallCount, 1)
        XCTAssertEqual(delegate.lastStatusMessage, L10n.Collaboration.Status.simulatorNotSupported)
    }

    /// startBrowsing 应触发 delegate.providerDidUpdateStatus（simulatorNotSupported）
    func testStubCollaborationProvider_startBrowsing_触发delegate状态() {
        let provider = StubCollaborationProvider()
        let delegate = MockCollaborationProviderDelegate()
        provider.delegate = delegate

        provider.startBrowsing(userName: "test-user")

        XCTAssertEqual(delegate.didUpdateStatusCallCount, 1)
        XCTAssertEqual(delegate.lastStatusMessage, L10n.Collaboration.Status.simulatorNotSupported)
    }

    /// joinRoom 应不崩溃（空实现，不触发 delegate）
    func testStubCollaborationProvider_joinRoom_不崩溃() {
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
    func testStubCollaborationProvider_stop_触发delegate断开() {
        let provider = StubCollaborationProvider()
        let delegate = MockCollaborationProviderDelegate()
        provider.delegate = delegate

        provider.stop()

        XCTAssertEqual(delegate.didUpdateStatusCallCount, 1)
        XCTAssertEqual(delegate.lastStatusMessage, L10n.Collaboration.Status.disconnected)
    }

    /// broadcast 应不崩溃（空实现）
    func testStubCollaborationProvider_broadcast_不崩溃() {
        let provider = StubCollaborationProvider()
        provider.broadcast(data: Data([0x01, 0x02]))
    }

    /// 无 delegate 时所有方法应不崩溃
    func testStubCollaborationProvider_无delegate_不崩溃() {
        let provider = StubCollaborationProvider()
        provider.startHosting(roomName: "test", userName: "user")
        provider.startBrowsing(userName: "user")
        provider.stop()
        provider.broadcast(data: Data())
    }
}
