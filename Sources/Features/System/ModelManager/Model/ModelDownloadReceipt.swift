//
//  ModelDownloadReceipt.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/12.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层 / 数据模型
//  核心职责：大模型下载完成的权威凭据与离线收据存储管理，记录服务器确切交付的 Content-Length 与哈希指纹。
//

import Foundation
import UFPCore

/// 大模型下载完成的权威收据凭证
public struct ModelDownloadReceipt: Codable, Sendable, Equatable {
    /// 模型唯一 ID 标识
    public let modelId: String

    /// 服务器权威交付的精确物理字节数 (Content-Length)
    public let exactFileSize: Int64

    /// 下载完成的本地时间戳
    public let completedAt: Date

    /// 校验通过的 SHA-256 指纹（若有）
    public let sha256Checksum: String?

    /// 嗅探到的格式标识 (gguf, coreml, generic_bin)
    public let format: String

    public init(
        modelId: String,
        exactFileSize: Int64,
        completedAt: Date = Date(),
        sha256Checksum: String? = nil,
        format: String
    ) {
        self.modelId = modelId
        self.exactFileSize = exactFileSize
        self.completedAt = completedAt
        self.sha256Checksum = sha256Checksum
        self.format = format
    }
}

/// 权威凭据持久化存储中心
public final class ModelReceiptStore: Sendable {

    public static let shared = ModelReceiptStore()

    private init() {
        createReceiptsDirectoryIfNeeded()
    }

    /// 沙盒 Documents/ModelReceipts 专有目录
    private var receiptsDirectory: URL {
        let doc = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return doc.appendingPathComponent("ModelReceipts", isDirectory: true)
    }

    private func createReceiptsDirectoryIfNeeded() {
        try? FileManager.default.createDirectory(at: receiptsDirectory, withIntermediateDirectories: true)
    }

    /// 校验 modelId 并解析严格落在 ModelReceipts 目录内的安全路径，阻断 `../` 路径穿越读/写/删
    internal func safeReceiptURL(for modelId: String) -> URL? {
        let trimmed = modelId.trimmingCharacters(in: .whitespacesAndNewlines)
        let doubleDot = SystemConstants.Character.dot + SystemConstants.Character.dot
        guard !trimmed.isEmpty,
              trimmed == modelId,
              trimmed != SystemConstants.Character.dot,
              !trimmed.contains(doubleDot),
              !trimmed.contains(SystemConstants.Character.slash),
              !trimmed.contains(SystemConstants.Character.backslash),
              trimmed.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) else {
            return nil
        }
        let baseDir = receiptsDirectory.standardizedFileURL
        let candidate = baseDir.appendingPathComponent("\(trimmed).receipt.json").standardizedFileURL
        guard candidate.deletingLastPathComponent().path == baseDir.path else {
            return nil
        }
        return candidate
    }

    /// 写入权威完成凭据
    public func saveReceipt(_ receipt: ModelDownloadReceipt) {
        createReceiptsDirectoryIfNeeded()
        guard let url = safeReceiptURL(for: receipt.modelId) else {
            Logger.shared.warning("[ModelReceiptStore] 非法 modelId，拒绝写入收据: \(receipt.modelId)")
            return
        }
        if let data = try? JSONEncoder().encode(receipt) {
            try? data.write(to: url, options: .atomic)
        }
    }

    /// 读取特定模型的权威完成凭据
    public func getReceipt(for modelId: String) -> ModelDownloadReceipt? {
        guard let url = safeReceiptURL(for: modelId),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ModelDownloadReceipt.self, from: data)
    }

    /// 物理删除特定模型的完成凭据（当用户主动删除模型时调用）
    public func removeReceipt(for modelId: String) {
        guard let url = safeReceiptURL(for: modelId) else {
            Logger.shared.warning("[ModelReceiptStore] 非法 modelId，拒绝删除收据: \(modelId)")
            return
        }
        try? FileManager.default.removeItem(at: url)
    }
}
