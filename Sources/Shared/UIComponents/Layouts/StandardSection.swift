//
//  StandardSection.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：可复用 UI 组件库：编辑器、卡片、加载态、空状态等通用视图。
//
import SwiftUI

/// 标准卡片容器组件
/// 提供带标题和脚注的分组视图，内部内容自动应用玻璃拟态背景。
public struct StandardSection<Content: View>: View {
    // MARK: - Properties
    
    /// 顶部显示的标题文本
    public let title: String?
    /// 底部显示的辅助说明文本
    public let footer: String?
    /// 内容区域的视图闭包
    public let content: Content
    
    // MARK: - Initialization
    
    /// 初始化标准分段组件
    /// - Parameters:
    ///   - title: 可选标题
    ///   - footer: 可选脚注
    ///   - content: 视图内容
    public init(title: String? = nil, footer: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content()
    }
    
    // MARK: - Body
    
    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            // 渲染标题
            if let title = title {
                Group {
                    Text(title)
                }
                .font(Typography.captionFont)
                .foregroundStyle(.appSecondary)
                .padding(.leading, Spacing.medium)
                .textCase(.uppercase)
            }
            
            // 渲染内容区域（带玻璃拟态背景）
            VStack(spacing: 0) {
                content
            }
            .appGlassCardStyle(opacity: SystemOpacity.active, cornerRadius: DesignSystem.cardRadius)
            
            // 渲染脚注
            if let footer = footer {
                Group {
                    Text(footer)
                }
                .font(Typography.caption2Font)
                .foregroundStyle(.appSecondary)
                .padding(.horizontal, Spacing.medium)
            }
        }
        .padding(.horizontal, Spacing.standardPadding)
        .padding(.vertical, Spacing.small)
    }
}

// MARK: - View 扩展

public extension View {
    /// 应用列表行样式
    /// 为视图添加标准的内边距和可选的底部分割线，通常用于 StandardSection 内部。
    /// - Parameter showDivider: 是否显示底部分割线
    /// - Returns: 包装后的视图
    func appListRowStyle(showDivider: Bool = true) -> some View {
        VStack(spacing: 0) {
            self
                .padding(.horizontal, Spacing.medium)
                .padding(.vertical, Spacing.medium)
                .contentShape(Rectangle()) // 确保整行可点击
            
            if showDivider {
                Divider()
                    .padding(.leading, DesignSystem.medium)
                    .opacity(DesignSystem.dividerOpacity)
            }
        }
    }
}
