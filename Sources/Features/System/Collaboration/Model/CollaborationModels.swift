//
//  CollaborationModels.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：多人协作：Network Framework 连接、实时同步。
//

import Foundation

// MARK: - Collaboration Models
struct CollabUser: Identifiable, Codable, Hashable {
    let id: String
    let displayName: String
    let deviceName: String
    let joinedAt: Date

    var displayLabel: String { "\(displayName) (\(deviceName))" }
}

struct CollabEdit: Identifiable, Codable {
    let id: String
    let userID: String
    let pageID: UUID
    let field: String
    let oldValue: String
    let newValue: String
    let timestamp: Date
}

enum CollabRole: String, Codable {
    case owner
    case editor
    case viewer

    var displayName: String {
        switch self {
        case .owner: return L10n.Collaboration.role.owner
        case .editor: return L10n.Collaboration.role.editor
        case .viewer: return L10n.Collaboration.role.viewer
        }
    }

    var icon: String {
        switch self {
        case .owner: return "crown.fill"
        case .editor: return "pencil.circle.fill"
        case .viewer: return "eye.fill"
        }
    }
}

// MARK: - Discovered Room Model
struct DiscoveredRoom: Identifiable, Hashable {
    let id: String
    let platformPeer: AnyHashable // 平台相关的 Peer 对象 (如 NWEndpoint)
    let roomName: String
    let owner: String

    /// 判等比较
    static func == (lhs: DiscoveredRoom, rhs: DiscoveredRoom) -> Bool {
        lhs.id == rhs.id
    }

    /// 计算哈希值
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
