//
//  PageRowView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：构建 PageRow 界面的 UI 视图层组件。
//
import SwiftUI

/// 知识库页面行视图组件
/// 展示页面图标、标题、类型、更新时间及状态指示器。
struct PageRowView: View {
    // MARK: - Properties
    
    let page: KnowledgePage
    var compact: Bool = false
    
    // MARK: - Initialization
    
    init(page: KnowledgePage, compact: Bool = false) {
        self.page = page
        self.compact = compact
    }
    
    // MARK: - Body
    
    public var body: some View {
        HStack(spacing: Spacing.medium) {
            // 类型图标容器
            Image(systemName: page.displayIcon)
                .font(.body)
                .foregroundStyle(Color.fromModelColorName(page.pageType.colorName))
                .frame(width: Spacing.largeIconSize, height: Spacing.largeIconSize) // 32
                .background(Color.fromModelColorName(page.pageType.colorName).opacity(Colors.glassOpacity * 1.5))
                .clipShape(RoundedRectangle(cornerRadius: Spacing.smallRadius))
            
            VStack(alignment: .leading, spacing: Spacing.atomic * 1.5) { // 3
                // 页面标题
                Text(page.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.appText)
                    .lineLimit(1)
                
                // 紧凑模式下隐藏辅助信息
                if !compact {
                    HStack(spacing: Spacing.small) {
                        // 页面类型标签
                        Text(page.pageType.displayName)
                            .font(.caption2)
                            .padding(.horizontal, DesignSystem.Chip.horizontalPadding)
                            .padding(.vertical, DesignSystem.Chip.verticalPadding)
                            .background(Color.fromModelColorName(page.pageType.colorName).opacity(Colors.glassOpacity * 2))
                            .clipShape(Capsule())
                            .foregroundStyle(Color.fromModelColorName(page.pageType.colorName))
                        
                        // 更新时间
                        Text(page.updatedAt.formatted(Date.FormatStyle(date: .numeric, time: .omitted, locale: Localized.currentLocale)))
                            .font(.caption2)
                            .foregroundStyle(.appSecondary)
                        
                        // 标签预览
                        if !page.tags.isEmpty {
                            Text(page.tags.prefix(2).joined(separator: ", "))
                                .font(.caption2)
                                .foregroundStyle(.appSecondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            
            Spacer()
            
            // 导航箭头（标准 chevron 替代绿点，语义更清晰）
            Image(systemName: DesignSystem.Icons.forward)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.appSecondary.opacity(DesignSystem.Opacity.disabled))
        }
        .padding(.horizontal, DesignSystem.small)
        .padding(.vertical, DesignSystem.small)
        .appCardClip(cornerRadius: Spacing.smallRadius, backgroundOpacity: DesignSystem.Opacity.prominent)
        .contentShape(Rectangle()) // 确保整行可点击
    }
}
