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
    func segmentedPickerStyleIfAvailable() -> some View {
        modifier(SegmentedPickerStyleModifier())
    }

    /// 仅在非 watchOS 上填满最大宽度
    func maxWidthIfNotWatchOS(_ alignment: Alignment = .center) -> some View {
        modifier(MaxWidthIfNotWatchModifier(alignment: alignment))
    }

    /// 仅在 iOS 或 macOS 设置 textFieldStyle 为 roundedBorder
    func roundedBorderTextFieldStyle() -> some View {
        modifier(RoundedBorderTextFieldStyleModifier())
    }

    /// 在 watchOS 上隐藏视图（手表端不支持的操作/控件）
    func hiddenOnWatch() -> some View {
        modifier(HiddenOnWatchModifier())
    }

    /// 仅在 iOS/macOS 显示视图（手表端不渲染）
    func visibleOniOSOrMac() -> some View {
        modifier(HiddenOnWatchModifier())
    }

    /// 平台自适应列表样式：iOS 使用 insetGrouped，macOS 使用 inset，其他平台保持默认
    func adaptiveListStyle() -> some View {
        self.insetGroupedListStyleIfIOS().insetListStyleIfMac()
    }

    /// 平台自适应数字键盘：iOS 使用 numberPad，其他平台使用默认键盘
    func adaptiveNumberPadKeyboard() -> some View {
        self.numberPadKeyboardIfAvailable()
    }

    /// watchOS 上跳过，其他平台执行自定义 modifier
    @ViewBuilder
    func skipOnWatch<Content: View>(@ViewBuilder _ modifier: (Self) -> Content) -> some View {
        #if os(watchOS)
        self
        #else
        modifier(self)
        #endif
    }
}

// MARK: - iOS 专属视图修饰器集中适配块

#if os(iOS)
public extension View {
    /// 仅在 iOS 应用 inline navigationBarTitleDisplayMode
    func inlineNavigationBarTitleIfAvailable() -> some View {
        self.navigationBarTitleDisplayMode(.inline)
    }

    /// 仅在 iOS 应用 large navigationBarTitleDisplayMode
    func largeNavigationBarTitleIfAvailable() -> some View {
        self.navigationBarTitleDisplayMode(.large)
    }

    /// 仅在 iOS 隐藏 Navigation Bar Back Button
    func hideBackButtonIfIOS(_ hidden: Bool = true) -> some View {
        self.navigationBarBackButtonHidden(hidden)
    }

    /// 仅在 iOS 修改 Navigation Bar 可见性
    func hideNavigationBarIfIOS(_ hidden: Bool) -> some View {
        self.toolbar(hidden ? .hidden : .visible, for: .navigationBar)
    }

    /// 仅在 iOS 设置 listStyle 为 insetGrouped
    func insetGroupedListStyleIfIOS() -> some View {
        self.listStyle(.insetGrouped)
    }

    /// 仅在 iOS 应用 numberPad 键盘
    func numberPadKeyboardIfAvailable() -> some View {
        self.keyboardType(.numberPad)
    }

    /// 全屏沉浸模式：仅在 iOS 控制状态栏与 TabBar 可见性
    func adaptiveFullScreenImmersive(_ hidden: Bool) -> some View {
        self.statusBarHidden(hidden)
            .toolbar(hidden ? .hidden : .visible, for: .tabBar)
    }

    /// 仅在 iOS 应用 matchedGeometryEffect
    func matchedGeometryEffectIfAvailable<ID: Hashable>(
        id: ID,
        in namespace: Namespace.ID,
        isSource: Bool = true
    ) -> some View {
        self.matchedGeometryEffect(id: id, in: namespace, isSource: isSource)
    }

    /// iOS 键盘自动收起：仅在 iOS 添加 tap gesture 收起键盘
    func keyboardDismissOnTapIfAvailable() -> some View {
        self.onTapGesture {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )
        }
    }
}
#else
public extension View {
    func inlineNavigationBarTitleIfAvailable() -> some View { self }
    func largeNavigationBarTitleIfAvailable() -> some View { self }
    func hideBackButtonIfIOS(_ hidden: Bool = true) -> some View { self }
    func hideNavigationBarIfIOS(_ hidden: Bool) -> some View { self }
    func insetGroupedListStyleIfIOS() -> some View { self }
    func numberPadKeyboardIfAvailable() -> some View { self }
    func adaptiveFullScreenImmersive(_ hidden: Bool) -> some View { self }
    func matchedGeometryEffectIfAvailable<ID: Hashable>(
        id: ID,
        in namespace: Namespace.ID,
        isSource: Bool = true
    ) -> some View { self }
    func keyboardDismissOnTapIfAvailable() -> some View { self }
}
#endif

// MARK: - macOS 专属列表样式与侧边栏工具栏集中适配块

#if os(macOS)
public extension View {
    /// 仅在 macOS 设置 listStyle 为 inset
    func insetListStyleIfMac() -> some View {
        self.listStyle(.inset)
    }

