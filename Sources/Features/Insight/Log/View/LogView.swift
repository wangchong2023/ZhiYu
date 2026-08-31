//
//  LogView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：构建 Log 界面的 UI 视图层组件。
//
import SwiftUI

// MARK: - 导航入口
/// 操作日志主视图容器
/// 负责为日志内容提供独立的导航堆栈，支持在设置页或侧边栏中嵌入
struct LogView: View {
    var body: some View {
        LogViewContent()
    }
}

// MARK: - 视图核心
/// 操作日志核心内容列表视图
/// 负责从存储引擎加载日志条目，处理清空逻辑，并管理条目的展开/折叠状态
struct LogViewContent: View {
    @Environment(AppStore.self) var store
    @Environment(ThemeManager.self) var themeManager
    @State private var expandedEntryIDs: Set<UUID> = []
    @State private var showConfirmation = false

    private var emptyPadding: CGFloat {
        ComponentSpacing.ultra
    }

    var body: some View {
        List {
            if store.logEntries.isEmpty {
                emptyStateView
                    .appListRowBackground()
            } else {
                logListRows
                    .appListRowBackground()
            }
        }
        .adaptiveListStyle()
        .scrollContentBackground(.hidden)
        .background(themeManager.pageBackground())
        .appSubPageToolbar(title: L10n.Settings.operationLog) {
            Button(role: .destructive) {
                showConfirmation = true
            } label: {
                Label(L10n.Common.Misc.clear, systemImage: DesignSystem.Icons.trashSlash)
            }
        }
        .confirmationDialog(
            L10n.Log.clearConfirmTitle,
            isPresented: $showConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.Common.Misc.clearAll, role: .destructive) {
                HapticFeedback.shared.trigger(.warning)
                Task { await store.clearLogs() }
            }
            Button(L10n.Common.cancel, role: .cancel) {}
        } message: {
            Text(L10n.Settings.clearAll.message)
        }
        .scrollContentBackground(.hidden)
        .background(PageBackgroundView(accentColor: .appAccent))
    }

    // MARK: - 子视图提取

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: DesignSystem.medium) {
            Image(systemName: DesignSystem.Icons.history)
                .font(.system(size: DesignSystem.Timeline.emptyIconSize))
                .foregroundStyle(.appSecondary)
            Text(L10n.Log.noLogs)
                .font(.subheadline)
                .foregroundStyle(.appSecondary)
            Text(L10n.Log.noLogsHint)
                .font(.caption)
                .foregroundStyle(.appSecondary.opacity(DesignSystem.secondaryOpacity))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, emptyPadding)
    }

    @ViewBuilder
    private var logListRows: some View {
        ForEach(store.logEntries) { entry in
            Button(action: {
                withAnimation(.easeInOut(duration: DesignSystem.Animation.standardDuration)) {
                    if expandedEntryIDs.contains(entry.id) {
                        expandedEntryIDs.remove(entry.id)
                    } else {
                        expandedEntryIDs.insert(entry.id)
                    }
                }
            }) {
                LogEntryRow(
                    entry: entry,
                    isExpanded: expandedEntryIDs.contains(entry.id)
                )
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - 日志项渲染
/// 日志条目行渲染组件
/// 负责展示单条日志的动词、目标对象、模块、时间戳，并在展开时显示耗时详情与原始元数据
private struct LogEntryRow: View {
    let entry: LogEntry
    let isExpanded: Bool

    // 提前计算复杂的布局常量，避免在 View 渲染中进行繁重的算术运算导致编译器超时
    private var vspacing: CGFloat {
        SystemSpacing.small
    }
    private var modFontSize: CGFloat {
        DesignSystem.microFontSize - SystemStroke.divider
    }
    private var modVerticalPadding: CGFloat {
        SystemStroke.divider
    }
    private var modCornerRadius: CGFloat {
        DesignSystem.microRadius - SystemStroke.divider
    }
    private var statusFontSize: CGFloat {
        DesignSystem.caption2FontSize - SystemStroke.divider
    }
    private var statusHorizontalPadding: CGFloat {
        SystemSpacing.small
    }
    private var actionBgOpacity: Double {
        SystemOpacity.faint
    }
    private var statusBgOpacity: Double {
        DesignSystem.glassOpacity
    }
    private var detailBgOpacity: Double {
        SystemOpacity.disabled
    }
    private var failureBgOpacity: Double {
        SystemOpacity.ghost
    }
    private var failureTextOpacity: Double {
        DesignSystem.secondaryOpacity
    }

    private var statusBackgroundColor: Color {
        guard let status = entry.status else { return .clear }
        return status == .success ? Color.theme.green.opacity(statusBgOpacity) : Color.theme.red.opacity(statusBgOpacity)
    }
    private var statusForegroundColor: Color {
        guard let status = entry.status else { return .clear }
        return status == .success ? Color.theme.green : Color.theme.red
    }
    private var startFormattedString: String {
        entry.startTime?.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: Localized.currentLocale)) ?? ""
    }
    private var endFormattedString: String {
        entry.endTime?.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: Localized.currentLocale)) ?? ""
    }
    private var timeRangeString: String {
        if entry.startTime != nil && entry.endTime != nil {
            return "\(startFormattedString) - \(endFormattedString)"
        } else {
            return entry.timestamp.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened, locale: Localized.currentLocale))
        }
    }
    private var detailStartString: String {
        entry.startTime?.formatted(Date.FormatStyle(date: .omitted, time: .standard, locale: Localized.currentLocale)) ?? ""
    }
    private var detailEndString: String {
        entry.endTime?.formatted(Date.FormatStyle(date: .omitted, time: .standard, locale: Localized.currentLocale)) ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: vspacing) {
            HStack(spacing: DesignSystem.medium) {
                actionIcon
                
                VStack(alignment: .leading, spacing: DesignSystem.atomic) {
                    mainHeaderRow
                    timeAndDurationRow
                }

                Image(systemName: isExpanded ? DesignSystem.Icons.up : DesignSystem.Icons.down)
                    .font(.caption2)
                    .foregroundStyle(.appSecondary)
            }

            if isExpanded {
                expandedDetailsView
            }
        }
        .padding(.vertical, DesignSystem.Timeline.rowVerticalPadding)
    }

    // MARK: - 子视图组件拆分

    @ViewBuilder
    private var actionIcon: some View {
        ZStack {
            Circle()
                .fill(Color.fromModelColorName(entry.action.colorName).opacity(actionBgOpacity))
                .frame(width: DesignSystem.Timeline.iconCircleSize, height: DesignSystem.Timeline.iconCircleSize)
            
            Image(systemName: entry.action.icon)
                .foregroundStyle(Color.fromModelColorName(entry.action.colorName))
                .font(.system(size: DesignSystem.subheadlineFontSize, weight: .bold))
        }
    }

    @ViewBuilder
    private var mainHeaderRow: some View {
        HStack {
            Text(entry.action.localizedName)
                .font(.headline)
                .foregroundStyle(Color.fromModelColorName(entry.action.colorName))
            
            Text(entry.target)
                .font(.headline)
                .foregroundStyle(.appText)
                .lineLimit(1)
            
            if let mod = entry.module {
                Text(mod)
                    .font(.system(size: modFontSize, weight: .bold))
                    .padding(.horizontal, DesignSystem.tiny)
                    .padding(.vertical, modVerticalPadding)
                    .background(Color.appSecondary.opacity(statusBgOpacity))
                    .clipShape(RoundedRectangle(cornerRadius: modCornerRadius))
                    .foregroundStyle(.appSecondary)
            }
            
            Spacer()
            
            if let status = entry.status {
                Text(status.localizedName)
                    .font(.system(size: statusFontSize, weight: .bold))
                    .padding(.horizontal, statusHorizontalPadding)
                    .padding(.vertical, DesignSystem.atomic)
                    .background(statusBackgroundColor)
                    .foregroundStyle(statusForegroundColor)
                    .clipShape(Capsule())
            }
        }
    }

    @ViewBuilder
    private var timeAndDurationRow: some View {
        HStack(spacing: DesignSystem.tightPadding) {
            Text(timeRangeString)
            
            if let dur = entry.duration {
                Text(DesignSystem.Icons.bullet)
                Text(dur.formattedAdaptive)
                    .foregroundStyle(.appAccent)
            }
        }
        .font(.caption2)
        .foregroundStyle(.appSecondary)
    }

    @ViewBuilder
    private var expandedDetailsView: some View {
        VStack(alignment: .leading, spacing: DesignSystem.medium) {
            HStack(spacing: DesignSystem.wide) {
                if entry.startTime != nil {
                    VStack(alignment: .leading) {
                        Text(L10n.Log.startTime)
                            .font(.caption2)
                            .foregroundStyle(.appSecondary)
                        Text(detailStartString)
                            .font(.system(.caption2, design: .monospaced))
                    }
                }
                
                if entry.endTime != nil {
                    VStack(alignment: .leading) {
                        Text(L10n.Log.endTime)
                            .font(.caption2)
                            .foregroundStyle(.appSecondary)
                        Text(detailEndString)
                            .font(.system(.caption2, design: .monospaced))
                    }
                }
                
                if let dur = entry.duration {
                    VStack(alignment: .leading) {
                        Text(L10n.Log.duration)
                            .font(.caption2)
                            .foregroundStyle(.appSecondary)
                        Text(dur.formattedAdaptive)
                            .font(.system(.caption2, design: .monospaced).bold())
                            .foregroundStyle(.appAccent)
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Timeline.detailHorizontalPadding)
            .padding(.vertical, DesignSystem.Timeline.detailVerticalPadding)
            .background(Color.appCard.opacity(detailBgOpacity))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.smallRadius))

            if let reason = entry.failureReason {
                VStack(alignment: .leading, spacing: DesignSystem.tiny) {
                    Text(L10n.Log.failureReason)
                        .font(.caption2.bold())
                        .foregroundStyle(Color.theme.red)
                    Text(reason)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Color.theme.red.opacity(failureTextOpacity))
                }
                .padding(DesignSystem.Timeline.detailHorizontalPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.theme.red.opacity(failureBgOpacity))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.standardRadius))
            }

            if !entry.details.isEmpty {
                Text(entry.details)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.appSecondary)
                    .padding(DesignSystem.Timeline.detailHorizontalPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.appCard)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.standardRadius))
            }
        }
        .padding(.leading, DesignSystem.Timeline.indentPadding)
        .padding(.top, DesignSystem.tiny)
    }
}
