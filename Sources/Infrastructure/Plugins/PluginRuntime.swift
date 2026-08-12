//
//  PluginRuntime.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：插件运行时生命周期管理、安全看门狗、资源监控与内容拦截管道。
//

import Foundation
import UFPCore
import Combine
import Dependencies

/// 插件运行时引擎：负责插件激活/停用、资源限流、安全熔断与内容拦截管道
@MainActor
@Observable
final class PluginRuntime: @unchecked Sendable {

    /// 父注册中心弱引用（避免循环引用）
    @ObservationIgnored
    weak var registry: PluginRegistry!

    // MARK: - 依赖注入
    @ObservationIgnored @Dependency(\.keyStore) private var keyStore: (any KeyStoreProtocol)?
    @ObservationIgnored @Dependency(\.knowledgeStore) private var knowledgeStore: KnowledgeStore
    @ObservationIgnored @Dependency(\.llmService) private var llmService: any LLMServiceProtocol
    @ObservationIgnored @Dependency(\.linkService) private var linkService: LinkService

    // MARK: - 资源监控

    /// 插件资源消耗快照 (Watchdog 2.0)
    struct ResourceUsage: Sendable {
        var totalExecutionTime: TimeInterval = 0
        var callCount: Int = 0
        var lastExecutionTime: TimeInterval = 0
        var status: Status = .active

        enum Status: String, Sendable {
            case active, throttled, suspended
        }
    }

    /// 插件资源使用统计
    var pluginResourceUsage: [String: ResourceUsage] = [:]

    /// 已挂起的插件 ID (Security Watchdog)，采用持久化存储
    private var _suspendedPluginIDs: Set<String>?
    var suspendedPluginIDs: Set<String> {
        get {
            if let existing = _suspendedPluginIDs {
                return existing
            }
            let saved = keyStore?.object(forKey: AppConstants.Keys.Storage.suspendedPlugins) as? [String] ?? []
            let set = Set(saved)
            _suspendedPluginIDs = set
            return set
        }
        set {
            _suspendedPluginIDs = newValue
        }
    }

    // MARK: - 初始化

    init() {}

    /// 限流计数器
    private var pluginCallCounts: [String: Int] = [:]

    // MARK: - 配置常量

    /// 单插件最大执行时间 0.5s
    private let pluginTimeout: TimeInterval = 0.5

    /// 限流窗口内最大调用次数
    private let maxCallsPerWindow: Int = 50

    /// 限流窗口 60 秒
    private let throttlingWindow: TimeInterval = 60.0

    /// 内核版本定义（nonisolated 避免 @MainActor 跨越）
    nonisolated let currentHostVersion: String = "2.0.0"

    // MARK: - 插件生命周期

    /// 加载插件到注册中心
    /// - Parameter plugin: 待加载的插件实例
    func loadPlugin(_ plugin: KnowledgePlugin) {

        // 去重检查：防止重复加载已存在的插件
        guard !registry.plugins.contains(where: { $0.manifest.id == plugin.manifest.id }) else {
            Logger.shared.info("[PluginRegistry] Skipped duplicate: \(plugin.manifest.id)")
            return
        }

        // 安全检查：如果该插件已被持久化封禁，禁止加载
        guard !suspendedPluginIDs.contains(plugin.manifest.id) else {
            Logger.shared.warning("[Security] Blocked: \(plugin.manifest.id)")
            return
        }

        // 版本兼容性检查
        if plugin.manifest.version.hasPrefix(PluginConstants.PluginID.v1VersionPrefix) {
            Logger.shared.debug(" [Adapter]  1.x  \(plugin.manifest.name) v1_Compatibility_Shim")
        }

        // 创建沙盒上下文
        let context = PluginContextImpl(manifest: plugin.manifest, registry: registry)

        plugin.onLoad(context: context)
        registry.plugins.append(plugin)
        if let intercepter = plugin as? InterceptionPlugin {
            registry.intercepters.append(intercepter)
        }

        // 初始化统计
        if pluginResourceUsage[plugin.manifest.id] == nil {
            pluginResourceUsage[plugin.manifest.id] = ResourceUsage()
        }

        registry.analytics?.trackEvent("plugin_loaded", properties: [PluginConstants.AnalyticsKey.id: plugin.manifest.id])
    }

