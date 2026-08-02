//
//  TaskCenterView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：构建 TaskCenter 界面的 UI 视图层组件。
//
import SwiftUI

// MARK: - 任务中心入口
/// 任务中心主视图
/// 负责全局异步任务（如 AI 扫描、文档导入、知识合成）的队列监控、状态管理与历史追溯
struct TaskCenterView: View {
    @ObservedObject var taskCenter = TaskCenter.shared
    @Environment(AppStore.self) var store
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(Router.self) var router
    @State private var showClearConfirm = false
    // 跟踪当前选中的过滤任务类型，为 nil 时展示全部分类
    @State private var selectedFilterType: TaskType?
    
    var body: some View {
        Group {
            if taskCenter.tasks.isEmpty {
                ScrollView {
                    VStack(spacing: DesignSystem.loosePadding) {
                        statusDashboard
                            .padding(.horizontal, DesignSystem.Task.dashboardPadding)
                        emptyState
                            .padding(.top, DesignSystem.loosePadding)
                    }
                    // 追加底部安全间距，确保在小屏或带底部 TabBar 的机型上，描述文字可以完全滚上来
                    .padding(.bottom, DesignSystem.huge)
                }
            } else {
                List {
                    Section {
                        statusDashboard
                            .padding(.vertical, DesignSystem.tightPadding)
                    } header: {
                        Text(L10n.AI.Task.categories)
                            .font(.subheadline.bold())
                            .foregroundStyle(.appText)
                    }
                    
                    Section {
                        // 根据选中的过滤条件筛选展示的 Section 分类
                        ForEach(TaskType.allCases.filter { selectedFilterType == nil || $0 == selectedFilterType }, id: \.self) { type in
                            let metrics = taskCenter.metrics(for: type)
                            let tasks = taskCenter.tasks.filter { $0.type == type }
                            
                            #if os(watchOS)
                            Section {
                                if tasks.isEmpty {
                                    Text(L10n.AI.Task.noHistory)
                                        .font(.caption)
                                        .foregroundStyle(.appSecondary)
                                        .padding(.vertical, DesignSystem.tightPadding)
                                } else {
                                    ForEach(tasks.sorted(by: { $0.startTime > $1.startTime })) { task in
                                        TaskRow(task: task)
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                taskCenter.markAsRead(task.id)
                                                if let pageID = task.associatedPageID {
                                                    router.navigateToPage(id: pageID)
                                                }
                                            }
                                    }
                                    .onDelete { indices in
                                        let sortedTasks = tasks.sorted(by: { $0.startTime > $1.startTime })
                                        indices.forEach { index in
                                            taskCenter.removeTask(sortedTasks[index].id)
                                        }
                                    }
                                }
                            } header: {
                                HStack(spacing: DesignSystem.medium) {
                                    ZStack {
                                        Circle()
                                            .fill(taskColor(for: type).opacity(DesignSystem.glassOpacity / 3))
                                            .frame(width: DesignSystem.Task.badgeSize, height: DesignSystem.Task.badgeSize)
                                        Image(systemName: type.icon)
                                            .font(.system(size: DesignSystem.Action.smallIconSize, weight: .bold))
                                            .foregroundStyle(taskColor(for: type))
                                    }
                                    
                                    VStack(alignment: .leading, spacing: DesignSystem.atomic) {
                                        Text(type.localizedName)
                                            .font(.subheadline.bold())
                                        Text(L10n.AI.Task.historyCount(metrics.total))
                                            .font(.caption2)
                                            .foregroundStyle(.appSecondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if metrics.running > 0 {
                                        HStack(spacing: DesignSystem.tiny) {
                                            ProgressView()
                                                .controlSize(.small)
                                            Text("\(metrics.running)")
                                                .font(.system(size: DesignSystem.Metrics.dashboardLabelSize, weight: .bold, design: .rounded))
                                                .foregroundStyle(taskColor(for: type))
                                        }
                                        .padding(.horizontal, DesignSystem.tightPadding)
                                        .padding(.vertical, DesignSystem.tiny)
                                        .background(taskColor(for: type).opacity(DesignSystem.glassOpacity / 3))
                                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.smallRadius))
                                    }
                                }
                                .padding(.vertical, DesignSystem.tiny)
                            }
                            #else
                            DisclosureGroup {
                                if tasks.isEmpty {
                                    Text(L10n.AI.Task.noHistory)
                                        .font(.caption)
                                        .foregroundStyle(.appSecondary)
                                        .padding(.vertical, DesignSystem.tightPadding)
                                } else {
                                    ForEach(tasks.sorted(by: { $0.startTime > $1.startTime })) { task in
                                        TaskRow(task: task)
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                taskCenter.markAsRead(task.id)
                                                if let pageID = task.associatedPageID {
                                                    router.navigateToPage(id: pageID)
                                                }
                                            }
                                    }
                                    .onDelete { indices in
                                        let sortedTasks = tasks.sorted(by: { $0.startTime > $1.startTime })
                                        indices.forEach { index in
                                            taskCenter.removeTask(sortedTasks[index].id)
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: DesignSystem.medium) {
                                    ZStack {
                                        Circle()
                                            .fill(taskColor(for: type).opacity(DesignSystem.glassOpacity / 3))
                                            .frame(width: DesignSystem.Task.badgeSize, height: DesignSystem.Task.badgeSize)
                                        Image(systemName: type.icon)
                                            .font(.system(size: DesignSystem.Action.smallIconSize, weight: .bold))
                                            .foregroundStyle(taskColor(for: type))
                                    }
                                    
                                    VStack(alignment: .leading, spacing: DesignSystem.atomic) {
                                        Text(type.localizedName)
                                            .font(.subheadline.bold())
                                        Text(L10n.AI.Task.historyCount(metrics.total))
                                            .font(.caption2)
                                            .foregroundStyle(.appSecondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if metrics.running > 0 {
                                        HStack(spacing: DesignSystem.tiny) {
                                            ProgressView()
                                                .controlSize(.small)
                                            Text("\(metrics.running)")
                                                .font(.system(size: DesignSystem.Metrics.dashboardLabelSize, weight: .bold, design: .rounded))
                                                .foregroundStyle(taskColor(for: type))
                                        }
                                        .padding(.horizontal, DesignSystem.tightPadding)
                                        .padding(.vertical, DesignSystem.tiny)
                                        .background(taskColor(for: type).opacity(DesignSystem.glassOpacity / 3))
                                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.smallRadius))
                                    }
                                }
                                .padding(.vertical, DesignSystem.tiny)
                            }
                            #endif
                        }
                    } header: {
                        Text(L10n.AI.Task.listTitle)
                            .font(.subheadline.bold())
                            .foregroundStyle(.appText)
                            .textCase(nil)
                    }
                }
                #if !os(watchOS)
                .listStyle(.insetGrouped)
                #endif
            }
        }
        .appSubPageToolbar(title: L10n.AI.Task.centerTitle)
        .scrollContentBackground(.hidden)
        .background(PageBackgroundView(accentColor: .appAccent))
        .onAppear {
            taskCenter.markAllAsRead()
        }
        .confirmationDialog(
            L10n.AI.Task.clearConfirmTitle,
            isPresented: $showClearConfirm,
            titleVisibility: .visible
        ) {
            Button(L10n.Common.Misc.clearAll, role: .destructive) {
                taskCenter.reset()
                HapticFeedback.shared.trigger(.success)
            }
            Button(L10n.Common.cancel, role: .cancel) {}
        } message: {
            Text(L10n.AI.Task.clearConfirmMessage)
        }
    }
    
