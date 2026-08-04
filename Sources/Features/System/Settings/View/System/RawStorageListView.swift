//
//  RawStorageListView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/21.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：构建 RawStorageList 界面的 UI 视图层组件，支持在开发调试中查看基于卡帕西 Wiki 方法论的原始页面存储详情。
//

import SwiftUI

/// [L1.5] 领域层/表现层辅助：原始存储分类强类型枚举，消除分类的硬编码魔鬼字符串
enum RawCategoryType: String, CaseIterable, Identifiable {
    case document
    case audio
    case ocr
    case web
    case clipboard
    case manual
    
    /// 遵循 Identifiable 协议的唯一识别码
    var id: String { self.rawValue }
    
    /// 获取分类对应的系统图标名称
    var systemIconName: String {
        switch self {
        case .document: return "doc.text.fill"
        case .audio: return "music.note"
        case .ocr: return "photo.fill"
        case .web: return "globe"
        case .clipboard: return "doc.on.clipboard.fill"
        case .manual: return "square.and.pencil"
        }
    }
    
    /// 获取分类对应的默认主题颜色
    var defaultColor: Color {
        switch self {
        case .document: return .teal
        case .audio: return .indigo
        case .ocr: return .orange
        case .web: return .blue
        case .clipboard: return .purple
        case .manual: return .secondary
        }
    }
    
    /// 获取分类在当前语言下的本地化可读标题
    var displayName: String {
        switch self {
        case .document: return L10n.Vault.raw.categoryDocument
        case .audio: return L10n.Vault.raw.categoryAudio
        case .ocr: return L10n.Vault.raw.categoryOcr
        case .web: return L10n.Vault.raw.categoryWeb
        case .clipboard: return L10n.Vault.raw.categoryClipboard
        case .manual: return L10n.Vault.raw.categoryManual
        }
    }
}

/// [L3] 表现层：高亮文本组件
struct HighlightedText: View {
    let text: String
    let highlight: String

    var body: some View {
        if highlight.isEmpty {
            Text(text)
        } else {
            let attributedString = getAttributedString()
            Text(attributedString)
        }
    }

    /// 执行富文本的高亮渲染逻辑
    /// - Returns: 构建好的高亮富文本对象
    private func getAttributedString() -> AttributedString {
        var attributed = AttributedString(text)
        let lowerText = text.lowercased()
        let lowerHighlight = highlight.lowercased()

        var searchIndex = lowerText.startIndex
        while searchIndex < lowerText.endIndex,
              let range = lowerText[searchIndex...].range(of: lowerHighlight) {
            let startOffset = lowerText.distance(from: lowerText.startIndex, to: range.lowerBound)
            let endOffset = lowerText.distance(from: lowerText.startIndex, to: range.upperBound)

            let chars = attributed.characters
            if let startAttrIndex = chars.index(chars.startIndex, offsetBy: startOffset, limitedBy: chars.endIndex),
               let endAttrIndex = chars.index(chars.startIndex, offsetBy: endOffset, limitedBy: chars.endIndex) {
                let attrRange = startAttrIndex..<endAttrIndex
                // Swift 6 严格并发: 不能直接 `attributed[range].foregroundColor = ...`,
                // 因为编译器会构造 `\.foregroundColor` key path,而
                // `AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute` 非 Sendable。
                // 改用 AttributeContainer 显式构造并 merge,完全绕过 key path。
                var container = AttributeContainer()
                container.foregroundColor = .appAccent
                container.backgroundColor = Color.appAccent.opacity(DesignSystem.dimmedOpacity)
                container.inlinePresentationIntent = .stronglyEmphasized
                attributed[attrRange].mergeAttributes(container)
            }
            searchIndex = range.upperBound
        }
        return attributed
    }
}

/// [L3] 表现层：渲染单个原始文件行的信息子组件
struct RawPageRow: View {
    let page: KnowledgePage
    let searchText: String
    
