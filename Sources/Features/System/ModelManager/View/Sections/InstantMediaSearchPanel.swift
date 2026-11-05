//
//  InstantMediaSearchPanel.swift
//  ZhiYu
//
//  系统层级：[L3] 表现层
//  核心职责：多模态即时媒体检索（以文搜图）沙盒交互面板，支持图片导入、多模态特征索引与端侧向量余弦相似度检索展示。
//

import SwiftUI
import PhotosUI
import CoreGraphics
import ImageIO
import ZhiYuAICore
import UFPDesignSystem

/// 即时媒体检索沙盒状态管理
@Observable
@MainActor
public final class InstantMediaSearchState {
    public static let shared = InstantMediaSearchState()

    public var query: String = ""
    public var results: [MediaSearchResult] = []
    public var allItems: [MediaItem] = []
    public var isSearching: Bool = false
    public var isImporting: Bool = false
    public var selectedPhotoItems: [PhotosPickerItem] = []
    public var similarityThreshold: Double = FeatureConstants.MediaSearch.defaultSimilarityThreshold

    /// 根据相似度阈值动态过滤检索结果
    public var filteredResults: [MediaSearchResult] {
        results.filter { Double($0.score) >= similarityThreshold }
    }

    public init() {}

    public func refreshItems() async {
        allItems = await MediaSearchIndexer.shared.allItems()
    }

    public func executeSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            return
        }
        isSearching = true
        do {
            results = try await MediaSearchIndexer.shared.search(
                query: trimmed,
                topK: FeatureConstants.MediaSearch.defaultTopK
            )
        } catch {
            results = []
        }
        isSearching = false
    }

    public func clearIndex() async {
        await MediaSearchIndexer.shared.clear()
        results = []
        allItems = []
    }

    /// 载入预置演示特征图库，无需读取系统相册即可快速体验真实多模态检索
    public func loadDemoSamples() async {
        isImporting = true
        // 优先导入真实丰富的预置多模态视觉画幅（智能工位、分层架构拓扑、城市夜景晚霞天际线）
        for sample in LabVisualSampleProvider.shared.presetSamples {
            if let source = CGImageSourceCreateWithData(sample.imageData as CFData, nil),
               let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) {
                _ = try? await MediaSearchIndexer.shared.indexImage(cgImage, title: sample.title)
            }
        }
        await refreshItems()
        isImporting = false
    }

    /// 以图搜图：使用特定图片的视觉特征向量检索图库中相似图片
    public func searchByImage(targetId: String) async {
        isSearching = true
        results = await MediaSearchIndexer.shared.searchByImage(
            targetId: targetId,
            topK: FeatureConstants.MediaSearch.defaultTopK
        )
        isSearching = false
    }

    public func handleSelectedPhotos() async {
        guard !selectedPhotoItems.isEmpty else { return }
        isImporting = true
        for (index, item) in selectedPhotoItems.enumerated() {
            if let data = try? await item.loadTransferable(type: Data.self),
               let source = CGImageSourceCreateWithData(data as CFData, nil),
               let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) {
                let title = "\(L10n.ModelManager.Lab.useCaseInstantMediaSearch) #\(allItems.count + index + 1)"
                _ = try? await MediaSearchIndexer.shared.indexImage(cgImage, title: title)
            }
        }
        selectedPhotoItems = []
        await refreshItems()
        if !query.isEmpty {
            await executeSearch()
        }
        isImporting = false
    }
}

// MARK: - 即时媒体检索视图扩展

extension ModelLabView {

    /// 即时媒体检索沙盒面板
    @ViewBuilder
    var instantMediaSearchSandboxView: some View {
        InstantMediaSearchContentView(
            labView: self,
            state: InstantMediaSearchState.shared
        )
    }
}

/// 媒体检索内容子视图
@MainActor
struct InstantMediaSearchContentView: View {
    let labView: ModelLabView
    @Bindable var state: InstantMediaSearchState

