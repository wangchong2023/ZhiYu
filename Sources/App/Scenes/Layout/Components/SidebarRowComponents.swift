//
//  SidebarRowComponents.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 应用层
//  核心职责：SwiftUI 视图组件，构建应用的导航、侧边栏、布局等 UI 结构。
//
import SwiftUI
import UFPCore
import Dependencies

// MARK: - Navigation Definitions

/// 侧边栏导航选中项定义
/// 用于追踪用户在 NavigationSplitView 侧边栏中的交互位置
public enum SidebarSelection: Hashable {
    /// 跳转到特定的知识页面条目 (根据 UUID 唯一定位)
    case page(UUID)
    
    /// 跳转到系统预设的工具项 (如：仪表盘、页面列表、设置等)
    case tool(ToolItem)
    
    /// 按特定 PageType 类型过滤后的知识列表 (如：仅查看实体或概念)
    case filteredIndex(PageType)
    
    /// 将当前的侧边栏选中项转换为具体的物理路由目标
    /// 这一映射过程解耦了侧边栏的 UI 交互状态与底层的视图分发逻辑。
    /// - Returns: 对应的 AppRoute 目标，可直接用于导航栈。
    public func asRoute() -> AppRoute {
        switch self {
        case .page(let id): return .pageDetail(id: id)
        case .tool(let tool): return tool.route
        case .filteredIndex(let type): return .pageList(filterType: type)
        }
    }
}

// MARK: - Navigation Row Wrapper

/// 自适应侧边栏行包装器
/// 用于协调不同屏幕尺寸与系统（iPhone vs iPad/Mac）的导航栏渲染路径：
/// 1. 手机（Compact）模式：由于没有双栏，需要使用原生的 `NavigationLink(value:)` 将视图推入全局 `NavigationStack`。
/// 2. 平板/Mac（Regular）模式：使用两栏或三栏布局，直接返回原始内容并标记 `.tag(value)`，通过外层的 `List(selection:)` 触发单选绑定来更新详情区，规避 `NavigationLink` 在无 Stack 列中寻路失败报错。
struct SidebarRowWrapper<Content: View>: View {
    /// 绑定的路由项值
    let value: SidebarSelection
    /// 行内的子视图内容
    let content: () -> Content
    
    @Environment(Router.self) private var router
    
    /// 全局注入的平台设备环境，用于替代不准确的系统的 sizeClass 判定
    private var appEnv: any AppEnvironmentProtocol {
        ServiceContainer.shared.resolve((any AppEnvironmentProtocol).self)
    }
    
    var body: some View {
        #if os(watchOS)
        content()
        #else
        // 注意：iPadOS 的 SwiftUI 会将 NavigationSplitView 侧边栏内部子视图的 horizontalSizeClass
        // 强行覆写为 .compact，这导致大屏设备会被误判为 compact 并展示错误的 NavigationLink。
        // 我们通过 appEnv.screenClass 来精确判定是否应以手机紧凑模式进行导航渲染。
        if appEnv.screenClass == .compact {
            NavigationLink(value: value) {
                content()
            }
        } else {
            // 在 iPadOS/macOS 大屏下，如果 List 在非编辑状态下，点击带有 .tag() 的普通列表行
            // 不会自动触发 List(selection:) 绑定的更新。为了保证数据在点击时能够绝对触发状态流转，
            // 采用 onTapGesture 手动为全局路由器赋予新的选中值，从根本上激活右侧的联动刷新。
            content()
                .tag(value)
                .contentShape(Rectangle())
                .onTapGesture {
                    router.sidebarSelection = value
                }
        }
        #endif
    }
}

struct CapabilitiesSection: View {
    var body: some View {
        Section {
            SidebarRowWrapper(value: SidebarSelection.tool(.dashboard)) {
                SidebarIconRow(
                    icon: DesignSystem.Icons.dashboard,
                    color: .blue,
                    title: L10n.Common.Sidebar.dashboard
                )
                .contentShape(Rectangle())
            }
            SidebarRowWrapper(value: SidebarSelection.tool(.weeklyReport)) {
                SidebarIconRow(
                    icon: DesignSystem.Icons.weeklyInsight,
                    color: .purple,
                    title: L10n.Common.Sidebar.weeklyInsight
                )
                .contentShape(Rectangle())
            }
        } header: {
            Text(L10n.Common.Sidebar.capabilities)
        }
        .listRowBackground(SidebarRowBackground())
    }
}

