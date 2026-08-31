//
//  AIProcessingActivityWidget.swift
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
import ActivityKit

// MARK: - Widget 私有常量

/// 预计 AI 治理任务时长（1 小时）
private let estimatedTaskDuration: TimeInterval = 3600

/// 进度条纵向缩放比例
private let progressBarScale: CGFloat = 1.5

/// AI 治理扫描实时活动视图
struct AIProcessingActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AIProcessingAttributes.self) { context in
            // 锁定屏幕/横幅通知下的展示布局
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(WidgetSharedConstants.Color.purple)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.taskName)
                            .font(.headline)
                        Text(context.state.status)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("\(Int(context.state.progress * 100))%")
                        .font(.system(.title, design: .rounded))
                        .bold()
                }
                
                ProgressView(value: context.state.progress)
                    .tint(WidgetSharedConstants.Color.purple)
            }
            .padding()
            // swiftlint:disable:next magic_numbers_opacity
            .activityBackgroundTint(Color.indigo.opacity(0.3))
            .activitySystemActionForegroundColor(.white)
            
        } dynamicIsland: { context in
            DynamicIsland {
                // 展开模式 (Expanded) - 左侧：图标增强
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "sparkles")
                        .symbolRenderingMode(.multicolor)
                        .font(.title2)
                        .padding(.leading, 8)
                }
                
                // 展开模式 - 右侧：大字号进度
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(Int(context.state.progress * 100))%")
                        .font(.system(.title2, design: .rounded))
                        .fontWeight(.black)
                        .foregroundStyle(WidgetSharedConstants.Color.purple)
                        .padding(.trailing, 8)
                }
                
                // 展开模式 - 底部：核心进度与状态流
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 3) {
                        // 状态标签
                        HStack {
                            Text(context.state.status)
                                .font(.caption.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                // swiftlint:disable:next magic_numbers_opacity
                                .background(Capsule().fill(WidgetSharedConstants.Color.purple.opacity(0.2)))
                                .foregroundStyle(WidgetSharedConstants.Color.purple)
                            
                            Spacer()
                            
                            // 耗时计算
                            Text(timerInterval: context.attributes.startTime...Date().addingTimeInterval(estimatedTaskDuration), countsDown: false)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        
                        // 高亮进度条
                        ProgressView(value: context.state.progress)
                            .progressViewStyle(.linear)
                            .tint(LinearGradient(colors: [WidgetSharedConstants.Color.purple, WidgetSharedConstants.Color.blue], startPoint: .leading, endPoint: .trailing))
                            .scaleEffect(x: 1, y: progressBarScale, anchor: .center)
                            .clipShape(Capsule())
                    }
                    .padding(.top, 4)
                }
                
                // 展开模式 - 中心：主任务标题
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.taskName)
                        .font(.headline)
                        .foregroundStyle(.white)
                }
            } compactLeading: {
                // 紧凑模式 - 左侧：尝试在图标旁显示极简任务标识
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .symbolRenderingMode(.multicolor)
                        .font(.system(size: 14, weight: .bold)) // Dynamic Type
                    
                    Text(context.attributes.taskName.prefix(2))
                        .font(.system(size: 10, weight: .heavy)) // Dynamic Type
                        .foregroundStyle(WidgetSharedConstants.Color.purple)
                }
                .padding(.leading, 4)
            } compactTrailing: {
                // 紧凑模式 - 右侧：增大字体并使用等宽数字，提升易读性
                Text("\(Int(context.state.progress * 100))%")
                    .font(.system(size: 13, weight: .black, design: .rounded).monospacedDigit()) // Dynamic Type
                    .foregroundColor(WidgetSharedConstants.Color.purple)
            } minimal: {
                // 最小模式
                Image(systemName: "sparkles")
                    .symbolRenderingMode(.multicolor)
            }
            // swiftlint:disable:next magic_numbers_opacity
            .keylineTint(WidgetSharedConstants.Color.purple.opacity(0.5))
        }
    }
}
