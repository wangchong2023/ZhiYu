//
//  ModelStoreView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/29.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层 / 视图组件
//  核心职责：大模型市场容器视图 — 持有 @State 状态树，编排列表展示与导航。
//
import SwiftUI
import UFPCore

/// 动态端侧大模型市场面板视图
@MainActor
public struct ModelStoreView: View {

    // MARK: - 注入环境与中台

    @Environment(AppStore.self) private var store
    @Environment(Router.self) private var router
    @EnvironmentObject private var themeManager: ThemeManager

    /// 全局大模型市场中台管理器
    @State private var modelManager = GlobalModelManager.shared

    /// 进入测试实验室的回调
    public var onGoToLab: () -> Void

    // MARK: - 局部视图状态

    /// 触发警告弹窗的模型元数据
    @State private var alertManifest: LLMManifest?
    /// 展开详情的模型 ID
    @State private var expandedModelId: String?

    /// 是否需要外层 ScrollView 包装，用于扁平化整合单页滚动
    public var embedInScrollView: Bool = true

    public init(embedInScrollView: Bool = true, onGoToLab: @escaping () -> Void) {
        self.embedInScrollView = embedInScrollView
        self.onGoToLab = onGoToLab
    }

    public var body: some View {
        ZStack {
            VStack(spacing: 0) {
                if embedInScrollView {
                    ScrollView {
                        contentList
                    }
                    .task {
                        await modelManager.reload()
                    }
                    .refreshable {
                        await modelManager.reload()
                    }
                } else {
                    contentList
                        .task {
                            await modelManager.reload()
                        }
                }
            }
        }
        .navigationTitle(L10n.Settings.localModelManager)
        .inlineNavigationBarTitleIfAvailable()
        .alert(item: $alertManifest) { manifest in
            let requiredGb = String(format: "%.1f", manifest.minDeviceMemoryInGb)
            let currentGb = String(format: "%.1f", Double(modelManager.physicalMemory) / SystemConstants.bytesPerGB)
            return Alert(
                title: Text(L10n.ModelManager.Alert.oomTitle),
                message: Text(L10n.ModelManager.Alert.oomMessage(manifest.displayName, requiredGb, currentGb)),
                dismissButton: .default(Text(L10n.Common.ok))
            )
        }
    }

    @ViewBuilder
    private var contentList: some View {
        LazyVStack(spacing: DesignSystem.medium) {
            ForEach(modelManager.remoteManifests) { manifest in
                ModelCardView(
                    manifest: manifest,
                    modelManager: modelManager,
                    alertManifest: $alertManifest,
                    expandedModelId: $expandedModelId,
                    onGoToLab: onGoToLab
                )
            }
        }
        .padding(DesignSystem.medium)
    }
}