struct SourcesSection: View {
    var sourceStore = SourceStore.shared
    
    var body: some View {
        if !sourceStore.activeSources.isEmpty {
            Section {
                SidebarRowWrapper(value: SidebarSelection.tool(.sources)) {
                    Label {
                        HStack {
                            Text(L10n.Plugin.Sidebar.currentSources)
                            Spacer()
                            Text("\(sourceStore.activeSources.count)")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.white)
                                .padding(.horizontal, DesignSystem.tightPadding)
                                .background(Color.appAccent)
                                .clipShape(Capsule())
                        }
                    } icon: {
                        Image(systemName: DesignSystem.Icons.quoteBubble)
                            .foregroundStyle(.appAccent)
                    }
                }
            } header: {
                Text(L10n.Plugin.Section.rag)
            }
            .listRowBackground(SidebarRowBackground())
        }
    }
}

struct UniverseSection: View {
    @Environment(KnowledgeStore.self) var store
    @Environment(Router.self) var router
    
    var body: some View {
        Section {
            SidebarRowWrapper(value: SidebarSelection.tool(.pageList)) {
                UniverseNavRow(
                    icon: DesignSystem.Icons.pageList,
                    colorName: "accent",
                    title: L10n.Common.Sidebar.pageList,
                    count: store.pages.count
                )
                .contentShape(Rectangle())
            }
            
            // 遍历用户可见页面类型，过滤掉内部使用的 raw 类型
            ForEach(PageType.allVisibleCases) { type in
                let count = store.pages.filter { $0.pageType == type }.count
                if count > 0 {
                    SidebarRowWrapper(value: SidebarSelection.filteredIndex(type)) {
                        SidebarTypeRow(
                            type: type,
                            count: count
                        )
                        .contentShape(Rectangle())
                    }
                }
            }
        } header: {
            Text(L10n.Common.Sidebar.universe)
        }
        .listRowBackground(SidebarRowBackground())
    }
}

struct PinnedSection: View {
    @Environment(KnowledgeStore.self) var store
    var heroNamespace: Namespace.ID
    @Binding var pageToDelete: KnowledgePage?
    @Binding var showDeleteConfirmation: Bool
    
    var body: some View {
        let pinnedPages = store.pages.filter { $0.isPinned }
        if !pinnedPages.isEmpty {
            Section {
                ForEach(pinnedPages) { page in
                    SidebarPinnedRow(
                        page: page,
                        heroNamespace: heroNamespace,
                        onTogglePin: {
                            var p = page
                            p.isPinned.toggle()
                            Task { await store.updatePage(p) }
                        },
                        onDelete: {
                            pageToDelete = page
                            showDeleteConfirmation = true
                        }
                    )
                }
            } header: {
                Text(L10n.Common.pinned)
            }
            .listRowBackground(SidebarRowBackground())
        }
    }
}

struct ToolsSection: View {
    @Environment(AppStore.self) var appStore
    @Dependency(\.taskCenter) var taskCenter
    
