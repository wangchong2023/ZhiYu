//
//  FeedbackRepository.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/10.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层
//  核心职责：定义用户反馈与评价数据的仓储读写与持久化存储抽象接口。

import Foundation

public protocol FeedbackRepository: Sendable {
    func save(_ entry: FeedbackEntry) async throws
    func fetchAll(limit: Int) async throws -> [FeedbackEntry]
    func fetchByID(id: String) async throws -> FeedbackEntry?
    func updateStatus(id: String, status: FeedbackStatus) async throws
}

// MARK: - DependencyKey 注册

import Dependencies
import UFPCore

/// FeedbackRepository 的 DependencyKey（P7 迁移：过渡期 liveValue 从 ServiceContainer 解析）
public enum FeedbackRepositoryKey: DependencyKey {
    public static var liveValue: any FeedbackRepository {
        ServiceContainer.shared.resolve((any FeedbackRepository).self)
    }
}

extension DependencyValues {
    /// 用户反馈仓储依赖
    public var feedbackRepository: any FeedbackRepository {
        get { self[FeedbackRepositoryKey.self] }
        set { self[FeedbackRepositoryKey.self] = newValue }
    }
}
