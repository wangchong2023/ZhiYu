//
//  AIViewProvider.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：SwiftUI 视图，负责 AIProvider 界面的布局与渲染。
//
import SwiftUI

struct AIViewProvider: ViewProvider {

    /// 创建View
    /// - Returns: 可选值
    func makeView(for route: AnyHashable) -> AnyView? {
        guard let route = route as? AppRoute, route.domain == .ai else { return nil }
        
        switch route {
        case .chat:
            return AnyView(ChatViewContent(selectedTab: .constant(.knowledge)))
        case .synthesis:
            return AnyView(SynthesisViewWrapper())
        case .taskCenter:
            return AnyView(TaskCenterView())
        case .weeklyReport:
            return AnyView(WeeklyReportView())
        case .quiz:
            // Quiz 目前可能通过辅助视图或独立的 Route 呈现
            return AnyView(Text(L10n.AI.Prompt.Quiz.placeholder))
        default:
            return nil
        }
    }
}