    /// 卸载插件：从内存移除并删除磁盘文件，防止重启后重新加载
    /// - Parameter id: 插件 ID
    func unloadPlugin(id: String) {

        if let index = registry.plugins.firstIndex(where: { $0.manifest.id == id }) {
            registry.plugins[index].onUnload()
            registry.plugins.remove(at: index)
        }
        registry.intercepters.removeAll(where: { $0.manifest.id == id })

        // 清理该插件注册的所有扩展点
        registry.commands.removeAll(where: { $0.pluginID == id })
        registry.ribbonItems.removeAll(where: { $0.pluginID == id })
        registry.settingTabs.removeAll(where: { $0.pluginID == id })
        registry.customViews.removeAll(where: { $0.pluginID == id })
        registry.eventListeners.removeAll(where: { $0.pluginID == id })

        // 安全注销页面处理器
        if let store = knowledgeStore as KnowledgeStore? {
            store.unregisterProcessors(for: id)
        }

        // 删除磁盘上的插件文件，防止重启后重新加载
        removePluginFilesFromDisk(pluginID: id)

        registry.analytics?.trackEvent("plugin_unloaded", properties: [PluginConstants.AnalyticsKey.id: id])
    }

    /// 标记并持久化封禁插件
    func suspendPlugin(_ id: String) {

        suspendedPluginIDs.insert(id)
        let array = Array(suspendedPluginIDs)
        keyStore?.set(array, forKey: AppConstants.Keys.Storage.suspendedPlugins)

        // 物理回收：从活跃插件列表中彻底移除，释放 JSContext 内存
        if let index = registry.plugins.firstIndex(where: { $0.manifest.id == id }) {
            let plugin = registry.plugins[index]
            plugin.onUnload()
            registry.plugins.remove(at: index)
        }
        registry.intercepters.removeAll(where: { $0.manifest.id == id })
        registry.commands.removeAll(where: { $0.pluginID == id })
        registry.ribbonItems.removeAll(where: { $0.pluginID == id })
        registry.settingTabs.removeAll(where: { $0.pluginID == id })
        registry.customViews.removeAll(where: { $0.pluginID == id })

        // 更新资源状态
        var usage = pluginResourceUsage[id] ?? ResourceUsage()
        usage.status = .suspended
        pluginResourceUsage[id] = usage

        Logger.shared.error(" [Watchdog 2.0]  \(id) ")
    }

    /// 分发事件给插件监听器
    func emitEvent(_ event: String, data: Any? = nil) {
        let relevant = registry.eventListeners.filter { $0.event == event }
        for listener in relevant {
            listener.callback(data)
        }
    }

    /// 执行全量拦截过滤 (含超时熔断逻辑)
    func applyPreProcess(to content: String) -> String {
        var result = content

        for intercepter in registry.plugins.compactMap({ $0 as? InterceptionPlugin }) {
            let pluginID = intercepter.manifest.id

            // 安全隔离：过滤已挂起的插件
            guard !suspendedPluginIDs.contains(pluginID) else { continue }

            // 动态流控监控 (Throttling)
            let callCount = pluginCallCounts[pluginID] ?? 0
            if callCount > maxCallsPerWindow {
                Logger.shared.debug(" [Throttling]  \(pluginID) ")
                continue
            }
            pluginCallCounts[pluginID] = callCount + 1

            // 异步重置计数器 (简易窗口期)
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(throttlingWindow * 1_000_000_000))
                self.pluginCallCounts[pluginID] = 0
            }

            let start = CFAbsoluteTimeGetCurrent()

