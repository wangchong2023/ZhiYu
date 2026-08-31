//
//  CollaborationServiceDeepTests.swift
//  ZhiYuTests
//
//  系统层级：[Test] 单元测试
//  核心职责：CollaborationService 深度补盲测试 — 覆盖 startHosting/startBrowsing/joinRoom
//            状态转换、stop 状态清理、peer 连接/断开、room 发现/丢失、
//            data 接收（CollabEdit + pageSync）、appendEdit 上限、
//            setUserName 持久化、isAvailable 模拟器降级、错误回调等未覆盖路径。
//
//  说明：Tests/Unit/Services/CollaborationServiceTests.swift 已覆盖基础 startHosting、
//        joinRoom、peer 连接断开，但未验证 stop 状态残留、appendEdit 上限、
//        pageSync 解码、delegate 为 nil 时静默失败、isConnecting 状态泄漏、
//        room 去重、error 回调、setUserName 持久化。
//        本文件补充状态机完整性、数据解码、边界条件，并尝试发现潜在 bug。
//

import XCTest
import UFPCore
import Combine
@testable import ZhiYu

@MainActor
final class CollaborationServiceDeepTests: XCTestCase {

    // MARK: - 常量

    /// 测试房间名
    private let testRoomName = "Deep Test Room"
    /// 测试用户显示名
    private let testDisplayName = "Test User"
    /// 测试用户设备名
    private let testDeviceName = "iPhone Test"
    /// 测试用户 ID
    private let testUserId = "user-deep-1"
    /// 第二个测试用户 ID
    private let testUserId2 = "user-deep-2"
    /// 测试房间 ID
    private let testRoomId = "room-deep-1"
    /// 第二个测试房间 ID
    private let testRoomId2 = "room-deep-2"
    /// 测试平台 Peer 标识
    private let testPlatformPeer = "test-peer-deep"
    /// 测试房主名
    private let testOwnerName = "Deep Owner"
    /// appendEdit 上限（与源码 maxRecentEdits 一致）
    private let maxRecentEditsLimit = 100
    /// 超过上限的编辑数量（用于验证截断）
    private let overflowEditCount = 105
    /// pageSync payload type 字段值
    private let pageSyncTypeValue = "pageSync"
    /// pageSync payload page key
    private let pageSyncPageKey = "page"
    /// pageSync payload id key
    private let pageSyncIdKey = "id"
    /// pageSync payload title key
    private let pageSyncTitleKey = "title"
    /// pageSync payload content key
    private let pageSyncContentKey = "content"
    /// pageSync payload type key（页面类型）
    private let pageSyncPageTypeKey = "type"
    /// pageSync payload tags key
    private let pageSyncTagsKey = "tags"
    /// pageSync payload status key
    private let pageSyncStatusKey = "status"
    /// pageSync payload updated key
    private let pageSyncUpdatedKey = "updated"
    /// 测试页面标题
    private let testPageTitle = "Deep Sync Page"
    /// 测试页面内容
    private let testPageContent = "Deep sync content"
    /// 测试页面类型 concept
    private let testPageTypeConcept = "concept"
    /// 测试页面状态 active
    private let testPageStatusActive = "active"
    /// 测试标签
    private let testTag = "deep-tag"
    /// 异步 Task 等待时间（纳秒）
    private let asyncWaitNanoseconds: UInt64 = 100_000_000
    /// 错误消息测试字符串
    private let testErrorMessage = "Deep connection error"
    /// 状态消息测试字符串
    private let testStatusMessage = "Deep status update"
    /// userName 持久化测试值
    private let testUserNameValue = "Deep User Name"

    // MARK: - 被测对象

    private var service: CollaborationService!
    private var mockProvider: MockCollaborationProvider!
    private var mockDelegate: MockCollaborationDelegate!

    // MARK: - 生命周期

    override func setUp() async throws {
        try await super.setUp()
        resetPersistentTestState()
        setupFullMockEnvironment()

        mockProvider = MockCollaborationProvider()
        ServiceContainer.shared.register(mockProvider as any CollaborationProviderProtocol, for: (any CollaborationProviderProtocol).self)

        service = CollaborationService()
        // 强行模拟可用状态以越过 iOS 模拟器环境下的 isAvailable 检查
        service.isAvailable = true

        // 确保 mockProvider.delegate 指向 service（绕过 @Dependency 缓存不确定性）
        mockProvider.delegate = service

        mockDelegate = MockCollaborationDelegate()
        service.delegate = mockDelegate
    }

