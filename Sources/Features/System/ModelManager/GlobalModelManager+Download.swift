//
//  GlobalModelManager+Download.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/11/25.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层 / 模型下载调度扩展
//  核心职责：承载 GlobalModelManager 的双源下载路由、按域名鉴权令牌隔离、
//           后台静默下载、异步镜像自动容灾切换与进度流订阅管理。
//

import Foundation
import UFPCore

extension GlobalModelManager {

    // MARK: - 后台静默下载管理

    /// 解析双源下载路由结果（含主源与自动容灾备用源）
    public struct ResolvedDownloadRoute: Equatable, Sendable {
        public let primaryURL: URL
        public let fallbackURL: URL?
        public let prefersModelScope: Bool
    }

    /// 根据当前下载源偏好与地区计算主/备下载路由
    public func resolveDownloadRoute(
        for manifest: LLMManifest,
        isChinaRegionOverride: Bool? = nil
    ) -> ResolvedDownloadRoute? {
        let preferModelScope: Bool
        switch downloadSourcePreference {
        case .auto:
            preferModelScope = isChinaRegionOverride ?? isChinaRegion
        case .modelscope:
            preferModelScope = true
        case .huggingface:
            preferModelScope = false
        }

        let primaryURLString: String
        let fallbackURLString: String?
        if preferModelScope {
            primaryURLString = manifest.modelscopeURLString ?? manifest.remoteURLString
            fallbackURLString = manifest.huggingfaceURLString
        } else {
            primaryURLString = manifest.huggingfaceURLString ?? manifest.remoteURLString
            fallbackURLString = manifest.modelscopeURLString
        }

        guard let primaryURL = URL(string: primaryURLString) else { return nil }
        let fallbackURL: URL?
        if let fallback = fallbackURLString, fallback != primaryURLString {
            fallbackURL = URL(string: fallback)
        } else {
            fallbackURL = nil
        }
        return ResolvedDownloadRoute(
            primaryURL: primaryURL,
            fallbackURL: fallbackURL,
            prefersModelScope: preferModelScope
        )
    }

    /// 按目标域名严格隔离鉴权令牌，严禁把 HuggingFace Token 发给魔搭或第三方域名（反之亦然）
    public func authorizationHeader(for url: URL) -> String? {
        guard let host = url.host?.lowercased(), !host.isEmpty else { return nil }
        if Self.matchesDomain(host, suffixes: BYOMConstants.modelScopeHostSuffixes) {
            let token = loadModelScopeToken()
            return token.isEmpty ? nil : BYOMConstants.bearerPrefix + token
        }
        if Self.matchesDomain(host, suffixes: BYOMConstants.huggingFaceHostSuffixes) {
            let token = loadHuggingFaceToken()
            return token.isEmpty ? nil : BYOMConstants.bearerPrefix + token
        }
        return nil
    }

    private static func matchesDomain(_ host: String, suffixes: [String]) -> Bool {
        suffixes.contains { suffix in
            host == suffix || host.hasSuffix("." + suffix)
        }
    }

    /// 发起大模型权重文件后台静默下载
    /// - Parameter manifest: 期望下载的白名单大模型规格元数据
    public func startDownload(for manifest: LLMManifest) {
        guard let route = resolveDownloadRoute(for: manifest) else { return }
        let url = route.primaryURL
        Logger.shared.info(
            "[GlobalModelManager] Routing download to \(route.prefersModelScope ? "ModelScope" : "HuggingFace"): \(url.absoluteString)"
        )
        let modelId = manifest.modelId

        // 1. 如果该模型不支持该硬件物理内存 (restricted)，强力拦截，杜绝 OOM 爆内存
        if evaluateEligibility(for: manifest) == .restricted {
            Logger.shared.warning("[GlobalModelManager] Model \(modelId) exceeds hardware capacity, restricted.")
            return
        }

        // 2. 记录备用镜像源（供异步 HTTP 404/5xx 失败时自动容灾切换），并启动后台物理下载
        pendingFallbackURLs[modelId] = route.fallbackURL
        Task {
            do {
                try await downloadManager.startDownload(modelId: modelId, remoteURL: url)
                // 3. 实时观察进度流
                observeDownloadState(for: modelId)
            } catch {
                // 若首选源下载失败且存在备用镜像源（如 HuggingFace 失败自动切换 ModelScope），执行自动容灾重试
                if let fallbackURL = pendingFallbackURLs.removeValue(forKey: modelId) {
                    Logger.shared.warning("[GlobalModelManager] Primary download failed for \(modelId), automatically falling back to mirror: \(fallbackURL.absoluteString)")
                    do {
                        try await downloadManager.startDownload(modelId: modelId, remoteURL: fallbackURL)
                        observeDownloadState(for: modelId)
                        return
                    } catch let fallbackError {
                        Logger.shared.error("[GlobalModelManager] Fallback download also failed: \(fallbackError.localizedDescription)")
                    }
                }
                downloadStates[modelId] = .failed(error: error.localizedDescription)
            }
        }
    }

