//
//  CreatePageView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：构建 CreatePage 界面的 UI 视图层组件。
//
import SwiftUI
import UFPCore

struct CreatePageView: View {
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var type: PageType = .concept
    @State private var tags = ""

    // 通用字段
    @State private var summary = ""      // 一句话定义 / 对比背景
    @State private var bodyContent = ""  // 主体内容
    @State private var relatedItems = "" // 关联页面

    // 对比模板专用
    @State private var compareItemA = ""
    @State private var compareItemB = ""

    var body: some View {
        NavigationStack {
            Form {
                basicInfoSection
                templateSection
                contentSection
            }
            .scrollContentBackground(.hidden)
            .background(PageBackgroundView(accentColor: .appAccent))
            .navigationTitle(L10n.Creation.title)
            .appNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Common.done) { createPage() }
                        .disabled(title.isEmpty)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - 基本信息

    private var basicInfoSection: some View {
        Section {
            TextField(L10n.Creation.pageTitle, text: $title)
                .font(.body)
                .accessibilityIdentifier("pageTitle")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.small) {
                    // 遍历用户可见的页面类型，过滤掉内部 raw 类型
                    ForEach(PageType.allVisibleCases) { pageType in
                        let isSelected = type == pageType
                        let typeColor = Color.fromModelColorName(pageType.colorName)
                        Button(action: { type = pageType }) {
                            HStack(spacing: DesignSystem.tightPadding) {
                                Image(systemName: pageType.icon).font(.caption)
                                Text(pageType.displayName).font(.caption)
                            }
                            .padding(.horizontal, DesignSystem.medium)
                            .padding(.vertical, DesignSystem.small)
                            .background(isSelected
                                ? typeColor.opacity(DesignSystem.Opacity.medium)
                                : Color.appCard)
                            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.smallRadius))
                            .foregroundStyle(isSelected
                                ? typeColor
                                : .appSecondary)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.smallRadius)
                                    .stroke(isSelected
                                        ? typeColor.opacity(DesignSystem.Opacity.soft)
                                        : Color.clear, lineWidth: SystemStroke.divider)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            TextField(L10n.Creation.tagsPlaceholder, text: $tags)
        } header: {
            Text(L10n.Creation.basicInfo)
        }
    }

    // MARK: - 快速模板

    private var templateSection: some View {
        Section {
            VStack(spacing: DesignSystem.small) {
                templateCard(
                    icon: DesignSystem.Icons.entity,
                    title: L10n.Creation.entityTemplate,
                    description: L10n.Creation.template.entity.desc,
                    action: { type = .entity }
                )
                templateCard(
                    icon: DesignSystem.Icons.concept,
                    title: L10n.Creation.conceptTemplate,
                    description: L10n.Creation.template.concept.desc,
                    action: { type = .concept }
                )
                templateCard(
                    icon: DesignSystem.Icons.comparison,
                    title: L10n.Creation.comparisonTemplate,
                    description: L10n.Creation.template.comparison.desc,
                    action: { type = .comparison }
                )
            }
        } header: {
            Text(L10n.Creation.quickTemplates)
        }
    }

    // MARK: - 内容区（按类型不同布局）

    @ViewBuilder
    private var contentSection: some View {
        switch type {
        case .entity:
            entityContent
        case .concept:
            conceptContent
        case .comparison:
            comparisonContent
        default:
            conceptContent
        }
    }

    // MARK: 实体内容

    private var entityContent: some View {
        templatedContent(
            summaryLabel: cleanTemplateTitle(L10n.Creation.template.entity.overview),
            summaryHint: L10n.Creation.template.entity.desc,
            editorHint: L10n.Creation.template.entity.overviewHint,
            trailing: .dividerField(
                label: cleanTemplateTitle(L10n.Creation.template.entity.related),
                hint: L10n.Creation.tagsPlaceholder,
                text: $relatedItems
            )
        )
    }

    // MARK: 概念内容

    private var conceptContent: some View {
        templatedContent(
            summaryLabel: cleanTemplateTitle(L10n.Creation.template.concept.definition),
            summaryHint: L10n.Creation.template.concept.desc,
            editorHint: L10n.Creation.template.concept.analysisHint,
            trailing: .relatedLinks
        )
    }

    // MARK: 对比内容

    private var comparisonContent: some View {
        Section {
            VStack(alignment: .leading, spacing: DesignSystem.medium) {
                labeledField(L10n.Creation.template.comparison.desc, hint: "", text: $summary)
                Divider()
                HStack(spacing: DesignSystem.medium) {
                    compareItemField(label: L10n.Creation.compareItemA, text: $compareItemA, color: .appAccent)
                    compareItemField(label: L10n.Creation.compareItemB, text: $compareItemB, color: Color.theme.orange)
                }
                Divider()
                labeledEditor(
                    L10n.Creation.template.comparison.conclusionHint,
                    text: $bodyContent
                )
                relatedLinksSection
            }
        } header: {
            detailHeader
        }
    }

