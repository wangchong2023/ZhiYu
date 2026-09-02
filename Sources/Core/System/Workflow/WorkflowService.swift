//
//  WorkflowService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0.5] 系统集成层
//  核心职责：实现 Workflow 模块的核心业务逻辑服务。
//
import Foundation
import UFPCore
import Dependencies

/// 工作流服务：连接知识与外部系统（如提醒事项、日历）
@MainActor
final class WorkflowService: ObservableObject {
    static let shared = WorkflowService()

    private let injectedReminderService: (any ReminderServiceProtocol)?
    @Dependency(\.toastService) private var toastManager

    init(reminderService: (any ReminderServiceProtocol)? = nil) {
        self.injectedReminderService = reminderService
    }

    private var reminderService: any ReminderServiceProtocol {
        if let injected = injectedReminderService {
            return injected
        }
        return ServiceContainer.shared.resolve((any ReminderServiceProtocol).self)
    }
    
    enum WorkflowError: Error {
        case accessDenied
    }
    
    /// 请求提醒事项权限
    func requestAccess() async -> Bool {
        await reminderService.requestAccess()
    }
    
    /// 将 AI 提取的行动项同步至系统提醒事项
    func syncToReminders(text: String, title: String) async throws {
        let hasAccess = await requestAccess()
        guard hasAccess else {
            // 重构：将 Toast 硬编码文字替换为 L10n 强类型多语言接口
            toastManager.show(type: .error, message: L10n.Workflow.accessDeniedMessage)
            throw WorkflowError.accessDenied 
        }
        
        // 解析 Markdown 任务列表（支持 - [ ], - , *, 1. 等多种格式）
        let lines = text.components(separatedBy: .newlines)
        let tasks = lines.map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { line in
                // 匹配列表项：- , * , 1. , - [ ]
                // 排除已完成任务（- [x] / - [X]），避免已完成事项被重复同步（finding #8）
                let isCompletedTask = line.hasPrefix(CoreConstants.MarkdownSyntax.taskDone)
                    || line.hasPrefix(CoreConstants.MarkdownSyntax.taskDoneUpper)
                guard !isCompletedTask else { return false }
                return line.hasPrefix("-") || line.hasPrefix("*") || (line.count > 2 && line.first?.isNumber == true && line.contains("."))
            }
            .map { line -> String in
                var cleaned = line
                // 1. 剔除列表前缀
                if cleaned.hasPrefix(CoreConstants.MarkdownSyntax.taskOpen) || cleaned.hasPrefix(CoreConstants.MarkdownSyntax.taskDone) || cleaned.hasPrefix(CoreConstants.MarkdownSyntax.taskDoneUpper) {
                    cleaned = String(cleaned.dropFirst(6))
                } else if cleaned.hasPrefix(CoreConstants.MarkdownSyntax.dashSpace) || cleaned.hasPrefix(CoreConstants.MarkdownSyntax.asteriskSpace) {
                    cleaned = String(cleaned.dropFirst(2))
                } else if let dotIndex = cleaned.firstIndex(of: "."), !cleaned.prefix(upTo: dotIndex).isEmpty, cleaned.prefix(upTo: dotIndex).allSatisfy({ $0.isNumber }) {
                    cleaned = String(cleaned[cleaned.index(after: dotIndex)...])
                }
                
                // 2. 剔除 Markdown 样式标记（加粗、斜体、删除线、行内代码）
                cleaned = cleaned.replacingOccurrences(of: CoreConstants.MarkdownSyntax.boldItalic, with: "") // 粗斜体
                cleaned = cleaned.replacingOccurrences(of: CoreConstants.MarkdownSyntax.bold, with: "")  // 加粗
                cleaned = cleaned.replacingOccurrences(of: CoreConstants.MarkdownSyntax.italic, with: "")  // 下划线加粗
                cleaned = cleaned.replacingOccurrences(of: "*", with: "")   // 斜体
                cleaned = cleaned.replacingOccurrences(of: "_", with: "")   // 下划线斜体
                cleaned = cleaned.replacingOccurrences(of: CoreConstants.MarkdownSyntax.strikethrough, with: "")  // 删除线
                cleaned = cleaned.replacingOccurrences(of: "`", with: "")   // 行内代码
                
                return cleaned.trimmingCharacters(in: .whitespaces)
            }
            .filter { !$0.isEmpty }
        
        Logger.shared.info(" [Workflow] Extracted to-do items: \(tasks.count) items")
        
        guard !tasks.isEmpty else {
            Logger.shared.warning(" [Workflow] Failed to parse to-do items from text")
            // 重构：将 Toast 硬编码文字替换为 L10n 强类型多语言接口
            toastManager.show(type: .info, message: L10n.Workflow.noTasksFoundMessage)
            return
        }
        
        // 重构：将带有插值的 Toast 消息转换为强类型格式化本地化输出
        toastManager.show(type: .processing, message: L10n.Workflow.syncingMessage(tasks.count), duration: 0)
        
        do {
            for task in tasks {
                try await reminderService.createReminder(
                    title: task,
                    // 重构：将外部同步标签备注信息格式化为多语言引用
                    notes: L10n.Workflow.sourceNotes(title)
                )
            }
            
            Logger.shared.info(" [Workflow] Successfully synchronized \(tasks.count) items to Reminders")
            toastManager.dismiss()
            // 重构：将成功同步的 Toast 提示转换为多语言强类型输出
            toastManager.show(type: .success, message: L10n.Workflow.syncSuccessMessage(tasks.count))
            HapticFeedback.shared.trigger(.success)
        } catch {
            Logger.shared.error(" [Workflow] Sync failed: \(error.localizedDescription)", error: error)
            toastManager.dismiss()
            // 重构：将失败同步的 Toast 错误描述转换为多语言强类型输出
            toastManager.show(type: .error, message: L10n.Workflow.syncErrorMessage(error.localizedDescription))
            throw error
        }
    }
}

// MARK: - DependencyKey

@MainActor
enum WorkflowServiceKey: DependencyKey {
    @MainActor
    static var liveValue: WorkflowService {
        ServiceContainer.shared.resolveOptional(WorkflowService.self) ?? WorkflowService()
    }
    @MainActor
    static var testValue: WorkflowService {
        ServiceContainer.shared.resolveOptional(WorkflowService.self) ?? WorkflowService()
    }
    @MainActor
    static var previewValue: WorkflowService { testValue }
}

extension DependencyValues {
    @MainActor
    var workflowService: WorkflowService {
        get { self[WorkflowServiceKey.self] }
        set { self[WorkflowServiceKey.self] = newValue }
    }
}
