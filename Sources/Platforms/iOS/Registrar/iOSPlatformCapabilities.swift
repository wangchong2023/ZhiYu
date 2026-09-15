//
//  iOSPlatformCapabilities.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 平台适配层
//  核心职责：iOS 平台实现：后台任务、Widget、文件归档、Spotlight 索引。
//
import Foundation
import LocalAuthentication
import CoreML

// MARK: - 生物识别

/// iOS 平台的生物识别提供者：复用 Apple 全平台通用实现（DRY）。
/// 详见 `ApplePlatformCapabilities.swift` 中的 `AppleBiometricAuthProvider`。
typealias iOSBiometricAuthProvider = AppleBiometricAuthProvider

// MARK: - 模型编译

/// 基于 Core ML 的通用模型编译器 (支持 iOS/macOS)
struct CoreMLModelCompiler: MLModelCompilerProtocol {
    var supportsCompilation: Bool { true }
    
    /// 编译Model
    /// - Returns: 链接
    func compileModel(at url: URL) async throws -> URL {
        return try await MLModel.compileModel(at: url)
    }
}

// MARK: - 安全存储

/// iOS 的通用安全存储（主要由 UIDocumentPicker 自动处理上下文）
struct iOSSecurityScopedStorage: SecurityScopedStorageProtocol {

    /// 存储添加书签
    func storeBookmark(for url: URL) {
        // iOS 侧通常由外部选择器直接返回权限，此处作为扩展预留
    }
    
    /// 恢复URL
    /// - Returns: 可选值
    func restoreURL(from data: Data) -> URL? {
        return nil
    }
}
