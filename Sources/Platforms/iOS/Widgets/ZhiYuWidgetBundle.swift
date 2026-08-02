//
//  ZhiYuWidgetBundle.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 平台适配层
//  核心职责：iOS 平台实现：后台任务、Widget、文件归档、Spotlight 索引。
//
import SwiftUI
import WidgetKit

@main
struct ZhiYuWidgetBundle: WidgetBundle {
    var body: some Widget {
        // 注册实时活动 Widget
        AIProcessingActivityWidget()
        
        // 注册桌面与锁屏静态/动态 Widget
        KnowledgeStatsWidget()
        DailyInsightWidget()
        KnowledgeDistributionWidget()
        QuickCaptureWidget()
    }
}
