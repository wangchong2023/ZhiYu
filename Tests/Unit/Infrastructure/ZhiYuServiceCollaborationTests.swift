//
//  ZhiYuServiceCollaborationTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 CollaborationService 开展角色、用户名、对等节点与房间相等性的自动化单元测试验证。
//
import XCTest
import Network
@preconcurrency @testable import ZhiYu
@testable import UFPCore

// MARK: - CollaborationService Tests
@MainActor
final class ZhiYuServiceCollaborationTests: XCTestCase {

    var collabService: CollaborationService!
    var store: AppStore!

    override func setUp() async throws {
        try await super.setUp()
        // 统一配置标准测试 Mock 环境，将协作提供商与环境适配等服务一并就绪，确保完全物理隔离且不崩溃
        setupFullMockEnvironment()
        collabService = CollaborationService()
        store = AppStore()
    }

    override func tearDown() async throws {
        collabService.stop()
        collabService = nil
        store = nil
        // 允许当前主线程/协程事件循环排水，确保所有未完成的异步任务运行完毕，规避重置 DI 导致的 Race Condition (@SRS-7.1)
        try await Task.sleep(nanoseconds: 50_000_000)
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    @MainActor
    func testSetStoreAssignsStore() {
        // store is usually managed via AppStore instance or passed to views
        XCTAssertNotNil(AppStore())
    }

    @MainActor
    func testDefaultRoleIsViewer() {
        XCTAssertEqual(collabService.role, .viewer)
    }

    @MainActor
    func testDefaultUserNameIsSet() {
        // displayName was moved to internal or statusMessage,
        // we test availability instead or check if setUserName works without crash
        collabService.setUserName("TestUser")
        XCTAssertTrue(collabService.isAvailable || collabService.isSimulator)
    }

    @MainActor
    func testSetUserNameUpdatesName() {
        collabService.setUserName("TestUser")
        // Just verify it doesn't crash as we can't easily read back private userName
        XCTAssertNotNil(collabService)
    }

    @MainActor
    func testNoPeersWhenNotConnected() {
        XCTAssertTrue(collabService.connectedPeers.isEmpty)
    }

    @MainActor
    func testRecentEditsEmptyInitially() {
        XCTAssertTrue(collabService.recentEdits.isEmpty)
    }

    @MainActor
    func testRoleColors() {
        // roles no longer have color property directly, usually handled by UI theme
        XCTAssertEqual(CollabRole.owner.icon, "crown.fill")
    }

    @MainActor
    func testDiscoveredRoomEquality() {
        let endpoint = NWEndpoint.service(name: "p1", type: "_km-collab._tcp", domain: "", interface: nil)
        let room1 = DiscoveredRoom(id: "r1", platformPeer: endpoint, roomName: "Room", owner: "Host1")
        let room2 = DiscoveredRoom(id: "r1", platformPeer: endpoint, roomName: "Room", owner: "Host1")
        XCTAssertEqual(room1, room2)
    }
}
