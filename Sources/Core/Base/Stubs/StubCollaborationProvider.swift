//
//  StubCollaborationProvider.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 底层基座层
//  核心职责：平台不支持功能的安全桩实现，遵循协议提供空操作或未实现提示。
//
import Foundation

final class StubCollaborationProvider: CollaborationProviderProtocol {
    weak var delegate: CollaborationProviderDelegate?

    /// 统一通知 delegate 当前平台不支持
    private func notifyUnsupported() {
        delegate?.providerDidUpdateStatus(L10n.Collaboration.Status.simulatorNotSupported)
    }

    /// 启动Hosting
    /// - Parameter roomName: roomName
    /// - Parameter userName: userName
    func startHosting(roomName: String, userName: String) {
        notifyUnsupported()
    }

    /// 启动Browsing
    /// - Parameter userName: userName
    func startBrowsing(userName: String) {
        notifyUnsupported()
    }
    
    /// 加入Room
    /// - Parameter room: room
    func joinRoom(_ room: DiscoveredRoom) {}
    
    /// 停止
    func stop() {
        delegate?.providerDidUpdateStatus(L10n.Collaboration.Status.disconnected)
    }
    
    /// broadcast
    /// - Parameter data: data
    func broadcast(data: Data) {}
}
