//
//  ZIPFoundationArchiver.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 平台适配层 — ZIPFoundation 库适配器
//  核心职责：ZIPFoundation 开源库唯一适配层。
//           封装 ZIP 压缩（zip）与解压（extractContents），上层禁止直接 import ZIPFoundation。
//           由 iOSPlatformRegistrar 注册，适用于 iOS + Mac Catalyst 平台。
//
import Foundation
import UFPCore
import ZIPFoundation

/// ZIPFoundation 归档适配层（适用于 iOS 和 Mac Catalyst）
final class ZIPFoundationArchiver: FileArchiverProtocol, Sendable {

    private enum ArchiverLimits {
        static let maxTotalExtractedMB: UInt64 = 256
        static let maxTotalExtractedBytes: UInt64 = maxTotalExtractedMB * UInt64(SystemConstants.bytesPerMB)
        static let maxEntryCount: Int = 5000
        static let windowsDrivePattern: String = #"^[A-Za-z]:[\\/]"#
        static let budgetExceededReason: String = "ZIP_Extraction_Budget_Exceeded"
    }

    // MARK: - 压缩

    func zip(directory sourceDir: URL, to destinationURL: URL) async throws {
        try FileManager.default.zipItem(at: sourceDir, to: destinationURL)
    }

    // MARK: - 解压（含路径穿越防护 VULN-014 / #134）

    /// 校验并解析单个 ZIP entry 的安全落盘路径，防御路径穿越、反斜杠穿越与兄弟目录前缀欺骗
    internal static func safeDestinationURL(for entryPath: String, in destinationURL: URL) -> URL? {
        guard !entryPath.isEmpty else {
            Logger.shared.warning("ZIP_Skipped_EmptyPath_Entry")
            return nil
        }
        // 统一将 Windows 反斜杠转换为正斜杠后再校验，防 ..\..\ 绕过
        let normalizedPath = entryPath.replacingOccurrences(
            of: PlatformConstants.PDFSecurity.backslashSeparator,
            with: PlatformConstants.PDFSecurity.pathSeparator
        )
        // 1. 拒绝绝对路径（Unix / 和 Windows 盘符 C:\）
        guard !normalizedPath.hasPrefix(PlatformConstants.PDFSecurity.pathSeparator),
              !entryPath.matchesRegex(ArchiverLimits.windowsDrivePattern) else {
            Logger.shared.warning("ZIP_Skipped_AbsolutePath_Entry: \(entryPath)")
            return nil
        }
        // 2. 拒绝 ".." 路径穿越——按路径组件检查，避免误拒含 ".." 的合法文件名
        let pathComponents = normalizedPath.split(separator: Character(PlatformConstants.PDFSecurity.pathSeparator)).map(String.init)
        guard !pathComponents.contains(PlatformConstants.PDFSecurity.pathTraversalMarker) else {
            Logger.shared.warning("ZIP_Skipped_PathTraversal_Entry: \(entryPath)")
            return nil
        }

        let destRoot = destinationURL.standardizedFileURL.path
        let destPrefix = destRoot.hasSuffix(PlatformConstants.PDFSecurity.pathSeparator)
            ? destRoot
            : destRoot + PlatformConstants.PDFSecurity.pathSeparator
        let destURL = destinationURL.appendingPathComponent(normalizedPath)
        let resolvedPath = destURL.standardizedFileURL.path

        // 3. 强制带目录分隔符边界校验，防御 /tmp/extract_evil 绕过 /tmp/extract 前缀欺骗
        guard resolvedPath == destRoot || resolvedPath.hasPrefix(destPrefix) else {
            Logger.shared.warning("ZIP_Skipped_OutsideDest_Entry: \(entryPath)")
            return nil
        }
        return destURL
    }

    /// 校验解压预算（条目数上限与累计解压字节上限，含防溢出加法），防御 Zip Bomb 耗尽磁盘或 I/O
    internal static func validateExtractionBudget(
        entryCount: Int,
        totalBytes: UInt64,
        nextEntryBytes: UInt64
    ) throws -> UInt64 {
        guard entryCount <= ArchiverLimits.maxEntryCount else {
            throw FileArchiverError.extractionFailed(reason: ArchiverLimits.budgetExceededReason)
        }
        let (updatedTotal, overflow) = totalBytes.addingReportingOverflow(nextEntryBytes)
        guard !overflow, updatedTotal <= ArchiverLimits.maxTotalExtractedBytes else {
            throw FileArchiverError.extractionFailed(reason: ArchiverLimits.budgetExceededReason)
        }
        return updatedTotal
    }

    /// 将 ZIP 归档文件解压到指定目录，内置路径穿越、符号链接逃逸与 Zip Bomb 容量预算防护
    func extractContents(from archiveURL: URL, to destinationURL: URL) throws {
        let archive: Archive
        do {
            archive = try Archive(url: archiveURL, accessMode: .read)
        } catch {
            throw FileArchiverError.extractionFailed(reason: "Cannot open archive: \(error)")
        }

        var processedEntries = 0
        var totalExtractedBytes: UInt64 = 0

        for entry in archive {
            // 拒绝符号链接 entry，防止恶意归档通过 symlink 写穿目标沙盒目录
            guard entry.type != .symlink else {
                Logger.shared.warning("ZIP_Skipped_Symlink_Entry: \(entry.path)")
                continue
            }
            guard let destURL = Self.safeDestinationURL(for: entry.path, in: destinationURL) else {
                continue
            }

            processedEntries += 1
            totalExtractedBytes = try Self.validateExtractionBudget(
                entryCount: processedEntries,
                totalBytes: totalExtractedBytes,
                nextEntryBytes: entry.uncompressedSize
            )

            // 确保父目录存在（处理 ZIP 内目录结构）
            try? FileManager.default.createDirectory(
                at: destURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            _ = try archive.extract(entry, to: destURL)
        }
    }
}
