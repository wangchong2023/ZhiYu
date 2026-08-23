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

// MARK: - 下载进度状态栏

/// 下载进度环与状态文案提示
struct ModelDownloadStatusBar: View {
    let manifest: LLMManifest
    let downloadState: DownloadState
    let modelManager: GlobalModelManager

    var body: some View {
        switch downloadState {
        case .failed(let error):
            if error == "Not Downloaded" {
                EmptyView()
            } else {
                ringWithStatus(state: downloadState, statusText: error, color: .red)
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
        HStack(spacing: DesignSystem.small) {
            DownloadProgressRing(state: state, size: DesignSystem.Metrics.ringSize)

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
        case .downloading(let progress, let speed):
            let totalBytes = manifest.fileSizeInBytes
            let downloadedBytes = Int64(Double(totalBytes) * progress)
            let progressText = ByteFormatter.formatProgress(downloadedBytes: downloadedBytes, totalBytes: totalBytes)
            let speedText = bytesLabelWithSpeed(progressText: progressText, speed: speed)
            Text(speedText)
                .font(.caption.bold())
                .foregroundStyle(.appAccent)
        case .paused:
            Text(L10n.ModelManager.Status.paused)
                .font(.caption)
                .foregroundStyle(.orange)
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

    private func bytesLabelWithSpeed(progressText: String, speed: Double) -> String {
        if speed > 0 {
            let speedStr = ByteFormatter.formatSpeed(speed)
            return "\(progressText)  ·  \(speedStr)"
        }
        return progressText
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
        Button(action: { alertManifest = manifest }) {
            HStack(spacing: SystemSpacing.tiny) {
                Image(systemName: "exclamationmark.octagon.fill")
                Text(L10n.ModelManager.Card.unavailable)
            }
            .font(.subheadline.bold())
            .padding(.horizontal, SystemSpacing.content)
            .padding(.vertical, SystemSpacing.element)
            .background(Color.theme.red.opacity(DesignSystem.Opacity.glass))
            .foregroundStyle(.red)
            .clipShape(Capsule())
        }
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
            Image(systemName: "arrow.right")
                .font(.system(size: 16, weight: .bold)) // Dynamic Type
                .foregroundStyle(.white)
                .frame(width: DesignSystem.Metrics.ringSize, height: DesignSystem.Metrics.ringSize)
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
                Image(systemName: "pause.fill")
                    .font(.caption)
                    .padding(DesignSystem.small)
                    .background(Color.appBackground)
                    .foregroundStyle(.orange)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.theme.orange, lineWidth: SystemStroke.divider))
            }
        case .paused:
            HStack(spacing: DesignSystem.small) {
                Button(action: { modelManager.cancelDownload(for: manifest.modelId) }) {
                    Image(systemName: "xmark")
                        .font(.caption2)
                        .padding(DesignSystem.small)
                        .background(Color.appBackground)
                        .foregroundStyle(.appSecondary)
                        .clipShape(Circle())
                }
                Button(action: { modelManager.resumeDownload(for: manifest.modelId) }) {
                    Image(systemName: "play.fill")
                        .font(.caption2)
                        .padding(DesignSystem.small)
                        .background(Color.appAccent)
                        .foregroundStyle(.white)
                        .clipShape(Circle())
                }
            }
        default:
            Button(action: { modelManager.startDownload(for: manifest) }) {
                HStack(spacing: SystemSpacing.tiny) {
                    Image(systemName: "icloud.and.arrow.down")
                    Text(L10n.ModelManager.Card.download)
                }
                .font(.subheadline.bold())
                .padding(.horizontal, SystemSpacing.content)
                .padding(.vertical, SystemSpacing.element)
                .background(Color.appAccent)
                .foregroundStyle(.white)
                .clipShape(Capsule())
            }
        }
    }
}
