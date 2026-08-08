//
//  PluginConstants.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/07.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：插件系统模块的强类型常量集。
//           消除 JS 沙箱时间限制、载荷大小、本地化语言、
//           默认 manifest 值等散落的魔鬼数字与字符串。
//

import Foundation
import UFPCore

/// 插件系统模块常量集
enum PluginConstants {

    // MARK: - JS 沙箱限制 (Sandbox Limits)
    enum Sandbox {
        /// JSContextGroup 单次执行时间限制（秒）
        static let jsExecutionTimeLimitSeconds: Double = 0.5
        /// 插件预处理/后处理响应最大载荷 MB 数
        static let maxResponseSizeMB: Int = 5
        /// 插件预处理/后处理响应最大字节数（maxResponseSizeMB * KB²）
        static let maxResponseSizeBytes: Int = maxResponseSizeMB * Int(SystemConstants.bytesPerKB) * Int(SystemConstants.bytesPerKB)
    }

    // MARK: - 本地化语言要求 (Localization)
    enum Localization {
        /// 插件 README 强制要求的语言列表（引用 CoreConstants.LanguageCode）
        static let requiredLocales: [String] = [CoreConstants.LanguageCode.en, "zh-Hans"]
    }

    // MARK: - 默认 Manifest 值 (Default Manifest Values)
    enum DefaultManifest {
        /// 裸 .js 插件的默认版本号（引用 SystemConstants.Version.defaultSemVer）
        static let version: String = SystemConstants.Version.defaultSemVer
        /// 裸 .js 插件的默认作者名
        static let author: String = "Local Developer"
        /// 裸 .js 插件的默认权限列表
        static let permissions: [String] = ["log", "writeContent"]
        /// 裸 .js 插件的默认描述（英文）
        static let descriptionEn: String = "Legacy .js plugin (migrate to .zyplugin format)"
        /// 裸 .js 插件的 ID 前缀
        static let idPrefix: String = "local."
    }

    // MARK: - CodingKey 字面量 (Coding Keys)
    /// 插件记录持久化 CodingKey 字面量常量集，避免 PluginRecord 与 GRDB 扩展重复定义
    enum CodingKey {
        /// manifestJSON 字段的序列化 key
        static let manifestJSON: String = "manifest_json"
        /// permissionsJSON 字段的序列化 key
        static let permissionsJSON: String = "permissions_json"
        /// loadDuration 字段的序列化 key
        static let loadDuration: String = "load_duration"
        /// unloadDuration 字段的序列化 key
        static let unloadDuration: String = "unload_duration"
        /// totalExecutionTime 字段的序列化 key
        static let totalExecutionTime: String = "total_execution_time"
        /// callCount 字段的序列化 key
        static let callCount: String = "call_count"
        /// installedAt 字段的序列化 key
        static let installedAt: String = "installed_at"
        /// updatedAt 字段的序列化 key
        static let updatedAt: String = "updated_at"
    }

    // MARK: - 权限字面量 (Permission Strings)
    /// 插件权限字符串常量，与 PluginPermission 枚举 rawValue 对齐
    /// 消除业务代码中 .contains("network") / .contains("llm") 等魔鬼字符串
    enum Permission {
        /// 网络访问权限
        static let network: String = "network"
        /// LLM 调用权限
        static let llm: String = "llm"
        /// 页面读取权限
        static let pagesRead: String = "pages.read"
        /// 内容写入权限
        static let writeContent: String = "writeContent"
        /// 日志权限
        static let log: String = "log"
    }
}
