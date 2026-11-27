//
//  MultipeerCollaborationProvider.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 平台适配层
//  核心职责：iOS 平台协作服务实现，基于 Network Framework (NWBrowser/NWListener/NWConnection)。
//

import Foundation
import Network
import UFPCore

@MainActor
final class MultipeerCollaborationProvider: CollaborationProviderProtocol {
    weak var delegate: CollaborationProviderDelegate?

    private let serviceType = PlatformConstants.NetworkCollaboration.serviceType
    private var myPeerID: String?
    private var listener: NWListener?
    private var browser: NWBrowser?
    private var connections: [NWConnection] = []
    private var pendingJoinConnection: NWConnection?

    /// 构造带唯一后缀的 PeerID（`userName|uuid前8位`）
    private func makePeerID(userName: String) -> String {
        let suffix = String(UUID().uuidString.prefix(PlatformConstants.NetworkCollaboration.peerIDSuffixLength))
        return "\(userName)\(PlatformConstants.NetworkCollaboration.peerIDSeparator)\(suffix)"
    }

    /// 当前已就绪的活跃连接数（供状态校验与单测验证）
    internal var activeConnectionCount: Int {
        connections.count
    }

    /// 从 PeerID 提取展示名（去除后缀分隔符）
    internal static func parseDisplayName(from peerID: String) -> String {
        peerID.split(separator: PlatformConstants.NetworkCollaboration.peerIDSeparator, maxSplits: 1).first.map(String.init) ?? peerID
    }

    /// 构造 P2P TCP 参数（消除 startHosting / startBrowsing 重复的 NWParameters 配置）
    private func makePeerToPeerParameters() -> NWParameters {
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true
        return parameters
    }

    /// 启动Hosting
    /// - Parameter roomName: roomName
    /// - Parameter userName: userName
    func startHosting(roomName: String, userName: String) {
        listener?.cancel()
        listener = nil
        let peerID = makePeerID(userName: userName)
        self.myPeerID = peerID

        let parameters = makePeerToPeerParameters()

        do {
            let listener = try NWListener(using: parameters, on: .any)
            listener.service = NWListener.Service(
                name: peerID,
                type: "_\(serviceType)._tcp",
                domain: nil,
                txtRecord: NWTXTRecord([
                    PlatformConstants.NetworkCollaboration.txtRoomKey: roomName,
                    PlatformConstants.NetworkCollaboration.txtOwnerKey: userName
                ])
            )
            listener.newConnectionHandler = { [weak self] connection in
                runOnMainSync {
                    self?.handleNewConnection(connection)
                }
            }
            listener.start(queue: .main)
            self.listener = listener
        } catch {
            delegate?.providerDidEncounterError(error.localizedDescription)
            return
        }

        delegate?.providerDidUpdateStatus(L10n.Collaboration.Status.hosting)
    }

    /// 启动Browsing
    /// - Parameter userName: userName
    func startBrowsing(userName: String) {
        browser?.cancel()
        browser = nil
        let peerID = makePeerID(userName: userName)
        self.myPeerID = peerID

        let parameters = makePeerToPeerParameters()

        let descriptor = NWBrowser.Descriptor.bonjourWithTXTRecord(
            type: "_\(serviceType)._tcp",
            domain: nil
        )
        let browser = NWBrowser(for: descriptor, using: parameters)
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            runOnMainSync {
                self?.handleBrowseResults(results)
            }
        }
        browser.stateUpdateHandler = { [weak self] state in
            runOnMainSync {
                self?.handleBrowserStateChange(state)
            }
        }
        browser.start(queue: .main)
        self.browser = browser

