//
//  SearchView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：构建 Search 界面的 UI 视图层组件。
//
import SwiftUI

struct SearchView: View {
    @Environment(KnowledgeStore.self) var store
    @Environment(SearchStore.self) var searchStore
    @Environment(Router.self) var router
    // 初始值 (由外部传入)
    let initialQuery: String?
    let initialFilterType: PageType?
    
    @State private var searchText = ""
    @State private var filterType: PageType?
    @State private var filterStatus: PageStatus?
    @State private var sortBy: SortOption = .updated
    @EnvironmentObject var themeManager: ThemeManager
    @State private var previewPage: KnowledgePage?
    @State private var advancedResults: [KnowledgePage] = []
    @State private var useAdvancedSearch = false
    @State private var showDiagnostics = false
    
    init(initialQuery: String? = nil, initialFilterType: PageType? = nil) {
        self.initialQuery = initialQuery
        self.initialFilterType = initialFilterType
        // 注意：SwiftUI @State 在 init 中只能通过 _ 赋值，但通常我们在 onAppear 中应用初始值更稳妥，
        // 或者在此处直接初始化 _searchText。
        self._searchText = State(initialValue: initialQuery ?? "")
        self._filterType = State(initialValue: initialFilterType)
    }
    
    enum SortOption: String, CaseIterable {
        case updated = "search.sort.recentlyUpdated"
        case created = "search.sort.recentlyCreated"
        case title = "search.sort.title"
        case type = "search.sort.type"
    }
    
    var filteredPages: [KnowledgePage] {
        if useAdvancedSearch && !advancedResults.isEmpty {
            return advancedResults
        }
        
        var result = store.pages
        
        // Text search
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { page in
                page.title.lowercased().contains(query) ||
                page.content.lowercased().contains(query) ||
                page.tags.contains(where: { $0.lowercased().contains(query) }) ||
                page.aliases.contains(where: { $0.lowercased().contains(query) })
            }
        }
        
        // Type filter
        if let type = filterType {
            result = result.filter { $0.pageType == type }
        }
        
        // Status filter
        if let status = filterStatus {
            result = result.filter { $0.status == status }
        }
        
        // Sort
        switch sortBy {
        case .updated:
            result.sort { $0.updatedAt > $1.updatedAt }
        case .created:
            result.sort { $0.createdAt > $1.createdAt }
        case .title:
            result.sort { $0.title < $1.title }
        case .type:
            result.sort { $0.pageType.rawValue < $1.pageType.rawValue }
        }
        
