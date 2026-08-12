//
//  KnowledgePageListView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：构建 KnowledgePageList 界面的 UI 视图层组件。
//
import SwiftUI
import UFPCore

// MARK: - Index View (entry point with NavigationStack)
@MainActor
struct KnowledgePageListView: View {
    var filterType: PageType?
    var body: some View {
        KnowledgePageListContent(filterType: filterType)
    }
}

// MARK: - Knowledge Page List Content (for use inside parent NavigationStack)
@MainActor
struct KnowledgePageListContent: View {
    @Environment(AppStore.self) var store
    @Environment(Router.self) var router
    @Environment(ThemeManager.self) var themeManager
    var filterType: PageType?
    
    /// 全局注入的平台设备环境
    private var appEnv: any AppEnvironmentProtocol {
        ServiceContainer.shared.resolve((any AppEnvironmentProtocol).self)
    }
    
    @State private var showDeleteConfirmation = false
    @State private var pageToDelete: KnowledgePage?
    @State private var showInsights = false
    @State private var searchText = ""
    
    // 全局混合搜索与语义检索核心状态
    @State private var searchResults: [KnowledgePage] = []
    @State private var isSearchingAdvanced = false
    @State private var searchTask: Task<Void, Never>?
    
    private var totalLinks: Int {
        store.pages.reduce(0) { $0 + $1.outgoingLinks.count }
    }
    
    private func filteredPages(for type: PageType) -> [KnowledgePage] {
        if isSearchingAdvanced {
            // 如果处于高级全文搜索模式下，直接按 SearchStore 算出的 RRF 混合排名的权重顺序输出过滤列表，不进行强制字典序重排
            return searchResults.filter { $0.pageType == type }
        }
        
        // 否则回退为原本的笔记本页面全量字典序排序
        return store.pages.filter { $0.pageType == type }.sorted { $0.title < $1.title }
    }
    
    private var hasSearchResults: Bool {
        if searchText.isEmpty { return true }
        if let filterType {
            return !filteredPages(for: filterType).isEmpty
        }
        return PageType.allCases.contains { type in
            !filteredPages(for: type).isEmpty
        }
    }

