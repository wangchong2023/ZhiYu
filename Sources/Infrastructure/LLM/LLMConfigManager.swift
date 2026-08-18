//
//  LLMConfigManager.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：大语言模型客户端：多提供商适配、流式响应解析、端侧推理。
//
import Foundation
import Observation
import Combine
import UFPCore
import Dependencies

/// LLM 配置管理器 (L1-Infra)
@MainActor
@Observable
public final class LLMConfigManager {
    
    // MARK: - 持久化状态
    public var provider: LLMProvider {
        get { configStore.provider }
        set { configStore.provider = newValue; refreshSubServices() }
    }
    public var apiKey: String {
        get { configStore.apiKey }
        set { configStore.apiKey = newValue; refreshSubServices() }
    }
    public var baseURL: String {
        get { configStore.baseURL }
        set { configStore.baseURL = newValue; refreshSubServices() }
    }
    public var model: String {
        get { configStore.model }
        set { configStore.model = newValue; refreshSubServices() }
    }
    public var isEnabled: Bool {
        get { configStore.isEnabled }
        set { configStore.isEnabled = newValue; refreshSubServices() }
    }
    public var autoScan: Bool {
        get { configStore.autoScan }
        set { configStore.autoScan = newValue }
    }
    public var autoRefactor: Bool {
        get { configStore.autoRefactor }
        set { configStore.autoRefactor = newValue }
    }

    /// 服务是否已就绪
    public var isReady: Bool {
        isEnabled && !apiKey.isEmpty
    }

    private let configStore: LLMConfigStore
    private var cancellables = Set<AnyCancellable>()
    
    /// 子服务刷新闭包列表
    private var refreshHandlers: [@MainActor () -> Void] = []

    public init() {
        self.configStore = LLMConfigStore()
        
        // 订阅配置层底层变更
        configStore.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshSubServices()
            }
            .store(in: &cancellables)
    }
    
    /// 注册刷新 Handler（支持多服务同时订阅）
    /// - Parameter handler: 刷新回调
    public func setRefreshHandler(_ handler: @escaping @MainActor () -> Void) {
        self.refreshHandlers.append(handler)
    }

    private func refreshSubServices() {
        for handler in refreshHandlers {
            handler()
        }
    }
}

// MARK: - DependencyKey 注册

/// LLMConfigManager 的 DependencyKey（P7 迁移：过渡期 liveValue 从 ServiceContainer 解析）
public enum LLMConfigManagerKey: DependencyKey {
    @MainActor
    public static var liveValue: LLMConfigManager {
        ServiceContainer.shared.resolve(LLMConfigManager.self)
    }

    @MainActor
    public static var testValue: LLMConfigManager {
        ServiceContainer.shared.resolveOptional(LLMConfigManager.self) ?? LLMConfigManager()
    }
}

extension DependencyValues {
    /// LLM 配置管理器依赖
    public var llmConfigManager: LLMConfigManager {
        get { self[LLMConfigManagerKey.self] }
        set { self[LLMConfigManagerKey.self] = newValue }
    }
}