            // 安全校验：权限检查
            if !intercepter.manifest.permissions.contains(PluginConstants.Permission.writeContent) {
                Logger.shared.error(" []  \(intercepter.manifest.name)  writeContent ", error: nil)
                continue
            }

            do {
                let processed = try intercepter.preProcess(content: result)
                let duration = CFAbsoluteTimeGetCurrent() - start

                // 更新性能指标
                var usage = pluginResourceUsage[pluginID] ?? ResourceUsage()
                usage.lastExecutionTime = duration
                usage.totalExecutionTime += duration
                usage.callCount += 1
                pluginResourceUsage[pluginID] = usage

                if duration > pluginTimeout {
                    Logger.shared.error(" [Watchdog]  \(intercepter.manifest.name)  (\(String(format: "%.2f", duration))s)")
                    suspendPlugin(pluginID) // 物理封禁并持久化
                    registry.analytics?.trackEvent("plugin_circuit_break", properties: [PluginConstants.AnalyticsKey.id: pluginID, PluginConstants.AnalyticsKey.duration: duration])
                    continue // 丢弃该插件结果
                }

                result = processed

                // 埋点：插件执行成功，记录时长
                registry.analytics?.trackEvent("plugin_intercepted", properties: [
                    "id": pluginID,
                    "duration": duration,
                    "type": "preProcess"
                ])
            } catch {
                Logger.shared.error(" []  \(intercepter.manifest.name) ", error: error)
                registry.analytics?.trackEvent("plugin_crash", properties: [PluginConstants.AnalyticsKey.id: pluginID, PluginConstants.AnalyticsKey.error: error.localizedDescription])
            }
        }

        return result
    }

    /// 重置运行时状态（仅用于测试）
    func reset() {
        for plugin in registry.plugins {
            plugin.onUnload()
        }
        registry.plugins.removeAll()
        registry.intercepters.removeAll()
        registry.commands.removeAll()
        registry.ribbonItems.removeAll()
        registry.settingTabs.removeAll()
        registry.customViews.removeAll()
        registry.eventListeners.removeAll()
        suspendedPluginIDs.removeAll()
        keyStore?.removeObject(forKey: AppConstants.Keys.Storage.suspendedPlugins)
        pluginCallCounts.removeAll()
        pluginResourceUsage.removeAll()
    }

    // MARK: - 磁盘清理

    /// 删除插件在磁盘上的 .zyplugin 和 .js 文件
    private func removePluginFilesFromDisk(pluginID: String) {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let pluginsDir = documentsURL.appendingPathComponent("Plugins")

        // 匹配策略：pluginID 或 ID 的部分匹配文件名
        let patterns = [
            "\(pluginID).zyplugin",
            "\(pluginID).js"
        ]

        for pattern in patterns {
            let fileURL = pluginsDir.appendingPathComponent(pattern)
            if fileManager.fileExists(atPath: fileURL.path) {
                do {
                    try fileManager.removeItem(at: fileURL)
                    Logger.shared.info("[PluginRegistry] Deleted: \(fileURL.lastPathComponent)")
                } catch {
                    Logger.shared.error("[PluginRegistry] Failed to delete \(fileURL.lastPathComponent)", error: error)
                }
            }
        }

        // 模糊匹配与自适应后缀匹配：清理可能由简短 ID（如 "toc-generator"）命名落地的物理目录或文件，
        // 以及包含规范 ID 核心 Slug 片段的任何残留，防止应用重启时扫描器自动重新加载。
        do {
            let files = try fileManager.contentsOfDirectory(at: pluginsDir, includingPropertiesForKeys: nil)
            let idSlug = pluginID.replacingOccurrences(of: PluginConstants.PluginID.officialPrefix, with: "")
            for file in files {
                let name = file.deletingPathExtension().lastPathComponent
                // 1. 完全一致
                // 2. 包含核心 ID 片段 (idSlug)
                // 3. 规范注册 ID 以物理文件名后缀结尾 (例如 "com.zhiyu.plugin.local.toc-generator" 匹配 "toc-generator" 目录)
                if name == pluginID || name.contains(idSlug) || pluginID.hasSuffix("." + name) {
                    try? fileManager.removeItem(at: file)
                    Logger.shared.info("[PluginRegistry] 成功物理清理磁盘残留: \(file.lastPathComponent)")
                }
            }
        } catch {
            Logger.shared.error("[PluginRegistry] 清理磁盘扫描目录发生异常", error: error)
        }
    }
}

