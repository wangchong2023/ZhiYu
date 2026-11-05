//
//  VideoMomentSearchPanel.swift
//  ZhiYu
//
//  系统层级：[L3] 表现层
//  核心职责：多模态视频时刻查找沙盒交互面板，支持视频文件导入、时序抽帧与向量索引，以及通过自然语言精准检索并跳转视频播放时刻。
//

import SwiftUI
import CoreGraphics
import UniformTypeIdentifiers
import ZhiYuAICore
import UFPDesignSystem
#if canImport(AVFoundation) && canImport(AVKit)
import AVFoundation
#endif
#if canImport(AVKit)
import AVKit
#endif

/// 视频时刻检索沙盒状态管理
@Observable
@MainActor
public final class VideoMomentSearchState {
    public static let shared = VideoMomentSearchState()

    public var selectedVideoURL: URL?
    public var indexedFramesCount: Int = 0
    public var isIndexing: Bool = false
    public var query: String = ""
    public var momentResults: [VideoMomentResult] = []
    public var isSearching: Bool = false
    public var showFileImporter: Bool = false

    #if canImport(AVKit)
    public var player: AVPlayer?
    #endif

    public init() {}

    public func handleVideoSelection(_ url: URL) async {
        #if canImport(AVKit)
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        selectedVideoURL = url
        player = AVPlayer(url: url)
        isIndexing = true
        momentResults = []

        do {
            let videoId = url.lastPathComponent
            _ = try await VideoMomentIndexer.shared.indexVideo(
                url: url,
                videoId: videoId,
                sampleInterval: FeatureConstants.VideoMoment.defaultSampleInterval
            )
            indexedFramesCount = await VideoMomentIndexer.shared.frameCount(for: videoId)
        } catch {
            indexedFramesCount = 0
        }

        isIndexing = false
        if didStartAccessing {
            url.stopAccessingSecurityScopedResource()
        }
        #endif
    }

    public func executeSearch() async {
        guard let url = selectedVideoURL else { return }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            momentResults = []
            return
        }

        isSearching = true
        do {
            momentResults = try await VideoMomentIndexer.shared.searchMoments(
                videoId: url.lastPathComponent,
                query: trimmed,
                topK: FeatureConstants.VideoMoment.defaultTopK
            )
        } catch {
            momentResults = []
        }
        isSearching = false
    }

    public func seekTo(seconds: Double) {
        #if canImport(AVKit)
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        player?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        player?.play()
        #endif
    }

    public func clearIndex() async {
        if let videoId = selectedVideoURL?.lastPathComponent {
            await VideoMomentIndexer.shared.clear(videoId: videoId)
        } else {
            await VideoMomentIndexer.shared.clear()
        }
        indexedFramesCount = 0
        momentResults = []
        selectedVideoURL = nil
        #if canImport(AVKit)
        player = nil
        #endif
    }

    /// 载入预置演示视频（优先加载内置的开源实测自然森林高清短片），无需本地导入即可快速体验
    public func loadDemoVideo() async {
        #if canImport(AVFoundation) && canImport(AVKit)
        isIndexing = true
        let videoFileName = "\(FeatureConstants.VideoMoment.demoVideoResourceName).\(FeatureConstants.VideoMoment.demoVideoExtension)"
        let demoURL = FileManager.default.temporaryDirectory.appendingPathComponent(videoFileName)

        // 强制清理历史临时缓存，避免沿用旧版纯色视频
        try? FileManager.default.removeItem(at: demoURL)

        // 1. 优先加载内置的开源实测自然森林短片 (Big Buck Bunny 自然风光与角色高光，129KB)
        var targetBundleURL: URL? = Bundle.main.url(
            forResource: FeatureConstants.VideoMoment.demoVideoResourceName,
            withExtension: FeatureConstants.VideoMoment.demoVideoExtension
        )
        if targetBundleURL == nil {
            for bundle in Bundle.allBundles {
                if let url = bundle.url(
                    forResource: FeatureConstants.VideoMoment.demoVideoResourceName,
                    withExtension: FeatureConstants.VideoMoment.demoVideoExtension
                ) {
                    targetBundleURL = url
                    break
                }
            }
        }

        if let bundleURL = targetBundleURL {
            try? FileManager.default.copyItem(at: bundleURL, to: demoURL)
            await handleVideoSelection(demoURL)
        } else if FileManager.default.fileExists(atPath: demoURL.path) {
            await handleVideoSelection(demoURL)
        } else {
            isIndexing = false
        }
        #endif
    }
}

