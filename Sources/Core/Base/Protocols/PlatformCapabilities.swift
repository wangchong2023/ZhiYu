//
//  PlatformCapabilities.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 底层基座层
//  核心职责：跨层协议定义，建立 L0-L3 各层间的抽象契约。
//
import Foundation
import LocalAuthentication
import Dependencies
import UFPCore

// MARK: - 生物识别能力

/// 平台生物识别策略提供者
@MainActor
public protocol BiometricAuthProviderProtocol: Sendable {
    /// 获取当前平台适用的鉴权策略 (LAPolicy)
    var authenticationPolicy: LAPolicy { get }
    
    /// 检查生物识别是否可用
    func canEvaluatePolicy(context: LAContext) -> Bool
    
    /// 执行生物识别鉴权
    func evaluatePolicy(context: LAContext, reason: String) async -> Bool
}

// MARK: - 模型编译能力

/// 机器学习模型编译器协议
public protocol MLModelCompilerProtocol: Sendable {
    /// 是否支持在当前平台执行编译
    var supportsCompilation: Bool { get }
    
    /// 编译指定路径的模型
    /// - Parameter url: 原始模型路径 (.mlmodel)
    /// - Returns: 编译后的模型路径 (.mlmodelc)
    func compileModel(at url: URL) async throws -> URL
}

// MARK: - 安全存储能力

/// 平台特定的安全存储提供者（如 Security-Scoped Bookmarks）
public protocol SecurityScopedStorageProtocol: Sendable {
    /// 为指定 URL 存储持久化访问书签
    func storeBookmark(for url: URL)
    
    /// 从书签数据恢复具有访问权限的 URL
    func restoreURL(from data: Data) -> URL?
}

// MARK: - DependencyKey 注册

/// BiometricAuthProviderProtocol 的 DependencyKey（P7 迁移：过渡期 liveValue 从 ServiceContainer 解析）
public enum BiometricAuthProviderKey: DependencyKey {
    @MainActor
    public static var liveValue: any BiometricAuthProviderProtocol {
        ServiceContainer.shared.resolve((any BiometricAuthProviderProtocol).self)
    }

    @MainActor
    public static var testValue: any BiometricAuthProviderProtocol {
        ServiceContainer.shared.resolveOptional((any BiometricAuthProviderProtocol).self) ?? NoOpBiometricAuthProvider()
    }
}

/// 无操作生物识别服务（测试/预览占位，DI 未就绪时降级）
@MainActor
public final class NoOpBiometricAuthProvider: BiometricAuthProviderProtocol, @unchecked Sendable {
    public init() {}
    public var authenticationPolicy: LAPolicy { .deviceOwnerAuthenticationWithBiometrics }
    public func canEvaluatePolicy(context: LAContext) -> Bool { false }
    public func evaluatePolicy(context: LAContext, reason: String) async -> Bool { false }
}

/// MLModelCompilerProtocol 的 DependencyKey（P7 迁移：过渡期 liveValue 从 ServiceContainer 解析）
public enum MLModelCompilerKey: DependencyKey {
    public static var liveValue: any MLModelCompilerProtocol {
        ServiceContainer.shared.resolve((any MLModelCompilerProtocol).self)
    }
}

extension DependencyValues {
    /// 生物识别服务依赖
    public var biometricAuthProvider: any BiometricAuthProviderProtocol {
        get { self[BiometricAuthProviderKey.self] }
        set { self[BiometricAuthProviderKey.self] = newValue }
    }

    /// 模型编译服务依赖
    public var modelCompiler: any MLModelCompilerProtocol {
        get { self[MLModelCompilerKey.self] }
        set { self[MLModelCompilerKey.self] = newValue }
    }
}
