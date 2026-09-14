//
//  ScenesSharedComponents.swift
//  ZhiYu
//
//  Created by CodeFree on 2026/09/14.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 应用层
//  核心职责：抽取 App/Scenes 目录下跨视图共享的 UI 组件、修饰符与辅助方法，消除重复代码。
//
import SwiftUI
import UFPCore
import Dependencies

// MARK: - CommandPalette Sheet 修饰符

/// 命令面板 Sheet 与快捷键修饰符
/// 统一封装 `⌘K` 快捷键拉起 CommandPaletteView 的交互，避免在多个 TabView 容器中重复书写。
struct CommandPaletteSheetModifier: ViewModifier {
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                CommandPaletteView()
                    .presentationDetents([.height(DesignSystem.Metrics.commandPaletteHeight)])
                    .presentationBackground(.clear)
            }
            .background {
                Button(L10n.Common.action) {
                    isPresented.toggle()
                }
                .keyboardShortcut("k", modifiers: .command)
                .opacity(0)
            }
    }
}

extension View {
    /// 挂载命令面板 Sheet 与 ⌘K 快捷键
    /// - Parameter isPresented: 是否展示命令面板的绑定
    func commandPaletteSheet(isPresented: Binding<Bool>) -> some View {
        modifier(CommandPaletteSheetModifier(isPresented: isPresented))
    }
}

// MARK: - Tab Content 构建器

/// Tab 内容视图构建器
/// 统一封装 `NavigationStack(path:) + 根视图 + .id(languageForceUpdate) + .navigationDestination(AppRoute)` 的重复模式，
/// 供 chat/graph/synthesis/ingest 等非 knowledge Tab 复用。
extension ContentView {
    /// 构建标准 Tab 内容：NavigationStack + 根视图 + AppRoute 路由目标
    /// - Parameters:
    ///   - root: 根视图内容
    /// - Returns: 包裹后的 Tab 内容视图
    @ViewBuilder
    func standardTabContent<Root: View>(@ViewBuilder _ root: () -> Root) -> some View {
        @Bindable var router = router
        NavigationStack(path: $router.path) {
            root()
                .id(router.languageForceUpdate)
                .navigationDestination(for: AppRoute.self) { route in
                    ViewFactory.makeView(for: route)
                }
        }
    }
}

// MARK: - 侧边栏图标框组件

/// 侧边栏彩色圆角图标框
/// 统一封装 `Image + 字号 + 前景色 + frame + 背景 + clipShape` 的重复样式，
/// 供 SidebarIconRow / UniverseNavRow / SidebarTypeRow 共享。
struct SidebarIconBox: View {
    let icon: String
    let color: Color
    var backgroundOpacity: Double = DesignSystem.Opacity.subtle

    var body: some View {
        Image(systemName: icon)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(color)
            .frame(width: DesignSystem.largeIconSize, height: DesignSystem.largeIconSize)
            .background(color.opacity(backgroundOpacity))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.smallRadius, style: .continuous))
    }
}

/// 侧边栏行标题（统一字号、字重、颜色 + Spacer）
/// 供 SidebarIconRow / UniverseNavRow / SidebarTypeRow 共享。
struct SidebarRowTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.appText)
        Spacer()
    }
}

/// 侧边栏数量角标胶囊
/// 统一封装 `Text(count) + caption2 + padding + background + clipShape(Capsule)` 的重复样式。
struct SidebarCountBadge: View {
    let count: Int
    let color: Color
    var backgroundOpacity: Double = DesignSystem.subtleFillOpacity

    var body: some View {
        Text("\(count)")
            .font(.caption2.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, DesignSystem.Chip.horizontalPadding)
            .padding(.vertical, DesignSystem.Chip.verticalPadding)
            .background(color.opacity(backgroundOpacity))
            .clipShape(Capsule())
    }
}

// MARK: - Splash 动画辅助

/// Splash 启动页动画序列辅助
/// 统一封装 `DispatchQueue.main.asyncAfter + withAnimation` 的延迟动画模式。
enum SplashAnimationScheduler {
    /// 在指定延迟后以指定时长淡入目标状态
    /// - Parameters:
    ///   - delay: 延迟时间（秒）
    ///   - duration: 动画时长（秒）
    ///   - action: 状态变更闭包
    static func scheduleFadeIn(after delay: Double, duration: Double, action: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.easeOut(duration: duration)) {
                action()
            }
        }
    }

    /// 在指定延迟后以标准缓动动画执行闭包（用于自动消失等场景）
    /// - Parameters:
    ///   - delay: 延迟时间（秒）
    ///   - action: 状态变更闭包
    static func scheduleStandardTransition(after delay: Double, action: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.easeInOut(duration: DesignSystem.Animation.standardDuration)) {
                action()
            }
        }
    }
}

// MARK: - 全局弹窗主题修饰符

/// 全局弹窗主题修饰符
/// 统一封装 `fullScreenCover` 中重复的 `.environment(themeManager) + .preferredColorScheme(...)` 模式，
/// 供 ContentView 的各个 sheet 复用。
struct GlobalSheetThemeModifier: ViewModifier {
    @Environment(ThemeManager.self) private var themeManager

    func body(content: Content) -> some View {
        content
            .environment(themeManager)
            .preferredColorScheme(themeManager.colorSchemeMode.preferredColorScheme)
    }
}

extension View {
    /// 应用全局弹窗主题（ThemeManager + preferredColorScheme）
    func globalSheetTheme() -> some View {
        modifier(GlobalSheetThemeModifier())
    }
}