// MARK: - 视频时刻检索视图扩展

extension ModelLabView {
    /// 视频时刻查找沙盒面板
    @ViewBuilder
    var videoMomentSearchSandboxView: some View {
        VideoMomentSearchContentView(labView: self, state: VideoMomentSearchState.shared)
    }
}

/// 视频时刻检索内容子视图
@MainActor
struct VideoMomentSearchContentView: View {
    let labView: ModelLabView
    @Bindable var state: VideoMomentSearchState

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: DesignTokens.Spacing.medium) {
                labView.modelAndConfigControlBar(for: .videoMomentSearch)
                quickChipsBar
                videoPlayerSection
                searchAndActionBar
                if state.isIndexing {
                    indexingIndicator
                } else if !state.momentResults.isEmpty {
                    momentResultsList
                }
            }
            .padding(.vertical, DesignTokens.SystemSpacing.atomic)
        }
        .fileImporter(
            isPresented: $state.showFileImporter,
            allowedContentTypes: [.movie, .quickTimeMovie, .mpeg4Movie],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                Task { await state.handleVideoSelection(url) }
            }
        }
    }

    // MARK: - 快捷时刻检索词胶囊栏

    @ViewBuilder
    private var quickChipsBar: some View {
        let sampleQueries = [L10n.ModelManager.Lab.Chip.intro, L10n.ModelManager.Lab.Chip.nature, L10n.ModelManager.Lab.Chip.highlight]
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignTokens.SystemSpacing.tiny) {
                ForEach(sampleQueries, id: \.self) { sample in
                    Button(action: {
                        state.query = sample
                        Task { await state.executeSearch() }
                    }) {
                        Text(sample)
                            .font(.caption2.bold())
                            .foregroundStyle(state.query == sample ? Color.theme.white : Color.theme.green)
                            .padding(.horizontal, DesignTokens.SystemSpacing.small)
                            .padding(.vertical, DesignTokens.SystemSpacing.tiny)
                            .background(state.query == sample ? Color.theme.green : Color.theme.green.opacity(DesignTokens.Opacity.disabled))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(state.selectedVideoURL == nil || state.isIndexing)
                    .opacity((state.selectedVideoURL == nil || state.isIndexing) ? DesignTokens.Opacity.disabled : DesignTokens.Opacity.solid)
                }
            }
            .padding(.horizontal, DesignTokens.SystemSpacing.atomic)
        }
    }

    // MARK: - 视频播放器视图

    @ViewBuilder
    private var videoPlayerSection: some View {
        #if canImport(AVKit)
        if let player = state.player {
            VideoPlayer(player: player)
                .frame(height: FeatureConstants.MediaSearch.previewImageHeight)
                .cornerRadius(DesignTokens.Spacing.mediumRadius)
                .clipped()
        } else {
            emptyVideoPlaceholder
        }
        #else
        emptyVideoPlaceholder
        #endif
    }

    @ViewBuilder
    private var emptyVideoPlaceholder: some View {
        VStack(spacing: DesignTokens.Spacing.medium) {
            Image(systemName: DesignTokens.Icons.playRectangleFill)
                .font(.system(size: DesignTokens.Spacing.Gallery.iconSize))
                .foregroundStyle(Color.theme.green.opacity(DesignTokens.Opacity.soft))
            Text(L10n.ModelManager.Lab.VideoSearch.emptyHint)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignTokens.Spacing.large)

            HStack(spacing: DesignTokens.Spacing.medium) {
                Button(action: { state.showFileImporter = true }) {
                    HStack(spacing: DesignTokens.SystemSpacing.tiny) {
                        Image(systemName: DesignTokens.Icons.plusCircle)
                        Text(L10n.ModelManager.Lab.VideoSearch.importVideo)
                    }
                    .font(.caption.bold())
                    .foregroundStyle(Color.theme.white)
                    .padding(.horizontal, DesignTokens.SystemSpacing.medium)
                    .padding(.vertical, DesignTokens.SystemSpacing.small)
                    .background(Color.theme.green)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button(action: { Task { await state.loadDemoVideo() } }) {
                    HStack(spacing: DesignTokens.SystemSpacing.tiny) {
                        Image(systemName: DesignTokens.Icons.sparkles)
                        Text(L10n.ModelManager.Lab.loadDemoVideo)
                    }
                    .font(.caption.bold())
                    .foregroundStyle(Color.theme.green)
                    .padding(.horizontal, DesignTokens.SystemSpacing.medium)
                    .padding(.vertical, DesignTokens.SystemSpacing.small)
                    .background(Color.theme.green.opacity(DesignTokens.Opacity.disabled))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, minHeight: FeatureConstants.MediaSearch.previewImageHeight)
        .cardStyle(horizontalPadding: DesignTokens.Spacing.medium, verticalPadding: DesignTokens.Spacing.large)
    }

    // MARK: - 搜索输入与操作栏

    @ViewBuilder
    private var searchAndActionBar: some View {
        VStack(spacing: DesignTokens.Spacing.small) {
            HStack(spacing: DesignTokens.Spacing.small) {
                Image(systemName: DesignTokens.Icons.magnifyingglass)
                    .foregroundStyle(Color.theme.green)
                TextField(L10n.ModelManager.Lab.VideoSearch.searchPlaceholder, text: $state.query)
                    .textFieldStyle(.plain)
                    .foregroundStyle(Color.theme.text)
                    .onSubmit { Task { await state.executeSearch() } }

                if !state.query.isEmpty {
                    Button(action: { state.query = ""; state.momentResults = [] }) {
                        Image(systemName: DesignTokens.Icons.xmarkCircle).foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Button(action: { Task { await state.executeSearch() } }) {
                    Text(L10n.ModelManager.Lab.send)
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.theme.white)
                        .padding(.horizontal, DesignTokens.SystemSpacing.content)
                        .padding(.vertical, DesignTokens.SystemSpacing.tiny)
                        .background(Color.theme.green)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(state.selectedVideoURL == nil || state.isIndexing)
                .opacity((state.selectedVideoURL == nil || state.isIndexing) ? DesignTokens.Opacity.disabled : DesignTokens.Opacity.solid)
            }
            .padding(DesignTokens.Spacing.standardPadding)
            .background(Color.appCard.opacity(DesignTokens.Opacity.dim))
            .cornerRadius(DesignTokens.Spacing.mediumRadius)

            HStack(spacing: DesignTokens.SystemSpacing.small) {
                if state.indexedFramesCount > 0 {
                    Text(L10n.ModelManager.Lab.VideoSearch.framesCount(state.indexedFramesCount))
                        .font(.caption).foregroundStyle(Color.theme.green)
                }
                Spacer()
                Button(action: { Task { await state.loadDemoVideo() } }) {
                    HStack(spacing: DesignTokens.SystemSpacing.atomic) {
                        Image(systemName: DesignTokens.Icons.sparkles)
                        Text(L10n.ModelManager.Lab.loadDemoVideo)
                    }
                    .font(.caption).foregroundStyle(Color.theme.green)
                }
                .buttonStyle(.plain)

                if state.selectedVideoURL != nil {
                    Button(action: { state.showFileImporter = true }) {
                        Text(L10n.ModelManager.Lab.VideoSearch.importVideo).font(.caption).foregroundStyle(Color.theme.green)
                    }
                    .buttonStyle(.plain)
                    Button(action: { Task { await state.clearIndex() } }) {
                        Text(L10n.ModelManager.Lab.clearIndex).font(.caption).foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 时刻列表与胶片打点时间轴展示

    @ViewBuilder
    private var momentResultsList: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            filmstripTimelineBar

            ForEach(state.momentResults) { moment in
                momentCard(moment: moment)
            }
        }
    }

    /// 抽帧胶片打点时间轴 (Filmstrip Scrubber)
    @ViewBuilder
    private var filmstripTimelineBar: some View {
        VStack(alignment: .leading, spacing: DesignTokens.SystemSpacing.tiny) {
            HStack(spacing: DesignTokens.SystemSpacing.tiny) {
                Image(systemName: DesignTokens.Icons.pinFill)
                    .font(.caption2)
                    .foregroundStyle(Color.theme.green)
                Text(L10n.ModelManager.Lab.VideoSearch.filmstripTitle)
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignTokens.Spacing.small) {
                    ForEach(state.momentResults) { moment in
                        Button {
                            HapticFeedback.shared.trigger(.selection)
                            state.seekTo(seconds: moment.timeOffsetSeconds)
                        } label: {
                            HStack(spacing: DesignTokens.SystemSpacing.tiny) {
                                Image(systemName: DesignTokens.Icons.pinFill)
                                    .font(.system(size: DesignTokens.SystemFontSize.nano))
                                Text(moment.formattedTime)
                                    .font(.caption2.monospacedDigit().bold())
                            }
                            .padding(.horizontal, DesignTokens.Spacing.small)
                            .padding(.vertical, DesignTokens.SystemSpacing.tiny)
                            .background(Color.theme.green.opacity(DesignTokens.Opacity.subtle))
                            .foregroundStyle(Color.theme.green)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(Color.theme.green.opacity(DesignTokens.Opacity.prominent), lineWidth: DesignTokens.SystemStroke.divider)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(DesignTokens.Spacing.small)
        .background(Color.appCard.opacity(DesignTokens.Opacity.dim))
        .cornerRadius(DesignTokens.SystemRadius.small)
    }

    @ViewBuilder
    private func momentCard(moment: VideoMomentResult) -> some View {
        Button(action: {
            HapticFeedback.shared.trigger(.selection)
            state.seekTo(seconds: moment.timeOffsetSeconds)
        }) {
            HStack(spacing: DesignTokens.Spacing.medium) {
                // 缩略图
                if let data = moment.thumbnailData,
                   let platformImage = makePlatformImage(from: data) {
                    Image(platformImage: platformImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: DesignTokens.Spacing.Gallery.splashIconSize, height: DesignTokens.Spacing.Gallery.iconSize)
                        .clipped()
                        .cornerRadius(DesignTokens.Spacing.smallRadius)
                } else {
                    Rectangle()
                        .fill(Color.theme.gray.opacity(DesignTokens.Opacity.disabled))
                        .frame(width: DesignTokens.Spacing.Gallery.splashIconSize, height: DesignTokens.Spacing.Gallery.iconSize)
                        .cornerRadius(DesignTokens.Spacing.smallRadius)
                        .overlay(
                            Image(systemName: DesignTokens.Icons.playFill)
                                .foregroundStyle(.secondary)
                        )
                }

                VStack(alignment: .leading, spacing: DesignTokens.SystemSpacing.tiny) {
                    HStack {
                        Text(L10n.ModelManager.Lab.timestampLabel(moment.formattedTime))
                            .font(.subheadline.bold())
                            .foregroundStyle(Color.theme.text)

                        Spacer()

                        Text(L10n.ModelManager.Lab.similarityScore(moment.score * FeatureConstants.MediaSearch.scoreMultiplier))
                            .font(.caption.bold())
                            .foregroundStyle(Color.theme.green)
                    }

                    Text(moment.videoId)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Image(systemName: DesignTokens.Icons.playCircleFill)
                    .font(.title2)
                    .foregroundStyle(Color.theme.green)
            }
            .padding(DesignTokens.Spacing.standardPadding)
            .background(Color.appCard.opacity(DesignTokens.Opacity.dim))
            .cornerRadius(DesignTokens.Spacing.mediumRadius)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 索引进行中指示

    @ViewBuilder
    private var indexingIndicator: some View {
        VStack(spacing: DesignTokens.Spacing.medium) {
            ProgressView()
                .tint(Color.theme.green)
            Text(L10n.ModelManager.Lab.VideoSearch.indexing)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: FeatureConstants.MediaSearch.thumbnailHeight)
    }
}
