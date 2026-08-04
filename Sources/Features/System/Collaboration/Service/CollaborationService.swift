//
//  CollaborationService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：实现 Collaboration 模块的核心业务逻辑服务。
//
import Foundation
import UFPCore
import Combine

/// 协作服务代理协议
@MainActor
protocol CollaborationDelegate: AnyObject {
    var pages: [KnowledgePage] { get }

    /// 应用Remote更新
    /// - Parameter page: page
    func applyRemoteUpdate(_ page: KnowledgePage) async

    /// 插入RemotePage
    /// - Parameter page: page
    func insertRemotePage(_ page: KnowledgePage) async
}

// MARK: - Collaboration Service
/// 实时多用户协作服务（逻辑编排层）
@MainActor
final class CollaborationService: NSObject, ObservableObject, @unchecked Sendable {
    @Published var isAvailable: Bool = false
    @Published var isHosting: Bool = false
    @Published var isJoined: Bool = false
    @Published var connectedPeers: [CollabUser] = []
    @Published var role: CollabRole = .viewer
    @Published var roomName: String = ""
    @Published var recentEdits: [CollabEdit] = []
    @Published var statusMessage: String = ""
    @Published var discoveredRooms: [DiscoveredRoom] = []
    @Published var isSimulator: Bool = false
    @Published var connectionError: String?
    @Published var isConnecting: Bool = false

    /// 注入的协作提供商实现
    @Inject private var provider: any CollaborationProviderProtocol
    @Inject private var appEnv: any AppEnvironmentProtocol
    /// Factory 风格：属性类型标注为可选（T?）， 自动使用 resolveOptional
     @Inject private var keyStore: (any KeyStoreProtocol)?

    /// 数据应用代理
    weak var delegate: CollaborationDelegate?

    private let maxRecentEdits = 100

    private var userName: String {
        keyStore?.string(forKey: AppConstants.Keys.Storage.userName) ?? appEnv.deviceName
    }

    // MARK: - Init
    override init() {
        #if targetEnvironment(simulator)
        isSimulator = true
        #endif
        super.init()
        setupProvider()
        checkAvailability()
    }

    private func setupProvider() {
        provider.delegate = self
    }

    /// setDelegate
    /// - Parameter delegate: delegate
    func setDelegate(_ delegate: CollaborationDelegate) {
        self.delegate = delegate
    }

    // MARK: - Availability
    private func checkAvailability() {
        #if targetEnvironment(simulator)
        isAvailable = false
        statusMessage = L10n.Collaboration.Status.simulatorNotSupported
        #else
        isAvailable = true
        statusMessage = L10n.Collaboration.Status.ready
        #endif
    }

    // MARK: - API
    /// 启动Hosting
    /// - Parameter roomName: roomName
    func startHosting(roomName: String) {
        guard isAvailable else { return }
        self.roomName = roomName
        self.role = .owner
        connectionError = nil
        isConnecting = true
        provider.startHosting(roomName: roomName, userName: userName)
        isHosting = true
        isJoined = true
    }

    /// 启动Browsing
    func startBrowsing() {
        guard isAvailable else { return }
        connectionError = nil
        isConnecting = true
        provider.startBrowsing(userName: userName)
    }

    /// 加入Room
    /// - Parameter room: room
    func joinRoom(_ room: DiscoveredRoom) {
        guard isAvailable else { return }
        self.role = .editor
        isConnecting = true
        provider.joinRoom(room)
    }

    /// 停止
    func stop() {
        provider.stop()
        isHosting = false
        isJoined = false
        isConnecting = false
        connectedPeers.removeAll()
        discoveredRooms.removeAll()
        recentEdits.removeAll()
        connectionError = nil
    }

    // MARK: - Data Transmission
    /// broadcastEdit
    /// - Parameter pageID: pageID
    /// - Parameter field: field
    /// - Parameter oldValue: oldValue
    /// - Parameter newValue: newValue
    func broadcastEdit(pageID: UUID, field: String, oldValue: String, newValue: String) {
        guard isJoined, role != .viewer else { return }

        let edit = CollabEdit(
            id: UUID().uuidString,
            userID: userName, // 简化标识
            pageID: pageID,
            field: field,
            oldValue: oldValue,
            newValue: newValue,
            timestamp: Date()
        )
        appendEdit(edit)
        if let data = try? JSONEncoder().encode(edit) {
            provider.broadcast(data: data)
        }
    }

