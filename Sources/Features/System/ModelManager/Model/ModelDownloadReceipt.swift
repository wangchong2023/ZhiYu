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
        let doc = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return doc.appendingPathComponent("ModelReceipts", isDirectory: true)
    }

    private func createReceiptsDirectoryIfNeeded() {
        try? FileManager.default.createDirectory(at: receiptsDirectory, withIntermediateDirectories: true)
    }

    /// 获取特定模型的权威凭据路径
    private func receiptURL(for modelId: String) -> URL {
        receiptsDirectory.appendingPathComponent("\(modelId).receipt.json")
    }

    /// 写入权威完成凭据
    public func saveReceipt(_ receipt: ModelDownloadReceipt) {
        createReceiptsDirectoryIfNeeded()
        let url = receiptURL(for: receipt.modelId)
        if let data = try? JSONEncoder().encode(receipt) {
            try? data.write(to: url, options: .atomic)
        }
    }

    /// 读取特定模型的权威完成凭据
    public func getReceipt(for modelId: String) -> ModelDownloadReceipt? {
        let url = receiptURL(for: modelId)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ModelDownloadReceipt.self, from: data)
    }

    /// 物理删除特定模型的完成凭据（当用户主动删除模型时调用）
    public func removeReceipt(for modelId: String) {
        let url = receiptURL(for: modelId)
        try? FileManager.default.removeItem(at: url)
    }
}