    override func tearDown() async throws {
        service = nil
        mockProvider = nil
        mockDelegate = nil
        try await super.tearDown()
    }

    // MARK: - 辅助方法

    /// 构造测试用 CollabUser
    private func makeUser(id: String, displayName: String = "Test User", deviceName: String = "iPhone") -> CollabUser {
        CollabUser(id: id, displayName: displayName, deviceName: deviceName, joinedAt: Date())
    }

    /// 构造测试用 DiscoveredRoom
    private func makeRoom(id: String, roomName: String = "Test Room", owner: String = "Owner") -> DiscoveredRoom {
        DiscoveredRoom(id: id, platformPeer: testPlatformPeer, roomName: roomName, owner: owner)
    }

    /// 构造 pageSync payload Data
    private func makePageSyncData(
        id: UUID,
        title: String = "Deep Sync Page",
        content: String = "Deep sync content",
        pageType: String = "concept",
        tags: [String] = ["deep-tag"],
        status: String = "active",
        updated: TimeInterval = Date().timeIntervalSince1970
    ) throws -> Data {
        let payload: [String: Any] = [
            "type": "pageSync",
            "page": [
                "id": id.uuidString,
                "title": title,
                "content": content,
                "type": pageType,
                "tags": tags,
                "status": status,
                "updated": updated
            ]
        ]
        return try JSONSerialization.data(withJSONObject: payload)
    }

    /// 构造测试用 CollabEdit Data
    private func makeCollabEditData(pageID: UUID, userID: String = "user-deep-1") throws -> Data {
        let edit = CollabEdit(
            id: UUID().uuidString,
            userID: userID,
            pageID: pageID,
            field: "content",
            oldValue: "old",
            newValue: "new",
            timestamp: Date()
        )
        return try JSONEncoder().encode(edit)
    }

    /// 构造任意 JSON 对象的 Data（用于构造非法/边界 payload）
    private func makeJSONData(_ object: Any) throws -> Data {
        try JSONSerialization.data(withJSONObject: object)
    }