    // 布局常量，彻底消除魔鬼数字与硬编码
    private static let typeBadgeFontSize: CGFloat = 9
    private static let titleLineLimit = 1
    private static let tagHorizontalPadding = Spacing.tiny
    private static let tagVerticalPadding = Spacing.atomic * 0.5
    private static let itemVerticalPadding = DesignSystem.tiny
    
    /// 字节格式化助手
    /// - Parameter bytes: 字节大小
    /// - Returns: 人类可读的文件大小格式化字符串
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    var body: some View {
        HStack(spacing: DesignSystem.medium) {
            Image(systemName: page.displaySourceIcon)
                .font(.title3)
                .foregroundStyle(.appAccent)
                .frame(width: DesignSystem.Metrics.largeIconBoxSize, height: DesignSystem.Metrics.largeIconBoxSize)
                .background(Color.appAccent.opacity(DesignSystem.glassOpacity))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.smallRadius))
            
            VStack(alignment: .leading, spacing: DesignSystem.atomic) {
                // 使用高亮文本显示匹配项
                HighlightedText(text: page.title, highlight: searchText)
                    .font(.subheadline.bold())
                    .foregroundStyle(.appText)
                    .lineLimit(Self.titleLineLimit)
                
                HStack(spacing: Spacing.tiny) {
                    // 后缀名高亮显示
                    if let ext = page.sourceType {
                        HighlightedText(text: ext.uppercased(), highlight: searchText)
                            .font(.system(size: Self.typeBadgeFontSize, weight: .heavy))
                            .foregroundStyle(Color.appAccent)
                            .padding(.horizontal, Self.tagHorizontalPadding)
                            .padding(.vertical, Self.tagVerticalPadding)
                            .background(Color.appAccent.opacity(DesignSystem.subtleFillOpacity))
                            .cornerRadius(Spacing.microRadius)
                    }
                    
                    Text(L10n.Dashboard.stats.rawPageCountFormat(page.content.count, formatBytes(page.fileSize ?? Int64(page.content.utf8.count))))
                        .font(.caption2)
                        .foregroundStyle(.appSecondary)
                }
            }
            
            Spacer()
            
            Text(page.updatedAt.formatted(date: .numeric, time: .omitted))
                .font(.caption2)
                .foregroundStyle(.appSecondary)
        }
        .padding(.vertical, Self.itemVerticalPadding)
    }
}

/// [L3] 表现层：原始文件存储详情列表视图
/// 用于开发调试中展示所有 pageType == .raw 的知识页面及其存储细节
struct RawStorageListView: View {
    @Environment(KnowledgeStore.self) var store
    @Environment(Router.self) var router
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var searchText = ""
    @State private var expandedCategories: Set<RawCategoryType> = Set(RawCategoryType.allCases)
    
    // 搜索与空状态常量定义，消除魔鬼数字与硬编码
    private static let emptyStateIcon = "doc.text.magnifyingglass"
    
    // 后缀分类静态资源池，消除后缀匹配中的硬编码魔鬼字符串
    private static let documentExtensions = ["pdf", "markdown", "md", "txt", "doc", "docx", "file"]
    private static let audioExtensions = ["voice", "audio", "mp3", "m4a", "wav"]
    private static let ocrExtensions = ["ocr", "png", "jpg", "jpeg"]
    private static let webExtensions = ["link", "web", "url"]
    private static let clipboardExtensions = ["clipboard"]
    
    /// 根据原始文件的后缀名将其自动映射至对应的强类型业务分类中
    /// - Parameter page: 待映射的原始页面实体
    /// - Returns: 对应的 RawCategoryType 分类
    private func getCategory(for page: KnowledgePage) -> RawCategoryType {
        guard let st = page.sourceType?.lowercased() else { return .manual }
        if Self.documentExtensions.contains(st) {
            return .document
        } else if Self.audioExtensions.contains(st) {
            return .audio
        } else if Self.ocrExtensions.contains(st) {
            return .ocr
        } else if Self.webExtensions.contains(st) {
            return .web
        } else if Self.clipboardExtensions.contains(st) {
            return .clipboard
        } else {
            return .manual
        }
    }
    
