//
//  WatchModuleRegistrar.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 平台适配层
//  核心职责：watchOS 平台实现：语音听写、健康数据同步、紧凑 UI。
//
import Foundation
import UFPCore

/// watchOS 平台轻量服务注册中枢 (WatchModuleRegistrar)
@MainActor
struct WatchModuleRegistrar {
    /// 注册 watchOS 特定的服务实现
    /// - Parameter container: 服务注入容器实例
    static func register(in container: ServiceContainer) {
        // 1. 注册手表端语音同步数据管道
        container.register(WatchWatchSyncService(), for: (any WatchSyncProtocol).self)
        
        // 2. 注册手表端触感震动反馈服务
        container.register(WatchHapticService(), for: (any HapticFeedbackProtocol).self)
        
        // 3. 注册手表端轻量生物识别鉴权
        container.register(WatchBiometricAuthProvider(), for: BiometricAuthProviderProtocol.self)
        
        // 4. 注册手表端安全存储占位
        container.register(WatchSecurityScopedStorage(), for: SecurityScopedStorageProtocol.self)
        
        // 5. 注册手表端 CoreML 模型编译
        container.register(WatchModelCompiler(), for: MLModelCompilerProtocol.self)
        
        // 6. 注册手表端只读 PDF 文本解析服务
        container.register(WatchPDFService(), for: (any PDFServiceProtocol).self)
    }
}