    private let gridColumns = [
        GridItem(.adaptive(minimum: DesignTokens.Metrics.sourceCardHeight, maximum: DesignSystem.Vault.gridCardMax), spacing: DesignTokens.Spacing.medium)
    ]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: DesignTokens.Spacing.medium) {
                // 控制栏
                labView.modelAndConfigControlBar(for: .instantMediaSearch)

                // 预设快捷检索词胶囊栏
                quickChipsBar

                // 搜索输入区与导入栏
                searchAndActionBar

                // 内容展示区
                if state.isImporting {
                    importingIndicator
                } else if state.allItems.isEmpty {
                    emptyHintView
                } else {
                    mediaResultsGrid
                }
            }
            .padding(.vertical, DesignTokens.SystemSpacing.atomic)
        }
        .task {
            await state.refreshItems()
        }
        .onChange(of: state.selectedPhotoItems) { _, _ in
            Task {
                await state.handleSelectedPhotos()
            }
        }
    }

    // MARK: - 快捷检索词胶囊栏

    @ViewBuilder
    private var quickChipsBar: some View {
        let sampleQueries = [
            L10n.ModelManager.Lab.Prompt.instantMediaSearch,
            L10n.ModelManager.Lab.Chip.plants,
            L10n.ModelManager.Lab.Chip.ocean,
            L10n.ModelManager.Lab.Chip.sunset
        ]

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignTokens.SystemSpacing.tiny) {
                ForEach(sampleQueries, id: \.self) { sample in
                    Button(action: {
                        state.query = sample
                        Task { await state.executeSearch() }
                    }) {
                        Text(sample)
                            .font(.caption2.bold())
                            .foregroundStyle(state.query == sample ? Color.theme.white : Color.theme.orange)
                            .padding(.horizontal, DesignTokens.SystemSpacing.small)
                            .padding(.vertical, DesignTokens.SystemSpacing.tiny)
                            .background(
                                state.query == sample ? Color.theme.orange : Color.theme.orange.opacity(DesignTokens.Opacity.disabled)
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DesignTokens.SystemSpacing.atomic)
        }
    }

    // MARK: - 搜索与操作栏

    @ViewBuilder
    private var searchAndActionBar: some View {
        VStack(spacing: DesignTokens.Spacing.small) {
            HStack(spacing: DesignTokens.Spacing.small) {
                Image(systemName: DesignTokens.Icons.magnifyingglass)
                    .foregroundStyle(Color.theme.orange)

                TextField(
                    L10n.ModelManager.Lab.MediaSearch.searchPlaceholder,
                    text: $state.query
                )
                .textFieldStyle(.plain)
                .foregroundStyle(Color.theme.text)
                .onSubmit {
                    Task { await state.executeSearch() }
                }

                if !state.query.isEmpty {
                    Button(action: {
                        state.query = ""
                        state.results = []
                    }) {
                        Image(systemName: DesignTokens.Icons.xmarkCircle)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Button(action: {
                    Task { await state.executeSearch() }
                }) {
                    Text(L10n.ModelManager.Lab.send)
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.theme.white)
                        .padding(.horizontal, DesignTokens.SystemSpacing.content)
                        .padding(.vertical, DesignTokens.SystemSpacing.tiny)
                        .background(Color.theme.orange)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(DesignTokens.Spacing.standardPadding)
            .background(Color.appCard.opacity(DesignTokens.Opacity.dim))
            .cornerRadius(DesignTokens.Spacing.mediumRadius)

            // 操作按键组
            HStack(spacing: DesignTokens.SystemSpacing.small) {
                PhotosPicker(
                    selection: $state.selectedPhotoItems,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    HStack(spacing: DesignTokens.SystemSpacing.tiny) {
                        Image(systemName: DesignTokens.Icons.plusCircle)
                        Text(L10n.ModelManager.Lab.MediaSearch.importImage)
                    }
                    .font(.caption.bold())
                    .foregroundStyle(Color.theme.orange)
                    .padding(.horizontal, DesignTokens.SystemSpacing.medium)
                    .padding(.vertical, DesignTokens.SystemSpacing.small)
                    .background(Color.theme.orange.opacity(DesignTokens.Opacity.disabled))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button(action: {
                    Task { await state.loadDemoSamples() }
                }) {
                    HStack(spacing: DesignTokens.SystemSpacing.tiny) {
                        Image(systemName: DesignTokens.Icons.sparkles)
                        Text(L10n.ModelManager.Lab.loadDemoImages)
                    }
                    .font(.caption.bold())
                    .foregroundStyle(Color.theme.orange)
                    .padding(.horizontal, DesignTokens.SystemSpacing.medium)
                    .padding(.vertical, DesignTokens.SystemSpacing.small)
                    .background(Color.theme.orange.opacity(DesignTokens.Opacity.disabled))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Spacer()

                if !state.allItems.isEmpty {
                    Button(action: {
                        Task { await state.clearIndex() }
                    }) {
                        Text(L10n.ModelManager.Lab.clearIndex)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if !state.results.isEmpty {
                HStack(spacing: DesignTokens.Spacing.small) {
                    Text(L10n.ModelManager.Lab.MediaSearch.thresholdLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Slider(
                        value: $state.similarityThreshold,
                        in: FeatureConstants.MediaSearch.minSimilarityThreshold...FeatureConstants.MediaSearch.maxSimilarityThreshold,
                        step: FeatureConstants.MediaSearch.thresholdStep
                    )
                    .tint(Color.theme.orange)
                    Text(L10n.ModelManager.Lab.MediaSearch.thresholdFormat(state.similarityThreshold * FeatureConstants.MediaSearch.percentMultiplier))
                        .font(.caption2.monospacedDigit().bold())
                        .foregroundStyle(Color.theme.orange)
                }
                .padding(.top, DesignTokens.SystemSpacing.atomic)
            }
        }
    }

    // MARK: - 媒体网格展示

    @ViewBuilder
    private var mediaResultsGrid: some View {
        let displayItems: [(item: MediaItem, score: Float?)] = {
            if !state.results.isEmpty {
                return state.filteredResults.map { ($0.item, Optional($0.score)) }
            }
            return state.allItems.map { ($0, nil) }
        }()

        LazyVGrid(columns: gridColumns, spacing: DesignTokens.Spacing.medium) {
            ForEach(displayItems, id: \.item.id) { element in
                mediaCard(item: element.item, score: element.score)
            }
        }
    }

    @ViewBuilder
    private func mediaCard(item: MediaItem, score: Float?) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            ZStack(alignment: .topTrailing) {
                if let data = item.thumbnailData,
                   let platformImage = makePlatformImage(from: data) {
                    Image(platformImage: platformImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: FeatureConstants.MediaSearch.thumbnailHeight)
                        .clipped()
                        .cornerRadius(DesignTokens.Spacing.smallRadius)
                } else {
                    Rectangle()
                        .fill(Color.theme.gray.opacity(DesignTokens.Opacity.disabled))
                        .frame(height: FeatureConstants.MediaSearch.thumbnailHeight)
                        .cornerRadius(DesignTokens.Spacing.smallRadius)
                        .overlay(
                            Image(systemName: DesignTokens.Icons.photo)
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                        )
                }

                if let scoreVal = score {
                    Text(L10n.ModelManager.Lab.similarityScore(scoreVal * FeatureConstants.MediaSearch.scoreMultiplier))
                        .font(.system(size: DesignTokens.SystemFontSize.micro).bold())
                        .padding(.horizontal, DesignTokens.SystemSpacing.tiny)
                        .padding(.vertical, DesignTokens.SystemSpacing.atomic)
                        .background(Color.theme.orange)
                        .foregroundStyle(Color.theme.white)
                        .clipShape(Capsule())
                        .padding(DesignTokens.SystemSpacing.tiny)
                }
            }

            HStack {
                Text(item.title)
                    .font(.caption.bold())
                    .foregroundStyle(Color.theme.text)
                    .lineLimit(1)

                Spacer()

                Button(action: {
                    Task { await state.searchByImage(targetId: item.id) }
                }) {
                    Image(systemName: DesignTokens.Icons.sparkles)
                        .font(.caption2)
                        .foregroundStyle(Color.theme.orange)
                        .padding(DesignTokens.SystemSpacing.tiny)
                        .background(Color.theme.orange.opacity(DesignTokens.Opacity.disabled))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help(L10n.ModelManager.Lab.searchSimilarImage)
            }
        }
        .padding(DesignTokens.Spacing.small)
        .background(Color.appCard.opacity(DesignTokens.Opacity.dim))
        .cornerRadius(DesignTokens.Spacing.mediumRadius)
    }

    // MARK: - 空提示与加载中

    @ViewBuilder
    private var emptyHintView: some View {
        VStack(spacing: DesignTokens.Spacing.medium) {
            Image(systemName: DesignTokens.Icons.photoOnRectangle)
                .font(.system(size: DesignTokens.Spacing.Gallery.iconSize))
                .foregroundStyle(Color.theme.orange.opacity(DesignTokens.Opacity.soft))

            Text(L10n.ModelManager.Lab.MediaSearch.emptyHint)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignTokens.Spacing.large)

            Button(action: {
                Task { await state.loadDemoSamples() }
            }) {
                HStack(spacing: DesignTokens.SystemSpacing.tiny) {
                    Image(systemName: DesignTokens.Icons.sparkles)
                    Text(L10n.ModelManager.Lab.loadDemoImages)
                }
                .font(.caption.bold())
                .foregroundStyle(Color.theme.white)
                .padding(.horizontal, DesignTokens.SystemSpacing.medium)
                .padding(.vertical, DesignTokens.SystemSpacing.small)
                .background(Color.theme.orange)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, minHeight: FeatureConstants.MediaSearch.previewImageHeight)
        .cardStyle(horizontalPadding: DesignTokens.Spacing.medium, verticalPadding: DesignTokens.Spacing.large)
    }

    @ViewBuilder
    private var importingIndicator: some View {
        VStack(spacing: DesignTokens.Spacing.medium) {
            ProgressView()
                .tint(Color.theme.orange)
            Text(L10n.ModelManager.Lab.VideoSearch.indexing)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: FeatureConstants.MediaSearch.previewImageHeight)
    }
}

// MARK: - 跨平台图片生成辅助

#if canImport(UIKit)
import UIKit
typealias LabCrossPlatformImage = UIImage
func makePlatformImage(from data: Data) -> LabCrossPlatformImage? {
    UIImage(data: data)
}
extension Image {
    init(platformImage: LabCrossPlatformImage) {
        self.init(uiImage: platformImage)
    }
}
#elseif canImport(AppKit)
import AppKit
typealias LabCrossPlatformImage = NSImage
func makePlatformImage(from data: Data) -> LabCrossPlatformImage? {
    NSImage(data: data)
}
extension Image {
    init(platformImage: LabCrossPlatformImage) {
        self.init(nsImage: platformImage)
    }
}
#endif