    /// 筛选并排序后的原始页面列表
    private var filteredRawPages: [KnowledgePage] {
        let raws = store.pages.filter { $0.sourceURL != nil }
        if searchText.isEmpty {
            return raws.sorted { $0.updatedAt > $1.updatedAt }
        } else {
            return raws.filter { page in
                page.title.localizedCaseInsensitiveContains(searchText) ||
                (page.sourceType?.localizedCaseInsensitiveContains(searchText) ?? false)
            }.sorted { $0.updatedAt > $1.updatedAt }
        }
    }
    
    /// 构建针对特定强类型分类折叠状态的实时绑定实例
    /// - Parameter category: 目标原始分类类型
    /// - Returns: 折叠/展开布尔状态的双向绑定
    private func isExpandedBinding(for category: RawCategoryType) -> Binding<Bool> {
        Binding<Bool>(
            get: { expandedCategories.contains(category) },
            set: { isExpanding in
                if isExpanding {
                    expandedCategories.insert(category)
                } else {
                    expandedCategories.remove(category)
                }
            }
        )
    }
    
    var body: some View {
        ZStack {
            // 背景渲染
            themeManager.pageBackground()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 搜索框
                searchBar
                
                if filteredRawPages.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(RawCategoryType.allCases) { category in
                            let pagesInCategory = filteredRawPages.filter { getCategory(for: $0) == category }
                            if !pagesInCategory.isEmpty {
                                DisclosureGroup(isExpanded: isExpandedBinding(for: category)) {
                                    ForEach(pagesInCategory) { page in
                                        NavigationLink {
                                            RawPageDetailView(page: page)
                                        } label: {
                                            RawPageRow(page: page, searchText: searchText)
                                        }
                                        .buttonStyle(.plain)
                                        .listRowBackground(Color.appCard.opacity(DesignSystem.Opacity.disabled))
                                        .skipOnWatch { $0.listRowSeparator(.visible) }
                                    }
                                } label: {
                                    HStack(spacing: Spacing.small) {
                                        Image(systemName: category.systemIconName)
                                            .foregroundStyle(category.defaultColor)
                                        Text(category.displayName)
                                            .font(.subheadline.bold())
                                            .foregroundStyle(.appText)
                                        Spacer()
                                        Text("\(pagesInCategory.count)")
                                            .font(.caption2.bold())
                                            .foregroundStyle(.appSecondary)
                                            .padding(.horizontal, Spacing.Chip.horizontalPadding)
                                            .padding(.vertical, Spacing.atomic)
                                            .background(Color.appSecondary.opacity(DesignSystem.subtleFillOpacity))
                                            .clipShape(Capsule())
                                    }
                                    .padding(.vertical, Spacing.tiny)
                                }
                                .listRowBackground(Color.clear)
                            }
                        }
                    }
                    .listStyle(.sidebar)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(PageBackgroundView(accentColor: .appAccent))
        }
        .navigationTitle(L10n.Dashboard.stats.rawStorageTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: searchText) { newValue, _ in
            if !newValue.isEmpty {
                // 自动展开包含匹配项的父级分类目录
                let matches = store.pages.filter { $0.sourceURL != nil }
                    .filter { $0.title.localizedCaseInsensitiveContains(newValue) || ($0.sourceType?.localizedCaseInsensitiveContains(newValue) ?? false) }
                for page in matches {
                    let cat = getCategory(for: page)
                    expandedCategories.insert(cat)
                }
            }
        }
    }
    
    /// 搜索输入条
    private var searchBar: some View {
        HStack {
            Image(systemName: DesignSystem.Icons.search)
                .font(.caption)
                .foregroundStyle(.appSecondary)
            
            TextField(L10n.SearchPlaceholder, text: $searchText)
                .textFieldStyle(.plain)
                .font(.subheadline)
                .foregroundStyle(.appText)
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: DesignSystem.Icons.errorCircle)
                        .foregroundStyle(.appSecondary.opacity(DesignSystem.Opacity.dim))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DesignSystem.standardPadding)
        .padding(.vertical, DesignSystem.tightPadding)
        .background(Color.appCard.opacity(DesignSystem.Opacity.subtle))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.smallRadius))
        .padding()
    }
    
    /// 空白占位状态
    private var emptyState: some View {
        VStack(spacing: DesignSystem.medium) {
            Spacer()
            Image(systemName: Self.emptyStateIcon)
                .font(.system(size: Spacing.iconDisplay))
                .foregroundStyle(.appSecondary.opacity(DesignSystem.dimmedOpacity))
            Text(L10n.Search.noResults)
                .font(.headline)
                .foregroundStyle(.appSecondary)
            Spacer()
        }
    }
}