    var body: some View {
        Section {
            // 健康检查（带 lint 问题数量角标）
            SidebarRowWrapper(value: SidebarSelection.tool(.lint)) {
                SidebarIconRow(
                    icon: DesignSystem.Icons.healthCheck,
                    color: .green,
                    title: L10n.Common.Sidebar.healthCheck,
                    badge: appStore.lintIssues.count
                )
                .contentShape(Rectangle())
            }
            // 标签管理
            SidebarRowWrapper(value: SidebarSelection.tool(.tagCloud)) {
                SidebarIconRow(
                    icon: DesignSystem.Icons.tag,
                    color: .orange,
                    title: L10n.Common.Sidebar.tagManager
                )
                .contentShape(Rectangle())
            }
            // 任务中心（带未读数量角标，使用填充橙色高亮）
            SidebarRowWrapper(value: SidebarSelection.tool(.taskCenter)) {
                SidebarIconRow(
                    icon: DesignSystem.Icons.refresh,
                    color: .cyan,
                    title: L10n.AI.Task.centerTitle,
                    badge: taskCenter.unreadCount,
                    badgeFilled: true
                )
                .contentShape(Rectangle())
            }
            // 协作
            SidebarRowWrapper(value: SidebarSelection.tool(.collab)) {
                SidebarIconRow(
                    icon: DesignSystem.Icons.collaborationPeers,
                    color: .teal,
                    title: L10n.Common.Sidebar.collaboration
                )
                .contentShape(Rectangle())
            }
        } header: {
            Text(L10n.Common.Sidebar.tools)
        }
        .listRowBackground(SidebarRowBackground())
    }
}

// MARK: - Row Components

struct SidebarRowBackground: View {
    var body: some View {
        Color.appCard.opacity(DesignSystem.subtleOpacity)
            .background(.ultraThinMaterial)
    }
}

// MARK: - 通用侧边栏图标行

/// 通用侧边栏图标行
/// 图标带彩色圆角背景框，与知识宇宙分区视觉风格保持一致。
/// - Parameters:
///   - icon: SF Symbol 图标名称
///   - color: 图标与背景的主题色
///   - title: 行标题
///   - badge: 角标数值，0 时不显示
///   - badgeFilled: true 时角标使用填充背景（橙色），适用于紧急未读计数
struct SidebarIconRow: View {
    let icon: String
    let color: Color
    let title: String
    var badge: Int = 0
    var badgeFilled: Bool = false
    
    var body: some View {
        HStack(spacing: DesignSystem.medium) {
            // 彩色圆角图标框（与知识宇宙风格统一）
            Image(systemName: icon)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(color)
                .frame(width: DesignSystem.largeIconSize, height: DesignSystem.largeIconSize)
                .background(color.opacity(DesignSystem.Opacity.subtle))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.smallRadius, style: .continuous))
            
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.appText)
            
            Spacer()
            
            // 角标：badgeFilled = true 时使用填充橙色（任务中心未读提醒）
            if badge > 0 {
                Text("\(badge)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(badgeFilled ? .white : color)
                    .padding(.horizontal, DesignSystem.Chip.horizontalPadding)
                    .padding(.vertical, DesignSystem.Chip.verticalPadding)
                    .background(
                        Capsule().fill(
                            badgeFilled ? Color.theme.orange : color.opacity(DesignSystem.subtleFillOpacity)
                        )
                    )
            }
        }
        .padding(.vertical, DesignSystem.small)
    }
}

/// 知识宇宙通用导航行（参考搜索页面卡片风格）
struct UniverseNavRow: View {
    let icon: String
    let colorName: String
    let title: String
    let count: Int
    
    var iconColor: Color {
        colorName == "accent" ? .appAccent : Color.fromModelColorName(colorName)
    }
    
    var body: some View {
        HStack(spacing: DesignSystem.medium) {
            // 彩色图标区域
            Image(systemName: icon)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(iconColor)
                .frame(width: DesignSystem.largeIconSize, height: DesignSystem.largeIconSize)
                .background(iconColor.opacity(DesignSystem.Opacity.subtle))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.smallRadius, style: .continuous))
            
            // 标题
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.appText)
            
            Spacer()
            
            // 数量角标
            if count > 0 {
                Text("\(count)")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, DesignSystem.Chip.horizontalPadding)
                    .padding(.vertical, DesignSystem.Chip.verticalPadding)
                    .background(Color.appAccent.opacity(DesignSystem.subtleFillOpacity))
                    .foregroundStyle(.appAccent)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, DesignSystem.small)
    }
}

/// 按类型过滤的导航行（参考搜索页面卡片风格）
struct SidebarTypeRow: View {
    let type: PageType
    let count: Int
    
