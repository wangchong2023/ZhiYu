//
//  InsightTagInteractions.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/14.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：Insight 模块标签交互辅助，统一 CircularTagBubbleView 与 TagCapsuleView 中重复的
//  标签选中切换逻辑、HapticFeedback 触发与右键管理上下文菜单（重命名/删除）。
//

import SwiftUI

/// [L3] 表现层：标签交互辅助
///
/// 将标签的"编辑模式批量选择 / 普通模式单选切换"逻辑与 HapticFeedback 触发封装为静态方法，
/// 消除 CircularTagBubbleView 与 TagCapsuleView 中完全相同的 Button action 闭包。
enum InsightTagInteractions {

    /// 切换标签选中状态
    /// - Parameters:
    ///   - tag: 标签名称
    ///   - coordinator: 标签云协调器
    static func toggleSelection(tag: String, coordinator: TagCloudCoordinator) {
        withAnimation(DesignSystem.Animation.prominent) {
            if coordinator.isEditMode {
                if coordinator.selectedTagsForBulk.contains(tag) {
                    coordinator.selectedTagsForBulk.remove(tag)
                } else {
                    coordinator.selectedTagsForBulk.insert(tag)
                }
            } else {
                coordinator.selectedTag = coordinator.selectedTag == tag ? nil : tag
            }
        }
        HapticFeedback.shared.trigger(.selection)
    }
}

/// [L3] 表现层：标签管理上下文菜单
///
/// 统一 CircularTagBubbleView 与 TagCapsuleView 中重复的右键菜单（重命名/删除），
/// 仅在非编辑模式下展示。
struct TagManagementContextMenu: ViewModifier {
    let tag: String
    let coordinator: TagCloudCoordinator

    func body(content: Content) -> some View {
        content.contextMenu {
            if !coordinator.isEditMode {
                Button(action: {
                    coordinator.tagToRename = tag
                    coordinator.newTagName = tag
                }) {
                    Label(L10n.Common.rename, systemImage: DesignSystem.Icons.edit)
                }
                Button(role: .destructive, action: {
                    coordinator.tagToDelete = tag
                    coordinator.showDeleteConfirm = true
                }) {
                    Label(L10n.Common.delete, systemImage: DesignSystem.Icons.delete)
                }
            }
        }
    }
}

extension View {
    /// 应用标签管理上下文菜单（重命名/删除），仅在非编辑模式下展示
    func tagManagementContextMenu(tag: String, coordinator: TagCloudCoordinator) -> some View {
        modifier(TagManagementContextMenu(tag: tag, coordinator: coordinator))
    }
}
