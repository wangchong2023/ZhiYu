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
        /// JSContext 引擎连接池物理上限
        static let maxEngineContextPoolSize: Int = 4
        /// 单插件拦截执行超时时间（秒）
        static let pluginTimeoutSeconds: TimeInterval = 0.5
        /// 限流窗口内最大调用次数
        static let maxCallsPerWindow: Int = 50
        /// 限流窗口时间（秒）
        static let throttlingWindowSeconds: TimeInterval = 60.0
        /// 当前插件宿主内核版本号
        static let defaultHostVersion: String = "2.0.0"
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
        /// HTTP method 权限
        static let httpMethod: String = "httpMethod"
        /// HTTP header 权限
        static let httpHeader: String = "httpHeader"
    }

    // MARK: - 网络安全 (Network Security)
    /// 插件网络请求安全策略常量
    enum NetworkSecurity {
        /// 允许的 HTTP 方法白名单（拒绝 DELETE/TRACE/CONNECT 等危险方法）
        static let allowedHTTPMethods: Set<String> = ["GET", "POST", "PUT", "PATCH", "HEAD", "OPTIONS"]
        /// 危险 header 黑名单（插件不可注入宿主凭证相关 header）
        static let blockedHeaders: Set<String> = [
            "Authorization", "Cookie", "Set-Cookie",
            "Proxy-Authorization", "X-API-Key"
        ]
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

    // MARK: - 插件 ID 前缀分类 (Plugin ID Prefix by Scope)
    /// 插件 ID 前缀分类（local/remote/base），用于 displayName 裁剪
    enum IDPrefix {
        /// 本地插件 ID 前缀
        static let local: String = "com.zhiyu.plugin.local."
        /// 远程插件 ID 前缀
        static let remote: String = "com.zhiyu.plugin.remote."
        /// 基础插件 ID 前缀
        static let base: String = "com.zhiyu.plugin."
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

    // MARK: - 插件分类 (Category)
    /// 插件分类字符串常量集，消除 categoryPillsSection 与筛选逻辑中的魔鬼字符串
    enum Category {
        /// 效率工具分类
        static let efficiency: String = "efficiency"
        /// 社交分类
        static let social: String = "social"
        /// 阅读分类
        static let reading: String = "reading"
        /// 其他分类（含 nil category 的兜底匹配）
        static let other: String = "other"
    }

    // MARK: - 本地图标关键词 (Local Icon Keyword)
    /// localIconName(for:) 匹配用的插件 ID 关键词常量集
    enum LocalIconKeyword {
        /// 目录生成器
        static let tocGenerator: String = "toc-generator"
        /// 字数统计
        static let wordCounter: String = "word-counter"
        /// 智能清理
        static let smartCleaner: String = "smart-cleaner"
        /// AI 摘要
        static let aiSummary: String = "ai-summary"
        /// 代码高亮
        static let codeHighlighter: String = "code-highlighter"
        /// 链接预览
        static let linkPreview: String = "link-preview"
        /// AI 翻译
        static let aiTranslator: String = "ai-translator"
        /// Markdown 美化
        static let markdownBeautifier: String = "markdown-beautifier"
    }

    // MARK: - URL 前缀 (URL Prefix)
    /// URL scheme 前缀判断常量
    enum URLPrefix {
        /// HTTP/HTTPS 协议前缀
        static let http: String = "http"
    }

    // MARK: - SF Symbol 图标名 (SF Symbol Name)
    /// PluginCard 中使用的 SF Symbol 图标名常量集
    enum IconName {
        /// 远程图标加载失败/未知 default 的拼图块图标
        static let puzzleExtensionFill: String = "puzzlepiece.extension.fill"
        /// 重试箭头图标
        static let arrowClockwise: String = "arrow.clockwise"
        /// WiFi 断开图标
        static let wifiSlash: String = "wifi.slash"
    }

    // MARK: - 文件名安全 (File Name Security)
    /// 文件名路径穿越校验常量集
    enum FileNameSecurity {
        /// 路径穿越标记（..）
        static let pathTraversalMarker: String = ".."
        /// 路径分隔符（/）
        static let pathSeparator: String = "/"
    }
}
