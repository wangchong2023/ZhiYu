//
//  CollaborationComponents.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：多人协作：Multipeer 连接、实时同步。
//
import SwiftUI

// MARK: - Collab Info Row
/// 协作信息提示行（图标 + 文字），轻量级复用组件。
/// 协作信息提示行组件
/// 负责以紧凑的图标与文本形式展示协作相关的元数据信息
struct CollabInfoRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: DesignSystem.CompositeRow.spacing) { // 10
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.appAccent)
                .frame(width: ComponentSpacing.section) // 20
            Text(text)
                .font(.caption)
                .foregroundStyle(.appText)
        }
    }
}

// MARK: - Discovered Room Row
/// 发现房间列表行。
/// 发现房间列表行组件
/// 负责展示局域网内扫描到的可用协作房间，支持展示房主信息及点击加入交互
struct DiscoveredRoomRow: View {
    let room: DiscoveredRoom
    let onJoin: () -> Void

    var body: some View {
        Button(action: onJoin) {
            HStack {
                Image(systemName: DesignSystem.Icons.collaboration)
                    .foregroundStyle(.appAccent)

                VStack(alignment: .leading) {
                    Text(room.roomName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.appText)
                    Text("\(L10n.Collaboration.hostedBy) \(room.owner)")
                        .font(.caption)
                        .foregroundStyle(.appSecondary)
                }

                Spacer()

                Image(systemName: DesignSystem.Icons.forwardCircle)
                    .foregroundStyle(.appAccent)
            }
            .padding()
            .background(Color.appCard)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.standardRadius))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("collab-discovered-room-\(room.id)")
    }
}

// MARK: - Connected Peer Row
/// 已连接用户行。
/// 已连接用户行组件
/// 负责展示当前会话中已连接的其他成员身份信息、角色及加入时间
struct ConnectedPeerRow: View {
    let peer: CollabUser
    var showRole: Bool = false
    var roleDisplayName: String?

    var body: some View {
        HStack {
            Image(systemName: DesignSystem.Icons.person)
                .foregroundStyle(.appAccent)
            Text(peer.displayName)
                .font(.subheadline)
                .foregroundStyle(.appText)
            Spacer()
            if showRole, let roleName = roleDisplayName {
                Text(roleName)
                    .font(.caption)
                    .foregroundStyle(.appSecondary)
            } else {
                Text(peer.joinedAt, style: .time)
                    .font(.caption)
                    .foregroundStyle(.appSecondary)
            }
        }
        .padding()
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.standardRadius))
        .accessibilityIdentifier("collab-connected-peer-\(peer.id)")
    }
}

// MARK: - Recent Edit Row
/// 最近编辑记录行。
/// 最近编辑记录行组件
/// 负责实时展示会话中发生的原子编辑操作流，增强协同感与操作追溯
struct RecentEditRow: View {
    let edit: CollabEdit

    var body: some View {
        HStack {
            Image(systemName: DesignSystem.Icons.pencilCircle)
                .foregroundStyle(.appConcept)

            VStack(alignment: .leading, spacing: DesignSystem.atomic) { // 2
                Text(edit.userID.components(separatedBy: "|").first ?? edit.userID)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.appText)
                Text("\(edit.field)  \(String(edit.newValue.prefix(DesignSystem.Metrics.maxCollabEditPreviewLength)))") // 50
                    .font(.caption2)
                    .foregroundStyle(.appSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(edit.timestamp, style: .time)
                .font(.caption2)
                .foregroundStyle(.appSecondary)
        }
        .padding()
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.standardRadius))
        .accessibilityIdentifier("collab-edit-row-\(edit.id)")
    }
}

// MARK: - Role Badge
/// 角色徽章（Owner/Editor/Viewer）。
/// 协作角色徽章组件
/// 负责根据用户的协作权限（房主/编辑/查看）展示视觉化的角色标识
struct CollabRoleBadge: View {
    let role: CollabRole
    
    private var color: Color {
        switch role {
        case .owner: return .yellow
        case .editor: return .appAccent
        case .viewer: return .appSecondary
        }
    }
    
    var body: some View {
        Text(role.displayName)
            .font(.caption.weight(.medium))
            .padding(.horizontal, DesignSystem.small) // 8
            .padding(.vertical, DesignSystem.tiny) // 4
            .background(color.opacity(DesignSystem.glassOpacity)) // 0.15
            .clipShape(Capsule())
            .foregroundStyle(color)
    }
}