    // MARK: - 共用组件

    /// 对比项字段：标签 + 文本输入框
    @ViewBuilder
    private func compareItemField(label: String, text: Binding<String>, color: Color) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.tiny) {
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(color)
            TextField(label, text: text).font(.body)
        }
    }

    private func labeledField(_ label: String, hint: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.tiny) {
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(.appSecondary)
            TextField(hint.isEmpty ? label : hint, text: text, axis: .vertical)
                .font(.body)
        }
    }

    private func labeledEditor(_ hint: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.tiny) {
            PlatformTextEditor(text: text, minHeight: 80)
                .overlay(alignment: .topLeading) {
                    if text.wrappedValue.isEmpty {
                        Text(hint)
                            .font(.body)
                            .foregroundStyle(.appSecondary.opacity(DesignSystem.Opacity.disabled))
                            .padding(.top, SystemSpacing.element).padding(.leading, SystemSpacing.tiny)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    private var detailHeader: some View {
        HStack {
            Text(L10n.Creation.content)
            Spacer()
            Text(L10n.Editor.bidirectionalLinks)
                .font(.caption2).foregroundStyle(.appSecondary)
        }
    }

    /// 模板内容尾部样式
    private enum ContentTrailing {
        /// Divider + 关联链接分区
        case relatedLinks
        /// Divider + 自定义字段
        case dividerField(label: String, hint: String, text: Binding<String>)
    }

    /// 实体/概念模板通用内容骨架：
    /// summary 字段 + Divider + body 编辑器 + 尾部（关联链接或自定义字段）
    @ViewBuilder
    private func templatedContent(
        summaryLabel: String,
        summaryHint: String,
        editorHint: String,
        trailing: ContentTrailing
    ) -> some View {
        Section {
            VStack(alignment: .leading, spacing: DesignSystem.medium) {
                labeledField(summaryLabel, hint: summaryHint, text: $summary)
                Divider()
                labeledEditor(editorHint, text: $bodyContent)
                switch trailing {
                case .relatedLinks:
                    relatedLinksSection
                case let .dividerField(label, hint, text):
                    Divider()
                    labeledField(label, hint: hint, text: text)
                }
            }
        } header: {
            detailHeader
        }
    }

    private func templateCard(icon: String, title: String, description: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.medium) {
                Image(systemName: icon)
                    .font(.title3).foregroundStyle(.appAccent)
                    .frame(width: DesignSystem.iconLarge)
                VStack(alignment: .leading, spacing: DesignSystem.atomic) {
                    Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.appText)
                    Text(description).font(.caption).foregroundStyle(.appSecondary).lineLimit(2)
                }
                Spacer()
                Image(systemName: DesignSystem.Icons.forward)
                    .font(.caption).foregroundStyle(.appSecondary.opacity(DesignSystem.Opacity.disabled))
            }
            .padding(.vertical, DesignSystem.tiny)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 创建页面

    /// 将逗号分隔的字符串拆分为清理后的非空条目数组
    private func splitCSV(_ raw: String) -> [String] {
        raw.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private func createPage() {
        let tagList = splitCSV(tags)

        var relatedSection = ""
        if !relatedItems.isEmpty {
            let links = splitCSV(relatedItems)
            if !links.isEmpty {
                relatedSection = "\n## \(L10n.Creation.relatedLinks)\n" + links.map { "- \($0)" }.joined(separator: "\n") + "\n"
            }
        }

        var compareHeader = ""
        if type == .comparison {
            let a = compareItemA.trimmingCharacters(in: .whitespaces)
            let b = compareItemB.trimmingCharacters(in: .whitespaces)
            if !a.isEmpty || !b.isEmpty {
                compareHeader = "## \(a) vs \(b)\n\n"
            }
        }

        let content = """
        \(compareHeader)\(summary)

        \(bodyContent)
        \(relatedSection)
        """

        Task {
            let page = await store.createPage(
                title: title,
                pageType: type,
                content: content,
                tags: tagList
            )
            await MainActor.run {
                router.navigateToPage(id: page.id)
                dismiss()
            }
        }
    }

    /// 清理模板标题：移除 H2 前缀和换行符并修剪空白
    private func cleanTemplateTitle(_ title: String) -> String {
        title
            .replacingOccurrences(of: SystemConstants.MarkdownSyntax.h2Prefix, with: "")
            .replacingOccurrences(of: SystemConstants.Character.newline, with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    /// 关联链接分区：Divider + relatedLinks 字段
    @ViewBuilder
    private var relatedLinksSection: some View {
        Divider()
        labeledField(
            L10n.Creation.relatedLinks,
            hint: L10n.Creation.tagsPlaceholder,
            text: $relatedItems
        )
    }
}
