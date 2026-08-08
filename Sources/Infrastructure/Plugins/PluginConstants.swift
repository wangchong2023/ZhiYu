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
        static let requiredLocales: [String] = [CoreConstants.LanguageCode.en, CoreConstants.LanguageCode.zhHans]
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

    // MARK: - 插件市场 JSON 文件名 (Market JSON Filenames)
    /// 插件市场元数据 JSON 文件名常量集
    enum MarketJSON {
        /// 默认社区插件列表文件名
        static let communityPlugins: String = "community-plugins.json"
        /// 简体中文社区插件列表文件名
        static let communityPluginsZhHans: String = "community-plugins_zh-Hans.json"
        /// 旧版社区插件列表文件名
        static let community: String = "community.json"
        /// 替换后的 plugins 路径段
        static let pluginsPathSegment: String = "plugins"
    }

    // MARK: - 语言前缀标记 (Language Prefix Markers)
    /// 语言代码前缀匹配标记
    enum LanguagePrefix {
        /// 中文语言前缀
        static let zh: String = "zh"
        /// 英文语言前缀
        static let en: String = "en"
    }

    // MARK: - 插件市场错误域 (Error Domain)
    /// 插件市场服务错误域与描述常量集
    enum MarketError {
        /// NSError domain 字段值
        static let domain: String = "PluginMarketService"
        /// HTTP 错误描述前缀
        static let httpPrefix: String = "HTTP "
        /// 文档目录定位失败描述
        static let documentsNotFound: String = "Failed to locate documents directory"
    }

    // MARK: - 插件 ID 前缀 (Plugin ID Prefix)
    /// 规范插件 ID 前缀，用于 replacingOccurrences 清理
    enum PluginID {
        /// 规范插件 ID 前缀
        static let officialPrefix: String = "com.zhiyu.plugin."
        /// v1.x 版本前缀（兼容性检测）
        static let v1VersionPrefix: String = "1."
    }

    // MARK: - JS 全局对象名 (JS Global Object Name)
    /// JSContext 注入的全局对象名常量集
    enum JSGlobal {
        /// ZhiYu 全局对象名（插件通过 ZhiYu.xxx 访问宿主 API）
        static let hostBridge: String = "ZhiYu"
    }

    // MARK: - 分析事件参数 Key (Analytics Event Keys)
    /// 插件分析事件 properties 字典 key 常量集
    enum AnalyticsKey {
        /// 插件 ID 字段 key
        static let id: String = "id"
        /// 事件持续时长字段 key
        static let duration: String = "duration"
        /// 错误描述字段 key
        static let error: String = "error"
    }
}