    // MARK: - Status Dashboard
    private var statusDashboard: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: DesignSystem.Task.dashboardSpacing), GridItem(.flexible(), spacing: DesignSystem.Task.dashboardSpacing)], spacing: DesignSystem.Task.dashboardSpacing) {
            summaryCard(type: .ingest, color: .blue)
            summaryCard(type: .healthCheck, color: .red)
            summaryCard(type: .aiScan, color: .orange)
            summaryCard(type: .synthesis, color: .purple)
        }
    }
    
    private func taskColor(for type: TaskType) -> Color {
        type.uiColor
    }
    
    private func summaryCard(type: TaskType, color: Color) -> some View {
        let metrics = taskCenter.metrics(for: type)
        let runningCount = metrics.running
        let isSelected = selectedFilterType == type
        let isAnySelected = selectedFilterType != nil
        
        return VStack(alignment: .center, spacing: DesignSystem.tiny) {
            ZStack {
                Circle()
                    .fill(color.opacity(DesignSystem.glassOpacity / 2))
                    .frame(width: DesignSystem.Timeline.indicatorSize - DesignSystem.tiny, height: DesignSystem.Timeline.indicatorSize - DesignSystem.tiny) // 32
                Image(systemName: type.icon)
                    .font(.system(size: DesignSystem.subheadlineFontSize, weight: .bold))
                    .foregroundStyle(color)
                
                if runningCount > 0 {
                    Circle()
                        .trim(from: 0, to: 0.8)
                        .stroke(color, lineWidth: DesignSystem.borderWidth * 2)
                        .frame(width: DesignSystem.Timeline.indicatorSize, height: DesignSystem.Timeline.indicatorSize)
                        .rotationEffect(.degrees(-90))
                }
            }
            
            VStack(spacing: DesignSystem.atomic) {
                Text(type.localizedName)
                    .font(.system(size: DesignSystem.microFontSize + DesignSystem.atomic, weight: .bold)) // 11
                    .foregroundStyle(.appSecondary)
                
                HStack(alignment: .firstTextBaseline, spacing: DesignSystem.atomic) {
                    Text("\(metrics.completed)")
                        .font(.system(size: DesignSystem.standardFontSize + DesignSystem.small, weight: .bold, design: .rounded)) // 20
                        .foregroundStyle(.appText)
                    Text("/ \(metrics.total)")
                        .font(.system(size: DesignSystem.microFontSize, weight: .medium, design: .rounded))
                        .foregroundStyle(.appSecondary.opacity(DesignSystem.secondaryOpacity * 0.75)) // 0.6
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.standardPadding)
        .appMetricCardStyle(color: color, cornerRadius: DesignSystem.standardRadius)
        // 选中状态应用细微的色彩边框，提供强力视觉锚点
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.standardRadius)
                .stroke(isSelected ? color : Color.clear, lineWidth: DesignSystem.borderWidth * 2)
        )
        .padding(.vertical, DesignSystem.tiny)
        // 阴影和缩放微动效
        .shadow(
            color: Color.theme.black.opacity(isSelected ? DesignSystem.shadowOpacity / 2.5 : DesignSystem.shadowOpacity / 5),
            radius: isSelected ? DesignSystem.medium : DesignSystem.small,
            x: 0,
            y: isSelected ? DesignSystem.small : DesignSystem.tiny
        )
        .scaleEffect(isSelected ? 1.03 : 1.0)
        // 当过滤了其他类型时，对未选中的卡片进行半透明度弱化
        .opacity(isAnySelected && !isSelected ? 0.6 : 1.0)
        .animation(.fastAnimation, value: selectedFilterType)
        .contentShape(Rectangle())
        .onTapGesture {
            HapticFeedback.shared.trigger(.selection)
            if isSelected {
                selectedFilterType = nil
            } else {
                selectedFilterType = type
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: DesignSystem.loosePadding) {
            ZStack {
                Circle()
                    .fill(Color.appAccent.opacity(DesignSystem.glassOpacity / 2))
                    .frame(width: DesignSystem.Gallery.displayIconSize, height: DesignSystem.Gallery.displayIconSize)
                
                Image(systemName: DesignSystem.Icons.trayFill)
                    .font(.system(size: DesignSystem.Gallery.splashIconSize - DesignSystem.medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.appAccent.opacity(DesignSystem.fullOpacity), .appAccent.opacity(DesignSystem.glassOpacity * 2)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .offset(y: DesignSystem.tiny)
                
                Image(systemName: DesignSystem.Icons.sparkles)
                    .font(.system(size: DesignSystem.Action.largeIconSize))
                    .foregroundStyle(.purple)
                    .offset(x: DesignSystem.standardPadding + DesignSystem.medium, y: -(DesignSystem.standardPadding + DesignSystem.medium))
            }
            
            VStack(spacing: DesignSystem.medium) {
                Text(L10n.AI.Task.emptyTitle)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.appText)
                
                Text(L10n.AI.Task.emptyDesc)
                    .font(.subheadline)
                    .foregroundStyle(.appSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(DesignSystem.atomic * 2)
            }
            
            VStack(alignment: .leading, spacing: DesignSystem.standardPadding) {
                Text(L10n.AI.Task.howToTrigger)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.appSecondary)
                    .padding(.bottom, DesignSystem.tiny)
                
                guideRow(icon: "stethoscope", color: .red, title: L10n.AI.Task.guideHealth, desc: L10n.AI.Task.guideHealthDesc)
                guideRow(icon: "bolt.shield.fill", color: .orange, title: L10n.AI.Task.guideAIScan, desc: L10n.AI.Task.guideAIScanDesc)
                guideRow(icon: "tray.and.arrow.down.fill", color: .blue, title: L10n.AI.Task.guideIngest, desc: L10n.AI.Task.guideIngestDesc)
                guideRow(icon: "wand.and.stars", color: .purple, title: L10n.AI.Task.guideSynthesis, desc: L10n.AI.Task.guideSynthesisDesc)
            }
            .padding()
            .background(Color.appCard)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cardRadius))
            .padding(.horizontal, DesignSystem.loosePadding + DesignSystem.tiny)
        }
        .frame(maxWidth: .infinity)
        .listRowBackground(Color.clear)
    }
    
    private func guideRow(icon: String, color: Color, title: String, desc: String) -> some View {
        HStack(spacing: DesignSystem.standardPadding) {
            Image(systemName: icon)
                .font(.system(size: DesignSystem.Action.iconSize))
                .foregroundStyle(color)
                .frame(width: DesignSystem.Task.badgeSize, height: DesignSystem.Task.badgeSize)
                .background(color.opacity(DesignSystem.glassOpacity / 2))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: DesignSystem.atomic) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.appText)
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.appSecondary)
            }
            Spacer()
        }
    }
}

