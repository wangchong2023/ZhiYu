//
//  PluginCenterView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：构建 PluginCenter 界面的 UI 视图层组件，支持在插件中心展示各示意插件的独立专属图标。
//

import SwiftUI
import Dependencies

/// 插件中心 (Stub: 为未来生态预留位置)
struct PluginCenterView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(Router.self) var router
    @Dependency(\.pluginRegistry) var registry
    @StateObject private var marketService: PluginMarketService

    @State private var selectedTab = 0
    @State private var searchText = ""
    @State private var isSafeModeOn = true
    @State private var showSafeModeWarning = false
    @State private var showFileImporter = false
    @State private var selectedCategory: String?

    /// 初始化插件中心视图，注入 PluginMarketService 依赖
    init() {
        @Dependency(\.pluginRegistry) var registry: PluginRegistry
        _marketService = StateObject(wrappedValue: PluginMarketService(registry: registry))
    }

    var body: some View {
        VStack(spacing: 0) {
            // 1. 高级搜索与筛选头部
            headerSection
            
            // 分类筛选 Chip 药丸栏
            categoryPillsSection
                .padding(.top, DesignSystem.tiny)
            
            // 2. 分段切换 (带动效)
            Picker("", selection: $selectedTab) {
                Text(L10n.Plugin.marketTitle).tag(0)
                Text(L10n.Plugin.myPlugins).tag(1)
            }
            .segmentedPickerStyleIfAvailable()
            .padding(.horizontal)
            .padding(.vertical, DesignSystem.small)
            
            // 3. 内容主体
            ScrollView {
                if selectedTab == 0 {
                    marketSection
                } else {
                    myPluginsSection
                }
            }
        }
        .background(PageBackgroundView(accentColor: .appAccent))
        .id(router.languageForceUpdate)
        .navigationTitle(L10n.Plugin.centerTitle)
        .appNavigationBarTitleDisplayMode(.inline)
        .task {
            await marketService.fetchPlugins()
        }
        .skipOnWatch { $0.fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.item]) { _ in
            // 处理文件选择结果
        } }
        .confirmationDialog(
            L10n.Plugin.safeModeWarningTitle,
            isPresented: $showSafeModeWarning,
            titleVisibility: .visible
        ) {
            Button(L10n.Plugin.safeModeTurnOff, role: .destructive) {
                isSafeModeOn = false
                HapticFeedback.shared.trigger(.warning)
            }
            Button(L10n.Common.cancel, role: .cancel) {
                isSafeModeOn = true
            }
        } message: {
            Text(L10n.Plugin.safeModeWarningMessage)
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(L10n.Common.done) {
                    dismiss()
                }
            }
        }
    }
    
    /// 头部筛选栏
    private var headerSection: some View {
        VStack(spacing: DesignSystem.standardPadding) {
            // 搜索框：玻璃拟态
            HStack {
                Image(systemName: DesignSystem.Icons.search)
                    .foregroundStyle(.appAccent)
                TextField(L10n.Plugin.searchPlaceholder, text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(DesignSystem.medium)
            .background(Color.appCard)
            .clipShape(RoundedRectangle(cornerRadius: SystemRadius.card))
            .overlay(RoundedRectangle(cornerRadius: SystemRadius.card).stroke(Color.appBorder.opacity(SystemOpacity.disabled), lineWidth: SystemStroke.hairline))
            
            // 安全模式与加载按钮
            HStack(spacing: DesignSystem.large) {
                // 安全模式切换
                HStack(spacing: DesignSystem.small) {
                    Image(systemName: isSafeModeOn ? DesignSystem.Icons.shieldFill : DesignSystem.Icons.shieldSlash)
                        .font(.subheadline.bold())
                        .foregroundStyle(.appAccent)
                    
                    Text(L10n.Plugin.safeModeTitle)
                        .font(.subheadline.bold())
                        .foregroundStyle(.appText)
                        .lineLimit(1)
                    
                    Toggle("", isOn: Binding(
                        get: { isSafeModeOn },
                        set: { newValue in
                            if !newValue {
                                showSafeModeWarning = true
                            } else {
                                isSafeModeOn = true
                            }
                        }
                    ))
                    .labelsHidden()
                    .controlSize(.mini)
                    .tint(.appAccent)
                }
                
                // 加载本地插件 Action
                Button(action: {
                    HapticFeedback.shared.trigger(.selection)
                    showFileImporter = true
                }) {
                    Label(L10n.Plugin.local.mount, systemImage: DesignSystem.Icons.plusCircle)
                        .font(.subheadline.bold())
                        .foregroundStyle(.appAccent)
                }
                
                Spacer() // 靠左对齐
            }
            .padding(.top, DesignSystem.tiny)
        }
        .padding()
        .background(Color.clear)
    }
    
    /// 本地已启用/已安装的插件列表区域
    private var myPluginsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.widePadding) {
            let filtered = registry.plugins.filter { plugin in
                let matchesSearch = searchText.isEmpty || plugin.manifest.name.localizedCaseInsensitiveContains(searchText)
                let matchesCategory: Bool
                if let sel = selectedCategory {
                    if sel == "other" {
                        matchesCategory = plugin.manifest.category == nil || plugin.manifest.category == "other"
                    } else {
                        matchesCategory = plugin.manifest.category == sel
                    }
                } else {
                    matchesCategory = true
                }
                return matchesSearch && matchesCategory
            }
            
            if !filtered.isEmpty {
                Text(L10n.Plugin.Status.enabled)
                    .font(.caption.bold())
                    .foregroundStyle(.appSecondary)
                    .padding(.horizontal)
                
                ForEach(filtered, id: \.manifest.id) { plugin in
                    NavigationLink {
                        LocalPluginDetailView(manifest: plugin.manifest)
                    } label: {
                        // 传入特定本地示意插件的功能性图标名称，避免显示单一的拼图块图标
                        PluginCard(
                            name: plugin.manifest.name,
                            version: plugin.manifest.version,
                            icon: localIconName(for: plugin.manifest.id),
                            pluginID: plugin.manifest.id,
                            source: determineSource(for: plugin.manifest.id),
                            isLocal: true
                        )
                    }
                }
                .padding(.horizontal)
            } else if searchText.isEmpty {
                if selectedCategory != nil && !registry.plugins.isEmpty {
                    AppEmptyState.simple(
                        icon: DesignSystem.Icons.pluginOutline,
                        title: L10n.Plugin.noPluginsInCategory,
                        description: L10n.Plugin.noPluginsInCategoryHint
                    )
                    .padding(.vertical, DesignSystem.giant)
                } else {
                    AppEmptyState.simple(
                        icon: DesignSystem.Icons.pluginOutline,
                        title: L10n.Plugin.noPlugins,
                        description: L10n.Plugin.noPluginsHint
                    )
                    .padding(.vertical, DesignSystem.giant)
                }
            } else {
                AppEmptyState.simple(
                    icon: DesignSystem.Icons.search,
                    title: L10n.Plugin.noResults,
                    description: L10n.Plugin.noResultsHint
                )
                .padding(.vertical, DesignSystem.giant)
            }
        }
    }
    
    /// 远端/社区插件市场的插件列表区域
    private var marketSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.standardPadding) {
            if marketService.isLoading {
                ProgressView()
                    .padding(.top, DesignSystem.Gallery.splashIconSize - DesignSystem.tightPadding)
                    .frame(maxWidth: .infinity)
            } else {
                if let errorMessage = marketService.errorMessage {
                    AppEmptyState.withAction(
                        icon: "wifi.slash",
                        title: L10n.Plugin.market.connectionError,
                        description: errorMessage,
                        actionLabel: L10n.Shared.retryButton,
                        actionIcon: "arrow.clockwise"
                    ) {
                        Task {
                            await marketService.fetchPlugins()
                        }
                    }
                    .padding(.vertical, DesignSystem.giant)
                } else {
                    let filtered = marketService.availablePlugins.filter { p in
                        let matchesSearch = searchText.isEmpty || p.name.localizedCaseInsensitiveContains(searchText)
                        let matchesCategory: Bool
                        if let sel = selectedCategory {
                            if sel == "other" {
                                matchesCategory = p.category == nil || p.category == "other"
                            } else {
                                matchesCategory = p.category == sel
                            }
                        } else {
                            matchesCategory = true
                        }
                        return matchesSearch && matchesCategory
                    }
                    
                    if filtered.isEmpty {
                        AppEmptyState.simple(
                            icon: DesignSystem.Icons.storefront,
                            title: L10n.Plugin.market.empty,
                            description: L10n.Plugin.market.emptyHint
                        )
                        .padding(.vertical, DesignSystem.giant)
                    } else {
                        ForEach(filtered) { p in
                            NavigationLink(destination: PluginDetailView(plugin: p, marketService: marketService)) {
                                PluginCard(
                                    name: p.name,
                                    version: p.version,
                                    author: p.author,
                                    downloads: p.downloads,
                                    rating: p.rating,
                                    icon: p.icon,
                                    pluginID: p.id,
                                    source: .community,
                                    marketPlugin: p,
                                    marketService: marketService
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
    }

    /// 根据本地已安装插件 ID 的特征动态匹配合适的功能性 SF Symbol 图标，保证各示意插件图标各具特色
    private func localIconName(for id: String) -> String {
        if id.contains("toc-generator") {
            return "list.bullet.rectangle.portrait"
        } else if id.contains("word-counter") {
            return "character.textbox"
        } else if id.contains("smart-cleaner") {
            return "wand.and.stars"
        } else if id.contains("ai-summary") {
            return "brain.head.profile"
        } else if id.contains("code-highlighter") {
            return "curlybraces"
        } else if id.contains("link-preview") {
            return "link"
        } else if id.contains("ai-translator") {
            return "translate"
        } else if id.contains("markdown-beautifier") {
            return "doc.text.magnifyingglass"
        } else {
            return "puzzlepiece.fill"
        }
    }

    /// 动态研判已安装插件的真实来源属性（若在社区插件列表内匹配则为community，否则为local）
    private func determineSource(for pluginID: String) -> PluginSource {
        let isMarket = marketService.availablePlugins.contains { marketPlugin in
            pluginID == marketPlugin.id || pluginID.hasSuffix("." + marketPlugin.id)
        }
        return isMarket ? .community : .local
    }

    private var categoryPillsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.small) {
                categoryPill(title: L10n.Plugin.Category.all, category: nil)
                categoryPill(title: L10n.Plugin.Category.efficiency, category: "efficiency")
                categoryPill(title: L10n.Plugin.Category.social, category: "social")
                categoryPill(title: L10n.Plugin.Category.reading, category: "reading")
                categoryPill(title: L10n.Plugin.Category.other, category: "other")
            }
            .padding(.horizontal)
            .padding(.vertical, DesignSystem.tiny)
        }
    }
    
    private func categoryPill(title: String, category: String?) -> some View {
        let isSelected = selectedCategory == category
        return Text(title)
            .font(.caption.bold())
            .padding(.horizontal, SystemSpacing.medium)
            .padding(.vertical, SystemSpacing.small)
            .background(isSelected ? Color.appAccent : Color.appCard.opacity(DesignSystem.Opacity.dim))
            .foregroundColor(isSelected ? .white : .appText)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : Color.appBorder.opacity(DesignSystem.Opacity.prominent), lineWidth: SystemStroke.hairline)
            )
            .onTapGesture {
                HapticFeedback.shared.trigger(.selection)
                withAnimation {
                    selectedCategory = category
                }
            }
    }
}

