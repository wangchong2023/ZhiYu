//
//  ActivityService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 平台适配层
//  核心职责：实现 Activity 模块的核心业务逻辑服务。
//
import Foundation
#if os(iOS) && !targetEnvironment(macCatalyst)
@preconcurrency import ActivityKit
#endif

/// 灵动岛与实时活动管理服务 (iOS 专属)
/// 负责在 Dynamic Island 展示 AI 扫描、导出、同步等长时任务的进度。
@MainActor
final class ActivityService: LiveActivityProtocol {
    static let shared = ActivityService()

    #if os(iOS) && !targetEnvironment(macCatalyst)
    /// 任务 ID 与实时活动的映射表，支持多任务并发展示
    nonisolated(unsafe) private var activeActivities: [UUID: Activity<AIProcessingAttributes>] = [:]
    #endif

    private init() {}

    /// 遵从 LiveActivityProtocol 基础协议的启动接口
    func startActivity(id: UUID, name: String, target: String) {
        startActivity(
            id: id,
            name: name,
            target: target,
            kind: .synthesis,
            sourceCount: 0,
            currentFileName: "",
            estimatedSecondsRemaining: 0
        )
    }

    /// 启动实时活动
    func startActivity(
        id: UUID,
        name: String,
        target: String,
        kind: ActivityKind = .synthesis,
        sourceCount: Int = 0,
        currentFileName: String = "",
        estimatedSecondsRemaining: Int = 0
    ) {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        
        Task { @MainActor in
            Logger.shared.debug("DynamicIsland_Preparing")
            
            let attributes = AIProcessingAttributes(taskName: name, startTime: Date())
            let contentState = AIProcessingAttributes.ContentState(
                progress: 0.05,
                status: target,
                kind: kind,
                sourceCount: sourceCount,
                currentFileName: currentFileName,
                estimatedSecondsRemaining: estimatedSecondsRemaining
            )
            
            do {
                if activeActivities.count >= 5 {
                    if let oldestID = activeActivities.keys.first {
                        await activeActivities[oldestID]?.end(nil, dismissalPolicy: .immediate)
                        activeActivities.removeValue(forKey: oldestID)
                    }
                }
                
                let activity = try Activity<AIProcessingAttributes>.request(
                    attributes: attributes,
                    content: ActivityContent(state: contentState, staleDate: nil)
                )
                activeActivities[id] = activity
                Logger.shared.debug("DynamicIsland_Started")
            } catch {
                Logger.shared.error("DynamicIsland_Failed")
            }
        }
        #endif
    }

    /// 遵从 LiveActivityProtocol 基础协议的更新进度接口
    func updateProgress(id: UUID, progress: Double, message: String) async {
        await updateProgress(
            id: id,
            progress: progress,
            message: message,
            sourceCount: 0,
            currentFileName: "",
            estimatedSecondsRemaining: 0
        )
    }

    /// 更新指定任务的实时进度
    func updateProgress(
        id: UUID,
        progress: Double,
        message: String,
        sourceCount: Int = 0,
        currentFileName: String = "",
        estimatedSecondsRemaining: Int = 0
    ) async {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        guard let activity = activeActivities[id] else { return }
        
        var currentState = activity.content.state
        currentState.progress = progress
        currentState.status = message
        if sourceCount > 0 { currentState.sourceCount = sourceCount }
        if !currentFileName.isEmpty { currentState.currentFileName = currentFileName }
        if estimatedSecondsRemaining > 0 { currentState.estimatedSecondsRemaining = estimatedSecondsRemaining }

        let title = LocalizedStringResource(stringLiteral: "\(Int(progress * 100))%")
        let body = LocalizedStringResource(stringLiteral: message)
        let alertConfiguration = AlertConfiguration(title: title, body: body, sound: .default)
        
        await activity.update(
            ActivityContent(state: currentState, staleDate: nil),
            alertConfiguration: alertConfiguration
        )
        #endif
    }

    /// 结束指定任务的实时活动
    func endActivity(id: UUID) async {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        guard let activity = activeActivities[id] else { return }
        
        Logger.shared.debug("DynamicIsland_Ending")
        
        let content = ActivityContent(state: activity.content.state, staleDate: nil)
        await activity.end(content, dismissalPolicy: .immediate)
        activeActivities.removeValue(forKey: id)
        #endif
    }
}
