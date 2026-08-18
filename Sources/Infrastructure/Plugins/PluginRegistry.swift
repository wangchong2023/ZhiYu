//
//  PluginRegistry.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：插件系统中枢协调器，组合加载器、运行时引擎与存储管理器。
//

import Foundation
import Combine
import Dependencies
import UFPCore

/// 插件注册中心 (L2 层：中枢管理)
/// 组合 PluginLoader / PluginRuntime / PluginStorage 三大子模块
@MainActor
@Observable
final class PluginRegistry: @unchecked Sendable {

    // MARK: - 子模块

    let loader = PluginLoader()
    let runtime = PluginRuntime()
    let storage = PluginStorage()

    // MARK: - 已发布的插件注册表

    var plugins: [KnowledgePlugin] = []
    var commands: [PluginCommand] = []
    var ribbonItems: [PluginRibbonItem] = []
    var settingTabs: [PluginSettingTab] = []
    var customViews: [PluginCustomView] = []

    // MARK: - 资源使用（委托至 PluginRuntime）

    var pluginResourceUsage: [String: PluginRuntime.ResourceUsage] {
        get { runtime.pluginResourceUsage }
        set { runtime.pluginResourceUsage = newValue }
    }

    // MARK: - 内部状态

    var eventListeners: [PluginEventListener] = []
    var intercepters: [InterceptionPlugin] = []

    /// 已挂起的插件 ID（委托至 PluginRuntime）
    var suspendedPluginIDs: Set<String> {
        get { runtime.suspendedPluginIDs }
        set { runtime.suspendedPluginIDs = newValue }
    }

    // MARK: - 注入服务

    /// 分析服务
    var analytics: (any AnalyticsServiceProtocol)?

    /// 数据提供者：用于将核心数据（如页面列表）安全传递给沙盒
    var pagesProvider: (@Sendable () -> [KnowledgePage])?

    // MARK: - 版本信息

    /// 内核版本
    var currentHostVersion: String { runtime.currentHostVersion }

    // MARK: - 初始化

    public init() {
        runtime.registry = self
        loader.registry = self
        runtime.suspendedPluginIDs = storage.loadSuspendedPluginIDs()

        // 异步扫描加载本地已安装的插件，保证重启后状态与已发现插件能被自动唤醒和展示
        Task {
            self.scanAndLoadLocalPlugins()
        }
    }

    // MARK: - 重置

    /// 重置注册中心状态（仅用于测试）
    func reset() {
        runtime.reset()
        storage.clearSuspendedPluginIDs()
    }

    // MARK: - 插件加载（委托至 PluginRuntime）

    /// 加载 Plugin
    func loadPlugin(_ plugin: KnowledgePlugin) {
        runtime.loadPlugin(plugin)
    }

    // MARK: - 插件卸载（委托至 PluginRuntime）

    /// 卸载插件
    func unloadPlugin(id: String) {
        runtime.unloadPlugin(id: id)
    }

    // MARK: - 封禁插件（委托至 PluginRuntime + PluginStorage）

    /// 标记并持久化封禁插件
    func suspendPlugin(_ id: String) {
        runtime.suspendPlugin(id)
        storage.saveSuspendedPluginIDs(runtime.suspendedPluginIDs)
    }

    // MARK: - 事件分发（委托至 PluginRuntime）

    /// 分发事件给插件监听器
    func emitEvent(_ event: String, data: Any? = nil) {
        runtime.emitEvent(event, data: data)
    }

    // MARK: - 内容拦截（委托至 PluginRuntime）

    /// 执行全量拦截过滤 (含超时熔断逻辑)
    func applyPreProcess(to content: String) -> String {
        runtime.applyPreProcess(to: content)
    }

    // MARK: - 插件发现（委托至 PluginLoader）

    /// 从本地沙盒目录扫描并加载外部脚本插件
    func scanAndLoadLocalPlugins() {
        loader.scanAndLoadLocalPlugins()
    }

    // MARK: - 资源访问（委托至 PluginLoader）

    /// 获取已安装插件的图标 URL
    func iconURL(for pluginID: String) -> URL? {
        loader.iconURL(for: pluginID)
    }

    /// 获取已安装插件的本地化 README 内容
    func localizedReadme(for pluginID: String) -> String? {
        loader.localizedReadme(for: pluginID)
    }

    // MARK: - 插件数据持久化（委托至 PluginStorage）

    /// 保存插件私有数据
    func savePluginData(pluginID: String, key: String, value: String) {
        storage.savePluginData(pluginID: pluginID, key: key, value: value)
    }

    /// 读取插件私有数据
    func loadPluginData(pluginID: String, key: String) -> String? {
        storage.loadPluginData(pluginID: pluginID, key: key)
    }

    /// 获取插件的所有持久化数据（解密后）
    func loadAllPluginData(pluginID: String) -> [String: String] {
        storage.loadAllPluginData(pluginID: pluginID)
    }
}

// MARK: - DependencyKey 注册

private enum PluginRegistryKey: DependencyKey {
    static var liveValue: PluginRegistry { ServiceContainer.shared.resolve(PluginRegistry.self) }
    static var testValue: PluginRegistry {
        ServiceContainer.shared.resolveOptional(PluginRegistry.self) ?? MainActor.assumeIsolated { PluginRegistry() }
    }
    static var previewValue: PluginRegistry { MainActor.assumeIsolated { PluginRegistry() } }
}

extension DependencyValues {
    var pluginRegistry: PluginRegistry {
        get { self[PluginRegistryKey.self] }
        set { self[PluginRegistryKey.self] = newValue }
    }
}