    /// broadcastPage
    /// - Parameter page: page
    func broadcastPage(_ page: KnowledgePage) {
        guard isJoined, role != .viewer else { return }

        let payload: [String: Any] = [
            "type": "pageSync",
            "page": [
                "id": page.id.uuidString,
                "title": page.title,
                "content": page.content,
                "type": page.pageType.rawValue,
                "tags": page.tags,
                "status": page.status.rawValue,
                "updated": page.updatedAt.timeIntervalSince1970
            ]
        ]

        if let data = try? JSONSerialization.data(withJSONObject: payload) {
            provider.broadcast(data: data)
        }
    }

    /// setUserName
    /// - Parameter name: name
    func setUserName(_ name: String) {
        keyStore?.set(name, forKey: AppConstants.Keys.Storage.userName)
    }

    private func appendEdit(_ edit: CollabEdit) {
        recentEdits.append(edit)
        if recentEdits.count > maxRecentEdits {
            recentEdits.removeFirst(recentEdits.count - maxRecentEdits)
        }
    }
}

// MARK: - CollaborationProviderDelegate
extension CollaborationService: CollaborationProviderDelegate {

    /// providerDid更新Status
    /// - Parameter message: message
    func providerDidUpdateStatus(_ message: String) {
        self.statusMessage = message
    }
    
    /// providerDidDiscoverRoom
    /// - Parameter room: room
    func providerDidDiscoverRoom(_ room: DiscoveredRoom) {
        if !discoveredRooms.contains(where: { $0.id == room.id }) {
            discoveredRooms.append(room)
        }
    }
    
    /// providerDidLoseRoom
    /// - Parameter id: id
    func providerDidLoseRoom(id: String) {
        discoveredRooms.removeAll { $0.id == id }
    }
    
    /// providerDid连接Peer
    /// - Parameter user: user
    func providerDidConnectPeer(_ user: CollabUser) {
        isConnecting = false
        if !connectedPeers.contains(where: { $0.id == user.id }) {
            connectedPeers.append(user)
        }
        isJoined = true
    }
    
    /// providerDid断开Peer
    /// - Parameter id: id
    func providerDidDisconnectPeer(id: String) {
        connectedPeers.removeAll { $0.id == id }
        if connectedPeers.isEmpty && !isHosting {
            isJoined = false
        }
    }
    
    /// providerDid接收Data
    /// - Parameter data: data
    func providerDidReceiveData(_ data: Data, from userID: String) {
        // Try to decode as CollabEdit
        if let edit = try? JSONDecoder().decode(CollabEdit.self, from: data) {
            appendEdit(edit)
            return
        }
        
        // Try to decode as page sync
        if let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           payload["type"] as? String == "pageSync",
           let pageData = payload["page"] as? [String: Any] {
            applyRemotePage(pageData)
            return
        }
    }
    
    /// providerDidEncounterError
    /// - Parameter error: error
    func providerDidEncounterError(_ error: String) {
        self.connectionError = error
        self.isConnecting = false
    }
}

// MARK: - Remote Page Sync
extension CollaborationService {
    private func applyRemotePage(_ pageData: [String: Any]) {
        guard let idString = pageData["id"] as? String,
              let pageID = UUID(uuidString: idString),
              let title = pageData["title"] as? String,
              let content = pageData["content"] as? String,
              let typeRaw = pageData["type"] as? String,
              let pageType = PageType(rawValue: typeRaw),
              let tags = pageData["tags"] as? [String],
              let statusRaw = pageData["status"] as? String,
              let status = PageStatus(rawValue: statusRaw),
              let updatedTs = pageData["updated"] as? TimeInterval
        else { return }

        let remoteUpdated = Date(timeIntervalSince1970: updatedTs)
        guard let delegate = self.delegate else { return }

        if let existingPage = delegate.pages.first(where: { $0.id == pageID }) {
            if remoteUpdated > existingPage.updatedAt {
                var updated = existingPage
                updated.title = title
                updated.content = content
                updated.pageType = pageType
                updated.tags = tags
                updated.status = status
                updated.updatedAt = remoteUpdated
                Task {
                    await delegate.applyRemoteUpdate(updated)
                    self.statusMessage = L10n.Collaboration.Status.pageReceived
                }
            }
        } else {
            let newPage = KnowledgePage(
                id: pageID, title: title, pageType: pageType, content: content, aliases: [], tags: tags,
                status: status, confidence: .medium, sources: [], relatedPageIDs: [], isPinned: false,
                contentHash: nil, createdAt: remoteUpdated, updatedAt: remoteUpdated
            )
            Task {
                await delegate.insertRemotePage(newPage)
                self.statusMessage = L10n.Collaboration.Status.pageReceived
            }
        }
    }
}
