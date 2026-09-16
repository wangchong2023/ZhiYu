//
//  VersionInfoFormatter.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/27.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 基础设施层
//  核心职责：将 Info.plist 中的版本号字段格式化为 UI 展示字符串，
//          从 AboutView 中抽离以便独立单元测试。
//

import Foundation

/// 版本信息格式化器，将 Info.plist 原始字典转换为 UI 展示文本
enum VersionInfoFormatter {

    // MARK: - 版本号

    /// 干净版本号（SemVer）
    /// - Returns: 如 `"1.0.0"`，缺失时 `"0.0.0"`
    static func semVerString(from info: [String: Any]?) -> String {
        string(from: info, key: "CFBundleShortVersionString", default: CoreConstants.VersionDefault.missingSemVer)
    }

    // MARK: - 构建详情

    /// 构建号 + 短哈希
    /// - Returns: `"844 · abc1234"`
    static func buildDetailString(from info: [String: Any]?) -> String {
        guard let info else { return "? · unknown" }
        let build = info["CFBundleVersion"] as? String ?? "?"
        let hash = info["GIT_SHORT_HASH"] as? String ?? "unknown"
        return "\(build) · \(hash)"
    }

    // MARK: - 构建时间

    /// 从 infoDictionary 读取 BUILD_TIMESTAMP 并转换为本地化短格式
    /// - Returns: 格式 `"2026-06-27 15:30"`；无数据返回 `""`；解析失败返回原始值
    static func buildTimestampString(from info: [String: Any]?) -> String {
        guard let info, let raw = info["BUILD_TIMESTAMP"] as? String, !raw.isEmpty else {
            return ""
        }

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        guard let date = isoFormatter.date(from: raw) else { return raw }

        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        displayFormatter.timeZone = TimeZone.current
        return displayFormatter.string(from: date)
    }

    // MARK: - 辅助

    /// 从 infoDictionary 安全读取字符串字段，缺失时返回默认值
    private static func string(from info: [String: Any]?, key: String, default fallback: String) -> String {
        guard let info else { return fallback }
        return info[key] as? String ?? fallback
    }
}
