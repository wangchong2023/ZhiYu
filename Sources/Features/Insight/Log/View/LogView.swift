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
import UFPDesignSystem

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
        DesignTokens.ComponentSpacing.ultra
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
                Label(L10n.Common.Misc.clear, systemImage: DesignTokens.Icons.trashSlash)
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
        VStack(spacing: DesignTokens.Spacing.medium) {
            Image(systemName: DesignTokens.Icons.history)
                .font(.system(size: DesignSystem.Timeline.emptyIconSize))
                .foregroundStyle(.appSecondary)
            Text(L10n.Log.noLogs)
                .font(.subheadline)
                .foregroundStyle(.appSecondary)
            Text(L10n.Log.noLogsHint)
                .font(.caption)
                .foregroundStyle(.appSecondary.opacity(DesignTokens.Colors.Opacity.secondaryOpacity))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, emptyPadding)
    }

    @ViewBuilder
    private var logListRows: some View {
        ForEach(store.logEntries) { entry in
            Button(action: {
                withAnimation(.easeInOut(duration: DesignTokens.Animation.standardDuration)) {
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
        DesignTokens.SystemSpacing.small
    }
    private var modFontSize: CGFloat {
        DesignTokens.Typography.microFontSize - DesignTokens.SystemStroke.divider
    }
    private var modVerticalPadding: CGFloat {
        DesignTokens.SystemStroke.divider
    }
    private var modCornerRadius: CGFloat {
        DesignTokens.Spacing.microRadius - DesignTokens.SystemStroke.divider
    }
    private var statusFontSize: CGFloat {
        DesignTokens.Typography.caption2FontSize - DesignTokens.SystemStroke.divider
    }
    private var statusHorizontalPadding: CGFloat {
        DesignTokens.SystemSpacing.small
    }
    private var actionBgOpacity: Double {
        DesignTokens.SystemOpacity.faint
    }
    private var statusBgOpacity: Double {
        DesignTokens.Colors.Opacity.glassOpacity
    }
    private var detailBgOpacity: Double {
        DesignTokens.SystemOpacity.disabled
    }
    private var failureBgOpacity: Double {
        DesignTokens.SystemOpacity.ghost
    }
    private var failureTextOpacity: Double {
        DesignTokens.Colors.Opacity.secondaryOpacity
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
            HStack(spacing: DesignTokens.Spacing.medium) {
                actionIcon
                
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.atomic) {
                    mainHeaderRow
                    timeAndDurationRow
                }

                Image(systemName: isExpanded ? DesignTokens.Icons.up : DesignTokens.Icons.down)
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
                .font(.system(size: DesignTokens.Typography.subheadlineFontSize, weight: .bold))
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
                    .padding(.horizontal, DesignTokens.Spacing.tiny)
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
                    .padding(.vertical, DesignTokens.Spacing.atomic)
                    .background(statusBackgroundColor)
                    .foregroundStyle(statusForegroundColor)
                    .clipShape(Capsule())
            }
        }
    }

    @ViewBuilder
    private var timeAndDurationRow: some View {
        HStack(spacing: DesignTokens.Spacing.tightPadding) {
            Text(timeRangeString)
            
            if let dur = entry.duration {
                Text(DesignTokens.Icons.bullet)
                Text(dur.formattedAdaptive)
                    .foregroundStyle(.appAccent)
            }
        }
        .font(.caption2)
        .foregroundStyle(.appSecondary)
    }

    @ViewBuilder
    private var expandedDetailsView: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
            HStack(spacing: DesignTokens.Spacing.wide) {
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
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Spacing.smallRadius))

            if let reason = entry.failureReason {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.tiny) {
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
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Spacing.standardRadius))
            }

            if !entry.details.isEmpty {
                Text(entry.details)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.appSecondary)
                    .cardStyle(
                        horizontalPadding: DesignSystem.Timeline.detailHorizontalPadding,
                        verticalPadding: DesignSystem.Timeline.detailHorizontalPadding,
                        backgroundOpacity: DesignTokens.Opacity.solid,
                        cornerRadius: DesignTokens.Spacing.standardRadius
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.leading, DesignSystem.Timeline.indentPadding)
        .padding(.top, DesignTokens.Spacing.tiny)
    }
}
