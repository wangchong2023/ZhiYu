//
//  ModelDownloadSection.swift
//  ZhiYu
//
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层 / 视图组件
//  核心职责：模型下载/激活交互区 — 下载进度环、状态文案映射与操作按钮（下载/暂停/恢复/激活）。
//
import SwiftUI
import UFPCore
import UFPDesignSystem

// MARK: - 下载进度状态栏

/// 下载进度环与状态文案提示
struct ModelDownloadStatusBar: View {
    let manifest: LLMManifest
    let downloadState: DownloadState
    let modelManager: GlobalModelManager

    var body: some View {
        switch downloadState {
        case .failed(let error):
            if error == FeatureConstants.DefaultValue.notDownloaded {
                EmptyView()
            } else {
                ringWithStatus(state: downloadState, statusText: error, color: Color.theme.red)
            }
        case .cancelled:
            EmptyView()
        case .completed:
            EmptyView()
        default:
            ringWithStatus(state: downloadState)
        }
    }

    @ViewBuilder
    private func ringWithStatus(state: DownloadState, statusText: String? = nil, color: Color = .appAccent) -> some View {
        HStack(spacing: DesignTokens.Spacing.small) {
            DownloadProgressRing(state: state, size: DesignTokens.Metrics.ringSize)

            if let statusText {
                Text(statusText)
                    .font(.caption2)
                    .foregroundStyle(color)
                    .lineLimit(1)
            } else {
                statusLabel(for: state)
            }
        }
    }

    @ViewBuilder
    private func statusLabel(for state: DownloadState) -> some View {
        switch state {
        case .downloading(let progress, let speed, let stateDownloadedBytes, let stateTotalBytes):
            let effectiveTotalBytes: Int64 = stateTotalBytes > 0 ? stateTotalBytes : manifest.fileSizeInBytes
            let effectiveDownloadedBytes: Int64 = stateDownloadedBytes > 0 ? stateDownloadedBytes : Int64(Double(effectiveTotalBytes) * progress)
            let progressText = ByteFormatter.formatProgress(downloadedBytes: effectiveDownloadedBytes, totalBytes: effectiveTotalBytes)
            let remainingBytes = max(0, effectiveTotalBytes - effectiveDownloadedBytes)
            let speedText = bytesLabelWithSpeed(
                progressText: progressText,
                speed: speed,
                remainingBytes: remainingBytes
            )
            VStack(alignment: .leading, spacing: DesignTokens.SystemSpacing.atomic) {
                Text(speedText)
                    .font(.caption.bold())
                    .foregroundStyle(.appAccent)
                Text(modelManager.isChinaRegion ? FeatureConstants.ModelSpecConstants.sourceModelScope : FeatureConstants.ModelSpecConstants.sourceHuggingFace)
                    .font(.system(size: DesignTokens.SystemFontSize.nano, design: .monospaced))
                    .foregroundStyle(.appSecondary)
            }
        case .paused:
            Text(L10n.ModelManager.Status.paused)
                .font(.caption)
                .foregroundStyle(Color.theme.orange)
        case .verifying:
            Text(L10n.ModelManager.Status.verifying + "...")
                .font(.caption.bold())
                .foregroundStyle(.appAccent)
        case .pending:
            Text(L10n.ModelManager.Status.downloading + "...")
                .font(.caption.italic())
                .foregroundStyle(.appSecondary)
        default:
            EmptyView()
        }
    }

    private func bytesLabelWithSpeed(progressText: String, speed: Double, remainingBytes: Int64) -> String {
        if speed > 0 {
            let speedStr = ByteFormatter.formatSpeed(speed)
            let remainingSec = Int(Double(remainingBytes) / speed)
            if remainingSec > 0 {
                let mins = remainingSec / FeatureConstants.ModelSpecConstants.secondsPerMinute
                let secs = remainingSec % FeatureConstants.ModelSpecConstants.secondsPerMinute
                let etaRaw = mins > 0 ? "\(mins)m \(secs)s" : "\(secs)s"
                let etaText = L10n.ModelManager.Card.etaFormat(etaRaw)
                return "\(progressText) · \(speedStr) · \(etaText)"
            }
            return "\(progressText)  ·  \(speedStr)"
        }
        return progressText
    }
}

// MARK: - 模型清单规格扩展

extension LLMManifest {
    /// 模型量化精度规格标签
    public var quantizationBadge: String {
        let urlLower = remoteURLString.lowercased()
        if urlLower.contains(FeatureConstants.ModelSpecConstants.q4kmKeyword) {
            return FeatureConstants.ModelSpecConstants.quantInt4Q4KM
        } else if urlLower.contains(FeatureConstants.ModelSpecConstants.int8Keyword) {
            return FeatureConstants.ModelSpecConstants.quantInt8
        }
        return FeatureConstants.ModelSpecConstants.quantInt4AWQ
    }

