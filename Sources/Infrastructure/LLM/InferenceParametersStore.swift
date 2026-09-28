//
//  InferenceParametersStore.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/05.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：推理参数持久化存储管理器，负责保存和加载每个模型的推理参数配置。
//

import Foundation
import Dependencies
import UFPCore

// MARK: - 推理参数配置结构

/// 推理参数配置
/// 存储单个模型的推理参数设置
public struct InferenceParametersConfig: Codable, Equatable {
    /// 模型唯一标识符
    public let modelId: String
    
    /// 预设名称：creative | balanced | precise | custom
    public let presetName: String
    
    /// 温度参数 (0.0 - 2.0)
    public let temperature: Double
    
    /// Top-P 采样参数 (0.0 - 1.0)
    public let topP: Double
    
    /// Top-K 采样参数 (1 - 100)
    public let topK: Int
    
    /// 最大生成令牌数 (128 - 4096)
    public let maxTokens: Int
    
    /// 最后更新时间
    public let updatedAt: Date
    
    public init(
        modelId: String,
        presetName: String,
        temperature: Double,
        topP: Double,
        topK: Int,
        maxTokens: Int,
        updatedAt: Date = Date()
    ) {
        self.modelId = modelId
        self.presetName = presetName
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.maxTokens = maxTokens
        self.updatedAt = updatedAt
    }
}

// MARK: - 推理参数存储管理器

/// 推理参数存储管理器
/// 使用 UserDefaults 持久化每个模型的推理参数配置
@MainActor
public final class InferenceParametersStore {
    
    // MARK: - 单例
    
    /// 全局共享实例
    public static let shared = InferenceParametersStore()
    
    // MARK: - 私有属性
    
    /// UserDefaults 存储键
    private let userDefaultsKey = "ZhiYu.InferenceParameters"

    /// 键值存储抽象（DI 注入，替代 UserDefaults.standard 直接访问）
    @Dependency(\.keyStore) private var keyStore: (any KeyStoreProtocol)?

    /// 内存缓存，避免频繁解码 JSON
    private var cache: [String: InferenceParametersConfig] = [:]
    
    // MARK: - 初始化
    
    private init() {
        loadCache()
    }
    
    // MARK: - 公开方法
    
    /// 保存推理参数配置
    /// - Parameter config: 推理参数配置
    public func saveParameters(_ config: InferenceParametersConfig) {
        // 更新内存缓存
        cache[config.modelId] = config
        
        // 持久化到 UserDefaults
        persistCache()
    }
    
    /// 加载指定模型的推理参数配置
    /// - Parameter modelId: 模型唯一标识符
    /// - Returns: 推理参数配置，如果不存在则返回 nil
    public func loadParameters(for modelId: String) -> InferenceParametersConfig? {
        return cache[modelId]
    }
    
    /// 删除指定模型的推理参数配置
    /// - Parameter modelId: 模型唯一标识符
    public func deleteParameters(for modelId: String) {
        cache.removeValue(forKey: modelId)
        persistCache()
    }
    
    /// 获取所有已保存的推理参数配置
    /// - Returns: 所有推理参数配置数组
    public func allConfigurations() -> [InferenceParametersConfig] {
        return Array(cache.values).sorted { $0.updatedAt > $1.updatedAt }
    }
    
    /// 清空所有配置（用于测试或重置）
    public func clearAll() {
        cache.removeAll()
        keyStore?.removeObject(forKey: userDefaultsKey)
    }
    
    // MARK: - 私有方法
    
    /// 从 UserDefaults 加载缓存
    private func loadCache() {
        guard let data = keyStore?.data(forKey: userDefaultsKey) else {
            return
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            cache = try decoder.decode([String: InferenceParametersConfig].self, from: data)
        } catch {
            Logger.shared.error("[InferenceParametersStore] Failed to load configuration: \(error.localizedDescription)", error: error)
            // 如果解码失败，清空缓存避免损坏数据
            cache = [:]
        }
    }

    /// 将缓存持久化到 UserDefaults
    private func persistCache() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(cache)
            keyStore?.set(data, forKey: userDefaultsKey)
        } catch {
            Logger.shared.error("[InferenceParametersStore] Failed to save configuration: \(error.localizedDescription)", error: error)
        }
    }
}
