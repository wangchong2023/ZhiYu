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

struct ActivityRow: View {
    let task: GlobalTask
    @Environment(Router.self) var router
    var body: some View {
        Button(action: { if let id = task.associatedPageID { HapticFeedback.shared.trigger(.selection); router.navigateToPage(id: id) } }) {
            HStack(spacing: DesignSystem.medium) {
                ZStack {
                    Circle().fill(taskColor.opacity(SystemOpacity.glass)).frame(width: ComponentSpacing.huge, height: ComponentSpacing.huge)
                    Image(systemName: taskIcon).font(.system(size: DesignSystem.subheadlineFontSize)).foregroundStyle(taskColor)
                }
                VStack(alignment: .leading, spacing: DesignSystem.atomic) {
                    Text(task.name + ": " + task.target).font(.system(size: DesignSystem.subheadlineFontSize, weight: .medium)).foregroundStyle(.appText).lineLimit(1)
                    Text(task.startTime.formatted(Date.FormatStyle(locale: Localized.currentLocale))).font(.system(size: DesignSystem.captionFontSize)).foregroundStyle(.appSecondary)
                }
                Spacer()
                if task.associatedPageID != nil { Image(systemName: DesignSystem.Icons.forward).font(.system(size: DesignSystem.captionFontSize, weight: .bold)).foregroundStyle(.appSecondary.opacity(DesignSystem.disabledOpacity)) }
            }.padding(.vertical, SystemSpacing.elementLarge).padding(.horizontal, DesignSystem.medium)
        }.buttonStyle(.plain)
    }
    private var taskColor: Color {
        switch task.status {
        case .completed: return .green
        case .failed: return .red
        case .running: return .blue
        case .pending: return .gray
        }
    }
    private var taskIcon: String {
        switch task.status {
        case .completed: return DesignSystem.Icons.checkCircle
        case .failed: return DesignSystem.Icons.errorCircle
        case .running: return DesignSystem.Icons.refresh
        case .pending: return DesignSystem.Icons.clock
        }
    }
}