    private func triggerSearch(query: String) {
        searchTask?.cancel()
        
        let cleanedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedQuery.isEmpty else {
            withAnimation(.easeInOut) {
                searchResults = []
                isSearchingAdvanced = false
            }
            return
        }
        
        searchTask = Task {
            // 防抖 150ms 确连贯输入体验与节省 SQLite 核心物理 FTS5 开销
            try? await Task.sleep(for: .milliseconds(150))
            if Task.isCancelled { return }
            
            let results = await store.searchStore.performAdvancedSearch(query: cleanedQuery)
            if Task.isCancelled { return }
            
            await MainActor.run {
                withAnimation(.easeInOut) {
                    self.searchResults = results
                    self.isSearchingAdvanced = true
                }
            }
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            // 1. 方案 D 沉浸式高级背景 (同步 Hub 设计语言)
            ZStack {
                // 1. 底层：通透感深色背景
                themeManager.pageBackground().opacity(DesignSystem.translucentOpacity)
                
                MeshGradientView()
                    .blur(radius: DesignSystem.Gallery.blurRadius)
            }
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: DesignSystem.loosePadding) {
                    listView
                }
                .padding(.top, appEnv.screenClass != .compact ? 48 : 0) // 适配大屏设备（如 iPad / macOS），向下偏移避让顶部悬浮 TabBar，防止第一行内容重合遮挡
            }
            .scrollIndicators(.hidden)
            
        }
        .appSubPageToolbar(title: filterType?.displayName ?? L10n.Common.Sidebar.pageList)
        .navigationBarBackButtonHidden(false)
        .onChange(of: searchText) { _, newValue in
            triggerSearch(query: newValue)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("toggleDisplayMode"))) { _ in
            // 响应全局模式切换（如果需要）
            HapticFeedback.shared.trigger(.selection)
        }
        .sheet(isPresented: $showInsights) {
            VaultInsightsPanel()
        }
        .confirmationDialog(
            pageToDelete.map { L10n.Vault.Page.deletePageTitle( $0.title) } ?? L10n.Knowledge.Page.deletePage,
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.Knowledge.Page.deletePage, role: .destructive) {
                if let page = pageToDelete {
                    Task { await store.deletePage(page) }
                    HapticFeedback.shared.trigger(.success)
                }
            }
            Button(L10n.Common.cancel, role: .cancel) {
                pageToDelete = nil
            }
        } message: {
            Text(L10n.Settings.clearAll.message)
        }
    }
    
    @ViewBuilder
    private var listView: some View {
        LazyVStack(spacing: DesignSystem.standardPadding, pinnedViews: [.sectionHeaders]) {
            // 全局统一的高级毛玻璃搜索输入卡片，完美融合于顶端！
            searchBarSection
            
            if filterType == nil && searchText.isEmpty {
                summarySection
            }

            if store.searchStore.isSearching {
                // 如果正在执行混合检索，展示高精度骨架屏呼吸卡片
                VStack(spacing: DesignSystem.standardPadding) {
                    ForEach(0..<4) { _ in
                        HStack(spacing: DesignSystem.medium) {
                            AppSkeleton(width: DesignSystem.Sidebar.iconBoxSize, height: DesignSystem.Sidebar.iconBoxSize)
                            VStack(alignment: .leading, spacing: DesignSystem.tiny) {
                                AppSkeleton(width: 140, height: DesignSystem.standardFontSize)
                                AppSkeleton(width: 240, height: DesignSystem.microFontSize)
                            }
                            Spacer()
                        }
                    }
                    .padding(.top, DesignSystem.wide)
                }
            } else if hasSearchResults {
                if filterType == nil || filterType == .entity {
                    entitySection
                }

                if filterType == nil || filterType == .concept {
                    conceptSection
                }

                if filterType == nil || filterType == .source {
                    sourceSection
                }

                if filterType == nil || filterType == .comparison {
                    comparisonSection
                }

                if filterType == nil || filterType == .raw {
                    rawSection
                }
            } else {
                AppEmptyState.simple(
                    icon: DesignSystem.Icons.weeklyInsight,
                    title: L10n.Search.noResults,
                    description: L10n.Search.noResultsHint
                )
                .padding(.top, Spacing.Sidebar.backButtonWidth)
            }
        }
        .padding(.horizontal, DesignSystem.standardPadding)
        .padding(.vertical, DesignSystem.loosePadding)
        .padding(.bottom, DesignSystem.huge)
    }
    
    @ViewBuilder
    private var summarySection: some View {
        Section {
            HStack(spacing: DesignSystem.standardPadding) {
                KnowledgeStatItem(label: L10n.Dashboard.totalPages, value: "\(store.pages.count)", color: .appAccent)
                KnowledgeStatItem(label: L10n.Dashboard.totalLinks, value: "\(totalLinks)", color: .appSource)
                KnowledgeStatItem(label: L10n.Dashboard.pageList.tags, value: "\(store.tags.count)", color: .appConcept)
                KnowledgeStatItem(label: L10n.Dashboard.pageList.sources, value: "\(store.sourceCount)", color: .appSource)
            }
            .padding(.horizontal, DesignSystem.tiny)
            .padding(.vertical, DesignSystem.tiny)
        } header: {
            HStack {
                Text(L10n.Dashboard.pageList.overview)
                    .font(.subheadline.bold())
                    .foregroundStyle(.appSecondary)
                Spacer()
            }
            .padding(.vertical, DesignSystem.tiny)
        }
    }
    
    @ViewBuilder
    private func selectablePageRow(_ page: KnowledgePage) -> some View {
        NavigationLink(value: AppRoute.pageDetail(id: page.id)) {
            PageRowView(page: page)
        }
        .accessibilityIdentifier("PageRow_Item")
        .buttonStyle(AppPressButtonStyle())
    }

    @ViewBuilder
    private var entitySection: some View {
        let entities = filteredPages(for: .entity)
        if !entities.isEmpty {
            Section {
                VStack(spacing: DesignSystem.medium) {
                    ForEach(entities) { page in
                        selectablePageRow(page)
                    }
                }
            } header: {
                HStack {
                    Label(L10n.Dashboard.pageList.entityCount(entities.count), systemImage: DesignSystem.Icons.entity)
                        .font(.subheadline.bold())
                        .foregroundStyle(.appEntity)
                    Spacer()
                }
                .padding(.vertical, DesignSystem.tiny)
            }
        }
    }
    
    @ViewBuilder
    private var conceptSection: some View {
        let concepts = filteredPages(for: .concept)
        if !concepts.isEmpty {
            Section {
                VStack(spacing: DesignSystem.medium) {
                    ForEach(concepts) { page in
                        selectablePageRow(page)
                    }
                }
            } header: {
                HStack {
                    Label(L10n.Dashboard.pageList.conceptCount(concepts.count), systemImage: DesignSystem.Icons.concept)
                        .font(.subheadline.bold())
                        .foregroundStyle(.appConcept)
                    Spacer()
                }
                .padding(.vertical, DesignSystem.tiny)
            }
        }
    }
    
    @ViewBuilder
    private var sourceSection: some View {
        let sources = filteredPages(for: .source)
        if !sources.isEmpty {
            Section {
                VStack(spacing: DesignSystem.medium) {
                    ForEach(sources) { page in
                        selectablePageRow(page)
                    }
                }
            } header: {
                HStack {
                    Label(L10n.Dashboard.pageList.sourceCount(sources.count), systemImage: DesignSystem.Icons.source)
                        .font(.subheadline.bold())
                        .foregroundStyle(.appSource)
                    Spacer()
                }
                .padding(.vertical, DesignSystem.tiny)
            }
        }
    }
    
    @ViewBuilder
    private var comparisonSection: some View {
        let comparisons = filteredPages(for: .comparison)
        if !comparisons.isEmpty {
            Section {
                VStack(spacing: DesignSystem.medium) {
                    ForEach(comparisons) { page in
                        selectablePageRow(page)
                    }
                }
            } header: {
                HStack {
                    Label(L10n.Dashboard.pageList.comparisonCount(comparisons.count), systemImage: DesignSystem.Icons.comparison)
                        .font(.subheadline.bold())
                        .foregroundStyle(.appComparison)
                    Spacer()
                }
                .padding(.vertical, DesignSystem.tiny)
            }
        }
    }

    @ViewBuilder
    private var rawSection: some View {
        let raws = filteredPages(for: .raw)
        if !raws.isEmpty {
            Section {
                VStack(spacing: DesignSystem.medium) {
                    ForEach(raws) { page in
                        selectablePageRow(page)
                    }
                }
            } header: {
                HStack {
                    Label(L10n.Dashboard.pageList.rawCount(raws.count), systemImage: DesignSystem.Icons.raw)
                        .font(.subheadline.bold())
                        .foregroundStyle(.gray)
                    Spacer()
                }
                .padding(.vertical, DesignSystem.tiny)
            }
        }
    }
    
    @ViewBuilder
    private var searchBarSection: some View {
        HStack(spacing: DesignSystem.medium) {
            Image(systemName: DesignSystem.Icons.search)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.appAccent)
            
            TextField(L10n.SearchPlaceholder, text: $searchText)
                .textFieldStyle(.plain)
                .font(.subheadline)
                .foregroundStyle(.appText)
                .accessibilityIdentifier("searchPlaceholder")
                .submitLabel(.search)
                .onSubmit {
                    if !searchText.isEmpty {
                        triggerSearch(query: searchText)
                    }
                }

            if !searchText.isEmpty {
                Button(action: { 
                    searchText = ""
                    triggerSearch(query: "")
                }) {
                    Image(systemName: DesignSystem.Icons.errorCircle)
                        .foregroundStyle(.appSecondary.opacity(DesignSystem.Opacity.dim))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DesignSystem.standardPadding)
        .padding(.vertical, DesignSystem.tightPadding + DesignSystem.atomic)
        .background(Color.appCard.opacity(DesignSystem.Opacity.dim))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.mediumRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.mediumRadius, style: .continuous)
                .strokeBorder(Color.appAccent.opacity(DesignSystem.Opacity.medium), lineWidth: DesignSystem.borderWidth)
        )
        .padding(.horizontal, DesignSystem.tiny)
        .padding(.bottom, DesignSystem.tiny)
    }
}