    /// 标准侧边栏列表样式（macOS 用 .sidebar）
    func adaptiveSidebarListStyle() -> some View {
        self.listStyle(.sidebar)
    }

    /// macOS NavigationSplitView 侧边栏列移除系统默认 sidebarToggle（仅在 sidebar 列上生效）
    func appHideSystemSidebarToggle() -> some View {
        self.toolbar(removing: .sidebarToggle)
    }

    /// macOS NavigationSplitView 右侧 detail 窗体导航栏：
    /// 主侧边栏折叠按钮已归位至左侧窗体交通灯旁（macOS 原生 sidebarToggle）；
    /// 右侧 detail 工具栏仅保留本窗体控件：「（可选）知识库二级导航折叠 → VaultBadge」。
    func appCustomSidebarToggle(
        visibility _: Binding<NavigationSplitViewVisibility>,
        secondaryVisibility: Binding<Bool>? = nil
    ) -> some View {
        self
            .toolbar {
                if let secondaryVisibility {
                    ToolbarItem(placement: .navigation) {
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
                }

                ToolbarItem(placement: .navigation) {
                    VaultBadge()
                }
            }
    }
}
#else
public extension View {
    func insetListStyleIfMac() -> some View { self }
    func adaptiveSidebarListStyle() -> some View { self }
    func appHideSystemSidebarToggle() -> some View { self }
    func appCustomSidebarToggle(
        visibility _: Binding<NavigationSplitViewVisibility>,
        secondaryVisibility: Binding<Bool>? = nil
    ) -> some View { self }
}
#endif

public extension View {
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
    func plainMenuStyleIfMac() -> some View {
        modifier(PlainMenuStyleIfMacModifier())
    }

    // MARK: - 工具栏尺寸适配

    /// 工具栏纯图标按钮尺寸自适应：
    /// 在 macOS 下为工具栏图标按钮提供舒展的最小尺寸（28x28），防止因固定 20pt 宽度在工具栏中被左右挤压变形；
    /// 在 iOS/iPadOS/watchOS 下保持内容自适应大小。
    func appToolbarItemStandardFrame() -> some View {
        modifier(ToolbarItemStandardFrameModifier())
    }

    /// 用户头像及工具栏触控目标适配：
    /// iOS/iPadOS/watchOS: 保持 HIG 44x44 触控热区
    /// macOS: 遵循 macOS 工具栏 28x28 标准最小尺寸，保证舒展比例且不失衡
    func appToolbarAdaptiveTouchTarget() -> some View {
        modifier(ToolbarAdaptiveTouchTargetModifier())
    }

    /// 工具栏按钮样式跨平台适配：
    /// macOS 工具栏保留原生按钮样式，避免 `.buttonStyle(.plain)` 剥离系统水平内边距导致图标按钮被左右挤压；
    /// iOS/iPadOS/watchOS 保持 `.plain` 样式。
    func appToolbarButtonStyle() -> some View {
        modifier(ToolbarButtonStyleModifier())
    }

    /// 跨平台分组表单样式：全平台统一使用 `.grouped` 对齐系统设置卡片风格
    func appGroupedFormStyle() -> some View {
        self.formStyle(.grouped)
    }

    /// 桌面宽屏/全屏居中限宽容器：仅在 `.mac` 桌面形态下限制内容最大宽度并居中，
    /// 避免超宽屏全屏时单列内容被拉成横跨整屏的长条；iOS/iPadOS/watchOS 保持原样。
    func appDesktopReadableWidth(_ maxWidth: CGFloat) -> some View {
        modifier(DesktopReadableWidthModifier(maxWidth: maxWidth))
    }

    /// macOS 桌面端 `.sheet()` 弹窗语义化最小宽高约束（防止 macOS 弹窗塌缩成极窄小窗；iOS/watchOS 无影响）。
    func appDesktopSheetSize(_ preset: DesktopSheetPreset = .standard) -> some View {
        modifier(DesktopSheetSizeModifier(preset: preset))
    }

    /// 跨平台自适应弹窗原语（isPresented 版本）：内置 macOS 桌面最小宽高约束，从 API 层面杜绝漏配弹窗尺寸。
    func appAdaptiveSheet<Content: View>(
        isPresented: Binding<Bool>,
        preset: DesktopSheetPreset = .standard,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        self.sheet(isPresented: isPresented, onDismiss: onDismiss) {
            content().appDesktopSheetSize(preset)
        }
    }

    /// 跨平台自适应弹窗原语（item 版本）：内置 macOS 桌面最小宽高约束，从 API 层面杜绝漏配弹窗尺寸。
    func appAdaptiveSheet<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        preset: DesktopSheetPreset = .standard,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        self.sheet(item: item, onDismiss: onDismiss) { value in
            content(value).appDesktopSheetSize(preset)
        }
    }
}

