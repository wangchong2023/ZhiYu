//
//  MacFileArchiver.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 平台适配层
//  核心职责：macOS 平台实现：菜单栏、文件归档、辅助功能。
//
#if os(macOS)
import Foundation

/// macOS 原生归档实现
final class MacFileArchiver: FileArchiverProtocol, Sendable {

    /// zip
    func zip(directory sourceDir: URL, to destinationURL: URL) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = sourceDir
        process.arguments = ["-r", destinationURL.path, "."]

        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw NSError(domain: "MacFileArchiver", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "Zip_Failed"])
        }
    }

    /// 预检归档条目列表，拒绝含路径穿越（..）或绝对路径的恶意 ZIP（对齐 iOS Zip Slip 防线）
    private func validateArchiveEntries(at archiveURL: URL) throws {
        let listProcess = Process()
        let pipe = Pipe()
        listProcess.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        listProcess.arguments = ["-Z1", "--", archiveURL.path]
        listProcess.standardOutput = pipe
        try listProcess.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        listProcess.waitUntilExit()
        guard listProcess.terminationStatus == 0 else {
            throw FileArchiverError.extractionFailed(reason: "unzip_list_exit_\(listProcess.terminationStatus)")
        }
        let listing = String(data: data, encoding: .utf8) ?? ""
        for entry in listing.components(separatedBy: .newlines) where !entry.isEmpty {
            let normalized = entry.replacingOccurrences(
                of: PlatformConstants.PDFSecurity.backslashSeparator,
                with: PlatformConstants.PDFSecurity.pathSeparator
            )
            let components = normalized.split(separator: "/").map(String.init)
            if normalized.hasPrefix(PlatformConstants.PDFSecurity.pathSeparator)
                || components.contains(PlatformConstants.PDFSecurity.pathTraversalMarker) {
                throw FileArchiverError.extractionFailed(reason: "unsafe_zip_entry")
            }
        }
    }

    /// macOS 原生解压（/usr/bin/unzip，含 Zip Slip 条目预检与 -- 参数边界保护）
    func extractContents(from archiveURL: URL, to destinationURL: URL) throws {
        try validateArchiveEntries(at: archiveURL)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", "--", archiveURL.path, "-d", destinationURL.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw FileArchiverError.extractionFailed(reason: "unzip_exit_\(process.terminationStatus)")
        }
    }
}
#endif