    /// 模型运行时推理引擎格式标签
    public var runtimeEngineBadge: String {
        let urlLower = remoteURLString.lowercased()
        if urlLower.contains(FeatureConstants.ModelSpecConstants.ggufExtension) {
            return FeatureConstants.ModelSpecConstants.engineGGUF
        }
        return FeatureConstants.ModelSpecConstants.engineLiteRT
    }

    /// 本地沙盒相对路径显示文案
    public var localSandboxRelativePath: String {
        FeatureConstants.ModelSpecConstants.sandboxDocumentsPrefix + modelId + FeatureConstants.ModelSpecConstants.modelBinExtension
    }
}

// MARK: - 操作按钮

/// 操作按钮（激活、下载、暂停、恢复）
struct ModelActionButton: View {
    let manifest: LLMManifest
    let eligibility: DeviceEligibility
    let isSelected: Bool
    let isLocalReady: Bool
    let downloadState: DownloadState
    let modelManager: GlobalModelManager
    @Binding var alertManifest: LLMManifest?
    let onGoToLab: () -> Void

    var body: some View {
        if eligibility == .restricted {
            restrictedActionButton
        } else if isLocalReady {
            activeActionButton
        } else {
            downloadActionButton
        }
    }

    /// 渲染因硬件限制而被拦截的下载按钮
    private var restrictedActionButton: some View {
        downloadActionButton(
            icon: DesignTokens.Icons.exclamationmarkOctagonFill,
            text: L10n.ModelManager.Card.unavailable,
            background: Color.theme.red.opacity(DesignTokens.Opacity.glass),
            foreground: Color.theme.red,
            action: { alertManifest = manifest }
        )
    }

    /// 渲染已就绪模型的激活与选中切换按钮
    private var activeActionButton: some View {
        Button(action: {
            modelManager.activeModelId = manifest.modelId

            if let onDeviceService = ServiceContainer.shared.resolveOptional((any OnDeviceLLMServiceProtocol).self) as? OnDeviceLLMService { // inject_exempt: DI 就绪性检查（Key 返回非可选，测试时未注册会崩溃，故保留 resolveOptional）
                let expectedID = "downloaded_\(manifest.modelId)"
                onDeviceService.selectedModelID = expectedID

                Task {
                    try? await onDeviceService.loadModel()
                }
            }

            onGoToLab()
            HapticFeedback.shared.trigger(.success)
        }) {
            Image(systemName: DesignTokens.Icons.arrowRight)
                .font(.system(size: DesignTokens.SystemFontSize.body, weight: .bold)) // Dynamic Type
                .foregroundStyle(.white)
                .frame(width: DesignTokens.Metrics.ringSize, height: DesignTokens.Metrics.ringSize)
                .background(Color.appAccent)
                .clipShape(Circle())
        }
    }

    /// 渲染处于未下载、下载中或已暂停等各状态下的功能按钮组合
    @ViewBuilder
    private var downloadActionButton: some View {
        switch downloadState {
        case .pending, .downloading:
            Button(action: { modelManager.pauseDownload(for: manifest.modelId) }) {
                Image(systemName: DesignTokens.Icons.pauseFill)
                    .font(.caption)
                    .padding(DesignTokens.Spacing.small)
                    .background(Color.appBackground)
                    .foregroundStyle(Color.theme.orange)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.theme.orange, lineWidth: DesignTokens.SystemStroke.divider))
            }
        case .paused:
            HStack(spacing: DesignTokens.Spacing.small) {
                Button(action: { modelManager.cancelDownload(for: manifest.modelId) }) {
                    Image(systemName: DesignTokens.Icons.xmark)
                        .font(.caption2)
                        .padding(DesignTokens.Spacing.small)
                        .background(Color.appBackground)
                        .foregroundStyle(.appSecondary)
                        .clipShape(Circle())
                }
                Button(action: { modelManager.resumeDownload(for: manifest.modelId) }) {
                    Image(systemName: DesignTokens.Icons.playFill)
                        .font(.caption2)
                        .padding(DesignTokens.Spacing.small)
                        .background(Color.appAccent)
                        .foregroundStyle(.white)
                        .clipShape(Circle())
                }
            }
        default:
            downloadActionButton(
                icon: DesignTokens.Icons.icloudArrowDown,
                text: L10n.ModelManager.Card.download,
                background: Color.appAccent,
                foreground: .white,
                action: { modelManager.startDownload(for: manifest) }
            )
        }
    }

    /// 通用下载操作按钮，消除重复的 HStack+padding+background+clipShape(Capsule) 链
    private func downloadActionButton(icon: String, text: String, background: Color, foreground: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.SystemSpacing.tiny) {
                Image(systemName: icon)
                Text(text)
            }
            .font(.subheadline.bold())
            .padding(.horizontal, DesignTokens.SystemSpacing.content)
            .padding(.vertical, DesignTokens.SystemSpacing.element)
            .background(background)
            .foregroundStyle(foreground)
            .clipShape(Capsule())
        }
    }
}
