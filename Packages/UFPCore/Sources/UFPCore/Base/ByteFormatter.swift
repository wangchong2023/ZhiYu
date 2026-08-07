//
//  ByteFormatter.swift
//  UFPCore
//
//  Created by CodeFree on 2026/08/07.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 基础设施层
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

    /// 将字节数按自定义精度换算为易读文本（GB 优先，不足 GB 则用 MB）
    /// - Parameters:
    ///   - bytes: 字节数 (Int64)
    ///   - gbPrecision: GB 单位小数位数（默认 2）
    ///   - mbPrecision: MB 单位小数位数（默认 1）
    /// - Returns: 自定义精度的换算文本（如 2781167616 -> "2.59 GB", 524288 -> "0.5 MB"）
    public static func formatCustom(_ bytes: Int64, gbPrecision: Int = 2, mbPrecision: Int = 1) -> String {
        let bytesDouble = Double(bytes)
        let kb = bytesDouble / SystemConstants.bytesPerKB
        let mb = kb / SystemConstants.bytesPerKB
        let gb = mb / SystemConstants.bytesPerKB
        if gb >= 1.0 {
            return String(format: "%.\(gbPrecision)f GB", gb)
        }
        return String(format: "%.\(mbPrecision)f MB", mb)
    }

    /// 将字节数按 B/KB/MB 三档换算为易读文本（小文件场景）
    /// - Parameter bytes: 字节数 (Int)
    /// - Returns: 三档换算文本（如 512 -> "512 B", 2048 -> "2.0 KB", 1048576 -> "1.0 MB"）
    public static func formatSmall(_ bytes: Int) -> String {
        let b = Double(bytes)
        if b < SystemConstants.bytesPerKB { return "\(bytes) B" }
        if b < SystemConstants.bytesPerMB { return String(format: "%.1f KB", b / SystemConstants.bytesPerKB) }
        return String(format: "%.1f MB", b / SystemConstants.bytesPerMB)
    }
}
