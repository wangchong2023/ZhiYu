//
//  VaultStorageService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：实现 VaultStorage 模块的核心业务逻辑服务。
//
import Foundation
import UFPCore

@MainActor
struct ExternalPage {
    let url: URL
    let title: String
    let content: String
    let lastModified: Date
}

final class VaultStorageService {
    nonisolated(unsafe) static let shared = VaultStorageService()
    
    /// 注入的平台安全存储提供者
    @ObservationIgnored @Inject var storageProvider: SecurityScopedStorageProtocol

    /// 扫描指定文件夹下的所有 Markdown 文件
    func scan(directory: URL) -> [ExternalPage] {
        var results: [ExternalPage] = []
        let fileManager = FileManager.default

        guard let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
            return []
        }

        for case let fileURL as URL in enumerator where fileURL.pathExtension.lowercased() == StorageConstants.SourceType.md {
                if let page = processFile(at: fileURL) {
                    results.append(page)
                }
        }
        return results
    }

    private func processFile(at url: URL) -> ExternalPage? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let modificationDate = attributes[.modificationDate] as? Date ?? Date()
            let content = try String(contentsOf: url, encoding: .utf8)

            // 提取标题（优先找 H1，否则用文件名）
            let title = extractTitle(from: content) ?? url.deletingPathExtension().lastPathComponent

            return ExternalPage(
                url: url,
                title: title,
                content: content,
                lastModified: modificationDate
            )
        } catch {
            Logger.shared.addLog(action: .error, target: StorageConstants.LogTarget.vaultStorageService, details: StorageConstants.LogDetails.vaultFailed1)
            return nil
        }
    }

    private func extractTitle(from content: String) -> String? {
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix(StorageConstants.MarkdownSyntax.hashSpace) {
                return trimmed.replacingOccurrences(of: StorageConstants.MarkdownSyntax.hashSpace, with: "").trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    /// 存储书签以备持久化访问
    func storeBookmark(for url: URL) {
        storageProvider.storeBookmark(for: url)
    }

    /// 从书签恢复 URL 访问权限
    func restoreURL(from data: Data) -> URL? {
        storageProvider.restoreURL(from: data)
    }
}
