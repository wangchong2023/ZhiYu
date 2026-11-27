//
//  GlobalModelManager+BYOM.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/11/24.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：封装 BYOM（自定义本地模型导入与持久化）及双源（魔搭社区 / HuggingFace）访问令牌管理。
//

import Foundation
import UFPCore
import ZhiYuAICore

extension GlobalModelManager {

    /// 模型下载源路由偏好（支持自动按地区 / 优先魔搭社区 / 优先 HuggingFace）
    public enum DownloadSourcePreference: String, CaseIterable, Identifiable, Sendable {
        case auto
        case modelscope
        case huggingface

        public var id: String { rawValue }

        public var displayTitle: String {
            switch self {
            case .auto: return L10n.ModelManager.ModelSource.auto
            case .modelscope: return L10n.ModelManager.ModelSource.modelscope
            case .huggingface: return L10n.ModelManager.ModelSource.huggingface
            }
        }

        /// 三档下载源优先级的详细路由与容灾说明
        public var priorityDescription: String {
            switch self {
            case .auto: return L10n.ModelManager.ModelSource.autoDesc
            case .modelscope: return L10n.ModelManager.ModelSource.modelscopeDesc
            case .huggingface: return L10n.ModelManager.ModelSource.huggingfaceDesc
            }
        }
    }

    /// 自动模式下当前地区实时识别出的主下载源名称
    public var autoDetectedSourceTitle: String {
        isChinaRegion ? L10n.ModelManager.ModelSource.modelscope : L10n.ModelManager.ModelSource.huggingface
    }

    /// BYOM 本地模型导入错误
    public enum BYOMImportError: LocalizedError, Equatable {
        case emptyFile
        case corruptedFormat(String)

        public var errorDescription: String? {
            switch self {
            case .emptyFile:
                return L10n.ModelManager.Status.fileCorrupted
            case .corruptedFormat(let reason):
                return reason
            }
        }
    }

    internal enum BYOMConstants {
        static let huggingFaceTokenKey = "zhiyu_hf_access_token"
        static let modelScopeTokenKey = "zhiyu_ms_access_token"
        static let sourcePreferenceKey = "zhiyu_model_download_source_pref"
        static let customManifestsKey = "zhiyu_custom_imported_manifests"
        static let bearerPrefix = "Bearer "
        static let modelScopeHostSuffixes = ["modelscope.cn", "modelscope.ai"]
        static let huggingFaceHostSuffixes = ["huggingface.co", "hf-mirror.com"]
        static let supportedExtensions = [".litertlm", ".task", ".gguf", ".bin"]
        static let customModelPrefix = "custom-"
        static let customVendor = "Local"
        static let unsafeIdCharacters = [" ", "/", "\\", "..", ":"]
        static let idReplacementHyphen = "-"
        static let dotPrefix = "."
        static let defaultMinMemoryGB: Double = 4.0
        static let defaultTemperature: Double = 0.7
        static let defaultTopP: Double = 0.9
        static let defaultTopK: Int = 40
        static let defaultMaxTokens: Int = 2048
    }

    /// 用户首选下载源偏好（默认 .auto：国内优先魔搭社区，海外优先 HuggingFace）
    public var downloadSourcePreference: DownloadSourcePreference {
        get {
            if let cached = cachedDownloadSourcePreference {
                return cached
            }
            let raw = keyStore?.string(forKey: BYOMConstants.sourcePreferenceKey) ?? DownloadSourcePreference.auto.rawValue
            return DownloadSourcePreference(rawValue: raw) ?? .auto
        }
        set {
            cachedDownloadSourcePreference = newValue
            keyStore?.set(newValue.rawValue, forKey: BYOMConstants.sourcePreferenceKey)
        }
    }

    /// 是否已配置任一平台鉴权令牌
    public var hasAnySourceToken: Bool {
        hasModelScopeToken || hasHuggingFaceToken
    }