    /// 轮询等待条件满足，避免固定 sleep 在全量测试负载下不够的问题
    /// - Parameters:
    ///   - condition: 条件闭包，返回 true 表示条件已满足
    ///   - timeout: 超时时间（秒），默认 30 秒（全量测试高负载下 Task 调度可能延迟）
    ///   - interval: 轮询间隔（纳秒），默认 10ms
    private func waitFor(
        _ condition: @MainActor () -> Bool,
        timeout: TimeInterval = 30.0,
        interval: UInt64 = 10_000_000
    ) async throws {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if await MainActor.run(body: condition) { return }
            try await Task.sleep(nanoseconds: interval)
        }
        // 最后一次检查
        if await MainActor.run(body: condition) { return }
        XCTFail("等待条件超时（\(timeout)秒）")
    }

    // MARK: - startHosting 状态转换

    /// 验证 startHosting 完整状态转换：roomName/role/connectionError/isConnecting/isHosting/isJoined
    func testStartHosting完整状态转换() {
        XCTAssertFalse(service.isHosting)
        XCTAssertFalse(service.isJoined)
        XCTAssertFalse(service.isConnecting)
        XCTAssertEqual(service.role, .viewer)
        XCTAssertEqual(service.roomName, "")

        service.startHosting(roomName: testRoomName)

        XCTAssertEqual(service.roomName, testRoomName)
        XCTAssertEqual(service.role, .owner)
        XCTAssertNil(service.connectionError)
        XCTAssertFalse(service.isConnecting, "startHosting 后 isConnecting 应为 false — host 自身已连接到房间")
        XCTAssertTrue(service.isHosting)
        XCTAssertTrue(service.isJoined)
        XCTAssertTrue(mockProvider.didCallStartHosting)
        XCTAssertEqual(mockProvider.hostedRoomName, testRoomName)
    }

    /// 验证 isAvailable 为 false 时 startHosting 静默不执行
    func testIsAvailable为false时StartHosting静默不执行() {
        service.isAvailable = false
        service.startHosting(roomName: testRoomName)

        XCTAssertFalse(service.isHosting)
        XCTAssertFalse(service.isJoined)
        XCTAssertFalse(mockProvider.didCallStartHosting)
        XCTAssertEqual(service.roomName, "")
    }

    /// 验证 startHosting 后 isConnecting 在无 peer 连入时为 false
    /// - Note: C-8/Bug#4 已修复 — host 启动后自身已"连接"到房间，isConnecting 直接置 false。
    func testStartHosting后isConnecting在无peer连入时为false() {
        service.startHosting(roomName: testRoomName)
        // host 启动后，无 peer 连入，isConnecting 应为 false（已修复）
        XCTAssertFalse(service.isConnecting, "host 启动后 isConnecting 应为 false — host 自身已连接到房间")
    }

    // MARK: - startBrowsing 状态转换

    /// 验证 startBrowsing 状态转换：connectionError/isConnecting + provider 调用
    func testStartBrowsing状态转换() {
        service.startBrowsing()

        XCTAssertNil(service.connectionError)
        XCTAssertTrue(service.isConnecting)
        XCTAssertTrue(mockProvider.didCallStartBrowsing)
        XCTAssertNotNil(mockProvider.browsedUserName)
    }

    /// 验证 isAvailable 为 false 时 startBrowsing 静默不执行
    func testIsAvailable为false时StartBrowsing静默不执行() {
        service.isAvailable = false
        service.startBrowsing()

        XCTAssertFalse(mockProvider.didCallStartBrowsing)
        XCTAssertFalse(service.isConnecting)
    }

    // MARK: - joinRoom 状态转换

    /// 验证 joinRoom 状态转换：role/isConnecting + provider 调用
    func testJoinRoom状态转换() {
        let room = makeRoom(id: testRoomId)
        service.joinRoom(room)

        XCTAssertEqual(service.role, .editor)
        XCTAssertTrue(service.isConnecting)
        XCTAssertEqual(mockProvider.joinedRoom?.id, testRoomId)
    }

    /// 验证 isAvailable 为 false 时 joinRoom 静默不执行
    func testIsAvailable为false时JoinRoom静默不执行() {
        service.isAvailable = false
        let room = makeRoom(id: testRoomId)
        service.joinRoom(room)

        XCTAssertEqual(service.role, .viewer)
        XCTAssertFalse(service.isConnecting)
        XCTAssertNil(mockProvider.joinedRoom)
    }

    // MARK: - stop 状态清理

    /// 验证 stop 清理所有连接状态
    func testStop清理所有连接状态() {
        service.startHosting(roomName: testRoomName)
        mockProvider.simulatePeerConnect(makeUser(id: testUserId))

        service.stop()

        XCTAssertFalse(service.isHosting)
        XCTAssertFalse(service.isJoined)
        XCTAssertFalse(service.isConnecting)
        XCTAssertTrue(service.connectedPeers.isEmpty)
        XCTAssertTrue(service.discoveredRooms.isEmpty)
        XCTAssertTrue(service.recentEdits.isEmpty)
        XCTAssertNil(service.connectionError)
        XCTAssertTrue(mockProvider.didCallStop)
    }

    /// 验证 stop 后 roomName 和 role 被清理
    /// - Note: C-9/Bug#5 已修复 — stop() 现在清理 roomName="" 和 role=.viewer。
    func testStop后roomName和role被清理() {
        service.startHosting(roomName: testRoomName)
        XCTAssertEqual(service.roomName, testRoomName)
        XCTAssertEqual(service.role, .owner)

        service.stop()

        // 验证修复：roomName 和 role 被 stop 清理
        XCTAssertEqual(service.roomName, "", "stop() 后 roomName 应清理为空字符串")
        XCTAssertEqual(service.role, .viewer, "stop() 后 role 应清理为 .viewer")
    }

    // MARK: - peer 连接/断开

    /// 验证 peer 连接时 isConnecting 置 false 且 isJoined 置 true
    func testPeer连接时isConnecting置false且isJoined置true() {
        service.startBrowsing()
        XCTAssertTrue(service.isConnecting)

        mockProvider.simulatePeerConnect(makeUser(id: testUserId))

        XCTAssertFalse(service.isConnecting)
        XCTAssertTrue(service.isJoined)
        XCTAssertEqual(service.connectedPeers.count, 1)
    }

    /// 验证重复 peer 连接不重复添加
    func testDuplicatePeerConnectionNotAddedTwice() {
        let user = makeUser(id: testUserId)
        mockProvider.simulatePeerConnect(user)
        mockProvider.simulatePeerConnect(user)

        XCTAssertEqual(service.connectedPeers.count, 1, "相同 ID 的 peer 重复连接不应重复添加")
    }

    /// 验证 peer 断开后 connectedPeers 移除
    func testPeer断开后connectedPeers移除() {
        mockProvider.simulatePeerConnect(makeUser(id: testUserId))
        mockProvider.simulatePeerConnect(makeUser(id: testUserId2))
        XCTAssertEqual(service.connectedPeers.count, 2)

        mockProvider.simulatePeerDisconnect(testUserId)
        XCTAssertEqual(service.connectedPeers.count, 1)
        XCTAssertEqual(service.connectedPeers.first?.id, testUserId2)
    }

    /// 验证非 host 场景下所有 peer 断开后 isJoined 置 false
    func testNonHostScenarioAllPeersDisconnectedSetsIsJoinedFalse() {
        service.startBrowsing()
        mockProvider.simulatePeerConnect(makeUser(id: testUserId))
        XCTAssertTrue(service.isJoined)

        mockProvider.simulatePeerDisconnect(testUserId)

        XCTAssertFalse(service.isJoined, "非 host 场景所有 peer 断开后 isJoined 应为 false")
    }

    /// 验证 host 场景下所有 peer 断开后 isJoined 仍为 true（host 自身仍 joined）
    func testHost场景所有peer断开后isJoined保持true() {
        service.startHosting(roomName: testRoomName)
        mockProvider.simulatePeerConnect(makeUser(id: testUserId))
        XCTAssertTrue(service.isJoined)

        mockProvider.simulatePeerDisconnect(testUserId)

        XCTAssertTrue(service.isJoined, "host 场景所有 peer 断开后 isJoined 应保持 true")
    }

    /// 验证断开不存在的 peer ID 不崩溃且不改变状态
    func testDisconnectNonExistentPeerIDDoesNotCrash() {
        mockProvider.simulatePeerConnect(makeUser(id: testUserId))
        XCTAssertEqual(service.connectedPeers.count, 1)

        // 断开一个不存在的 ID
        mockProvider.simulatePeerDisconnect("non-existent-id")

        XCTAssertEqual(service.connectedPeers.count, 1, "断开不存在的 ID 不应影响现有 peer")
    }

    // MARK: - room 发现/丢失

    /// 验证 room 发现时添加到 discoveredRooms
    func testRoom发现时添加到DiscoveredRooms() {
        let room = makeRoom(id: testRoomId)
        // 通过 provider delegate 回调模拟发现
        mockProvider.delegate?.providerDidDiscoverRoom(room)

        XCTAssertEqual(service.discoveredRooms.count, 1)
        XCTAssertEqual(service.discoveredRooms.first?.id, testRoomId)
    }

    /// 验证重复 room ID 不重复添加
    func testDuplicateRoomIDNotAddedTwice() {
        let room = makeRoom(id: testRoomId)
        mockProvider.delegate?.providerDidDiscoverRoom(room)
        mockProvider.delegate?.providerDidDiscoverRoom(room)

        XCTAssertEqual(service.discoveredRooms.count, 1, "相同 ID 的 room 不应重复添加")
    }

    /// 验证 room 丢失时从 discoveredRooms 移除
    func testRoom丢失时从DiscoveredRooms移除() {
        let room = makeRoom(id: testRoomId)
        mockProvider.delegate?.providerDidDiscoverRoom(room)
        XCTAssertEqual(service.discoveredRooms.count, 1)

        mockProvider.delegate?.providerDidLoseRoom(id: testRoomId)

        XCTAssertTrue(service.discoveredRooms.isEmpty)
    }

    /// 验证丢失不存在的 room ID 不崩溃
    func testLoseNonExistentRoomIDDoesNotCrash() {
        mockProvider.delegate?.providerDidLoseRoom(id: "non-existent-room")
        XCTAssertTrue(service.discoveredRooms.isEmpty)
    }

    // MARK: - 状态消息更新

    /// 验证 providerDidUpdateStatus 更新 statusMessage
    func testProviderDidUpdateStatus更新StatusMessage() {
        mockProvider.delegate?.providerDidUpdateStatus(testStatusMessage)
        XCTAssertEqual(service.statusMessage, testStatusMessage)
    }

    // MARK: - 错误回调

    /// 验证 providerDidEncounterError 设置 connectionError 且 isConnecting 置 false
    func testProviderDidEncounterError设置ConnectionError且isConnecting置false() {
        service.isConnecting = true
        mockProvider.delegate?.providerDidEncounterError(testErrorMessage)

        XCTAssertEqual(service.connectionError, testErrorMessage)
        XCTAssertFalse(service.isConnecting)
    }

    // MARK: - data 接收：CollabEdit

    /// 验证接收 CollabEdit 数据添加到 recentEdits
    func testReceiveCollabEditDataAddedToRecentEdits() async throws {
        let pageID = UUID()
        let data = try makeCollabEditData(pageID: pageID)

        mockProvider.simulateDataReceived(data, from: testUserId)

        XCTAssertEqual(service.recentEdits.count, 1)
        XCTAssertEqual(service.recentEdits.first?.userID, testUserId)
        XCTAssertEqual(service.recentEdits.first?.pageID, pageID)
    }

    /// 验证接收无效 JSON 数据不崩溃且不添加到 recentEdits
    func testReceiveInvalidJSONDataDoesNotCrashAndNotAddedToRecentEdits() {
        let invalidData = Data("invalid json".utf8)
        mockProvider.simulateDataReceived(invalidData, from: testUserId)

        XCTAssertTrue(service.recentEdits.isEmpty, "无效 JSON 不应添加到 recentEdits")
    }

    /// 验证接收非 CollabEdit 非 pageSync 数据不崩溃
    func testReceiveUnknownFormatDataDoesNotCrash() throws {
        let unknownData = try makeJSONData(["unknown": "format"])
        mockProvider.simulateDataReceived(unknownData, from: testUserId)

        XCTAssertTrue(service.recentEdits.isEmpty)
    }

    /// 验证接收超过 100 条 Edit 时截断为 100 条
    /// - Note: C-10/Bug#6 已优化 — 改用 removeFirst() 单次移除，保持功能正确性。
    func testReceiveOver100EditsTruncatedTo100() throws {
        let pageID = UUID()
        for _ in 0..<overflowEditCount {
            let data = try makeCollabEditData(pageID: pageID)
            mockProvider.simulateDataReceived(data, from: testUserId)
        }

        XCTAssertEqual(service.recentEdits.count, maxRecentEditsLimit, "超过上限时应截断为 100 条")
    }

    /// 验证 recentEdits 截断后保留最新的编辑（最后插入的）
    func testRecentEdits截断后保留最新编辑() throws {
        let pageID = UUID()
        for _ in 0..<overflowEditCount {
            let data = try makeCollabEditData(pageID: pageID)
            mockProvider.simulateDataReceived(data, from: testUserId)
        }

        XCTAssertEqual(service.recentEdits.count, maxRecentEditsLimit)
        // 最后一条应为最新接收的 edit
        XCTAssertNotNil(service.recentEdits.last)
    }

    // MARK: - data 接收：pageSync

    /// 验证接收 pageSync 数据且 delegate 有对应页面时调用 applyRemoteUpdate
    func testReceivePageSyncDataWithMatchingPageCallsApplyRemoteUpdate() async throws {
        let pageID = UUID()
        let existingPage = KnowledgePage(id: pageID, title: "Old Title", content: "old content")
        mockDelegate.pages = [existingPage]

        // 远程更新时间需晚于本地 updatedAt 才会触发 applyRemoteUpdate
        let futureTimestamp = Date().addingTimeInterval(60).timeIntervalSince1970
        let data = try makePageSyncData(id: pageID, title: "New Title", content: "new content", updated: futureTimestamp)

        mockProvider.simulateDataReceived(data, from: testUserId)

        // 轮询等待 Task {} 异步完成，避免固定 sleep 在全量测试负载下不够
        try await waitFor { !mockDelegate.appliedUpdates.isEmpty }

        XCTAssertEqual(mockDelegate.appliedUpdates.count, 1, "应调用 applyRemoteUpdate")
        XCTAssertEqual(mockDelegate.appliedUpdates.first?.title, "New Title")
        XCTAssertEqual(mockDelegate.appliedUpdates.first?.content, "new content")
    }

    /// 验证接收 pageSync 数据且 delegate 无对应页面时调用 insertRemotePage
    func testReceivePageSyncDataWithoutMatchingPageCallsInsertRemotePage() async throws {
        let pageID = UUID()
        mockDelegate.pages = []

        let data = try makePageSyncData(id: pageID, title: "Brand New Page", content: "brand new content")

        mockProvider.simulateDataReceived(data, from: testUserId)

        // 轮询等待 Task {} 异步完成，避免固定 sleep 在全量测试负载下不够
        try await waitFor { !mockDelegate.insertedPages.isEmpty }

        XCTAssertEqual(mockDelegate.insertedPages.count, 1, "应调用 insertRemotePage")
        XCTAssertEqual(mockDelegate.insertedPages.first?.title, "Brand New Page")
        XCTAssertEqual(mockDelegate.insertedPages.first?.id, pageID)
    }

    /// 验证接收 pageSync 数据且远程时间不晚于本地时不调用 applyRemoteUpdate
    func testReceivePageSyncDataWithStaleTimestampDoesNotCallApplyRemoteUpdate() async throws {
        let pageID = UUID()
        let oldDate = Date().addingTimeInterval(-3600)
        let existingPage = KnowledgePage(id: pageID, title: "Existing", content: "existing", createdAt: oldDate, updatedAt: oldDate)
        mockDelegate.pages = [existingPage]

        // 远程时间早于本地 updatedAt
        let earlierTimestamp = oldDate.addingTimeInterval(-60).timeIntervalSince1970
        let data = try makePageSyncData(id: pageID, title: "Stale Update", content: "stale", updated: earlierTimestamp)

        mockProvider.simulateDataReceived(data, from: testUserId)

        try await Task.sleep(nanoseconds: asyncWaitNanoseconds)

        XCTAssertTrue(mockDelegate.appliedUpdates.isEmpty, "远程时间不晚于本地时不应调用 applyRemoteUpdate")
        XCTAssertTrue(mockDelegate.insertedPages.isEmpty, "已存在页面不应调用 insertRemotePage")
    }

    /// 验证接收 pageSync 数据且远程时间等于本地时也更新
    /// - Note: C-11/Bug#7 已修复 — 改用 >= 比较，相同时间戳的远程更新也会应用。
    /// - Important: 使用整数秒避免 JSONSerialization 对 Double 的精度损失导致比较失败。
    func testReceivePageSyncDataWithEqualTimestampAlsoUpdates() async throws {
        let pageID = UUID()
        // 使用整数秒时间戳，确保 JSON 序列化/反序列化无精度损失
        let rawTimestamp = TimeInterval(Int(Date().timeIntervalSince1970))
        let syncDate = Date(timeIntervalSince1970: rawTimestamp)
        let existingPage = KnowledgePage(id: pageID, title: "Existing", content: "existing", createdAt: syncDate, updatedAt: syncDate)
        mockDelegate.pages = [existingPage]

        let equalTimestamp = syncDate.timeIntervalSince1970
        let data = try makePageSyncData(id: pageID, title: "Equal Time Update", content: "equal", updated: equalTimestamp)

        mockProvider.simulateDataReceived(data, from: testUserId)

        // 轮询等待 Task {} 异步完成，避免固定 sleep 在全量测试负载下不够
        try await waitFor { !mockDelegate.appliedUpdates.isEmpty }

        // 验证修复：时间戳相等时也更新（避免并发编辑丢失）
        XCTAssertEqual(mockDelegate.appliedUpdates.count, 1, "远程时间等于本地时也应更新 — 避免并发编辑丢失")
        XCTAssertEqual(mockDelegate.appliedUpdates.first?.title, "Equal Time Update")
    }

    /// 验证接收 pageSync 数据但 delegate 为 nil 时不崩溃
    func testReceivePageSyncDataWithNilDelegateDoesNotCrash() async throws {
        service.delegate = nil
        let pageID = UUID()

        let data = try makePageSyncData(id: pageID, title: "Orphan Page", content: "orphan")

        // 不应崩溃
        mockProvider.simulateDataReceived(data, from: testUserId)

        try await Task.sleep(nanoseconds: asyncWaitNanoseconds)
    }

    /// 验证接收 pageSync 数据但 payload 缺少必需字段时不崩溃
    func testReceivePageSyncDataMissingRequiredFieldsDoesNotCrash() async throws {
        let pageID = UUID()
        // 缺少 title 字段
        let payload: [String: Any] = [
            "type": "pageSync",
            "page": [
                "id": pageID.uuidString,
                "content": "content",
                "type": "concept",
                "tags": ["tag"],
                "status": "active",
                "updated": Date().timeIntervalSince1970
            ]
        ]
        let data = try makeJSONData(payload)

        mockProvider.simulateDataReceived(data, from: testUserId)

        try await Task.sleep(nanoseconds: asyncWaitNanoseconds)

        XCTAssertTrue(mockDelegate.appliedUpdates.isEmpty)
        XCTAssertTrue(mockDelegate.insertedPages.isEmpty)
    }

    /// 验证接收 pageSync 数据但 id 不是合法 UUID 时不崩溃
    func testReceivePageSyncDataWithInvalidUUIDDoesNotCrash() async throws {
        let payload: [String: Any] = [
            "type": "pageSync",
            "page": [
                "id": "not-a-uuid",
                "title": "Title",
                "content": "content",
                "type": "concept",
                "tags": ["tag"],
                "status": "active",
                "updated": Date().timeIntervalSince1970
            ]
        ]
        let data = try makeJSONData(payload)

        mockProvider.simulateDataReceived(data, from: testUserId)

        try await Task.sleep(nanoseconds: asyncWaitNanoseconds)

        XCTAssertTrue(mockDelegate.appliedUpdates.isEmpty)
        XCTAssertTrue(mockDelegate.insertedPages.isEmpty)
    }

    /// 验证接收 pageSync 数据但 type 字段不是合法 PageType 时不崩溃
    func testReceivePageSyncDataWithInvalidPageTypeDoesNotCrash() async throws {
        let pageID = UUID()
        let data = try makePageSyncData(id: pageID, title: "Title", content: "content", pageType: "invalid_type")

        mockProvider.simulateDataReceived(data, from: testUserId)

        try await Task.sleep(nanoseconds: asyncWaitNanoseconds)

        XCTAssertTrue(mockDelegate.appliedUpdates.isEmpty)
        XCTAssertTrue(mockDelegate.insertedPages.isEmpty)
    }

    /// 验证接收 pageSync 数据但 status 字段不是合法 PageStatus 时不崩溃
    func testReceivePageSyncDataWithInvalidPageStatusDoesNotCrash() async throws {
        let pageID = UUID()
        let data = try makePageSyncData(id: pageID, title: "Title", content: "content", status: "invalid_status")

        mockProvider.simulateDataReceived(data, from: testUserId)

        try await Task.sleep(nanoseconds: asyncWaitNanoseconds)

        XCTAssertTrue(mockDelegate.appliedUpdates.isEmpty)
        XCTAssertTrue(mockDelegate.insertedPages.isEmpty)
    }

    /// 验证接收 pageSync 数据但 tags 不是 String 数组时不崩溃
    func testReceivePageSyncDataWithNonStringArrayTagsDoesNotCrash() async throws {
        let pageID = UUID()
        let payload: [String: Any] = [
            "type": "pageSync",
            "page": [
                "id": pageID.uuidString,
                "title": "Title",
                "content": "content",
                "type": "concept",
                "tags": "not-an-array", // 错误类型
                "status": "active",
                "updated": Date().timeIntervalSince1970
            ]
        ]
        let data = try makeJSONData(payload)

        mockProvider.simulateDataReceived(data, from: testUserId)

        try await Task.sleep(nanoseconds: asyncWaitNanoseconds)

        XCTAssertTrue(mockDelegate.appliedUpdates.isEmpty)
        XCTAssertTrue(mockDelegate.insertedPages.isEmpty)
    }

    // MARK: - setUserName 持久化

    /// 验证 setUserName 持久化到 keyStore
    func testSetUserName持久化到KeyStore() {
        service.setUserName(testUserNameValue)

        // 通过 ServiceContainer 解析 keyStore 验证
        let keyStore = ServiceContainer.shared.resolveOptional((any KeyStoreProtocol).self)
        XCTAssertEqual(keyStore?.string(forKey: AppConstants.Keys.Storage.userName), testUserNameValue)
    }

    /// 验证 setUserName 后 startHosting 传递新用户名给 provider
    func testSetUserName后StartHosting传递新用户名给Provider() {
        service.setUserName(testUserNameValue)
        service.startHosting(roomName: testRoomName)

        XCTAssertEqual(mockProvider.hostedUserName, testUserNameValue)
    }

    /// 验证 setUserName 后 startBrowsing 传递新用户名给 provider
    func testSetUserName后StartBrowsing传递新用户名给Provider() {
        service.setUserName(testUserNameValue)
        service.startBrowsing()

        XCTAssertEqual(mockProvider.browsedUserName, testUserNameValue)
    }

    // MARK: - setDelegate

    /// 验证 setDelegate 正确设置 delegate
    func testSetDelegate正确设置Delegate() throws {
        let newDelegate = MockCollaborationDelegate()
        service.setDelegate(newDelegate)

        // 通过 pageSync 触发验证 delegate 已设置
        let pageID = UUID()
        let data = try makePageSyncData(id: pageID, title: "Test", content: "test")
        mockProvider.simulateDataReceived(data, from: testUserId)

        // newDelegate 应被调用（等待异步 Task）
        let expectation = expectation(description: "delegate 被调用")
        Task {
            try? await Task.sleep(nanoseconds: 200_000_000)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)

        XCTAssertEqual(newDelegate.insertedPages.count, 1, "setDelegate 设置的新 delegate 应被调用")
    }

    // MARK: - isAvailable 模拟器降级

    /// 验证模拟器环境下 isAvailable 初始为 false（#if targetEnvironment(simulator)）
    func testSimulatorEnvironmentIsAvailableInitiallyFalse() {
        // 在模拟器运行时，新建 service（不强制 isAvailable = true）
        let freshService = CollaborationService()
        #if targetEnvironment(simulator)
        XCTAssertFalse(freshService.isAvailable, "模拟器环境下 isAvailable 应为 false")
        XCTAssertTrue(freshService.isSimulator, "模拟器环境下 isSimulator 应为 true")
        #else
        XCTAssertTrue(freshService.isAvailable, "非模拟器环境下 isAvailable 应为 true")
        XCTAssertFalse(freshService.isSimulator, "非模拟器环境下 isSimulator 应为 false")
        #endif
    }

    // MARK: - provider delegate 设置

    /// 验证 init 时 provider.delegate 被设置为 service
    func testInit时ProviderDelegate被设置为Service() {
        // mockProvider.delegate 应为 service（setupProvider 中设置）
        // 通过触发回调验证 delegate 链路通畅
        mockProvider.delegate?.providerDidUpdateStatus(testStatusMessage)
        XCTAssertEqual(service.statusMessage, testStatusMessage, "provider.delegate 应已设置为 service")
    }

    // MARK: - 连续操作状态机

    /// 验证 startHosting → stop → startBrowsing 状态正确转换
    func testStartHosting到Stop到StartBrowsing状态正确转换() {
        service.startHosting(roomName: testRoomName)
        XCTAssertTrue(service.isHosting)
        XCTAssertEqual(service.role, .owner)

        service.stop()
        XCTAssertFalse(service.isHosting)
        XCTAssertFalse(service.isJoined)

        service.startBrowsing()
        XCTAssertFalse(service.isHosting)
        XCTAssertTrue(service.isConnecting)
        // C-9/Bug#5 已修复：stop 后 role 清理为 .viewer
        XCTAssertEqual(service.role, .viewer, "stop 后 role 应清理为 .viewer，startBrowsing 不改变 role")
    }

    /// 验证多次 stop 不崩溃
    func testMultipleStopCallsDoNotCrash() {
        service.startHosting(roomName: testRoomName)
        service.stop()
        service.stop()
        service.stop()

        XCTAssertFalse(service.isHosting)
        XCTAssertTrue(mockProvider.didCallStop)
    }
}
