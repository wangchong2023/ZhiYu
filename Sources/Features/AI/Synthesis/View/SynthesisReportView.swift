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
import UFPCore
import Dependencies

// MARK: - 报告内容视图

/// Markdown 链接定界符（点击链接时清除方括号，提取纯文本目标）
private enum MarkdownLinkDelimiter {
    static let openBracket: String = SystemConstants.Character.openBracket
    static let closeBracket: String = SystemConstants.Character.closeBracket
}

/// 以 Markdown 渲染器展示合成文档内容的通用回退视图
struct SynthesisReportView: View {
    let doc: SynthesisStore.SynthesisDocument
    @Dependency(\.router) private var router: Router
    @Environment(AppStore.self) private var store: AppStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.medium) {
                MarkdownRendererView(content: doc.content, isPrivate: false, onLinkTap: { target in
                    handleLinkTap(target)
                })
            }
            .padding(DesignSystem.standardPadding)
            .padding(.bottom, DesignSystem.huge)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }

    private func handleLinkTap(_ target: String) {
        let cleanTarget = target.replacingOccurrences(of: MarkdownLinkDelimiter.openBracket, with: "")
                               .replacingOccurrences(of: MarkdownLinkDelimiter.closeBracket, with: "")
                               .trimmingCharacters(in: .whitespacesAndNewlines)
        if let targetPage = store.pages.first(where: { $0.title.lowercased() == cleanTarget.lowercased() }) {
            router.navigate(to: .pageDetail(id: targetPage.id))
        }
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
                .background(Color.appBorder.opacity(DesignSystem.secondaryOpacity))

            HStack {
                Label(L10n.AI.Synthesis.sourceCount(sourcePageIDs.count), systemImage: "doc.text")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.appSecondary)
                Spacer()
            }
            .padding(.horizontal, DesignSystem.standardPadding)
            .padding(.top, DesignSystem.small)
            .padding(.bottom, DesignSystem.tiny)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.small) {
                    ForEach(sourcePages, id: \.id) { page in
                        Button(action: {
                            onNavigate(page.id)
                        }) {
                            HStack(spacing: DesignSystem.tiny) {
                                Image(systemName: page.displayIcon)
                                    .font(.caption2.weight(.medium))
                                Text(page.title)
                                    .font(.caption.weight(.medium))
                                    .lineLimit(1)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .bold)) // Dynamic Type
                                    .foregroundStyle(Color.appAccent.opacity(DesignSystem.secondaryOpacity))
                            }
                            .padding(.horizontal, SystemSpacing.small)
                            .padding(.vertical, SystemSpacing.small)
                            .background(
                                ZStack {
                                    Capsule().fill(Color.appAccent.opacity(SystemOpacity.disabled))
                                    Capsule().strokeBorder(Color.appAccent.opacity(DesignSystem.dimmedOpacity), lineWidth: 1)
                                }
                            )
                            .foregroundStyle(Color.appAccent)
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.standardPadding)
                .padding(.bottom, DesignSystem.small)
            }
        }
        .background(DesignSystem.containerMaterial)
        .shadow(color: Color.appBorder.opacity(DesignSystem.secondaryOpacity), radius: 8, x: 0, y: -4)
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
                } else if let md = QuizProcessor.convertJSONToMarkdown(doc.content) {
                    let fallbackDoc = SynthesisStore.SynthesisDocument(
                        id: doc.id,
                        type: doc.type,
                        name: doc.name,
                        content: md,
                        createdAt: doc.createdAt,
                        size: md.utf8.count,
                        sourcePageIDs: doc.sourcePageIDs
                    )
                    SynthesisReportView(doc: fallbackDoc)
                        .onAppear {
                            Logger.shared.error("[SYNTH_ERR_QUIZ_JSON]" + " \(doc.content.prefix(50))")
                        }
                } else {
                    SynthesisErrorStateView(docType: doc.type)
                        .onAppear {
                            Logger.shared.error("[SYNTH_ERR_QUIZ_FORMAT]" + " \(doc.content.prefix(50))")
                        }
                }
            default:
                if doc.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    SynthesisErrorStateView(docType: doc.type)
                } else {
                    SynthesisReportView(doc: doc)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
        .onAppear {
            if doc.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Logger.shared.error("[SYNTH_ERR_CONTENT_EMPTY]" + " \(doc.type.rawValue)")
            }
        }
    }
}