/// 插件来源类型
enum PluginSource: String {
    case local
    case community
}

/// 插件卡片通用视图组件
struct PluginCard: View {
    let name: String
    let version: String
    var author: String?
    var downloads: String?
    var rating: Double?
    var icon: String = "puzzlepiece.fill"
    var pluginID: String?
    var source: PluginSource?
    var isLocal: Bool = false
    var marketPlugin: MarketPlugin?
    var marketService: PluginMarketService?
    
    private var isInstalled: Bool {
        guard let id = pluginID else { return false }
        return registry.plugins.contains {
            $0.manifest.id == id || $0.manifest.id.hasSuffix("." + id)
        }
    }

    @Dependency(\.pluginRegistry) var registry
    @State private var localIcon: UIImage?

    /// 自适应计算插件的展示版本号，已安装则优先显示真实本地版本号
    private var displayVersion: String {
        if let id = pluginID, let localPlugin = registry.plugins.first(where: { 
            $0.manifest.id == id || $0.manifest.id.hasSuffix("." + id) 
        }) {
            return localPlugin.manifest.version
        }
        return version
    }

    var body: some View {
        HStack(spacing: DesignSystem.standardPadding) {
            // 优先显示本地 icon.png，fallback SF Symbol
            if let uiImage = localIcon {
                Image(uiImage: uiImage)
                    .renderingMode(.original)
                    .resizable().scaledToFit()
                    .frame(width: DesignSystem.Action.minTouchTarget, height: DesignSystem.Action.minTouchTarget)
                    .clipShape(RoundedRectangle(cornerRadius: SystemRadius.card, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: SystemRadius.card, style: .continuous).stroke(Color.appBorder.opacity(SystemOpacity.glass), lineWidth: SystemStroke.hairline))
            } else if let iconURL = URL(string: icon), iconURL.scheme?.hasPrefix("http") == true {
                CachedAsyncImage(url: iconURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable().scaledToFit()
                    case .empty:
                        // 网络图标加载中时，展示静止淡雅的拼图占位符，去除凌乱的局部菊花与闪烁
                        Image(systemName: "puzzlepiece.extension.fill")
                            .font(.title3)
                            .foregroundStyle(.appSecondary.opacity(DesignSystem.disabledOpacity))
                            .frame(width: DesignSystem.Action.minTouchTarget, height: DesignSystem.Action.minTouchTarget)
                            .background(Color.appCard.opacity(DesignSystem.Opacity.prominent))
                    case .failure:
                        // 远程图标拉取失败时，fallback 到带渐变底的拼图块默认图标
                        Image(systemName: "puzzlepiece.extension.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .frame(width: DesignSystem.Action.minTouchTarget, height: DesignSystem.Action.minTouchTarget)
                            .background(LinearGradient(colors: [Color.appAccent, Color.appAccent.opacity(SystemOpacity.active)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    @unknown default:
                        Image(systemName: "puzzlepiece.extension.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .frame(width: DesignSystem.Action.minTouchTarget, height: DesignSystem.Action.minTouchTarget)
                            .background(LinearGradient(colors: [Color.appAccent, Color.appAccent.opacity(SystemOpacity.active)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    }
                }
                .frame(width: DesignSystem.Action.minTouchTarget, height: DesignSystem.Action.minTouchTarget)
                .clipShape(RoundedRectangle(cornerRadius: SystemRadius.card, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: SystemRadius.card, style: .continuous).stroke(Color.theme.white.opacity(SystemOpacity.glass), lineWidth: SystemStroke.hairline))
            } else {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: DesignSystem.Action.minTouchTarget, height: DesignSystem.Action.minTouchTarget)
                    .background(LinearGradient(colors: [Color.appAccent, Color.appAccent.opacity(SystemOpacity.active)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .clipShape(RoundedRectangle(cornerRadius: SystemRadius.card, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: SystemRadius.card, style: .continuous).stroke(Color.theme.white.opacity(SystemOpacity.glass), lineWidth: SystemStroke.hairline))
            }
            
            VStack(alignment: .leading, spacing: DesignSystem.tiny) {
                Text(name)
                    .font(.subheadline.bold())
                    .foregroundStyle(.appText)
                
                HStack(spacing: DesignSystem.tightPadding) {
                    Text("v\(displayVersion)")
                        .font(.caption2)
                        .foregroundStyle(.appSecondary)
                    
                    // 来源类型微缩标签
                    if let src = source {
                        Text(sourceLabel(src))
                            .font(.system(size: DesignSystem.microFontSize, weight: .bold))
                            .padding(.horizontal, SystemSpacing.tiny)
                            .padding(.vertical, SystemSpacing.atomic)
                            .background(sourceColor(src))
                            .clipShape(Capsule())
                            .foregroundStyle(.white)
                    }
                    
                    if let author = author {
                        Text(DesignSystem.Icons.bullet)
                            .font(.caption2)
                            .foregroundStyle(.appSecondary)
                        Text(author)
                            .font(.caption2)
                            .foregroundStyle(.appSecondary)
                    }
                }
                
                if let downloads = downloads, let rating = rating {
                    HStack(spacing: DesignSystem.tightPadding) {
                        Label(downloads, systemImage: DesignSystem.Icons.arrowDownCircle)
                            .font(.system(size: DesignSystem.microFontSize))
                        Label(String(format: "%.1f", rating), systemImage: DesignSystem.Icons.star)
                            .font(.system(size: DesignSystem.microFontSize))
                            .foregroundStyle(.yellow)
                    }
                    .foregroundStyle(.appSecondary)
                    .padding(.top, SystemSpacing.atomic)
                }
            }
            Spacer()
            
            // 快捷安装 / 卸载一键操作按钮
            actionButton
            
            Image(systemName: DesignSystem.Icons.forward)
                .font(.caption2)
                .foregroundStyle(.appSecondary)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: SystemRadius.section, style: .continuous).fill(.ultraThinMaterial))
        .overlay(RoundedRectangle(cornerRadius: SystemRadius.section, style: .continuous).stroke(Color.theme.white.opacity(SystemOpacity.glass), lineWidth: SystemStroke.hairline))
        .shadow(color: Color.theme.black.opacity(SystemOpacity.faint), radius: SystemShadow.radiusMedium, x: 0, y: SystemShadow.offsetSmall)
        .task {
            if let id = pluginID {
                // 兼容支持物理包名 ID 与市场简短 ID 的匹配
                let targetID = registry.plugins.first(where: { 
                    $0.manifest.id == id || $0.manifest.id.hasSuffix("." + id) 
                })?.manifest.id ?? id
                
                if let url = registry.iconURL(for: targetID) {
                    // 使用后台异步线程在非 UI 线程中读取物理图片数据，避免直接读取 I/O 导致 UI 卡顿
                    Task.detached(priority: .background) {
                        if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                            await MainActor.run {
                                self.localIcon = image
                            }
                        }
                    }
                }
            }
        }
    }

    private func sourceLabel(_ src: PluginSource) -> String {
        switch src {
        case .local: return L10n.Plugin.Detail.categoryLocal
        case .community: return L10n.Plugin.Detail.categoryCommunity
        }
    }

    private func sourceColor(_ src: PluginSource) -> Color {
        switch src {
        case .local: return .green
        case .community: return .orange
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if isInstalled {
            HStack(spacing: SystemSpacing.tiny) {
                Image(systemName: "trash")
                    .font(.caption2)
                Text(L10n.Plugin.Action.uninstall)
                    .font(.caption.bold())
            }
            .padding(.horizontal, SystemSpacing.small)
            .padding(.vertical, SystemSpacing.tiny)
            .background(Color.theme.red)
            .clipShape(Capsule())
            .foregroundStyle(.white)
            .contentShape(Capsule()) // 提升手势判定区域
            .onTapGesture {
                HapticFeedback.shared.trigger(.success)
                let targetID = registry.plugins.first(where: {
                    $0.manifest.id == pluginID || $0.manifest.id.hasSuffix("." + (pluginID ?? ""))
                })?.manifest.id ?? (pluginID ?? "")
                registry.unloadPlugin(id: targetID)
            }
        } else if let marketPlugin = marketPlugin, let service = marketService {
            let isDownloading = service.downloadingPluginID == pluginID
            HStack(spacing: SystemSpacing.tiny) {
                if isDownloading {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: "icloud.and.arrow.down")
                        .font(.caption2)
                }
                Text(L10n.Plugin.Action.install)
                    .font(.caption.bold())
            }
            .padding(.horizontal, SystemSpacing.small)
            .padding(.vertical, SystemSpacing.tiny)
            .background(Color.appAccent)
            .clipShape(Capsule())
            .foregroundStyle(.white)
            .contentShape(Capsule()) // 提升手势判定区域
            .onTapGesture {
                guard !isDownloading else { return }
                HapticFeedback.shared.trigger(.selection)
                Task {
                    _ = await service.downloadPlugin(marketPlugin)
                }
            }
        }
    }
}