/// macOS 桌面端弹窗尺寸分档（全量基于 DesignTokens 既有令牌）
public enum DesktopSheetPreset {
    /// 轻量表单（500 × 500pt）：新建/编辑笔记本、链接导入、创建协作房间、Token/服务器配置等
    case compact
    /// 标准面板（560 × 600pt）：新建页面、反向链接、图标选择器、提示词、政策协议、合成参数等
    case standard
    /// 大尺寸诊断/预览（820 × 600pt）：知识巡检、洞察面板、性能监控、快照历史、合成预览、模型实验室配置等
    case large

    var minWidth: CGFloat {
        switch self {
        case .compact: DesignTokens.Spacing.Decorator.desktopSheetMinWidth
        case .standard: DesignTokens.Metrics.macProfileWindowWidth
        case .large: DesignTokens.Metrics.macSettingsWindowWidth
        }
    }

    var minHeight: CGFloat {
        switch self {
        case .compact: DesignTokens.Spacing.Decorator.desktopSheetMinWidth
        case .standard: DesignTokens.Spacing.Decorator.desktopSheetMinHeight
        case .large: DesignTokens.Metrics.macSettingsWindowHeight
        }
    }
}

/// macOS 桌面弹窗最小宽高修饰符（基于运行时 Trait `interfaceIdiom`，零平台宏）
private struct DesktopSheetSizeModifier: ViewModifier {
    @Environment(\.interfaceIdiom) private var idiom
    let preset: DesktopSheetPreset

    func body(content: Content) -> some View {
        if idiom == .mac {
            content.frame(minWidth: preset.minWidth, minHeight: preset.minHeight)
        } else {
            content
        }
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

// MARK: - 侧边栏列宽修饰器
public extension View {
    /// 仅 macOS 桌面应用侧边栏列首选宽度（基于运行时 Trait `interfaceIdiom`，零平台宏）
    @ViewBuilder
    func macSidebarColumnWidth(_ width: CGFloat = DesignTokens.Metrics.macSidebarWidth) -> some View {
        modifier(MacSidebarColumnWidthModifier(width: width))
    }
}

private struct MacSidebarColumnWidthModifier: ViewModifier {
    @Environment(\.interfaceIdiom) private var idiom
    let width: CGFloat

    func body(content: Content) -> some View {
        if idiom == .mac {
            content.navigationSplitViewColumnWidth(width)
        } else {
            content
        }
    }
}

private struct PlainMenuStyleIfMacModifier: ViewModifier {
    @Environment(\.interfaceIdiom) private var idiom

    func body(content: Content) -> some View {
        if idiom == .mac {
            content
                .menuStyle(.button)
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .fixedSize()
        } else {
            content
        }
    }
}

private struct ToolbarItemStandardFrameModifier: ViewModifier {
    @Environment(\.interfaceIdiom) private var idiom

    func body(content: Content) -> some View {
        if idiom == .mac {
            content
                .frame(minWidth: DesignTokens.Spacing.largeIconSize, minHeight: DesignTokens.Spacing.largeIconSize)
                .contentShape(Rectangle())
        } else {
            content
        }
    }
}

private struct ToolbarAdaptiveTouchTargetModifier: ViewModifier {
    @Environment(\.interfaceIdiom) private var idiom

    func body(content: Content) -> some View {
        if idiom == .mac {
            content
                .frame(minWidth: DesignTokens.Spacing.largeIconSize, minHeight: DesignTokens.Spacing.largeIconSize)
                .contentShape(Rectangle())
        } else {
            content.higTouchTarget()
        }
    }
}

private struct ToolbarButtonStyleModifier: ViewModifier {
    @Environment(\.interfaceIdiom) private var idiom

    func body(content: Content) -> some View {
        if idiom == .mac {
            content
        } else {
            content.buttonStyle(.plain)
        }
    }
}

private struct HiddenOnWatchModifier: ViewModifier {
    @Environment(\.interfaceIdiom) private var idiom

    func body(content: Content) -> some View {
        if idiom == .watch {
            content.hidden()
        } else {
            content
        }
    }
}

private struct MaxWidthIfNotWatchModifier: ViewModifier {
    @Environment(\.interfaceIdiom) private var idiom
    let alignment: Alignment

    func body(content: Content) -> some View {
        if idiom == .watch {
            content
        } else {
            content.frame(maxWidth: .infinity, alignment: alignment)
        }
    }
}

private struct SegmentedPickerStyleModifier: ViewModifier {
    @Environment(\.interfaceIdiom) private var idiom

    func body(content: Content) -> some View {
        if idiom == .watch {
            content
        } else {
            content.pickerStyle(.segmented)
        }
    }
}

private struct RoundedBorderTextFieldStyleModifier: ViewModifier {
    @Environment(\.interfaceIdiom) private var idiom

    func body(content: Content) -> some View {
        if idiom == .watch {
            content
        } else {
            content.textFieldStyle(.roundedBorder)
        }
    }
}