// MARK: - Plugin Context Implementation

/// 插件运行时上下文实现：桥接插件与宿主系统的交互能力
@MainActor
private struct PluginContextImpl: PluginContext {
    let manifest: PluginManifest
    weak var registry: PluginRegistry!
    var hostVersion: String { "2.0.0" }

    // MARK: - 依赖注入
    @Dependency(\.knowledgeStore) private var knowledgeStore: KnowledgeStore
    @Dependency(\.llmService) private var llmService: any LLMServiceProtocol
    @Dependency(\.linkService) private var linkService: LinkService

    /// 记录日志
    func log(_ message: String) {
        Logger.shared.debug(" [Plugin:\(manifest.id)] \(message)")
    }

    /// 请求 AI 访问
    func requestAIAccess(prompt: String) async -> String? {
        guard manifest.permissions.contains(PluginConstants.Permission.llm) else {
            Logger.shared.error(" []" + "  \(manifest.id)" + "  LLM" + " manifest " + " 'llm' ", error: nil)
            return nil
        }
        return try? await llmService.generate(prompt: prompt, systemPrompt: "")
    }

    /// 查询页面
    func queryPages(matching query: String) async -> [KnowledgePage] {
        guard manifest.permissions.contains(PluginConstants.Permission.pagesRead) else {
            Logger.shared.error(" []  \(manifest.id)  'pages.read' ", error: nil)
            return []
        }
        let pages = registry.pagesProvider?() ?? []
        return await linkService.search(query: query, in: pages)
    }

    /// 注册 Command
    func registerCommand(id: String, name: String, callback: @escaping @MainActor () -> Void) {
        let command = PluginCommand(id: id, pluginID: manifest.id, name: name, action: callback)
        registry.commands.append(command)
        log(": \(name)")
    }

    /// 注册 RibbonItem
    func registerRibbonItem(icon: String, title: String, callback: @escaping @MainActor () -> Void) {
        let item = PluginRibbonItem(pluginID: manifest.id, icon: icon, title: title, action: callback)
        registry.ribbonItems.append(item)
        log(": \(title)")
    }

    /// 注册 PageProcessor
    func registerPageProcessor(_ processor: any KnowledgePageProcessor) {
        knowledgeStore.registerProcessor(processor, pluginID: manifest.id)
        log(": \(processor.name)")
    }

    /// 注册 SettingTab
    func registerSettingTab(name: String, schema: String?, callback: @escaping @MainActor (String?) -> Void) {
        let tab = PluginSettingTab(pluginID: manifest.id, name: name, schema: schema, action: callback)
        registry.settingTabs.append(tab)
        log(": \(name)")
    }

    /// 注册 View
    func registerView(id: String, title: String, icon: String, callback: @escaping @MainActor () -> Void) {
        let view = PluginCustomView(id: id, pluginID: manifest.id, title: title, icon: icon, action: callback)
        registry.customViews.append(view)
        log(": \(title)")
    }

    /// 添加 EventListener
    func addEventListener(event: String, callback: @escaping @MainActor (Any?) -> Void) {
        let listener = PluginEventListener(pluginID: manifest.id, event: event, callback: callback)
        registry.eventListeners.append(listener)
        log(": \(event)")
    }

    /// 保存 Data
    func saveData(key: String, value: String) {
        registry.savePluginData(pluginID: manifest.id, key: key, value: value)
    }

    /// 加载 Data
    func loadData(key: String) -> String? {
        return registry.loadPluginData(pluginID: manifest.id, key: key)
    }
}
