//
//  FileSystemSyncService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：实现 FileSystemSync 模块的核心业务逻辑服务。
//
import Foundation
import UFPCore

/// 文件系统同步服务：将数据库内容导出为物理 Markdown 文件
final class FileSystemSyncService {

    private enum ExportConstants {
        static let fallbackFileName = "untitled"
        static let markdownExtension = ".md"
        static let replacementDash = "-"
        static let colonSeparator = ":"
        static let space = " "
        static let tagJoinSeparator = ", "
        static let duplicateSuffixStart = 2
        static let pathInvalidCharacters = CharacterSet(
            charactersIn: SystemConstants.Character.slash
                + SystemConstants.Character.backslash
                + colonSeparator
                + SystemConstants.Character.dot
        ).union(.newlines)
    }

    /// 清理导出文件名，防止标题含 `/`、`\`、`:`、`..`、换行符引发路径穿越或生成隐藏文件
    internal static func sanitizeFilename(_ rawTitle: String) -> String {
        let cleaned = rawTitle
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: ExportConstants.pathInvalidCharacters)
            .joined(separator: ExportConstants.replacementDash)
            .trimmingCharacters(in: CharacterSet(charactersIn: ExportConstants.replacementDash))
        return cleaned.isEmpty ? ExportConstants.fallbackFileName : cleaned
    }

    /// 清理 YAML Frontmatter 单行标题，防止换行符破坏元数据块结构
    internal static func sanitizeYAMLTitle(_ rawTitle: String) -> String {
        rawTitle
            .components(separatedBy: .newlines)
            .joined(separator: ExportConstants.space)
            .trimmingCharacters(in: .whitespaces)
    }

    /// 导出整个知识库到指定目录，按 PageType 分类存放
    func exportToMarkdown(pages: [KnowledgePage], destinationURL: URL) throws {
        let fm = FileManager.default
        
        // 确保主目录存在
        if !fm.fileExists(atPath: destinationURL.path) {
            try fm.createDirectory(at: destinationURL, withIntermediateDirectories: true)
        }
        
        var usedNormalizedPaths: Set<String> = []
        
        for page in pages {
            // 确定子目录 (如 knowledge/entities/)
            let subfolder = page.folderName
            let folderURL = destinationURL.appendingPathComponent(subfolder)
            
            if !fm.fileExists(atPath: folderURL.path) {
                try fm.createDirectory(at: folderURL, withIntermediateDirectories: true)
            }
            
            // 构建唯一文件名 (防止路径穿越、非法字符及同名/大小写冲突互相覆盖)
            let safeTitle = Self.sanitizeFilename(page.title)
            let fileURL = Self.uniqueFileURL(
                in: folderURL,
                baseName: safeTitle,
                usedNormalizedPaths: &usedNormalizedPaths
            )
            
            // 构建 Markdown 内容 (包含元数据 YAML)
            let safeYAMLTitle = Self.sanitizeYAMLTitle(page.title)
            let safeTags = page.tags.map(Self.sanitizeYAMLTitle).joined(separator: ExportConstants.tagJoinSeparator)
            let yaml = """
            ---
            title: \(safeYAMLTitle)
            type: \(page.pageType.rawValue)
            tags: \(safeTags)
            updated: \(page.updatedAt.formatted())
            ---
            
            """
            let fullContent = yaml + page.content
            
            try fullContent.write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }

    /// 为待导出文件分配不与本批次已有文件冲突的唯一路径（按小写路径判重，兼容大小写不敏感文件系统）
    private static func uniqueFileURL(
        in folderURL: URL,
        baseName: String,
        usedNormalizedPaths: inout Set<String>
    ) -> URL {
        var candidateURL = folderURL.appendingPathComponent(baseName + ExportConstants.markdownExtension)
        var normalizedKey = candidateURL.path.lowercased()
        if usedNormalizedPaths.insert(normalizedKey).inserted {
            return candidateURL
        }

        var suffixIndex = ExportConstants.duplicateSuffixStart
        while true {
            let disambiguatedName = baseName
                + ExportConstants.replacementDash
                + String(suffixIndex)
                + ExportConstants.markdownExtension
            candidateURL = folderURL.appendingPathComponent(disambiguatedName)
            normalizedKey = candidateURL.path.lowercased()
            if usedNormalizedPaths.insert(normalizedKey).inserted {
                return candidateURL
            }
            suffixIndex += 1
        }
    }
}
