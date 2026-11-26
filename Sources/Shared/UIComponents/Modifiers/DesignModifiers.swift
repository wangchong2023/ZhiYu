//
//  DesignModifiers.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：可复用 UI 组件库：编辑器、卡片、加载态、空状态等通用视图。
//
import SwiftUI
import UFPDesignSystem

// MARK: - 1. 弹性物理悬停修饰器

/// 弹性物理悬停微缩放修饰符
struct ScaleOnHoverModifier: ViewModifier {
    /// 悬停动画的目标缩放比例
    let scale: CGFloat
    
    /// 本地悬停激活状态
    @State private var isHovered = false
    
    /// 视图主体
    /// - Parameter content: content
    /// - Returns: 返回值
    func body(content: Content) -> some View {
        #if os(watchOS)
        content
        #else
        content
            .scaleEffect(isHovered ? scale : 1.0)
            .onHover { hovering in
                withAnimation(.appProminent) {
                    isHovered = hovering
                }
            }
        #endif
    }
}

// MARK: - 2. 高保真弥散软阴影修饰器

/// 高保真弥散环境光晕多重软阴影修饰符
struct PremiumAmbientShadowModifier: ViewModifier {
    /// 阴影的底色
    let color: Color
    
    /// 物理扩散半径
    let radius: CGFloat
    
    /// 视图主体
    /// - Parameter content: content
    /// - Returns: 返回值
    func body(content: Content) -> some View {
        content
            // 第一层：大范围微弱漫反射阴影，确立环境光底色
            .shadow(color: color.opacity(DesignTokens.Opacity.ghost), radius: radius, x: 0, y: radius * 0.4)
            // 第二层：小范围紧致遮蔽阴影，确立物理接缝立体感
            .shadow(color: color.opacity(DesignTokens.Opacity.faint), radius: radius * 0.4, x: 0, y: radius * 0.15)
    }
}

// MARK: - 3. 霓虹渐变呼吸边框修饰器

/// 霓虹渐变高亮呼吸外框修饰符
struct GlowingNeonBorderModifier: ViewModifier {
    /// 是否开启霓虹高光
    let isGlowing: Bool
    
    /// 覆盖圆角弧度
    let cornerRadius: CGFloat
    
    /// 自定义渐变色阵列
    let gradientColors: [Color]
    
    /// 视图主体
    /// - Parameter content: content
    /// - Returns: 返回值
    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: isGlowing ? gradientColors : [Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isGlowing ? 1.5 : 0
                    )
                    // 渐变外光圈发光，营造呼吸高亮
                    .shadow(color: isGlowing ? (gradientColors.first ?? .blue).opacity(DesignTokens.Opacity.disabled) : .clear, radius: isGlowing ? 6 : 0)
                    .animation(.easeInOut(duration: DesignTokens.Animations.springResponse), value: isGlowing)
            )
    }
}

// MARK: - 跨平台工具栏位置与背景扩展 (File Scope)

#if os(macOS)
@MainActor
private extension ToolbarItemPlacement {
    static let appLeading: ToolbarItemPlacement = .navigation
    static let appTrailing: ToolbarItemPlacement = .primaryAction
}
@MainActor
private extension ToolbarPlacement {
    static let appNavigation: ToolbarPlacement = .windowToolbar
}
#elseif os(iOS)
@MainActor
private extension ToolbarItemPlacement {
    static let appLeading: ToolbarItemPlacement = .navigationBarLeading
    static let appTrailing: ToolbarItemPlacement = .topBarTrailing
}
@MainActor
private extension ToolbarPlacement {
    static let appNavigation: ToolbarPlacement = .navigationBar
}
#else
@MainActor
private extension ToolbarItemPlacement {
    static let appLeading: ToolbarItemPlacement = .automatic
    static let appTrailing: ToolbarItemPlacement = .automatic
}
#endif

// MARK: - View 语义链式调用扩展

public extension View {
    /// 注入支持高级阻尼弹性悬停物理微动效
    /// - Parameter scale: 悬停时的缩放比例（默认 1.025）
    func scaleOnHover(scale: CGFloat = 1.025) -> some View {
        self.modifier(ScaleOnHoverModifier(scale: scale))
    }
    
    /// 注入多层低透明度环境光晕漫反射阴影，营造绝佳的拟物毛玻璃立体悬浮度
    /// - Parameters:
    ///   - color: 阴影颜色（默认黑色）
    ///   - radius: 阴影发散半径（默认 12）
    func premiumAmbientShadow(color: Color = .black, radius: CGFloat = 12) -> some View {
        self.modifier(PremiumAmbientShadowModifier(color: color, radius: radius))
    }
    
    /// 注入霓虹渐变高亮呼吸外框，用作焦点元素和 Aha Card 激活的微动效容器
    /// - Parameters:
    ///   - isGlowing: 是否亮起
    ///   - cornerRadius: 圆角弧度（默认 12）
    ///   - gradientColors: 渐变色组合，默认采用 [蓝色, 紫色, 青色] 现代高阶配色
    func glowingNeonBorder(
        isGlowing: Bool = true,
        cornerRadius: CGFloat = 12,
        gradientColors: [Color] = [.blue, .purple, .init(red: 0.0, green: 0.8, blue: 0.9)]
    ) -> some View {
        self.modifier(GlowingNeonBorderModifier(isGlowing: isGlowing, cornerRadius: cornerRadius, gradientColors: gradientColors))
    }
    
