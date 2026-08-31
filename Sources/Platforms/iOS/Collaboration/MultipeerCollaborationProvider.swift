//
//  MultipeerCollaborationProvider.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 平台适配层
//  核心职责：iOS 平台实现：后台任务、Widget、文件归档、Spotlight 索引。
//
#if canImport(MultipeerConnectivity)
import Foundation
import MultipeerConnectivity

@MainActor
final class MultipeerCollaborationProvider: NSObject, CollaborationProviderProtocol {
    weak var delegate: CollaborationProviderDelegate?
    
    private let serviceType = "km-collab"
    private var myPeerID: MCPeerID?
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    
    private var sessionDelegate: MCSessionDelegateImpl?
    private var advertiserDelegate: MCAdvertiserDelegateImpl?
    private var browserDelegate: MCBrowserDelegateImpl?
    
    /// 启动Hosting
    /// - Parameter roomName: roomName
    /// - Parameter userName: userName
    func startHosting(roomName: String, userName: String) {
        let peerID = MCPeerID(displayName: "\(userName)|\(UUID().uuidString.prefix(8))")
        self.myPeerID = peerID
        
        setupSession(peerID: peerID)
        
        advertiserDelegate = MCAdvertiserDelegateImpl(
            onInvitation: { [weak self] _, _, handler in
                handler(true, self?.session)
            },
            onError: { [weak self] error in
                self?.delegate?.providerDidEncounterError(error.localizedDescription)
            }
        )
        advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: [
            "room": roomName,
            "owner": userName
        ], serviceType: serviceType)
        advertiser?.delegate = advertiserDelegate
        advertiser?.startAdvertisingPeer()
        
        delegate?.providerDidUpdateStatus(L10n.Collaboration.Status.hosting)
    }
    
    /// 启动Browsing
    /// - Parameter userName: userName
    func startBrowsing(userName: String) {
        let peerID = MCPeerID(displayName: "\(userName)|\(UUID().uuidString.prefix(8))")
        self.myPeerID = peerID
        
        setupSession(peerID: peerID)
        
        browserDelegate = MCBrowserDelegateImpl(
            onRoomFound: { [weak self] peerID, info in
                let room = DiscoveredRoom(
                    id: peerID.displayName,
                    platformPeer: peerID,
                    roomName: info?["room"] ?? L10n.Collaboration.defaultRoom,
                    owner: info?["owner"] ?? peerID.displayName
                )
                self?.delegate?.providerDidDiscoverRoom(room)
            },
            onRoomLost: { [weak self] peerID in
                self?.delegate?.providerDidLoseRoom(id: peerID.displayName)
            },
            onError: { [weak self] error in
                self?.delegate?.providerDidEncounterError(error.localizedDescription)
            }
        )
        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        browser?.delegate = browserDelegate
        browser?.startBrowsingForPeers()
        
        delegate?.providerDidUpdateStatus(L10n.Collaboration.Status.searching)
    }
    
    /// 加入Room
    /// - Parameter room: room
    func joinRoom(_ room: DiscoveredRoom) {
        guard let session = session, let browser = browser, let targetPeer = room.platformPeer as? MCPeerID else { return }
        // Bug #53 修复：魔鬼数字 30 抽取为常量
        browser.invitePeer(targetPeer, to: session, withContext: nil, timeout: PlatformConstants.Multipeer.joinTimeoutSeconds)
        delegate?.providerDidUpdateStatus(L10n.Collaboration.Status.joining)
    }
    
    /// 停止
    func stop() {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        browser?.stopBrowsingForPeers()
        browser = nil
        session?.disconnect()
        session = nil
        delegate?.providerDidUpdateStatus(L10n.Collaboration.Status.disconnected)
    }
    
    /// broadcast
    /// - Parameter data: data
    func broadcast(data: Data) {
        // Bug #54 修复：无连接 peer 时记录日志，避免静默返回
        guard let session = session, !session.connectedPeers.isEmpty else {
            Logger.shared.warning("Collaboration_Broadcast_NoConnectedPeers")
            return
        }
        try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
    }
    
    private func setupSession(peerID: MCPeerID) {
        let session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        sessionDelegate = MCSessionDelegateImpl(
            onPeerConnected: { [weak self] peerID in
                // Bug #55 修复：用 split(maxSplits: 1) 替代 components(separatedBy:).first
                // 避免 displayName 含多个 "|" 时丢失信息
                let displayName = peerID.displayName.split(separator: "|", maxSplits: 1).first.map(String.init) ?? peerID.displayName
                let user = CollabUser(id: peerID.displayName, displayName: displayName, deviceName: "", joinedAt: Date())
                self?.delegate?.providerDidConnectPeer(user)
            },
            onPeerDisconnected: { [weak self] peerID in
                self?.delegate?.providerDidDisconnectPeer(id: peerID.displayName)
            },
            onDataReceived: { [weak self] data, peerID in
                self?.delegate?.providerDidReceiveData(data, from: peerID.displayName)
            },
            onStatusChange: { [weak self] state, _ in
                if state == .connecting {
                    self?.delegate?.providerDidUpdateStatus(L10n.Collaboration.Status.connecting)
                }
            }
        )
        session.delegate = sessionDelegate
        self.session = session
    }
}
#endif