/// [L3] 表现层：原始页面具体内容查看详情视图
struct RawPageDetailView: View {
    let page: KnowledgePage
    @EnvironmentObject var themeManager: ThemeManager
    
    // 布局常量与默认值，彻底消除魔鬼数字与硬编码
    private static let maxSourceURLLines = 2
    private static let defaultSourceType = "TXT"
    
    /// 格式化文件大小
    /// - Parameter bytes: 字节大小
    /// - Returns: 人类可读的大小字符串
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    var body: some View {
        ZStack {
            themeManager.pageBackground()
                .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.standardPadding) {
                    // 1. 元数据卡片
                    metadataCard
                    
                    // 2. 文件内容区
                    contentSection
                }
                .padding()
            }
            .background(PageBackgroundView(accentColor: .appAccent))
        }
        .navigationTitle(L10n.Dashboard.stats.rawPageDetailTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    /// 头部元数据渲染卡片
    private var metadataCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.medium) {
            Label(page.title, systemImage: page.displaySourceIcon)
                .font(.headline)
                .foregroundStyle(.appText)
            
            Divider()
                .opacity(DesignSystem.softOpacity)
            
            // 来源链接
            if let sourceURL = page.sourceURL, !sourceURL.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.atomic) {
                    Text(L10n.Ingest.PDF.sourceURL)
                        .font(.caption2)
                        .foregroundStyle(.appSecondary)
                    Text(sourceURL)
                        .font(.caption)
                        .foregroundStyle(.appAccent)
                        .lineLimit(Self.maxSourceURLLines)
                }
            }
            
            // 来源类型与字节大小
            HStack {
                VStack(alignment: .leading, spacing: DesignSystem.atomic) {
                    Text(L10n.Ingest.OCR.pageType)
                        .font(.caption2)
                        .foregroundStyle(.appSecondary)
                    Text(page.sourceType?.uppercased() ?? Self.defaultSourceType)
                        .font(.caption.bold())
                        .foregroundStyle(.appText)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: DesignSystem.atomic) {
                    Text(L10n.Dashboard.totalStorage)
                        .font(.caption2)
                        .foregroundStyle(.appSecondary)
                    Text(formatBytes(page.fileSize ?? Int64(page.content.utf8.count)))
                        .font(.caption.bold())
                        .foregroundStyle(.appText)
                }
            }
        }
        .appContainer(padding: true)
    }
    
    /// 原始文件内容展示区
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.small) {
            Text(L10n.Ingest.PDF.contentPreview)
                .font(.subheadline.bold())
                .foregroundStyle(.appSecondary)
                .padding(.horizontal, DesignSystem.tiny)
            
            Text(page.content)
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(.appText)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.appCard.opacity(DesignSystem.Opacity.disabled))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.standardRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.standardRadius)
                        .stroke(Color.appBorder, lineWidth: DesignSystem.borderWidth)
                )
        }
    }
}