    /// 暂停下载
    public func pauseDownload(for modelId: String) {
        Task {
            try? await downloadManager.pauseDownload(modelId: modelId)
        }
    }

    /// 恢复续传下载
    public func resumeDownload(for modelId: String) {
        Task {
            try? await downloadManager.resumeDownload(modelId: modelId)
            observeDownloadState(for: modelId)
        }
    }

    /// 取消下载并清理沙盒碎片
    public func cancelDownload(for modelId: String) {
        pendingFallbackURLs.removeValue(forKey: modelId)
        Task {
            try? await downloadManager.cancelDownload(modelId: modelId)
            downloadStates[modelId] = .cancelled
        }
    }

    /// 对指定模型启动异步下载状态流的消费订阅
    func observeDownloadState(for modelId: String) {
        // 防止重复订阅产生僵尸 Task，导致状态被旧流覆盖
        guard !subscribedModelIds.contains(modelId) else { return }
        subscribedModelIds.insert(modelId)
        Task {
            let stream = await downloadManager.observeDownloadState(for: modelId)
            for await state in stream {
                await MainActor.run {
                    self.handleDownloadStateUpdate(state, for: modelId)
                }
            }
            // 流结束后清理订阅标记，允许后续重新订阅
            self.subscribedModelIds.remove(modelId)
        }
    }

    /// 在主线程分发单条下载状态变更，包含异步镜像源自动容灾、真实大小同步与终态清理
    private func handleDownloadStateUpdate(_ state: DownloadState, for modelId: String) {
        // 若异步下载阶段收到 4xx/5xx 等失败且仍有未尝试的备用镜像源，自动容灾切换而非直接报错
        if case let .failed(errorMessage) = state,
           let fallbackURL = pendingFallbackURLs.removeValue(forKey: modelId) {
            Logger.shared.warning(
                "[GlobalModelManager] Async download failed for \(modelId) (\(errorMessage)), switching to fallback mirror: \(fallbackURL.absoluteString)"
            )
            downloadStates[modelId] = .pending
            Task {
                do {
                    try await downloadManager.startDownload(modelId: modelId, remoteURL: fallbackURL)
                } catch {
                    downloadStates[modelId] = .failed(error: error.localizedDescription)
                    subscribedModelIds.remove(modelId)
                }
            }
            return
        }

        downloadStates[modelId] = state
        syncDownloadedManifestSizeIfNeeded(state, for: modelId)
        if case let .completed(localURL) = state {
            finalizeCompletedDownload(modelId: modelId, localURL: localURL)
        }
        // 终态时立即清理订阅标记，允许后续重新订阅
        switch state {
        case .completed, .failed, .cancelled:
            pendingFallbackURLs.removeValue(forKey: modelId)
            subscribedModelIds.remove(modelId)
        default:
            break
        }
    }

    /// 当握手到真实网络文件大小时，动态更新本地清单中的 fileSizeInBytes
    private func syncDownloadedManifestSizeIfNeeded(_ state: DownloadState, for modelId: String) {
        guard case .downloading(_, _, _, let totalBytes) = state, totalBytes > 0,
              let index = remoteManifests.firstIndex(where: { $0.modelId == modelId }),
              remoteManifests[index].fileSizeInBytes == 0 || remoteManifests[index].fileSizeInBytes != totalBytes else {
            return
        }
        remoteManifests[index].fileSizeInBytes = totalBytes
    }

    /// 记录已完成下载的模型回执并标记就绪
    private func finalizeCompletedDownload(modelId: String, localURL: URL) {
        pendingFallbackURLs.removeValue(forKey: modelId)
        let actualSize = (try? FileManager.default.attributesOfItem(atPath: localURL.path)[.size] as? Int64) ?? 0
        let probe = ModelFormatProbe.shared.inspect(fileURL: localURL)
        let format = if case let .valid(fmt) = probe { fmt } else { FeatureConstants.ModelSpecConstants.ggufFormatName }
        let receipt = ModelDownloadReceipt(
            modelId: modelId,
            exactFileSize: actualSize,
            completedAt: Date(),
            sha256Checksum: nil,
            format: format
        )
        ModelReceiptStore.shared.saveReceipt(receipt)
        markModelAsDownloaded(modelId)
    }

    /// 重新订阅所有处于活跃下载状态的模型，防止视图重建/Tab 切换后订阅丢失导致状态停滞
    public func resubscribeActiveDownloads() {
        for (modelId, state) in downloadStates {
            switch state {
            case .downloading, .pending, .verifying:
                // 清除旧订阅标记以允许重新订阅
                subscribedModelIds.remove(modelId)
                observeDownloadState(for: modelId)
            default:
                break
            }
        }
    }
}
