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
import ZIPFoundation

/// ZIPFoundation 归档适配层（适用于 iOS 和 Mac Catalyst）
final class ZIPFoundationArchiver: FileArchiverProtocol, Sendable {

    // MARK: - 压缩

    func zip(directory sourceDir: URL, to destinationURL: URL) async throws {
        try FileManager.default.zipItem(at: sourceDir, to: destinationURL)
    }

    // MARK: - 解压（含路径穿越防护 VULN-014）

    /// 将 ZIP 归档文件解压到指定目录，内置路径穿越攻击防护
    func extractContents(from archiveURL: URL, to destinationURL: URL) throws {
        let archive: Archive
        do {
            archive = try Archive(url: archiveURL, accessMode: .read)
        } catch {
            throw FileArchiverError.extractionFailed(reason: "Cannot open archive: \(error)")
        }

        let destStandardized = destinationURL.standardizedFileURL.path

        for entry in archive {
            let entryPath = entry.path

            // 1. 拒绝 ".." 路径穿越——按路径组件检查，避免误拒含 ".." 的合法文件名
            // Bug #43 修复：从子串匹配改为路径组件检查
            let pathComponents = entryPath.split(separator: "/").map(String.init)
            guard !pathComponents.contains(PlatformConstants.PDFSecurity.pathTraversalMarker) else {
                // Bug #45 修复：恶意 entry 跳过时记录 warning 日志
                Logger.shared.warning("ZIP_Skipped_PathTraversal_Entry: \(entryPath)")
                continue
            }
            // 2. 拒绝绝对路径（Unix / 和 Windows 盘符 C:\）
            guard !entryPath.hasPrefix("/"),
                  !entryPath.matchesRegex(#"^[A-Za-z]:[\\/]"#) else {
                Logger.shared.warning("ZIP_Skipped_AbsolutePath_Entry: \(entryPath)")
                continue
            }
            // 3. 拒绝空路径
            guard !entryPath.isEmpty else {
                Logger.shared.warning("ZIP_Skipped_EmptyPath_Entry")
                continue
            }

            let destURL = destinationURL.appendingPathComponent(entryPath)

            // 4. 确保 destURL 标准化后仍在目标目录内
            guard destURL.standardizedFileURL.path.hasPrefix(destStandardized) else {
                Logger.shared.warning("ZIP_Skipped_OutsideDest_Entry: \(entryPath)")
                continue
            }

            // 确保父目录存在（处理 ZIP 内目录结构）
            try? FileManager.default.createDirectory(
                at: destURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            _ = try archive.extract(entry, to: destURL)
        }
    }
}
