//
//  SynthesisTimelineView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：展示合成任务运行中的进度时间线视图，包含任务状态卡片与无障碍语音公告。
//

import SwiftUI

// MARK: - 运行中任务时间线

/// 渲染当前正在执行的合成任务列表，每个任务以进度卡片形式展示
/// 并监听任务状态变更以触发 VoiceOver 主动语音公告
struct SynthesisTimelineView: View {
    @Bindable var taskCenter: TaskCenter

    var body: some View {
        let tasks = taskCenter.tasks.filter { task in
            if task.type != .synthesis { return false }
            switch task.status {
            case .running: return true
            default: return false
            }
        }
        return Group {
            if !tasks.isEmpty {
                runningTasksSection(tasks: tasks)
            }
        }
    }

    // MARK: - 运行任务区块

    private func runningTasksSection(tasks: [GlobalTask]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.medium) {
            Text(L10n.AI.Task.running)
                .font(.title3.bold())
                .foregroundStyle(.appAccent)
                .padding(.horizontal, DesignSystem.tiny)

            VStack(spacing: 0) {
                ForEach(tasks) { task in
                    synthesisTaskRow(task: task)
                        .padding()
                    if task.id != tasks.last?.id {
                        Divider().padding(.horizontal)
                    }
                }
            }
            .appContainer(padding: false)
        }
    }

    // MARK: - 单任务行

    private func synthesisTaskRow(task: GlobalTask) -> some View {
        HStack(spacing: DesignSystem.standardPadding) {
            ZStack {
                Circle().fill(Color.appAccent.opacity(SystemOpacity.faint)).frame(width: DesignSystem.Graph.selectedNodeSize, height: DesignSystem.Graph.selectedNodeSize)
                ProgressView()
            }
            VStack(alignment: .leading, spacing: DesignSystem.small) {
                Text(task.name).font(.subheadline.weight(.semibold))
                if case .running(let progress, _) = task.status {
                    ProgressView(value: progress).tint(.appAccent)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(buildTaskAccessibilityLabel(task))
    }

    // MARK: - 无障碍标签

    /// 构造任务在运行中的无障碍语音标签
    /// - Parameter task: 异步后台任务
    /// - Returns: 结合了进度与执行阶段描述的文本
    private func buildTaskAccessibilityLabel(_ task: GlobalTask) -> String {
        let base = "\(task.name)\(L10n.AI.Task.Accessibility.taskInProgress)"
        if case .running(let progress, let stage) = task.status {
            let percentage = Int(progress * 100)
            let stageName = localizedStageName(stage)
            return base + "" + L10n.AI.Task.Accessibility.progressValue(percentage, stageName)
        }
        return base
    }

    /// 将 RAG 执行阶段转化为强类型多语言 Status 描述文案
    /// - Parameter stage: RAG 任务阶段
    /// - Returns: 对应的本地化描述文案
    private func localizedStageName(_ stage: TaskStage) -> String {
        switch stage {
        case .embedding: return L10n.AI.Status.extracting
        case .retrieval: return L10n.AI.Status.scanning
        case .synthesis: return L10n.AI.Status.synthesizing
        default: return L10n.AI.Status.thinking
        }
    }
}

// MARK: - 任务状态变更监听（VoiceOver 公告）

extension View {
    /// 注册任务状态变更监听，当任务从 running 转为 completed/failed 时进行 VoiceOver 主动语音公告
    /// - Parameter taskCenter: 全局任务中心
    func onTaskStatusChange(_ taskCenter: TaskCenter) -> some View {
        self.onChange(of: taskCenter.tasks) { oldTasks, newTasks in
            for newTask in newTasks {
                if let oldTask = oldTasks.first(where: { $0.id == newTask.id }) {
                    switch (oldTask.status, newTask.status) {
                    case (.running, .completed):
                        AccessibilityService.postAnnouncement(L10n.AI.Task.Accessibility.taskFinishedAnnouncement(newTask.name))
                    case (.running, .failed(let error)):
                        AccessibilityService.postAnnouncement(L10n.AI.Task.Accessibility.taskFailedAnnouncement(newTask.name) + "" + error)
                    default:
                        break
                    }
                }
            }
        }
    }
}