    var body: some View {
        HStack(spacing: DesignSystem.medium) {
            // 彩色图标区域（匹配类型主色）
            Image(systemName: type.icon)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.fromModelColorName(type.colorName))
                .frame(width: DesignSystem.largeIconSize, height: DesignSystem.largeIconSize)
                .background(Color.fromModelColorName(type.colorName).opacity(DesignSystem.softOpacity * 0.3)) // 0.12
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.smallRadius, style: .continuous))
            
            // 分类名称
            Text(type.displayName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.appText)
            
            Spacer()
            
            // 数量角标（使用类型主色）
            Text("\(count)")
                .font(.caption2.weight(.bold))
                .padding(.horizontal, count > 9 ? DesignSystem.Chip.horizontalPadding : DesignSystem.Chip.verticalPadding)
                .padding(.vertical, DesignSystem.Chip.verticalPadding)
                .background(Color.fromModelColorName(type.colorName).opacity(DesignSystem.softOpacity * 0.375)) // 0.15
                .foregroundStyle(Color.fromModelColorName(type.colorName))
                .clipShape(Capsule())
        }
        .padding(.vertical, DesignSystem.small)
    }
}

struct SidebarPinnedRow: View {
    let page: KnowledgePage
    var heroNamespace: Namespace.ID
    let onTogglePin: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        SidebarRowWrapper(value: SidebarSelection.page(page.id)) {
            PageSidebarRow(page: page, heroNamespace: heroNamespace)
        }
        .contextMenu {
            Button(action: onTogglePin) {
                Label(page.isPinned ? L10n.Knowledge.Page.unpin : L10n.Knowledge.Page.pin, systemImage: page.isPinned ? DesignSystem.Icons.unpin : DesignSystem.Icons.pin)
            }
            Divider()
            Button(role: .destructive, action: onDelete) {
                Label(L10n.Knowledge.Page.deletePage, systemImage: DesignSystem.Icons.delete)
            }
        }
    }
}

struct PageSidebarRow: View {
    let page: KnowledgePage
    var heroNamespace: Namespace.ID
    var body: some View {
        HStack(spacing: DesignSystem.small) {
            Image(systemName: page.pageType.icon)
                .font(.system(size: DesignSystem.Icons.small))
                .foregroundStyle(Color.fromModelColorName(page.pageType.colorName))
                .frame(width: DesignSystem.Sidebar.iconFrameWidth)
            
            Text(page.title)
                .font(.system(size: DesignSystem.subheadlineFontSize, weight: .medium))
                .foregroundStyle(.appText)
                .lineLimit(1)
        }
        .padding(.vertical, DesignSystem.small)
    }
}

// MARK: - Modifiers

struct SidebarListStyleModifier: ViewModifier {
    let horizontalSizeClass: UserInterfaceSizeClass?
    
    /// 视图主体
    /// - Parameter content: content
    /// - Returns: 返回值
    func body(content: Content) -> some View {
        #if os(iOS)
        if horizontalSizeClass == .compact {
            content.listStyle(.insetGrouped)
        } else {
            content.listStyle(.sidebar)
        }
        #elseif os(macOS)
        content.listStyle(.sidebar)
        #else
        content.listStyle(.plain)
        #endif
    }
}

// MARK: - 插件扩展入口

struct PluginRibbonSection: View {
    @Dependency(\.pluginRegistry) var registry
    
    var body: some View {
        if !registry.ribbonItems.isEmpty {
            Section {
                ForEach(registry.ribbonItems) { item in
                    Button(action: {
                        HapticFeedback.shared.trigger(.selection)
                        item.action()
                    }) {
                        Label(item.title, systemImage: item.icon)
                            .foregroundStyle(.appText)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text(L10n.Plugin.section.ribbon)
            }
            .listRowBackground(SidebarRowBackground())
        }
    }
}

struct PluginCustomViewsSection: View {
    @Dependency(\.pluginRegistry) var registry
    
    var body: some View {
        ForEach(registry.customViews) { view in
            Button(action: {
                HapticFeedback.shared.trigger(.selection)
                view.action()
            }) {
                Label(view.title, systemImage: view.icon)
                    .foregroundStyle(.appText)
            }
            .buttonStyle(.plain)
        }
    }
}