    /// 刷新双源令牌配置状态
    public func refreshHuggingFaceTokenStatus() {
        let hfToken = (try? KeychainService.shared.retrieve(key: BYOMConstants.huggingFaceTokenKey)) ?? ""
        hasHuggingFaceToken = !hfToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let msToken = (try? KeychainService.shared.retrieve(key: BYOMConstants.modelScopeTokenKey)) ?? ""
        hasModelScopeToken = !msToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 读取已加密保存的魔搭社区 SDK 令牌
    public func loadModelScopeToken() -> String {
        (try? KeychainService.shared.retrieve(key: BYOMConstants.modelScopeTokenKey)) ?? ""
    }

    /// 加密保存魔搭社区 SDK 令牌至系统钥匙串
    public func saveModelScopeToken(_ token: String) {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            clearModelScopeToken()
            return
        }
        try? KeychainService.shared.store(key: BYOMConstants.modelScopeTokenKey, value: trimmed)
        hasModelScopeToken = true
    }

    /// 清除本地保存的魔搭社区 SDK 令牌
    public func clearModelScopeToken() {
        try? KeychainService.shared.delete(key: BYOMConstants.modelScopeTokenKey)
        hasModelScopeToken = false
    }

    /// 读取已加密保存的 HuggingFace 访问令牌
    public func loadHuggingFaceToken() -> String {
        (try? KeychainService.shared.retrieve(key: BYOMConstants.huggingFaceTokenKey)) ?? ""
    }

