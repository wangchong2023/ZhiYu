//
//  ActivityRow.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：知识摄入：文档导入、URL 抓取、OCR 扫描、PDF 解析。
//
import SwiftUI
import UFPDesignSystem

struct ActivityRow: View {
    let task: GlobalTask
    @Environment(Router.self) var router
    var body: some View {
        Button(action: { if let id = task.associatedPageID { HapticFeedback.shared.trigger(.selection); router.navigateToPage(id: id) } }) {
            HStack(spacing: DesignTokens.Spacing.medium) {
                ZStack {
                    Circle().fill(taskColor.opacity(DesignTokens.SystemOpacity.glass)).frame(width: DesignTokens.ComponentSpacing.huge, height: DesignTokens.ComponentSpacing.huge)
                    Image(systemName: taskIcon).font(.system(size: DesignTokens.Typography.subheadlineFontSize)).foregroundStyle(taskColor)
                }
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.atomic) {
                    Text(displayTitle).font(.system(size: DesignTokens.Typography.subheadlineFontSize, weight: .medium)).foregroundStyle(.appText).lineLimit(1)
                    Text(task.startTime.formatted(Date.FormatStyle(locale: Localized.currentLocale))).font(.system(size: DesignTokens.Typography.captionFontSize)).foregroundStyle(.appSecondary)
                }
                Spacer()
                if task.associatedPageID != nil { Image(systemName: DesignTokens.Icons.forward).font(.system(size: DesignTokens.Typography.captionFontSize, weight: .bold)).foregroundStyle(.appSecondary.opacity(DesignTokens.Colors.Opacity.disabledOpacity)) }
            }.padding(.vertical, DesignTokens.SystemSpacing.elementLarge).padding(.horizontal, DesignTokens.Spacing.medium)
        }.buttonStyle(.plain)
    }
    private var taskColor: Color {
        switch task.status {
        case .completed: return Color.theme.green
        case .failed: return Color.theme.red
        case .running: return Color.theme.blue
        case .pending: return Color.theme.gray
        }
    }
    
    /// 拼接任务名称与目标，空值时避免显示孤立的 ": "
    private var displayTitle: String {
        let name = task.name
        let target = task.target
        if name.isEmpty { return target }
        if target.isEmpty { return name }
        return "\(name): \(target)"
    }
    private var taskIcon: String {
        switch task.status {
        case .completed: return DesignTokens.Icons.checkCircle
        case .failed: return DesignTokens.Icons.errorCircle
        case .running: return DesignTokens.Icons.refresh
        case .pending: return DesignTokens.Icons.clock
        }
    }
}
