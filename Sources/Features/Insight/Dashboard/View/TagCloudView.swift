//
//  TagCloudView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：标签管理的顶层视图容器与核心内容视图的声明，负责状态持有、生命周期任务调度与
//  弹窗逻辑挂载。主内容布局、子视图组件、对话框及渲染微组件已拆分至独立文件。
//

import SwiftUI
import UFPCore

// MARK: - 标签云视图 (导航容器)

/// 标签管理的顶层视图容器，负责承载主内容
struct TagCloudView: View {
    /// 初始选中的标签（由外部跳转传入）
    var initialTag: String?

    var body: some View {
        TagCloudViewContent(initialTag: initialTag)
    }
}

// MARK: - 标签管理主内容

/// 标签管理的核心业务逻辑与界面实现
struct TagCloudViewContent: View {
    // ── 外部依赖 ──
    @Environment(AppStore.self) var store
    @Inject var appEnv: any AppEnvironmentProtocol
    @Inject var deviceInfo: any DeviceInfoProtocol

    // 使用协调器管理状态与交互
    @State var coordinator: TagCloudCoordinator
    @State var showBulkDeleteConfirm = false
    @State var displayMode: DisplayMode = .list
    @State private var showSearchBar = false
    @State var isExpanded = false

    enum DisplayMode {
        case list
        case bubble
    }

    // ── 顶部工具栏重构排版与透明度设计常量 (杜绝魔鬼数字与 swiftlint 禁用) ──
    let pickerBtnPaddingV: CGFloat = 8.0
    let pickerBtnPaddingH: CGFloat = 14.0
    let pickerInnerPadding: CGFloat = 3.0
    let actionBtnDiameter: CGFloat = 36.0
    let toolbarCornerRadius: CGFloat = 22.0
    let bubbleCanvasMinHeight: CGFloat = 280.0
    let viewModeFontSize: CGFloat = 13.0
    let actionBtnIconFontSize: CGFloat = 14.0
    let pickerSelectedBgOpacity = 0.85
    let pickerUnselectedBgOpacity = 0.18
    let actionBtnBgOpacity = 0.6
    let actionBtnBorderOpacity = 0.3
    let toolbarBgOpacity = 0.45
    let toolbarBorderOpacity = 0.35

    // ── 列表折叠遮罩设计常量 ──
    let listCollapseGradientHeight: CGFloat = 35.0
    let listCollapseGradientOpacity = 0.8

    /// 初始化路由状态
    /// - Parameter initialTag: 外部传入的初始选中标签
    init(initialTag: String? = nil) {
        self._coordinator = State(initialValue: TagCloudCoordinator(initialTag: initialTag))
    }

    var body: some View {
        @Bindable var coordinator = coordinator

        mainContent
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(PageBackgroundView(accentColor: .blue))
            .appSubPageToolbar(title: L10n.Tag.title)
            .task {
                await coordinator.fetchData()
            }
            .onChange(of: store.pages) { _, _ in
                Task { await coordinator.fetchData() }
            }
            // 关键优化：将繁重的弹窗及确认对话框逻辑移至独立子视图，规避 SwiftUI 闭包过深导致的 Swift 编译器类型推演超时 (Type-Checking Timeout)
            .background {
                dialogsView
            }
    }
}
