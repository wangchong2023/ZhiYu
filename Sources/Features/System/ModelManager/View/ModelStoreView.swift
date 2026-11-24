//
//  ModelStoreView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/29.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层 / 视图组件
//  核心职责：大模型市场容器视图 — 集成硬件看板、任务类型筛选胶囊与模型列表编排。
//

import SwiftUI
import UniformTypeIdentifiers
import Dependencies
import UFPCore
import UFPDesignSystem

/// 模型市场分类筛选类别
public enum ModelStoreFilter: String, CaseIterable, Identifiable {
    case all
    case chat
    case vision
    case search
    case audio

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .all: return L10n.ModelManager.Filter.all
        case .chat: return L10n.ModelManager.Filter.chat
        case .vision: return L10n.ModelManager.Filter.vision
        case .search: return L10n.ModelManager.Filter.search
        case .audio: return L10n.ModelManager.Filter.audio
        }
    }
}

/// 动态端侧大模型市场面板视图
@MainActor
public struct ModelStoreView: View {

    // MARK: - 注入环境与中台

    @Environment(AppStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(ThemeManager.self) private var themeManager
    @Dependency(\.toastService) private var toastService

    /// 全局大模型市场中台管理器
    @State private var modelManager = GlobalModelManager.shared

    /// 进入测试实验室的回调
    public var onGoToLab: () -> Void

    // MARK: - 局部视图状态

    /// 触发警告弹窗的模型元数据
    @State private var alertManifest: LLMManifest?
    /// 展开详情的模型 ID
    @State private var expandedModelId: String?
    /// 当前选中的任务类型筛选
    @State private var selectedFilter: ModelStoreFilter = .all
    /// 控制 BYOM 本地模型文件选择器弹出
    @State private var showModelImporter = false
    /// 控制双源（魔搭社区 / HuggingFace）令牌配置弹窗
    @State private var showHFTokenSheet = false
    /// HuggingFace 令牌编辑态文本
    @State private var hfTokenInput = ""
    /// 魔搭社区 SDK 令牌编辑态文本
    @State private var msTokenInput = ""

    /// 是否需要外层 ScrollView 包装，用于扁平化整合单页滚动
    public var embedInScrollView: Bool = true

    public init(embedInScrollView: Bool = true, onGoToLab: @escaping () -> Void) {
        self.embedInScrollView = embedInScrollView
        self.onGoToLab = onGoToLab
    }

    /// 根据筛选类型过滤的模型列表
    private var filteredManifests: [LLMManifest] {
        switch selectedFilter {
        case .all:
            return modelManager.remoteManifests
        case .chat:
            return modelManager.remoteManifests.filter {
                $0.supportedTasks.contains(FeatureConstants.TaskName.chat) ||
                $0.supportedTasks.contains(FeatureConstants.TaskName.completion) ||
                $0.supportedTasks.contains(FeatureConstants.TaskName.reasoning)
            }
        case .vision:
            return modelManager.remoteManifests.filter {
                $0.supportedTasks.contains(FeatureConstants.ModelTaskTag.multimodal) ||
                $0.supportedTasks.contains(FeatureConstants.ModelTaskTag.vision)
            }
        case .search:
            return modelManager.remoteManifests.filter {
                $0.supportedTasks.contains(FeatureConstants.TaskName.mediaSearch) ||
                $0.supportedTasks.contains(FeatureConstants.TaskName.videoSearch) ||
                $0.supportedTasks.contains(FeatureConstants.ModelTaskTag.embedding)
            }
        case .audio:
            return modelManager.remoteManifests.filter {
                $0.supportedTasks.contains(FeatureConstants.ModelTaskTag.audio) ||
                $0.supportedTasks.contains(FeatureConstants.ModelTaskTag.transcription)
            }
        }
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
                        // 视图重现时恢复活跃下载的订阅，防止离开页面/切换 Tab 后状态停滞
                        modelManager.resubscribeActiveDownloads()
                    }
                    .refreshable {
                        await modelManager.reload()
                    }
                } else {
                    contentList
                        .task {
                            await modelManager.reload()
                            modelManager.resubscribeActiveDownloads()
                        }
                }
            }
        }
        .navigationTitle(L10n.Settings.localModelManager)
        .inlineNavigationBarTitleIfAvailable()
        .onAppear {
            modelManager.refreshHuggingFaceTokenStatus()
        }
        .fileImporter(
            isPresented: $showModelImporter,
            allowedContentTypes: [.data, .item],
            allowsMultipleSelection: false
        ) { result in
            handleModelImportResult(result)
        }
        .sheet(isPresented: $showHFTokenSheet) {
            hfTokenConfigSheet
        }
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
        LazyVStack(spacing: DesignTokens.Spacing.medium) {
            // 1. 端侧硬件算力看板
            DeviceHardwareBar()

            // 2. BYOM 本地导入 & HuggingFace 令牌快捷操作条
            storeUtilityBar

            // 3. 任务分类横向筛选胶囊栏
            filterChipsBar

            // 3. 模型卡片列表
            if filteredManifests.isEmpty {
                emptyFilteredView
            } else {
                ForEach(filteredManifests) { manifest in
                    ModelCardView(
                        manifest: manifest,
                        modelManager: modelManager,
                        alertManifest: $alertManifest,
                        expandedModelId: $expandedModelId,
                        onGoToLab: onGoToLab
                    )
                }
            }
        }
        .padding(DesignTokens.Spacing.medium)
    }

    // MARK: - 筛选胶囊栏

    @ViewBuilder
    private var filterChipsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignTokens.SystemSpacing.small) {
                ForEach(ModelStoreFilter.allCases) { filter in
                    Button(action: {
                        withAnimation(.easeInOut) {
                            selectedFilter = filter
                        }
                    }) {
                        Text(filter.title)
                            .font(.caption.bold())
                            .foregroundStyle(selectedFilter == filter ? Color.theme.white : Color.theme.text)
                            .padding(.horizontal, DesignTokens.SystemSpacing.medium)
                            .padding(.vertical, DesignTokens.SystemSpacing.small)
                            .background(
                                selectedFilter == filter ? Color.theme.cyan : Color.appCard.opacity(DesignTokens.Opacity.disabled)
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DesignTokens.SystemSpacing.atomic)
        }
    }

    @ViewBuilder
    private var emptyFilteredView: some View {
        VStack(spacing: DesignTokens.Spacing.small) {
            Image(systemName: DesignTokens.Icons.magnifyingglass)
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(L10n.Common.Empty.noData)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: DesignTokens.Metrics.sourceCardHeight)
        .cardStyle(horizontalPadding: DesignTokens.Spacing.medium, verticalPadding: DesignTokens.Spacing.large)
    }

    // MARK: - BYOM 本地导入 & HuggingFace 令牌栏

    @ViewBuilder
    private var storeUtilityBar: some View {
        HStack(spacing: DesignTokens.Spacing.small) {
            Button(action: { showModelImporter = true }) {
                Label(L10n.ModelManager.BYOM.importButton, systemImage: DesignTokens.Icons.folderBadgePlus)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.appAccent)
                    .padding(.horizontal, DesignTokens.SystemSpacing.medium)
                    .padding(.vertical, DesignTokens.SystemSpacing.small)
                    .background(Color.appAccent.opacity(DesignTokens.Opacity.glass))
                    .clipShape(Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("importLocalModelButton")

            Button(action: {
                msTokenInput = modelManager.loadModelScopeToken()
                hfTokenInput = modelManager.loadHuggingFaceToken()
                showHFTokenSheet = true
            }) {
                HStack(spacing: DesignTokens.Spacing.tiny) {
                    Image(systemName: DesignTokens.Icons.lock)
                        .font(.caption)
                    Text(L10n.ModelManager.ModelSource.title)
                        .font(.caption.weight(.semibold))
                    if modelManager.hasAnySourceToken {
                        Text(L10n.ModelManager.HFToken.configured)
                            .font(.caption2.bold())
                            .foregroundStyle(Color.theme.green)
                    }
                }
                .foregroundStyle(.appText)
                .padding(.horizontal, DesignTokens.SystemSpacing.medium)
                .padding(.vertical, DesignTokens.SystemSpacing.small)
                .background(Color.appCard.opacity(DesignTokens.Opacity.prominent))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(Color.appBorder.opacity(DesignTokens.Opacity.soft), lineWidth: DesignTokens.Spacing.borderWidth)
                )
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("hfTokenConfigButton")

            Spacer()
        }
    }

    @ViewBuilder
    private var hfTokenConfigSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.large) {
                    // 1. 首选下载源路由策略（自动 / 魔搭社区 / HuggingFace）
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
                        Text(L10n.ModelManager.ModelSource.preferenceLabel)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.appText)

                        Picker(
                            L10n.ModelManager.ModelSource.preferenceLabel,
                            selection: Binding(
                                get: { modelManager.downloadSourcePreference },
                                set: { modelManager.downloadSourcePreference = $0 }
                            )
                        ) {
                            ForEach(GlobalModelManager.DownloadSourcePreference.allCases) { pref in
                                Text(pref.displayTitle).tag(pref)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }

                    Divider()

                    // 2. 魔搭社区 (ModelScope) SDK 令牌
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
                        HStack {
                            Text(L10n.ModelManager.ModelSource.msTokenTitle)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.appText)
                            if modelManager.hasModelScopeToken {
                                Text(L10n.ModelManager.HFToken.configured)
                                    .font(.caption2.bold())
                                    .foregroundStyle(Color.theme.green)
                            }
                        }
                        Text(L10n.ModelManager.ModelSource.msTokenDesc)
                            .font(.caption)
                            .foregroundStyle(.appSecondary)
                        SecureField(L10n.ModelManager.ModelSource.msTokenPlaceholder, text: $msTokenInput)
                            .textFieldStyle(.roundedBorder)
                    }

                    Divider()

                    // 3. HuggingFace 访问令牌
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
                        HStack {
                            Text(L10n.ModelManager.HFToken.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.appText)
                            if modelManager.hasHuggingFaceToken {
                                Text(L10n.ModelManager.HFToken.configured)
                                    .font(.caption2.bold())
                                    .foregroundStyle(Color.theme.green)
                            }
                        }
                        Text(L10n.ModelManager.HFToken.description)
                            .font(.caption)
                            .foregroundStyle(.appSecondary)
                        SecureField(L10n.ModelManager.HFToken.placeholder, text: $hfTokenInput)
                            .textFieldStyle(.roundedBorder)
                    }

                    HStack(spacing: DesignTokens.Spacing.medium) {
                        if modelManager.hasAnySourceToken {
                            Button(L10n.ModelManager.HFToken.clear, role: .destructive) {
                                modelManager.clearModelScopeToken()
                                modelManager.clearHuggingFaceToken()
                                msTokenInput = ""
                                hfTokenInput = ""
                                showHFTokenSheet = false
                            }
                        }
                        Spacer()
                        Button(L10n.Common.cancel) {
                            showHFTokenSheet = false
                        }
                        Button(L10n.Common.save) {
                            modelManager.saveModelScopeToken(msTokenInput)
                            modelManager.saveHuggingFaceToken(hfTokenInput)
                            showHFTokenSheet = false
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(DesignTokens.Spacing.wide)
            }
            .navigationTitle(L10n.ModelManager.ModelSource.title)
            .appNavigationBarTitleDisplayMode(.inline)
        }
        .frame(minWidth: DesignTokens.Metrics.authFormWidth, minHeight: DesignTokens.Metrics.authHeroWidth)
    }

    private func handleModelImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let manifest = try modelManager.importCustomModel(from: url)
                toastService.show(type: .success, message: L10n.ModelManager.BYOM.importSuccess(manifest.displayName))
            } catch {
                toastService.show(type: .error, message: L10n.ModelManager.BYOM.importFailed(error.localizedDescription))
            }
        case .failure(let error):
            toastService.show(type: .error, message: L10n.ModelManager.BYOM.importFailed(error.localizedDescription))
        }
    }
}
