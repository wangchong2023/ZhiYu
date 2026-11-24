//
//  PlatformModifiers.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/03.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：封装特定平台的 SwiftUI View Modifiers，解耦 Feature 层的宏依赖。
//
import SwiftUI
import UFPDesignSystem
#if canImport(UIKit)
import UIKit
#endif

public extension View {
    
    /// 仅在支持的平台应用 Segmented Picker Style
    @ViewBuilder

    /// segmentedPickerStyleIfAvailable
    func segmentedPickerStyleIfAvailable() -> some View {
        #if os(iOS) || os(macOS)
        self.pickerStyle(.segmented)
        #else
        self
        #endif
    }
    
    /// 仅在 iOS 应用 navigationBarTitleDisplayMode
    @ViewBuilder

    /// inlineNavigationBarTitleIfAvailable
    func inlineNavigationBarTitleIfAvailable() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
    
    /// 仅在 iOS 应用 large navigationBarTitleDisplayMode
    @ViewBuilder

    /// largeNavigationBarTitleIfAvailable
    func largeNavigationBarTitleIfAvailable() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.large)
        #else
        self
        #endif
    }
    
    /// 仅在 iOS 隐藏 Navigation Bar Back Button
    @ViewBuilder

    /// 隐藏BackButtonIfIOS
    /// /// - Parameter hidden: hidden
    func hideBackButtonIfIOS(_ hidden: Bool = true) -> some View {
        #if os(iOS)
        self.navigationBarBackButtonHidden(hidden)
        #else
        self
        #endif
    }
    
    /// 仅在 iOS 修改 Navigation Bar 可见性
    @ViewBuilder

    /// 隐藏NavigationBarIfIOS
    /// /// - Parameter hidden: hidden
    func hideNavigationBarIfIOS(_ hidden: Bool) -> some View {
        #if os(iOS)
        self.toolbar(hidden ? .hidden : .visible, for: .navigationBar)
        #else
        self
        #endif
    }
    
    /// 仅在非 watchOS 上填满最大宽度
    @ViewBuilder

    /// maxWidthIfNot监听OS
    /// /// - Parameter alignment: alignment
    func maxWidthIfNotWatchOS(_ alignment: Alignment = .center) -> some View {
        #if !os(watchOS)
        self.frame(maxWidth: .infinity, alignment: alignment)
        #else
        self
        #endif
    }
    
    /// 仅在 iOS 设置 listStyle 为 insetGrouped
    @ViewBuilder

    /// insetGroupedListStyleIfIOS
    func insetGroupedListStyleIfIOS() -> some View {
        #if os(iOS)
        self.listStyle(.insetGrouped)
        #else
        self
        #endif
    }
    
    /// 仅在 macOS 设置 listStyle 为 inset
    @ViewBuilder

    /// insetListStyleIfMac
    func insetListStyleIfMac() -> some View {
        #if os(macOS)
        self.listStyle(.inset)
        #else
        self
        #endif
    }
    
    /// 仅在 iOS 或 macOS 设置 textFieldStyle 为 roundedBorder
    @ViewBuilder

    /// roundedBorderTextFieldStyle
    func roundedBorderTextFieldStyle() -> some View {
        #if os(iOS) || os(macOS)
        self.textFieldStyle(.roundedBorder)
        #else
        self
        #endif
    }
    
    /// 仅在 iOS 或 macOS 应用 keyboardType
    @ViewBuilder

    /// numberPadKeyboardIfAvailable
    func numberPadKeyboardIfAvailable() -> some View {
        #if os(iOS)
        self.keyboardType(.numberPad)
        #else
        self
        #endif
    }

    @ViewBuilder
    /// 在 watchOS 上隐藏视图（手表端不支持的操作/控件）
    func hiddenOnWatch() -> some View {
        #if os(watchOS)
        self.hidden()
        #else
        self
        #endif
    }

    @ViewBuilder
    /// 仅在 iOS/macOS 显示视图（手表端不渲染）
    func visibleOniOSOrMac() -> some View {
        #if os(watchOS)
        self.hidden()
        #else
        self
        #endif
    }

    /// 跨平台工具栏：watchOS 上跳过渲染，其他平台正常显示
    @ViewBuilder
    /// toolbarIfNotWatchOS
    func toolbarIfNotWatchOS() -> some View {
        #if !os(watchOS)
        self
        #endif
    }

    /// 标准侧边栏列表样式（macOS 用 .sidebar，其他平台用默认）
    @ViewBuilder
    /// adaptiveSidebarListStyle
    func adaptiveSidebarListStyle() -> some View {
        #if os(macOS)
        self.listStyle(.sidebar)
        #else
        self
        #endif
    }

    /// watchOS 上跳过，其他平台执行自定义 modifier
    @ViewBuilder
    /// skipOnWatch
    func skipOnWatch<Content: View>(@ViewBuilder _ modifier: (Self) -> Content) -> some View {
        #if os(watchOS)
        self
        #else
        modifier(self)
        #endif
    }

    // MARK: - 列表样式适配

    /// 平台自适应列表样式：iOS 使用 insetGrouped，macOS 使用 inset，其他平台保持默认
    @ViewBuilder
    func adaptiveListStyle() -> some View {
        #if os(iOS)
        self.listStyle(.insetGrouped)
        #elseif os(macOS)
        self.listStyle(.inset)
        #else
        self
        #endif
    }

    // MARK: - 键盘类型适配

    /// 平台自适应数字键盘：iOS 使用 numberPad，其他平台使用默认键盘
    @ViewBuilder
    func adaptiveNumberPadKeyboard() -> some View {
        #if os(iOS)
        self.keyboardType(.numberPad)
        #else
        self
        #endif
    }

    // MARK: - 全屏模式适配

    /// 全屏沉浸模式：仅在 iOS 控制状态栏与 TabBar 可见性（macOS 无状态栏/TabBar，Watch 无该概念）
    @ViewBuilder
    func adaptiveFullScreenImmersive(_ hidden: Bool) -> some View {
        #if os(iOS)
        self.statusBarHidden(hidden)
            .toolbar(hidden ? .hidden : .visible, for: .tabBar)
        #else
        self
        #endif
    }

    // MARK: - 动画适配

    /// 仅在 iOS 应用 matchedGeometryEffect（macOS/watchOS 上跳过）
    @ViewBuilder
    func matchedGeometryEffectIfAvailable<ID: Hashable>(
        id: ID,
        in namespace: Namespace.ID,
        isSource: Bool = true
    ) -> some View {
        #if os(iOS)
        self.matchedGeometryEffect(id: id, in: namespace, isSource: isSource)
        #else
        self
        #endif
    }

    // MARK: - macOS 专属内容

    /// 仅在 macOS 渲染内容（用于 contextMenu 等 ViewBuilder 场景）
    @ViewBuilder
    static func macOnly<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        #if os(macOS)
        content()
        #else
        EmptyView()
        #endif
    }

    // MARK: - 键盘交互适配

    /// iOS 键盘自动收起：仅在 iOS 添加 tap gesture 收起键盘
    @ViewBuilder
    func keyboardDismissOnTapIfAvailable() -> some View {
        #if os(iOS)
        self.onTapGesture {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )
        }
        #else
        self
        #endif
    }

    // MARK: - 悬浮交互适配

    /// 仅在非 watchOS 平台应用 onHover（watchOS 无指针设备）
    @ViewBuilder
    func onHoverIfAvailable(perform action: @escaping (Bool) -> Void) -> some View {
        #if !os(watchOS)
        self.onHover(perform: action)
        #else
        self
        #endif
    }

    // MARK: - 菜单样式适配

    /// 在 macOS 上移除 Menu 默认按钮外框与系统下拉箭头，避免与自定义胶囊/图标标签叠加双层外框；
    /// iOS/iPadOS/watchOS 保持原样，不影响现有布局与视觉快照。
    @ViewBuilder
    func plainMenuStyleIfMac() -> some View {
        #if os(macOS)
        self
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
        #else
        self
        #endif
    }

    // MARK: - 工具栏尺寸适配

    /// 工具栏纯图标按钮尺寸自适应：
    /// 在 macOS 下为工具栏图标按钮提供舒展的最小尺寸（28x28），防止因固定 20pt 宽度在工具栏中被左右挤压变形；
    /// 在 iOS/iPadOS/watchOS 下保持内容自适应大小。
    @ViewBuilder
    func appToolbarItemStandardFrame() -> some View {
        #if os(macOS)
        self
            .frame(minWidth: DesignTokens.Spacing.largeIconSize, minHeight: DesignTokens.Spacing.largeIconSize)
            .contentShape(Rectangle())
        #else
        self
        #endif
    }

    /// 用户头像及工具栏触控目标适配：
    /// iOS/iPadOS/watchOS: 保持 HIG 44x44 触控热区
    /// macOS: 遵循 macOS 工具栏 28x28 标准最小尺寸，保证舒展比例且不失衡
    @ViewBuilder
    func appToolbarAdaptiveTouchTarget() -> some View {
        #if os(macOS)
        self
            .frame(minWidth: DesignTokens.Spacing.largeIconSize, minHeight: DesignTokens.Spacing.largeIconSize)
            .contentShape(Rectangle())
        #else
        self.higTouchTarget()
        #endif
    }

    /// 工具栏按钮样式跨平台适配：
    /// macOS 工具栏保留原生按钮样式，避免 `.buttonStyle(.plain)` 剥离系统水平内边距导致图标按钮被左右挤压；
    /// iOS/iPadOS/watchOS 保持 `.plain` 样式。
    @ViewBuilder
    func appToolbarButtonStyle() -> some View {
        #if os(macOS)
        self
        #else
        self.buttonStyle(.plain)
        #endif
    }

    /// 跨平台分组表单样式：macOS 使用 `.grouped` 对齐系统设置卡片风格，与列表页面主题统一
    @ViewBuilder
    func appGroupedFormStyle() -> some View {
        #if os(macOS)
        self.formStyle(.grouped)
        #else
        self
        #endif
    }

    /// 桌面宽屏/全屏居中限宽容器：仅在 `.mac` 桌面形态下限制内容最大宽度并居中，
    /// 避免超宽屏全屏时单列内容被拉成横跨整屏的长条；iOS/iPadOS/watchOS 保持原样。
    func appDesktopReadableWidth(_ maxWidth: CGFloat) -> some View {
        modifier(DesktopReadableWidthModifier(maxWidth: maxWidth))
    }

    /// macOS NavigationSplitView 侧边栏列移除系统默认 sidebarToggle（仅在 sidebar 列上生效）
    @ViewBuilder
    func appHideSystemSidebarToggle() -> some View {
        #if os(macOS)
        self.toolbar(removing: .sidebarToggle)
        #else
        self
        #endif
    }

    /// macOS NavigationSplitView 右侧 detail 窗体导航栏：
    /// 挂载于 detail 列，按「主侧边栏折叠 →（可选）知识库二级导航折叠 → VaultBadge」顺序排列，
    /// 始终紧贴右侧主窗体左缘，随分栏展开/折叠平滑跟随。
    @ViewBuilder
    func appCustomSidebarToggle(
        visibility: Binding<NavigationSplitViewVisibility>,
        secondaryVisibility: Binding<Bool>? = nil
    ) -> some View {
        #if os(macOS)
        self
            .toolbar {
                ToolbarItemGroup(placement: .navigation) {
                    Button {
                        withAnimation(DesignTokens.Animation.Config.prominentSpring) {
                            visibility.wrappedValue = (visibility.wrappedValue == .detailOnly) ? .all : .detailOnly
                        }
                    } label: {
                        Image(systemName: DesignTokens.Icons.sidebarToggle)
                            .appToolbarItemStandardFrame()
                    }
                    .help(L10n.Common.Sidebar.toggle)
                    .accessibilityIdentifier("toggleSidebarButton")

                    if let secondaryVisibility {
                        Button {
                            withAnimation(DesignTokens.Animation.Config.prominentSpring) {
                                secondaryVisibility.wrappedValue.toggle()
                            }
                        } label: {
                            Image(systemName: DesignTokens.Icons.listBulletIndent)
                                .foregroundStyle(secondaryVisibility.wrappedValue ? .appAccent : .appSecondary)
                                .appToolbarItemStandardFrame()
                        }
                        .help(L10n.Common.Sidebar.title)
                        .accessibilityIdentifier("toggleKnowledgeSidebarButton")
                    }

                    VaultBadge()
                }
            }
        #else
        self
        #endif
    }
}

/// 桌面端宽屏阅读最大宽度修饰符（基于运行时 Trait `interfaceIdiom`，零平台宏）
private struct DesktopReadableWidthModifier: ViewModifier {
    @Environment(\.interfaceIdiom) private var idiom
    let maxWidth: CGFloat

    func body(content: Content) -> some View {
        if idiom == .mac {
            content
                .frame(maxWidth: maxWidth)
                .frame(maxWidth: .infinity)
        } else {
            content
        }
    }
}
