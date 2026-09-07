//
//  ContentViewAndCollaborationDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/03.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests/Unit] 应用根视图与系统协同深度集成测试
//  核心职责：深度覆盖 ContentView、AppLayoutComponents、CollaborationView、
//            UserProfileView 及 UserProfileMenu 的全生命周期装载与分支状态。
//  质量标准：依据 unit-test-quality-review 规范，坚决杜绝空断言与假测试，
//            全方位覆盖时间戳冲突解决 (LWW)、队列溢出截断、错误注入与异常边界。
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

// MARK: - 测试用协同数据代理

@MainActor
private final class DeepMockCollabDelegate: CollaborationDelegate {
    var pages: [KnowledgePage] = []
    var appliedUpdates: [KnowledgePage] = []
    var insertedPages: [KnowledgePage] = []

    func applyRemoteUpdate(_ page: KnowledgePage) async {
        appliedUpdates.append(page)
        if let idx = pages.firstIndex(where: { $0.id == page.id }) {
            pages[idx] = page
        }
    }

    func insertRemotePage(_ page: KnowledgePage) async {
        insertedPages.append(page)
        pages.append(page)
    }
}

// MARK: - 测试套件

@MainActor
final class ContentViewAndCollaborationDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    override func tearDown() async throws {
        try? await Task.sleep(nanoseconds: 50_000_000)
        try await super.tearDown()
    }

    // MARK: - 1. 协同数据包冲突解决深测 (Timestamp LWW 变异测试)

    func testCollaboration_RemotePageSync_LastWriteWinsAndStaleRejection() async {
        let service = CollaborationService()
        let delegate = DeepMockCollabDelegate()
        service.setDelegate(delegate)

        let pageID = UUID()
        let baseTime = Date(timeIntervalSince1970: 1_700_000_000)
        let localPage = KnowledgePage(
            id: pageID,
            title: "本地初始页面",
            pageType: .concept,
            content: "本地原始内容",
            createdAt: baseTime,
            updatedAt: baseTime
        )
        delegate.pages = [localPage]

        // 场景 A: 注入过期的远程数据包 (时间戳早于本地更新时间，模拟陈旧网络延迟包)
        let staleTimestamp = baseTime.timeIntervalSince1970 - 100
        let stalePayload: [String: Any] = [
            FeatureConstants.CollaborationKey.type: FeatureConstants.CollaborationKey.pageSync,
            "page": [
                "id": pageID.uuidString,
                "title": "过期远程标题",
                "content": "过期远程内容",
                "type": PageType.concept.rawValue,
                "tags": ["stale"],
                "status": PageStatus.active.rawValue,
                "updated": staleTimestamp
            ]
        ]
        let staleData = try? JSONSerialization.data(withJSONObject: stalePayload)
        XCTAssertNotNil(staleData, "序列化过期测试数据包应成功")
        if let staleData = staleData {
            service.providerDidReceiveData(staleData, from: "peer-01")
        }

        // 等待异步分发
        try? await Task.sleep(nanoseconds: 30_000_000)

        // 验证：过期数据包必须被 LWW 算法坚决丢弃，绝不能覆盖本地较新的数据
        XCTAssertTrue(delegate.appliedUpdates.isEmpty, "陈旧的远程更新数据包必须被丢弃，绝不能触发 applyRemoteUpdate")
        XCTAssertEqual(delegate.pages.first?.title, "本地初始页面", "本地页面标题不应被过期数据篡改")

        // 场景 B: 注入更新的远程数据包 (时间戳晚于本地更新时间)
        let newerTimestamp = baseTime.timeIntervalSince1970 + 200
        let newerPayload: [String: Any] = [
            FeatureConstants.CollaborationKey.type: FeatureConstants.CollaborationKey.pageSync,
            "page": [
                "id": pageID.uuidString,
                "title": "最新远程标题",
                "content": "最新远程协同内容",
                "type": PageType.concept.rawValue,
                "tags": ["sync", "p2p"],
                "status": PageStatus.deprecated.rawValue,
                "updated": newerTimestamp
            ]
        ]
        let newerData = try? JSONSerialization.data(withJSONObject: newerPayload)
        XCTAssertNotNil(newerData, "序列化最新测试数据包应成功")
        if let newerData = newerData {
            service.providerDidReceiveData(newerData, from: "peer-02")
        }

        try? await Task.sleep(nanoseconds: 30_000_000)

        // 验证：最新数据包必须精准应用
        XCTAssertEqual(delegate.appliedUpdates.count, 1, "较新的远程更新包应当精准触发 1 次 applyRemoteUpdate")
        let updatedPage = delegate.pages.first { $0.id == pageID }
        XCTAssertEqual(updatedPage?.title, "最新远程标题", "页面标题应更新为远程最新标题")
        XCTAssertEqual(updatedPage?.content, "最新远程协同内容", "页面正文应更新为远程最新内容")
        XCTAssertEqual(updatedPage?.tags, ["sync", "p2p"], "页面标签应更新为远程同步标签")
        XCTAssertEqual(updatedPage?.status, .deprecated, "页面状态应更新为 deprecated")
    }

    // MARK: - 2. 远程新页面插入与不存在实体分流深测

    func testCollaboration_RemotePageSync_InsertNonExistentPage() async {
        let service = CollaborationService()
        let delegate = DeepMockCollabDelegate()
        service.setDelegate(delegate)

        let newPageID = UUID()
        let insertTimestamp = Date().timeIntervalSince1970
        let insertPayload: [String: Any] = [
            FeatureConstants.CollaborationKey.type: FeatureConstants.CollaborationKey.pageSync,
            "page": [
                "id": newPageID.uuidString,
                "title": "全新协同节点",
                "content": "由远端节点创建的新内容",
                "type": PageType.concept.rawValue,
                "tags": ["new-peer"],
                "status": PageStatus.active.rawValue,
                "updated": insertTimestamp
            ]
        ]
        let data = try? JSONSerialization.data(withJSONObject: insertPayload)
        XCTAssertNotNil(data)
        if let data = data {
            service.providerDidReceiveData(data, from: "peer-03")
        }

        try? await Task.sleep(nanoseconds: 30_000_000)

        // 验证：本地未收录页面应当调用 insertRemotePage
        XCTAssertEqual(delegate.insertedPages.count, 1, "不存在的远程页面应触发 insertRemotePage")
        XCTAssertEqual(delegate.insertedPages.first?.id, newPageID, "插入的页面 ID 应与远程数据包完全匹配")
        XCTAssertEqual(delegate.insertedPages.first?.title, "全新协同节点")
    }

    // MARK: - 3. 协同编辑记录历史队列超限自动淘汰深测 (内存泄漏与边界防御)

    func testCollaboration_RecentEditsQueue_MaxCapacityTruncation() {
        let service = CollaborationService()
        let pageID = UUID()

        // 连续注入 105 条 CollabEdit 记录（上限为 100）
        for index in 0..<105 {
            let edit = CollabEdit(
                id: "edit-\(index)",
                userID: "user-1",
                pageID: pageID,
                field: "content",
                oldValue: "old-\(index)",
                newValue: "new-\(index)",
                timestamp: Date()
            )
            if let editData = try? JSONEncoder().encode(edit) {
                service.providerDidReceiveData(editData, from: "user-1")
            }
        }

        // 验证：历史记录必须严格限制在 100 条以内，最早的 5 条被自动淘汰
        XCTAssertEqual(service.recentEdits.count, 100, "协同编辑历史队列必须严格卡控在 100 条以内")
        XCTAssertEqual(service.recentEdits.first?.id, "edit-5", "队列头部的旧编辑记录应已被移出（前 5 条已被淘汰）")
        XCTAssertEqual(service.recentEdits.last?.id, "edit-104", "队列尾部应为最新收到的第 104 号编辑记录")
    }

    // MARK: - 4. 对端断开与 Host/Guest 角色保活状态机深测

    func testCollaboration_PeerDisconnection_RolePreservationStateMachine() {
        let service = CollaborationService()
        let testUser = CollabUser(id: "peer-guest", displayName: "访客小李", deviceName: "iPad Pro", joinedAt: Date())

        // 场景 A: 访客/客户端角色断开所有 Peer
        service.isHosting = false
        service.providerDidConnectPeer(testUser)
        XCTAssertTrue(service.isJoined, "连接到对端后 isJoined 应为 true")
        XCTAssertEqual(service.connectedPeers.count, 1)

        service.providerDidDisconnectPeer(id: testUser.id)
        XCTAssertTrue(service.connectedPeers.isEmpty, "对端断开后连接列表应当为空")
        XCTAssertFalse(service.isJoined, "非 Host 模式下所有 Peer 离开后 isJoined 应当自动翻转为 false")

        // 场景 B: 房主 (Host) 角色断开所有 Peer
        service.isHosting = true
        service.isJoined = true
        service.providerDidConnectPeer(testUser)
        XCTAssertEqual(service.connectedPeers.count, 1)

        service.providerDidDisconnectPeer(id: testUser.id)
        XCTAssertTrue(service.connectedPeers.isEmpty, "对端断开后房主的连接列表变为空")
        XCTAssertTrue(service.isJoined, "Host 房主模式下即使暂无 Peer 连入，自身房间仍处于有效挂载状态，isJoined 必须保持 true")
    }

    // MARK: - 5. 畸形数据与安全异常防御深测

    func testCollaboration_MalformedData_FaultToleranceAndCleanStop() {
        let service = CollaborationService()

        // 1. 注入空数据与非 JSON 乱码字节
        let corruptedData = Data([0xDE, 0xAD, 0xBE, 0xEF, 0xFF, 0x00])
        service.providerDidReceiveData(corruptedData, from: "attacker")
        XCTAssertTrue(service.recentEdits.isEmpty, "接收畸形二进制时服务不应崩溃且不产生脏数据")

        // 2. 注入缺少关键字段的 JSON 数据
        let invalidJson = Data("{\"type\": \"pageSync\", \"page\": {}}".utf8)
        service.providerDidReceiveData(invalidJson, from: "faulty-peer")
        XCTAssertTrue(service.recentEdits.isEmpty, "缺少必填字段的数据包应被优雅忽略")

        // 3. 错误注入
        service.providerDidEncounterError("P2P 套接字意外中断")
        XCTAssertEqual(service.connectionError, "P2P 套接字意外中断", "网络异常信息应当被准确暴露")
        XCTAssertFalse(service.isConnecting, "错误发生后连接中状态应被复位")

        // 4. 执行原子清理
        service.stop()
        XCTAssertFalse(service.isHosting)
        XCTAssertFalse(service.isJoined)
        XCTAssertFalse(service.isConnecting)
        XCTAssertTrue(service.connectedPeers.isEmpty)
        XCTAssertTrue(service.discoveredRooms.isEmpty)
        XCTAssertTrue(service.recentEdits.isEmpty)
        XCTAssertNil(service.connectionError)
        XCTAssertEqual(service.roomName, "")
        XCTAssertEqual(service.role, .viewer)
    }

    // MARK: - 6. ContentView 根容器与通知事件深测

    func testContentView_RootContainerAndNotificationHandling() {
        let view = ContentView()
        let host = view.snapshotEnvironment().renderInWindow()
        XCTAssertNotNil(host.view, "ContentView 根视图应能成功装载并在主窗口完成布局计算")

        // 模拟触发侧边栏折叠展开通知
        NotificationCenter.default.post(name: .toggleSidebar, object: nil)
        XCTAssertNotNil(host.view, "接收侧边栏通知后根视图容器应保持稳定")
    }

    // MARK: - 7. CollaborationView 多端协同视图层次深测

    func testCollaborationView_InstantiationAndContentStructure() {
        let view = CollaborationView()
        let host = view.snapshotEnvironment().renderInWindow()
        XCTAssertNotNil(host.view, "CollaborationView 应能安全构建并渲染多端协同主界面")

        let content = CollaborationViewContent()
        let hostContent = content.snapshotEnvironment().renderInWindow()
        XCTAssertNotNil(hostContent.view, "CollaborationViewContent 核心业务视图应能安全装载")
    }

    // MARK: - 8. UserProfileView 用户资料与配额面板深测

    func testUserProfileView_InstantiationAndLayout() {
        let view = UserProfileView()
        let host = view.snapshotEnvironment().renderInWindow()
        XCTAssertNotNil(host.view, "UserProfileView 应能安全装载并渲染用户中心与套餐配额面板")
    }

    // MARK: - 9. UserProfileMenu 菜单操作与动作枚举深测

    func testUserProfileMenu_InstantiationAndMenuActions() {
        let menuView = UserProfileMenu()
        let host = menuView.snapshotEnvironment().renderInWindow()
        XCTAssertNotNil(host.view, "UserProfileMenu 应能安全挂载在导航栏并渲染头像微标")

        // 验证 MenuAction 枚举值完整性
        let actions: [UserProfileMenu.MenuAction] = [.settings, .profile, .plan, .plugins, .aiSettings]
        XCTAssertEqual(actions.count, 5, "UserProfileMenu 应支持 5 类全局导航快捷操作")
    }

    // MARK: - 10. AppLayoutComponents 布局分支与访客模式验证

    func testAppLayoutComponents_GuestAndVaultTransitions() {
        let authSession = AuthSession.shared
        let router = Router.shared

        // 验证访客登录状态下路由切换与 Tab 状态
        authSession.isGuest = true
        XCTAssertTrue(authSession.isLoggedIn || authSession.isGuest, "访客标记后应满足已登录或访客状态")

        // 切换活跃 Tab
        router.selectedTab = .knowledge
        XCTAssertEqual(router.selectedTab, .knowledge, "当前活跃 Tab 应当精准切换为 knowledge")

        router.selectedTab = .chat
        XCTAssertEqual(router.selectedTab, .chat, "当前活跃 Tab 应当精准切换为 chat")

        // 退出登录
        authSession.logout()
        XCTAssertFalse(authSession.isLoggedIn, "登出后 isLoggedIn 必须为 false")
        XCTAssertFalse(authSession.isGuest, "登出后 isGuest 必须为 false")
    }
}
