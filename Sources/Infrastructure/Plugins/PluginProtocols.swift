//
//  PluginProtocols.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：插件系统：JavaScript 沙箱、市场服务、插件注册与生命周期。
//
import Foundation

/// 插件元数据定义
@MainActor
struct PluginManifest: Codable {
    let id: String
    let version: String
    let author: String
    let permissions: [String]
    let allowedDomains: [String]? // 网络白名单：仅允许访问指定的域名
    public let category: String? // 插件分类
    
    /// 本地化显示名称 (Key 为语言代码，如 "en", "zh-Hans")
    private let names: [String: String]
    /// 本地化描述信息
    private let descriptions: [String: String]
    /// 多语言 README 文件映射 (Key: 语言代码, Value: 文件名)
    public let readmeFiles: [String: String]?
    /// 插件图标文件名
    public let iconFile: String?
    /// 插件代码签名（HMAC-SHA256，基于 index.js 内容 + 内置盐值计算）
    /// - Note: 安全要求：所有外部插件必须提供有效签名，否则拒绝加载（VULN-001 修复）
    public let codeSignature: String?

    init(id: String, version: String, author: String = "Unknown", permissions: [String] = [], allowedDomains: [String]? = nil, names: [String: String], descriptions: [String: String], readmeFiles: [String: String]? = nil, iconFile: String? = nil, category: String? = nil, codeSignature: String? = nil) {
        self.id = id
        self.version = version
        self.author = author
        self.permissions = permissions
        self.allowedDomains = allowedDomains
        self.category = category
        self.names = names
        self.descriptions = descriptions
        self.readmeFiles = readmeFiles
        self.iconFile = iconFile
        self.codeSignature = codeSignature
    }
    
    /// 获取当前语言环境下的显示名称
    var name: String {
        Localized.bestMatch(in: names, fallback: id)
    }

    /// 获取当前语言环境下的描述信息
    var description: String {
        Localized.bestMatch(in: descriptions, fallback: "")
    }
}

/// 插件权限定义
enum PluginPermission: String, Codable {
    case readContent    // 读取内容
    case writeContent   // 修改内容
    case network        // 网络访问
    case aiAccess       // 调用 LLM 服务
}

/// 插件商业化信息
struct MonetizationInfo: Codable {
    enum Model: String, Codable {
        case free               // 免费
        case donation       // 赞助/打赏
        case subscription // 订阅
    }
    var model: Model
    var supportURL: String? // 打赏链接或订阅主页
}

/// 插件执行上下文 (安全专家视角：权限隔离与沙盒控制)
@MainActor
protocol PluginContext {
    var hostVersion: String { get }

    /// 记录日志
    /// - Parameter message: message
    func log(_ message: String)

    /// 请求AIAccess
    /// - Parameter prompt: prompt
    func requestAIAccess(prompt: String) async -> String?

    /// queryPages
    func queryPages(matching query: String) async -> [KnowledgePage]
    
    // MARK: - 扩展点注册 (Obsidian-like)
    
    /// 注册全局命令（显示在 Command Palette 中）
    func registerCommand(id: String, name: String, callback: @escaping @MainActor () -> Void)
    
    /// 在侧边栏注册快捷入口 (Ribbon Icon)
    func registerRibbonItem(icon: String, title: String, callback: @escaping @MainActor () -> Void)
    
    /// 注册自定义页面处理器
    func registerPageProcessor(_ processor: any KnowledgePageProcessor)

    // MARK: - 高级扩展点 (Advanced Expansion)
    
    /// 注册插件设置面板 (支持声明式 UI Schema)
    func registerSettingTab(name: String, schema: String?, callback: @escaping @MainActor (String?) -> Void)
    
    /// 注册插件自定义视图 (作为侧边栏 Tab 展现)
    func registerView(id: String, title: String, icon: String, callback: @escaping @MainActor () -> Void)
    
    /// 监听系统事件 (如 onFileOpen, onVaultRename)
    func addEventListener(event: String, callback: @escaping @MainActor (Any?) -> Void)
    
    // MARK: - 持久化存储 (Phase 2)
    
    /// 保存插件私有数据
    func saveData(key: String, value: String)
    
    /// 读取插件私有数据
    func loadData(key: String) -> String?
}

/// 插件命令定义
struct PluginCommand: Identifiable {
    let id: String
    let pluginID: String
    let name: String
    let action: @MainActor () -> Void
}

/// 侧边栏快捷项定义
struct PluginRibbonItem: Identifiable {
    let id = UUID()
    let pluginID: String
    let icon: String
    let title: String
    let action: @MainActor () -> Void
}

/// 插件设置页项
struct PluginSettingTab: Identifiable {
    let id = UUID()
    let pluginID: String
    let name: String
    let schema: String? // 可选的 JSON 描述文件
    let action: @MainActor (String?) -> Void
}

/// 插件自定义视图项
struct PluginCustomView: Identifiable {
    let id: String // 视图唯一 ID
    let pluginID: String
    let title: String
    let icon: String
    let action: @MainActor () -> Void
}

/// 插件事件监听器
struct PluginEventListener {
    let pluginID: String
    let event: String
    let callback: @MainActor (Any?) -> Void
}

/// 知识库插件基础协议
@MainActor
protocol KnowledgePlugin: AnyObject {
    /// 插件元数据
    var manifest: PluginManifest { get }

    var monetization: MonetizationInfo? { get }        // 商业化声明

    /// 插件加载：进行资源初始化、UI 锚点注册等
    func onLoad(context: PluginContext)

    /// 插件卸载：清理资源、注销钩子
    func onUnload()
}

/// 拦截钩子插件：允许插件干扰核心业务逻辑
@MainActor
protocol InterceptionPlugin: KnowledgePlugin {
    /// 在内容入库前执行（例如：执行正则清洗、敏感词过滤）
    func preProcess(content: String) throws -> String

    /// 在内容渲染前执行（例如：将特定语法转化为自定义视图）
    func postProcess(content: String) throws -> String
}

/// 分析服务协议：用于系统埋点与行为观测
@MainActor
protocol AnalyticsServiceProtocol: AnyObject {

    /// 追踪Event
    /// - Parameter name: name
    /// - Parameter properties: properties
    func trackEvent(_ name: String, properties: [String: Any]?)

    /// 追踪Error
    /// - Parameter error: error
    /// - Parameter details: details
    func trackError(_ error: Error, details: String?)
}