    /// 加密保存 HuggingFace 访问令牌至系统钥匙串
    public func saveHuggingFaceToken(_ token: String) {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            clearHuggingFaceToken()
            return
        }
        try? KeychainService.shared.store(key: BYOMConstants.huggingFaceTokenKey, value: trimmed)
        hasHuggingFaceToken = true
    }

    /// 清除本地保存的 HuggingFace 访问令牌
    public func clearHuggingFaceToken() {
        try? KeychainService.shared.delete(key: BYOMConstants.huggingFaceTokenKey)
        hasHuggingFaceToken = false
    }

    /// 临时承载已暂存并完成格式校验的 BYOM 文件元数据
    private struct StagedBYOMFile {
        let sanitizedId: String
        let baseName: String
        let destURL: URL
        let fileSize: Int64
        let detectedFormat: String
    }

    /// 规范化自定义模型标识并暂存/校验物理权重文件（同路径原地导入时跳过删拷以保护源文件）
    private func stageAndValidateBYOMFile(from sourceURL: URL) throws -> StagedBYOMFile {
        let fm = FileManager.default
        let docDir = fm.urls(for: .documentDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let normalizedBaseName = BYOMConstants.unsafeIdCharacters.reduce(baseName.lowercased()) { partial, token in
            partial.replacingOccurrences(of: token, with: BYOMConstants.idReplacementHyphen)
        }
        let sanitizedId = normalizedBaseName.hasPrefix(BYOMConstants.customModelPrefix)
            ? normalizedBaseName
            : BYOMConstants.customModelPrefix + normalizedBaseName
        let rawExt = BYOMConstants.dotPrefix + sourceURL.pathExtension.lowercased()
        let preservedExt = BYOMConstants.supportedExtensions.contains(rawExt)
            ? rawExt
            : FeatureConstants.ModelSpecConstants.modelBinExtension
        let destURL = docDir.appendingPathComponent(sanitizedId + preservedExt)
        let isSameFile = sourceURL.standardizedFileURL == destURL.standardizedFileURL

        if !isSameFile {
            if fm.fileExists(atPath: destURL.path) {
                try fm.removeItem(at: destURL)
            }
            try fm.copyItem(at: sourceURL, to: destURL)
        }

        let cleanupIfCopied = {
            if !isSameFile { try? fm.removeItem(at: destURL) }
        }
        let attrs = try fm.attributesOfItem(atPath: destURL.path)
        let fileSize = (attrs[.size] as? Int64) ?? 0
        guard fileSize > 0 else {
            cleanupIfCopied()
            throw BYOMImportError.emptyFile
        }

        switch ModelFormatProbe.shared.inspect(fileURL: destURL) {
        case .valid(let format):
            return StagedBYOMFile(
                sanitizedId: sanitizedId,
                baseName: baseName,
                destURL: destURL,
                fileSize: fileSize,
                detectedFormat: format
            )
        case .corrupted(let reason):
            // 强拦截坏文件并立即清理沙盒脏副本，避免孤儿文件与错误完成状态
            cleanupIfCopied()
            throw BYOMImportError.corruptedFormat(reason)
        case .notFound:
            cleanupIfCopied()
            throw BYOMImportError.emptyFile
        }
    }

    /// 导入本地自定义模型权重（BYOM：支持 .litertlm / .task / .gguf / .bin）
    @discardableResult
    public func importCustomModel(from sourceURL: URL) throws -> LLMManifest {
        let didAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let staged = try stageAndValidateBYOMFile(from: sourceURL)
        let receipt = ModelDownloadReceipt(
            modelId: staged.sanitizedId,
            exactFileSize: staged.fileSize,
            completedAt: Date(),
            sha256Checksum: nil,
            format: staged.detectedFormat
        )
        ModelReceiptStore.shared.saveReceipt(receipt)
        modelStorageUsage[staged.sanitizedId] = staged.fileSize
        markModelAsDownloaded(staged.sanitizedId)
        downloadStates[staged.sanitizedId] = .completed(localURL: staged.destURL)

        let manifest = buildCustomManifest(
            sanitizedId: staged.sanitizedId,
            baseName: staged.baseName,
            sourceURL: sourceURL,
            destURL: staged.destURL,
            fileSize: staged.fileSize
        )
        persistCustomManifest(manifest)
        remoteManifests.removeAll { $0.modelId == staged.sanitizedId }
        remoteManifests.insert(manifest, at: 0)
        return manifest
    }

    private func buildCustomManifest(
        sanitizedId: String,
        baseName: String,
        sourceURL: URL,
        destURL: URL,
        fileSize: Int64
    ) -> LLMManifest {
        LLMManifest(
            modelId: sanitizedId,
            displayName: baseName,
            vendor: BYOMConstants.customVendor,
            fileSizeInBytes: fileSize,
            minDeviceMemoryInGb: BYOMConstants.defaultMinMemoryGB,
            remoteURLString: destURL.absoluteString,
            sha256Checksum: "",
            parameterCount: sourceURL.pathExtension.uppercased(),
            supportedTasks: [FeatureConstants.TaskName.chat, FeatureConstants.TaskName.completion],
            description: destURL.lastPathComponent,
            defaultParameters: InferenceParameters(
                temperature: BYOMConstants.defaultTemperature,
                topP: BYOMConstants.defaultTopP,
                topK: BYOMConstants.defaultTopK,
                maxTokens: BYOMConstants.defaultMaxTokens
            )
        )
    }

    /// 读取持久化存储的 BYOM 自定义模型清单（确保 App 重启后不丢失）
    internal func loadPersistedCustomManifests() -> [LLMManifest] {
        guard let data = keyStore?.data(forKey: BYOMConstants.customManifestsKey),
              let manifests = try? JSONDecoder().decode([LLMManifest].self, from: data) else {
            return []
        }
        return manifests
    }

    internal func persistCustomManifest(_ manifest: LLMManifest) {
        var existing = loadPersistedCustomManifests().filter { $0.modelId != manifest.modelId }
        existing.insert(manifest, at: 0)
        if let data = try? JSONEncoder().encode(existing) {
            keyStore?.set(data, forKey: BYOMConstants.customManifestsKey)
        }
    }

    internal func removePersistedCustomManifest(modelId: String) {
        let remaining = loadPersistedCustomManifests().filter { $0.modelId != modelId }
        if remaining.isEmpty {
            keyStore?.removeObject(forKey: BYOMConstants.customManifestsKey)
        } else if let data = try? JSONEncoder().encode(remaining) {
            keyStore?.set(data, forKey: BYOMConstants.customManifestsKey)
        }
    }
}
