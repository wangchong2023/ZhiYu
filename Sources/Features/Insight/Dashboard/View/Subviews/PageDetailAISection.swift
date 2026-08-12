//
//  PageDetailAISection.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：仪表盘：页面列表、知识统计、每周洞察、回链视图。
//
import SwiftUI
import UFPCore
import Dependencies

/// 页面详情 AI 结果展示区
struct PageDetailAISection: View {
    @Environment(AIWorkflowStore.self) var aiStore
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router
    let page: KnowledgePage
    let onLinkTap: (String) -> Void
    
    var body: some View {
        if aiStore.isProcessingPageAI || aiStore.activePageAIResult != nil {
            VStack(alignment: .leading, spacing: DesignSystem.medium) {
                HStack {
                    Image(systemName: DesignSystem.Icons.sparkles)
                        .foregroundStyle(.appAccent)
                    Text(L10n.Knowledge.Page.AI.labOutput)
                        .font(.headline)
                        .foregroundStyle(.appText)
                    Spacer()
                    if !aiStore.isProcessingPageAI {
                        // 一键“合入正文”按钮：将生成的 AI 智能总结和行动项追加到该页面正文的末尾
                        if let result = aiStore.activePageAIResult {
                            Button(action: {
                                Task {
                                    var updatedPage = page
                                    // 追加 Markdown 分隔线和一键总结标题
                                    updatedPage.content = page.content + "\n\n---\n### " + L10n.Common.appendToBody + "\n" + result
                                    // 保存修改，物理库和内存同步，并自动增量生成 Embedding 向量
                                    await store.updatePage(updatedPage, forceDeepScan: false)
                                    HapticFeedback.shared.trigger(.success)
                                    // 成功合入后清空结果区，使用户专注于新正文
                                    aiStore.activePageAIResult = nil
                                }
                            }) {
                                Label(L10n.Common.appendToBody, systemImage: "square.and.arrow.down")
                                    .font(.caption)
                                    .foregroundStyle(.appAccent)
                            }
                            .padding(.trailing, DesignSystem.small)
                        }

                        if let result = aiStore.activePageAIResult, result.contains("- ") {
                            Button(action: {
                                Task {
                                    @Dependency(\.workflowService) var workflowService
                                    try await workflowService.syncToReminders(text: result, title: page.title)
                                }
                            }) {
                                Label(L10n.Common.syncToReminders, systemImage: DesignSystem.Icons.checklist)
                                    .font(.caption)
                                    .foregroundStyle(.appAccent)
                            }
                            .padding(.trailing, DesignSystem.small)
                        }
                        
                        Button(action: { 
                            AppPasteboard.string = aiStore.activePageAIResult
                            HapticFeedback.shared.trigger(.success)
                        }) {
                            Image(systemName: DesignSystem.Icons.copy)
                                .font(.caption)
                                .foregroundStyle(.appSecondary)
                        }
                        
                        Button(action: { aiStore.activePageAIResult = nil }) {
                            Image(systemName: DesignSystem.Icons.xmarkCircle)
                                .font(.caption)
                                .foregroundStyle(.appSecondary)
                        }
                    }
                }
                
                if aiStore.isProcessingPageAI {
                    VStack(alignment: .leading, spacing: DesignSystem.medium) {
                        AppSkeleton(height: DesignSystem.IconSize.small).frame(width: DesignSystem.Metrics.sourceCardWidth)
                        AppSkeleton(height: 120)
                        AppSkeleton(height: 60)
                    }
                } else if let result = aiStore.activePageAIResult {
                    MarkdownRendererView(content: result, isPrivate: false, onLinkTap: onLinkTap)
                    .appContainer(padding: true)
                }
            }
            .padding()
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
