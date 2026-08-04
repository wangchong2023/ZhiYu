//
//  ByteFormatter.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 底层基座层 / 工具类
//  核心职责：字节大小自动换算单位工具类 (B, KB, MB, GB, TB)，提供易读的物理文件及网络下载进度文本。
//

import Foundation

/// 字节大小自动换算单位工具类
public enum ByteFormatter {
    // ByteCountFormatter 是非 Sendable 类，但其 string(fromByteCount:) 是线程安全的（Apple 官方文档）。
    // Swift 6 严格并发模式下静态属性必须 Sendable，使用 nonisolated(unsafe) 显式声明安全责任。
    private nonisolated(unsafe) static let formatter: ByteCountFormatter = {
        let bcf = ByteCountFormatter()
        bcf.allowedUnits = [.useBytes, .useKB, .useMB, .useGB, .useTB]
        bcf.countStyle = .file
        bcf.isAdaptive = true
        return bcf
    }()

    /// 将字节数自动换算为易读文本（如 1024 -> "1 KB", 2781167616 -> "2.59 GB"）
    /// - Parameter bytes: 字节数 (Int64)
    /// - Returns: 自动换算单位后的文本
    public static func format(_ bytes: Int64) -> String {
        guard bytes >= 0 else { return "0 B" }
        return formatter.string(fromByteCount: bytes)
    }

    /// 格式化下载进度文本（如 "492.1 MB / 2.59 GB"）
    /// - Parameters:
    ///   - downloadedBytes: 已下载字节数
    ///   - totalBytes: 总字节数
    /// - Returns: 已换算单位的拼接文本
    public static func formatProgress(downloadedBytes: Int64, totalBytes: Int64) -> String {
        let downloadedStr = format(downloadedBytes)
        let totalStr = format(totalBytes)
        return "\(downloadedStr) / \(totalStr)"
    }

    /// 将每秒字节数自动换算为易读的下载速率文本（如 12500000 -> "12.5 MB/s"）
    /// - Parameter bytesPerSecond: 每秒字节数
    /// - Returns: 自动换算后的速率文本
    public static func formatSpeed(_ bytesPerSecond: Double) -> String {
        guard bytesPerSecond > 0 else { return "0 B/s" }
        let formattedSize = format(Int64(bytesPerSecond))
        return "\(formattedSize)/s"
    }
}