    @ViewBuilder
    /// 跨平台 NavigationBarTitleDisplayMode 修饰符，自动在不支持的平台降级屏蔽
    func appNavigationBarTitleDisplayMode(_ mode: AppNavigationBarTitleDisplayMode) -> some View {
        #if os(iOS)
        let displayMode: NavigationBarItem.TitleDisplayMode = {
            switch mode {
            case .automatic: return .automatic
            case .inline: return .inline
            case .large: return .large
            }
        }()
        self.navigationBarTitleDisplayMode(displayMode)
        #else
        self
        #endif
    }

    /// 跨平台 Toolbar 左侧（leading）Item 放置：iOS 用 navigationBarLeading，macOS 用 navigation
    @ToolbarContentBuilder
    func appToolbarLeading<Content: View>(@ViewBuilder content: () -> Content) -> some ToolbarContent {
        ToolbarItem(placement: .appLeading) { content() }
    }

    /// 跨平台 Toolbar 右侧（trailing）Item 放置：iOS 用 topBarTrailing，macOS 用 primaryAction
    @ToolbarContentBuilder
    func appToolbarTrailing<Content: View>(@ViewBuilder content: () -> Content) -> some ToolbarContent {
        ToolbarItem(placement: .appTrailing) { content() }
    }

    /// 跨平台 Toolbar 右侧（trailing）ItemGroup 放置：iOS 用 topBarTrailing，macOS 用 primaryAction
    @ToolbarContentBuilder
    func appToolbarTrailingGroup<Content: View>(@ViewBuilder content: () -> Content) -> some ToolbarContent {
        ToolbarItemGroup(placement: .appTrailing) { content() }
    }

    /// 跨平台 Toolbar 背景控制统一收敛
    @ViewBuilder
    private func appToolbarBackgroundInternal(_ visibility: Visibility?, material: Material? = nil) -> some View {
        #if os(iOS) || os(macOS)
        if let visibility {
            self.toolbarBackground(visibility, for: .appNavigation)
        } else if let material {
            self.toolbarBackground(material, for: .appNavigation)
        } else {
            self
        }
        #else
        self
        #endif
    }

    /// 跨平台隐藏 Toolbar 背景：iOS 用 navigationBar，macOS 用 windowToolbar
    @ViewBuilder
    func appToolbarBackgroundHidden() -> some View {
        appToolbarBackgroundInternal(.hidden)
    }

    /// 跨平台显示 Toolbar 背景：iOS 用 navigationBar，macOS 用 windowToolbar
    @ViewBuilder
    func appToolbarBackgroundVisible() -> some View {
        appToolbarBackgroundInternal(.visible)
    }

    /// 跨平台设置 Toolbar 背景材质：iOS 用 navigationBar，macOS 用 windowToolbar
    @ViewBuilder
    func appToolbarBackgroundMaterial(_ material: Material) -> some View {
        appToolbarBackgroundInternal(nil, material: material)
    }

    /// 跨平台分页 TabView 样式：仅 iOS 应用 .page，macOS/watchOS 无此样式时降级为无操作
    @ViewBuilder
    func appPageTabViewStyle() -> some View {
        #if os(iOS)
        self.tabViewStyle(.page(indexDisplayMode: .never))
        #else
        self
        #endif
    }

    /// 跨平台全屏覆盖（isPresented 版本）：iOS 用 fullScreenCover，macOS 用 sheet
    @ViewBuilder
    func appFullScreenCover<Content: View>(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        #if os(iOS)
        self.fullScreenCover(isPresented: isPresented, onDismiss: onDismiss, content: content)
        #else
        self.sheet(isPresented: isPresented, onDismiss: onDismiss) {
            content()
                .frame(
                    minWidth: DesignTokens.Metrics.macSettingsWindowWidth,
                    minHeight: DesignTokens.Metrics.macSettingsWindowHeight
                )
        }
        #endif
    }

    /// 跨平台全屏覆盖（item 版本）：iOS 用 fullScreenCover，macOS 用 sheet
    @ViewBuilder
    func appFullScreenCover<Item, Content: View>(
        item: Binding<Item?>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View where Item: Identifiable {
        #if os(iOS)
        self.fullScreenCover(item: item, onDismiss: onDismiss, content: content)
        #else
        self.sheet(item: item, onDismiss: onDismiss) { value in
            content(value)
                .frame(
                    minWidth: DesignTokens.Metrics.macSettingsWindowWidth,
                    minHeight: DesignTokens.Metrics.macSettingsWindowHeight
                )
        }
        #endif
    }
}

// MARK: - 跨平台输入配置（键盘类型 / 自动大写）

/// 跨平台键盘类型，iOS 映射到 UIKeyboardType，其他平台忽略
public enum AppKeyboardType {
    /// URL 键盘
    case url
}

/// 跨平台 NavigationBar 标题展示模式（iOS 映射到 NavigationBarItem.TitleDisplayMode）
public enum AppNavigationBarTitleDisplayMode {
    /// 自动
    case automatic
    /// 内联
    case inline
    /// 大标题
    case large
}

public extension View {
    /// 跨平台 keyboardType：iOS 应用指定键盘，macOS/watchOS 无此概念时降级为无操作
    @ViewBuilder
    func appKeyboardType(_ type: AppKeyboardType?) -> some View {
        #if os(iOS)
        if let type {
            let uiType: UIKeyboardType = {
                switch type {
                case .url: return .URL
                }
            }()
            self.keyboardType(uiType)
        } else {
            self
        }
        #else
        self
        #endif
    }

    /// 跨平台禁用自动大写：iOS 应用 autocapitalization(.none)，其他平台降级为无操作
    @ViewBuilder
    func appAutocapitalizationDisabled() -> some View {
        #if os(iOS)
        self.autocapitalization(.none)
        #else
        self
        #endif
    }
}