        delegate?.providerDidUpdateStatus(L10n.Collaboration.Status.searching)
    }

    /// 加入Room
    /// - Parameter room: room
    func joinRoom(_ room: DiscoveredRoom) {
        guard let endpoint = room.platformPeer as? NWEndpoint else { return }
        pendingJoinConnection?.cancel()
        pendingJoinConnection = nil
        let roomID = room.id

        let parameters = makePeerToPeerParameters()

        let connection = NWConnection(to: endpoint, using: parameters)
        connection.stateUpdateHandler = { [weak self] state in
            runOnMainSync {
                self?.handleConnectionStateChange(connection, state: state, roomID: roomID)
            }
        }
        connection.start(queue: .main)
        self.pendingJoinConnection = connection

        delegate?.providerDidUpdateStatus(L10n.Collaboration.Status.joining)
    }

    /// 停止
    func stop() {
        listener?.cancel()
        listener = nil
        browser?.cancel()
        browser = nil
        connections.forEach { $0.cancel() }
        connections.removeAll()
        pendingJoinConnection?.cancel()
        pendingJoinConnection = nil
        delegate?.providerDidUpdateStatus(L10n.Collaboration.Status.disconnected)
    }

    /// broadcast
    /// - Parameter data: data
    func broadcast(data: Data) {
        guard !connections.isEmpty else {
            Logger.shared.warning("Collaboration_Broadcast_NoConnectedPeers")
            return
        }
        for connection in connections {
            connection.send(content: data, completion: .contentProcessed { [weak self] error in
                if let error {
                    runOnMainSync {
                        self?.delegate?.providerDidEncounterError(error.localizedDescription)
                    }
                }
            })
        }
    }

    // MARK: - Private Handlers

    /// 幂等移除断开的连接并在确曾活跃时通知 delegate 一次，防止僵尸连接泄漏与重复断连通知
    internal func removeConnectionIfPresent(_ connection: NWConnection, peerID: String) {
        guard let index = connections.firstIndex(where: { $0 === connection }) else { return }
        connections.remove(at: index)
        if !peerID.isEmpty {
            delegate?.providerDidDisconnectPeer(id: peerID)
        }
    }

    private func handleNewConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { [weak self] state in
            runOnMainSync {
                self?.handleIncomingConnectionState(connection, state: state)
            }
        }
        connection.start(queue: .main)
    }

    internal func handleIncomingConnectionState(_ connection: NWConnection, state: NWConnection.State) {
        switch state {
        case .ready:
            if !connections.contains(where: { $0 === connection }) {
                connections.append(connection)
            }
            let peerID = extractPeerID(from: connection.endpoint) ?? UUID().uuidString
            notifyPeerConnected(peerID: peerID, connection: connection)
        case .failed, .cancelled:
            let peerID = extractPeerID(from: connection.endpoint) ?? ""
            removeConnectionIfPresent(connection, peerID: peerID)
        default:
            break
        }
    }

    internal func handleConnectionStateChange(_ connection: NWConnection, state: NWConnection.State, roomID: String) {
        switch state {
        case .ready:
            if !connections.contains(where: { $0 === connection }) {
                connections.append(connection)
            }
            pendingJoinConnection = nil
            notifyPeerConnected(peerID: roomID, connection: connection)
        case .failed:
            pendingJoinConnection = nil
            removeConnectionIfPresent(connection, peerID: roomID)
            delegate?.providerDidEncounterError(L10n.Collaboration.Status.disconnected)
        case .cancelled:
            pendingJoinConnection = nil
            removeConnectionIfPresent(connection, peerID: roomID)
        default:
            if state == .preparing {
                delegate?.providerDidUpdateStatus(L10n.Collaboration.Status.connecting)
            }
        }
    }

    private func handleBrowseResults(_ results: Set<NWBrowser.Result>) {
        for result in results {
            switch result.metadata {
            case .bonjour(let record):
                let roomName = record[PlatformConstants.NetworkCollaboration.txtRoomKey] ?? L10n.Collaboration.defaultRoom
                let owner = record[PlatformConstants.NetworkCollaboration.txtOwnerKey] ?? PlatformConstants.NetworkCollaboration.unknownOwner
                let endpoint = result.endpoint
                let id = extractPeerID(from: endpoint) ?? UUID().uuidString
                let room = DiscoveredRoom(
                    id: id,
                    platformPeer: endpoint,
                    roomName: roomName,
                    owner: owner
                )
                delegate?.providerDidDiscoverRoom(room)
            default:
                break
            }
        }
    }

    private func handleBrowserStateChange(_ state: NWBrowser.State) {
        switch state {
        case .failed(let error):
            delegate?.providerDidEncounterError(error.localizedDescription)
        default:
            break
        }
    }

    private func receiveData(from connection: NWConnection) {
        connection.receive(
            minimumIncompleteLength: PlatformConstants.NetworkCollaboration.minReceiveLength,
            maximumLength: PlatformConstants.NetworkCollaboration.maxReceiveLength
        ) { [weak self] data, _, isComplete, error in
            runOnMainSync {
                if let data, !data.isEmpty {
                    let peerID = self?.extractPeerID(from: connection.endpoint) ?? ""
                    self?.delegate?.providerDidReceiveData(data, from: peerID)
                }
                if let error {
                    self?.delegate?.providerDidEncounterError(error.localizedDescription)
                }
                if !isComplete && error == nil {
                    self?.receiveData(from: connection)
                }
            }
        }
    }

    /// 从 NWEndpoint 提取 PeerID（Bonjour 服务名格式）
    private func extractPeerID(from endpoint: NWEndpoint) -> String? {
        switch endpoint {
        case .service(let name, _, _, _):
            return name
        default:
            return nil
        }
    }

    /// 通知 delegate 新 peer 已连接，并开始接收数据（消除 handleIncomingConnectionState / handleConnectionStateChange 重复）
    private func notifyPeerConnected(peerID: String, connection: NWConnection) {
        let displayName = Self.parseDisplayName(from: peerID)
        let user = CollabUser(id: peerID, displayName: displayName, deviceName: "", joinedAt: Date())
        delegate?.providerDidConnectPeer(user)
        receiveData(from: connection)
    }
}
