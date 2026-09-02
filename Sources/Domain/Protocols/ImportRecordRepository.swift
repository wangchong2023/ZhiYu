//
//  ImportRecordRepository.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/10.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层
//  核心职责：导入原始内容仓储协议

import Foundation
import Dependencies
import UFPCore

public protocol ImportRecordRepository: Sendable {
    func save(_ record: ImportRecord) async throws
    func fetchAll(category: String?, limit: Int) async throws -> [ImportRecord]
    func fetchByID(_ id: String) async throws -> ImportRecord?
    func updateStatus(id: String, status: String, completedAt: Date?) async throws
    func updatePageID(id: String, pageID: String) async throws
    func updateRawText(id: String, rawText: String) async throws
    func updateTags(id: String, tags: String) async throws
    func fetchInProgress() async throws -> [ImportRecord]
    func totalStorageSize() async throws -> Int64
}

// MARK: - DependencyKey 注册

/// ImportRecordRepository 的 DependencyKey（P7 迁移：过渡期 liveValue 从 ServiceContainer 解析）
public enum ImportRecordRepositoryKey: DependencyKey {
    public static var liveValue: any ImportRecordRepository {
        ServiceContainer.shared.resolve((any ImportRecordRepository).self)
    }

    public static var testValue: any ImportRecordRepository {
        ServiceContainer.shared.resolveOptional((any ImportRecordRepository).self) ?? NoOpImportRecordRepository()
    }
    public static var previewValue: any ImportRecordRepository { testValue }
}

/// 无操作导入记录仓储（测试/预览占位，DI 未就绪时降级）
public final class NoOpImportRecordRepository: ImportRecordRepository, Sendable {
    public init() {}
    public func save(_ record: ImportRecord) async throws {}
    public func fetchAll(category: String?, limit: Int) async throws -> [ImportRecord] { [] }
    public func fetchByID(_ id: String) async throws -> ImportRecord? { nil }
    public func updateStatus(id: String, status: String, completedAt: Date?) async throws {}
    public func updatePageID(id: String, pageID: String) async throws {}
    public func updateRawText(id: String, rawText: String) async throws {}
    public func updateTags(id: String, tags: String) async throws {}
    public func fetchInProgress() async throws -> [ImportRecord] { [] }
    public func totalStorageSize() async throws -> Int64 { 0 }
}

extension DependencyValues {
    /// 导入原始内容仓储依赖
    public var importRecordRepository: any ImportRecordRepository {
        get { self[ImportRecordRepositoryKey.self] }
        set { self[ImportRecordRepositoryKey.self] = newValue }
    }
}