/// 任务条目行组件
/// 负责单个异步任务的进度条展示、状态文本反馈及关联页面的快捷跳转交互
private struct TaskRow: View {
    let task: GlobalTask
    
    var body: some View {
        HStack(spacing: DesignSystem.Task.rowSpacing) {
            // 类型图标与状态
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(task.type == .ai ? Color.theme.purple.opacity(DesignSystem.glassOpacity / 2) : Color.appAccent.opacity(DesignSystem.glassOpacity / 2))
                    .frame(width: DesignSystem.Task.iconBoxSize, height: DesignSystem.Task.iconBoxSize)
                
                Image(systemName: task.type.icon)
                    .font(.system(size: DesignSystem.Action.iconSize + DesignSystem.atomic))
                    .foregroundStyle(task.type == .ai ? .purple : .appAccent)
                    .frame(width: DesignSystem.Task.iconBoxSize, height: DesignSystem.Task.iconBoxSize)
                
                if !task.isRead && (task.status == .completed || isFailed) {
                    Circle()
                        .fill(.red)
                        .frame(width: DesignSystem.Task.statusIndicatorSize, height: DesignSystem.Task.statusIndicatorSize)
                        .overlay(Circle().stroke(Color.appCard, lineWidth: DesignSystem.borderWidth * 2))
                }
            }
            
            VStack(alignment: .leading, spacing: DesignSystem.atomic * 2) {
                HStack {
                    Text(task.name)
                        .font(.subheadline.bold())
                        .lineLimit(1)
                    if task.associatedPageID != nil {
                        Image(systemName: DesignSystem.Icons.arrowUpRightSquare)
                            .font(.caption2)
                            .foregroundStyle(.appAccent)
                    }
                }
                
                Text(task.target)
                    .font(.caption2)
                    .foregroundStyle(.appSecondary)
                    .lineLimit(1)
                
                if case .failed(let error) = task.status {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                        .padding(.top, DesignSystem.atomic)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: DesignSystem.Metrics.progressHeight) {
                statusText
                Text(task.startTime.formatted(.dateTime.hour().minute().second().locale(Localized.currentLocale)))
                    .font(.system(size: DesignSystem.microFontSize - DesignSystem.atomic * 2, design: .monospaced)) // 8
                    .foregroundStyle(.appSecondary.opacity(DesignSystem.glassOpacity * 2))
                    .fixedSize()
            }
        }
        .padding(.vertical, DesignSystem.Task.rowVerticalPadding)
        .opacity(task.isRead ? DesignSystem.disabledOpacity : DesignSystem.fullOpacity)
    }
    
    private var isFailed: Bool {
        if case .failed = task.status { return true }
        return false
    }
    
    @ViewBuilder
    private var statusText: some View {
        switch task.status {
        case .pending:
            Text(L10n.AI.Task.statusPending)
                .font(.caption2)
                .foregroundStyle(.appSecondary)
        case .running(let progress, _):
            HStack(spacing: DesignSystem.tiny) {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .frame(width: DesignSystem.Task.progressWidth)
                Text(L10n.AI.Task.running)
                    .font(.caption2)
                    .foregroundStyle(.appAccent)
            }
        case .completed:
            Text(L10n.AI.Task.statusCompleted)
                .font(.caption2)
                .foregroundStyle(.green)
        case .failed:
            Text(L10n.AI.Task.statusFailed)
                .font(.caption2.bold())
                .foregroundStyle(.red)
        }
    }
}
// MARK: - UI Extensions
extension TaskType {
    var uiColor: Color {
        switch self.defaultColor {
        case "blue": return .blue
        case "red": return .red
        case "orange": return .orange
        case "purple": return .purple
        default: return .appAccent
        }
    }
}