        return result
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Header (Bar + Filters)
            VStack(spacing: DesignSystem.medium) {
                // Unified Search Bar
            // 1. 现代风格搜索区域 (对齐图 3)
            HStack {
                Image(systemName: DesignSystem.Icons.search)
                    .font(.callout.weight(.bold))
                    .foregroundStyle(.appAccent)
                
                TextField(L10n.SearchPlaceholder, text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.callout)
                    .accessibilityIdentifier("searchPlaceholder")
                    .submitLabel(.search)
                    .onSubmit {
                        if !searchText.isEmpty {
                            runAdvancedSearch()
                        }
                    }

                if !searchText.isEmpty {
                    Button(action: { 
                        searchText = ""
                        useAdvancedSearch = false
                        advancedResults = []
                    }) {
                        Image(systemName: DesignSystem.Icons.errorCircle)
                            .foregroundStyle(.appSecondary.opacity(DesignSystem.Opacity.dim))
                    }
                }
            }
            .padding(.horizontal, DesignSystem.standardPadding)
            .padding(.vertical, DesignSystem.tightPadding + DesignSystem.atomic)
            .background(Color.appCard.opacity(DesignSystem.Opacity.dim))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.mediumRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.mediumRadius, style: .continuous)
                    .strokeBorder(.appAccent.opacity(DesignSystem.Opacity.medium), lineWidth: 1)
            )
            .padding(.horizontal, DesignSystem.standardPadding)
            .padding(.vertical, DesignSystem.medium)
                
                // Filters
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignSystem.small) {
                        FilterPill(title: L10n.Search.all, accessibilityIdentifier: "filter-all", isSelected: filterType == nil) {
                            HapticFeedback.shared.trigger(.selection)
                            filterType = nil
                        }

                        // 遍历用户可见页面类型，屏蔽 raw 选项
                        ForEach(PageType.allVisibleCases) { type in
                            FilterPill(
                                title: type.displayName,
                                icon: type.icon,
                                color: Color.fromModelColorName(type.colorName),
                                accessibilityIdentifier: "filter-\(type.rawValue)",
                                isSelected: filterType == type
                            ) {
                                HapticFeedback.shared.trigger(.selection)
                                filterType = type
                            }
                        }

                        Divider().frame(height: DesignSystem.IconSize.standard).background(Color.appBorder)

                        // Status Filters
                        #if !os(watchOS)
                        Menu {
                            Button(L10n.Common.all) { filterStatus = nil }
                            ForEach(PageStatus.allCases, id: \.self) { status in
                                Button(status.displayName) { filterStatus = status }
                            }
                        } label: {
                            HStack(spacing: DesignSystem.tiny) {
                                Image(systemName: DesignSystem.Icons.flag)
                                    .font(.caption)
                                Text(filterStatus?.displayName ?? L10n.Knowledge.Page.status)
                                    .font(.caption)
                            }
                            .padding(.horizontal, DesignSystem.tightPadding + DesignSystem.atomic) // 10
                            .padding(.vertical, DesignSystem.tiny + DesignSystem.atomic) // 5
                            .background(filterStatusBackgroundColor)
                            .clipShape(Capsule())
                            .foregroundStyle(filterStatusLabelColor)
                        }
                        .buttonStyle(.plain)
                        #endif

                        Divider().frame(height: DesignSystem.IconSize.standard).background(Color.appBorder)

                        // Sort options
                        #if !os(watchOS)
                        Menu {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                Button(action: { sortBy = option }) {
                                    Label(L10n.Common.tr(option.rawValue), systemImage: sortBy == option ? DesignSystem.Icons.check : "")
                                }
                            }
                        } label: {
                            HStack(spacing: DesignSystem.tiny) {
                                Image(systemName: DesignSystem.Icons.sortUpDown)
                                    .font(.caption)
                                Text(L10n.Common.tr(sortBy.rawValue))
                                    .font(.caption)
                            }
                            .padding(.horizontal, DesignSystem.tightPadding + DesignSystem.atomic) // 10
                            .padding(.vertical, DesignSystem.tiny + DesignSystem.atomic) // 5
                            .background(Color.appCard.opacity(DesignSystem.Opacity.prominent))
                            .clipShape(Capsule())
                            .foregroundStyle(.appSecondary)
                        }
                        .buttonStyle(.plain)
                        #endif
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.top, DesignSystem.medium)
            .background(Color.appBackground.opacity(DesignSystem.Opacity.disabled))
            .background(.ultraThinMaterial)
            
            // Main Results Content
            ZStack {
                if searchStore.isSearching {
                    VStack(spacing: DesignSystem.standardPadding) {
                        ForEach(0..<6) { _ in
                            HStack(spacing: DesignSystem.medium) {
                                AppSkeleton(width: DesignSystem.Sidebar.iconBoxSize, height: DesignSystem.Sidebar.iconBoxSize) // 44
                                VStack(alignment: .leading, spacing: DesignSystem.tiny) {
                                    AppSkeleton(width: 140, height: DesignSystem.standardFontSize)
                                    AppSkeleton(width: 240, height: DesignSystem.microFontSize)
                                }

                                Spacer()
                            }
                            .padding(.horizontal)
                        }
                        Spacer()
                    }
                    .padding(.top, DesignSystem.Action.iconSize) // 20
                } else if filteredPages.isEmpty {
                    VStack(spacing: DesignSystem.standardPadding) {
                        Spacer()
                        Image(systemName: searchText.isEmpty ? DesignSystem.Icons.search : DesignSystem.Icons.weeklyInsight)
                            .font(.system(size: DesignSystem.Metrics.heroValueSize * 1.5)) // 48
                            .foregroundStyle(.appSecondary.opacity(DesignSystem.secondaryOpacity * 0.625)) // 0.5
                        
                        Text(searchText.isEmpty ? L10n.SearchPlaceholder : L10n.Search.noResults)
                            .font(.headline)
                            .foregroundStyle(.appSecondary)
                        
                        if !searchText.isEmpty {
                            Text(L10n.Search.noResultsHint)
                                .font(.caption)
                                .foregroundStyle(.appSecondary.opacity(DesignSystem.secondaryOpacity * 0.875)) // 0.7
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, DesignSystem.huge)
                        }
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(filteredPages) { page in
                            Button(action: {
                                HapticFeedback.shared.trigger(.selection)
                                router.navigate(to: .pageDetail(id: page.id))
                            }) {
                                PageRowView(page: page)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.clear)
                            #if !os(watchOS)
                            .listRowSeparator(.hidden)
                            #endif
                            .contextMenu {
                                Button {
                                    HapticFeedback.shared.trigger(.selection)
                                    previewPage = page
                                } label: {
                                    Label(L10n.Common.quickPreview, systemImage: DesignSystem.Icons.eye)
                                }
                                
                                Button {
                                    AppPasteboard.string = "[[\(page.title)]]"
                                } label: {
                                    Label(L10n.Common.copyPageLink, systemImage: "link")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .animation(.default, value: searchStore.isSearching)
            .animation(.default, value: filteredPages.isEmpty)
            
            // Footer
            if !filteredPages.isEmpty {
                Divider().background(Color.appBorder.opacity(DesignSystem.secondaryOpacity * 0.625)) // 0.5
                HStack {
                    Text(L10n.Search.pagesCount(filteredPages.count))
                        .font(.caption)
                        .foregroundStyle(.appSecondary)
                    
                    if useAdvancedSearch {
                        Spacer()
                        Button(action: { showDiagnostics = true }) {
                            Label(L10n.Search.Diagnostics, systemImage: DesignSystem.Icons.info)
                                .font(.caption2)
                                .foregroundStyle(.appAccent)
                        }
                    } else {
                        Spacer()
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, DesignSystem.tightPadding + DesignSystem.atomic) // 10
                .background(themeManager.pageBackground())
            }
        }
        .appTabToolbar(title: L10n.Search.title)
        .background(themeManager.pageBackground())
        .sheet(item: $previewPage) { page in
            PagePreviewSheet(page: page)
        }
        .sheet(isPresented: $showDiagnostics) {
            if let diag = searchStore.lastSearchDiagnostic {
                SearchDiagnosticSheet(info: diag)
            }
        }
    }
    
    private func runAdvancedSearch() {
        if useAdvancedSearch {
            withAnimation {
                useAdvancedSearch = false
                advancedResults = []
                searchStore.clearAll()
            }
            return
        }
        
        HapticFeedback.shared.trigger(.selection)
        Task {
            // 注意：SearchStore 内部已经处理了 isSearching 状态
            let results = await searchStore.performAdvancedSearch(query: searchText)
            await MainActor.run {
                withAnimation {
                    self.advancedResults = results
                    self.useAdvancedSearch = true
                }
            }
        }
    }
    
    private var filterStatusLabelColor: Color {
        filterStatus == nil ? .appSecondary : .appAccent
    }
    
    private var filterStatusBackgroundColor: Color {
        filterStatus == nil ? Color.appCard.opacity(DesignSystem.Opacity.prominent) : Color.appAccent.opacity(DesignSystem.glassOpacity / 1.5)
    }
}

// MARK: - Filter Pill
struct FilterPill: View {
    let title: String
    var icon: String?
    var color: Color = .appAccent
    var accessibilityIdentifier: String?
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// 大屏幕下使用 body 字体（约 17pt），小屏幕用 subheadline（约 15pt）
    private var pillFont: Font {
        horizontalSizeClass == .regular ? .body : .subheadline
    }

    var body: some View {
        HStack(spacing: DesignSystem.tiny + DesignSystem.atomic) { // 6
            if let icon = icon {
                Image(systemName: icon)
                    .font(horizontalSizeClass == .regular ? .subheadline : .caption)
            }
            Text(title)
                .font(pillFont.weight(isSelected ? .semibold : .regular))
        }
        .padding(.horizontal, DesignSystem.Chip.horizontalPadding)
        .padding(.vertical, DesignSystem.Chip.verticalPadding + DesignSystem.atomic) // 6
        .background(isSelected ? color.opacity(DesignSystem.Opacity.subtle) : Color.appCard.opacity(DesignSystem.Opacity.dim))
        .clipShape(Capsule())
        .foregroundStyle(isSelected ? color : .appSecondary)
        .contentShape(Capsule())
        .onTapGesture(perform: action)
        .accessibilityIdentifier(accessibilityIdentifier ?? title)
    }
}

struct SearchBadgeView: View {
    let label: String
    let color: Color
    var body: some View {
        Text(label)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, Spacing.Chip.horizontalPadding) // 6
            .padding(.vertical, Spacing.Chip.verticalPadding) // 3
            .background(color.opacity(DesignSystem.Opacity.subtle)) // 0.12
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}
