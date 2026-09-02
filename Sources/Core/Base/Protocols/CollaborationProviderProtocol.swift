//
//  CollaborationProviderProtocol.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 底层基座层
//  核心职责：定义 CollaborationProvider 模块的抽象契约接口。
//
import Foundation
import Combine

/// 协作服务提供商的代理协议，用于向业务层反向通知连接状态、网络发现及数据传输事件。
@MainActor
protocol CollaborationProviderDelegate: AnyObject {
    /// 通知状态发生变更。
    ///
    /// - Parameter message: 状态描述信息。
    func providerDidUpdateStatus(_ message: String)
    
    /// 发现网络中可用的协作房间。
    ///
    /// - Parameter room: 发现的房间实体。
    func providerDidDiscoverRoom(_ room: DiscoveredRoom)
    
    /// 原已发现的协作房间在网络中消失。
    ///
    /// - Parameter id: 丢失的房间唯一标识符。
    func providerDidLoseRoom(id: String)
    
    /// 新用户连接接入成功。
    ///
    /// - Parameter user: 新接入的用户信息模型。
    func providerDidConnectPeer(_ user: CollabUser)
    
    /// 用户断开连接。
    ///
    /// - Parameter id: 断开连接的用户唯一标识符。
    func providerDidDisconnectPeer(id: String)
    
    /// 接收到来自指定用户的同步载荷数据。
    ///
    /// - Parameters:
    ///   - data: 接收到的二进制同步载荷。
    ///   - userID: 发送方的用户唯一标识。
    func providerDidReceiveData(_ data: Data, from userID: String)
    
    /// 协作通信网络中遇到了可恢复或不可恢复的底层通信错误。
    ///
    /// - Parameter error: 错误详情信息。
    func providerDidEncounterError(_ error: String)
}

/// 跨平台局域网协作网络通信服务提供商抽象协议。
@MainActor
protocol CollaborationProviderProtocol: AnyObject {
    /// 获取或设置反向通知事件的代理实例。
    var delegate: CollaborationProviderDelegate? { get set }
    
    /// 开启服务，作为房主（Host）向本地局域网进行广播并等待对等端接入。
    ///
    /// - Parameters:
    ///   - roomName: 协作房间名称，由房主设定。
    ///   - userName: 房主在协作网络中展示的别名。
    func startHosting(roomName: String, userName: String)
    
    /// 开启局域网服务发现，搜索并浏览当前网络中可用的协作房间。
    ///
    /// - Parameter userName: 当前搜索者在协作网络中展示的别名。
    func startBrowsing(userName: String)
    
    /// 加入到指定发现的协作房间并建立握手连接。
    ///
    /// - Parameter room: 目标被发现的房间实体。
    func joinRoom(_ room: DiscoveredRoom)
    
    /// 停止所有的局域网广播、搜索监听及所有活跃的对等端连接，物理断开协作会话。
    func stop()
    
    /// 向当前会话中所有已建立连接的协作对等端广播发送同步数据包。
    ///
    /// - Parameter data: 待广播发送的二进制载荷数据。
    func broadcast(data: Data)
}

// MARK: - DependencyKey 注册

import Dependencies
import UFPCore

/// CollaborationProviderProtocol 的 DependencyKey（P7 迁移：过渡期 liveValue 从 ServiceContainer 解析）
enum CollaborationProviderKey: DependencyKey {
    static var liveValue: any CollaborationProviderProtocol {
        ServiceContainer.shared.resolve((any CollaborationProviderProtocol).self)
    }

    @MainActor
    static var testValue: any CollaborationProviderProtocol {
        ServiceContainer.shared.resolveOptional((any CollaborationProviderProtocol).self) ?? NoOpCollaborationProvider()
    }
    @MainActor
    static var previewValue: any CollaborationProviderProtocol { testValue }
}

/// 无操作协作服务（测试/预览占位，DI 未就绪时降级）
@MainActor
final class NoOpCollaborationProvider: CollaborationProviderProtocol, @unchecked Sendable {
    var delegate: CollaborationProviderDelegate?
    init() {}
    func startHosting(roomName: String, userName: String) {}
    func startBrowsing(userName: String) {}
    func joinRoom(_ room: DiscoveredRoom) {}
    func stop() {}
    func broadcast(data: Data) {}
}

extension DependencyValues {
    /// 协作提供商依赖
    var collaborationProvider: any CollaborationProviderProtocol {
        get { self[CollaborationProviderKey.self] }
        set { self[CollaborationProviderKey.self] = newValue }
    }
}
