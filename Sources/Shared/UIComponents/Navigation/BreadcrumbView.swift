//
//  BreadcrumbView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：构建 Breadcrumb 界面的 UI 视图层组件。
//
import SwiftUI

/// 空间导航面包屑视图
/// 负责在大屏或深度跳转时展示知识页面的层级路径，支持快速回溯及深度跳转后的导航反馈
struct BreadcrumbView: View {
    /// 历史跳转页面列表，用来渲染面包屑的层级节点
    let history: [KnowledgePage]
    /// 导航回调事件，当点击某个面包屑节点时，触发回溯跳转
    let onNavigate: (UUID) -> Void
    /// 返回首页回调事件
    let onGoHome: () -> Void
    
    var body: some View {
        // 挂载 BreadcrumbNavigation 标识符，供 UI 自动化测试全局定位面包屑容器
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.small) {
                // 常驻的“知识库主页”节点，方便深度跳转一键快速返回
                Button(action: {
                    HapticFeedback.shared.trigger(.selection)
                    onGoHome()
                }) {
                    HStack(spacing: DesignSystem.tiny) {
                        Image(systemName: DesignSystem.Icons.booksVerticalFill)
                            .font(.caption2)
                        Text(L10n.Knowledge.Page.knowledge)
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(.appSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("BreadcrumbHome")
                
                if !history.isEmpty {
                    BreadcrumbSeparator()
                }

                ForEach(Array(history.enumerated()), id: \.offset) { index, page in
                    HStack(spacing: DesignSystem.small) {
                        // 每一个面包屑节点按钮挂载 "BreadcrumbItem_\(index)" 唯一标识符，支持 UI 自动化测试精准点击
                        Button(action: { handleNavigate(to: page) }) {
                            HStack(spacing: DesignSystem.tiny) {
                                Image(systemName: page.displayIcon)
                                    .font(.caption2)
                                Text(page.title)
                                    .font(.caption.weight(index == history.count - 1 ? .bold : .medium))
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                            .foregroundStyle(index == history.count - 1 ? .appAccent : .appSecondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("BreadcrumbItem_\(index)")
                        
                        // 如果不是最后一个节点，则渲染面包屑分隔符（通常为向右小箭头）
                        if index < history.count - 1 {
                            Image(systemName: DesignSystem.Icons.forward)
                                .font(.caption2)
                                .foregroundStyle(.appSecondary)
                        }
                    }
                }
            }
            .padding(.horizontal, DesignSystem.standardPadding)
            .padding(.vertical, DesignSystem.small)
        }
        .accessibilityIdentifier("BreadcrumbNavigation")
        .background(Color.appBackground.opacity(DesignSystem.Opacity.prominent))
        .background(.ultraThinMaterial)
    }

    /// 触发面包屑导航节点的点击逻辑，提供单元测试直接调用的入口
    /// - Parameter page: 点击的面包屑节点对应的 KnowledgePage
    func handleNavigate(to page: KnowledgePage) {
        HapticFeedback.shared.trigger(.link)
        onNavigate(page.id)
    }
}
