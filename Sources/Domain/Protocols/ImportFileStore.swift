//
//  ImportFileStore.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/11.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层
//  核心职责：导入原始文件持久化协议

import Foundation
import Dependencies
import UFPCore

public protocol ImportFileStore: Sendable {
    func saveContent(_ content: String, category: ImportCategory, ext: String) -> String?
    func saveData(_ data: Data, category: ImportCategory, ext: String) -> String?
    
    /// 将指定路径的外部物理文件复制到沙盒内部
    /// - Parameters:
    ///   - url: 外部文件 URL
    ///   - category: 导入资源类别
    /// - Returns: 拷贝后的沙盒内绝对路径，失败时返回 nil
    func copyFile(at url: URL, category: ImportCategory) -> String?
}

// MARK: - DependencyKey 注册

/// ImportFileStore 的 DependencyKey（P7 迁移：过渡期 liveValue 从 ServiceContainer 解析）
public enum ImportFileStoreKey: DependencyKey {
    public static var liveValue: any ImportFileStore {
        ServiceContainer.shared.resolve((any ImportFileStore).self)
    }
}

extension DependencyValues {
    /// 导入原始文件持久化依赖
    public var importFileStore: any ImportFileStore {
        get { self[ImportFileStoreKey.self] }
        set { self[ImportFileStoreKey.self] = newValue }
    }
}