// MARK: - Knowledge Stat Item
struct KnowledgeStatItem: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: DesignSystem.tiny) {
            Text(label)
                .font(.caption.weight(.bold))
                .foregroundStyle(.appSecondary)
                .textCase(.uppercase)
            
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.medium)
        .background(Color.appCard.opacity(DesignSystem.Opacity.prominent))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.cardRadius)
                .stroke(.white.opacity(DesignSystem.accentStrokeOpacity), lineWidth: DesignSystem.borderWidth / 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cardRadius))
        .shadow(color: .primary.opacity(DesignSystem.shadowOpacity), radius: DesignSystem.small, x: 0, y: DesignSystem.tiny)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.cardRadius)
                .stroke(color.opacity(DesignSystem.dimmedOpacity), lineWidth: DesignSystem.borderWidth)
        )
        .shadow(color: .primary.opacity(DesignSystem.shadowOpacity * DesignSystem.subtleOpacity), radius: DesignSystem.medium, x: 0, y: DesignSystem.tiny)
    }
}

// MARK: - App Press Button Style
struct AppPressButtonStyle: ButtonStyle {

    /// 创建Body
    /// - Parameter configuration: configuration
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? DesignSystem.Action.pressScale : 1.0)
            .opacity(configuration.isPressed ? DesignSystem.pressedOpacity : 1.0)
            .animation(.spring(response: DesignSystem.Animation.springResponse, dampingFraction: DesignSystem.Animation.springDamping), value: configuration.isPressed)
    }
}
