//
//  SynthesisReportView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：渲染合成报告（Markdown 回退视图）与来源页面导航栏。
//

import SwiftUI

// MARK: - 报告内容视图

/// 以 Markdown 渲染器展示合成文档内容的通用回退视图
struct SynthesisReportView: View {
    let doc: SynthesisStore.SynthesisDocument

    var body: some View {
        ScrollView {
            MarkdownRendererView(content: doc.content, isPrivate: false, onLinkTap: { _ in })
                .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }
}

// MARK: - 来源页面底部栏

/// 展示合成文档所引用的来源页面列表，支持点击跳转
struct SynthesisSourcePagesBar: View {
    let sourcePageIDs: [UUID]
    let store: AppStore
    let onNavigate: (_ pageID: UUID) -> Void

    var body: some View {
        let sourcePages = store.pages.filter { sourcePageIDs.contains($0.id) }
        VStack(alignment: .leading, spacing: 0) {
            Divider()
            HStack {
                Label(L10n.AI.Synthesis.sourceCount(sourcePageIDs.count), systemImage: "doc.text")
                    .font(.caption.weight(.semibold))
                Spacer()
            }
            .padding(.horizontal, DesignSystem.standardPadding)
            .padding(.vertical, DesignSystem.tightPadding)
            .background(.ultraThinMaterial)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.small) {
                    ForEach(sourcePages, id: \.id) { page in
                        Button(action: {
                            onNavigate(page.id)
                        }) {
                            HStack(spacing: DesignSystem.tiny) {
                                Image(systemName: page.displayIcon)
                                    .font(.caption2)
                                Text(page.title)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, DesignSystem.small)
                            .padding(.vertical, DesignSystem.tightPadding)
                            .background(Capsule().fill(Color.appAccent.opacity(DesignSystem.Opacity.subtle)))
                            .foregroundStyle(.appAccent)
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.standardPadding)
                .padding(.vertical, DesignSystem.tightPadding)
            }
        }
    }
}

// MARK: - 输出 Sheet 内容分发

/// 根据文档类型分发到对应的子视图（Mindmap / Slides / Quiz / Report / Infographic / Expansion）
struct SynthesisOutputContent: View {
    let doc: SynthesisStore.SynthesisDocument

    var body: some View {
        Group {
            switch doc.type {
            case .mindmap, .infographic:
                SynthesisMindmapView(doc: doc)
            case .slides:
                SynthesisSlidesView(doc: doc)
            case .quiz:
                if let quiz = QuizProcessor.parseToQuizModel(doc.content) {
                    QuizView(quiz: quiz)
                } else {
                    SynthesisReportView(doc: doc)
                }
            default:
                SynthesisReportView(doc: doc)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }
}
