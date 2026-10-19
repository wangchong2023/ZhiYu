//
//  NoOpAIAnalyticsService.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/10/18.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests] 测试替身
//  核心职责：提供 AIAnalyticsServiceProtocol 的空实现，供单元测试隔离后台异步任务使用。
//

import Foundation
@testable import ZhiYu

/// 测试用空操作 AI 指标分析服务
public final class NoOpAIAnalyticsService: AIAnalyticsServiceProtocol, @unchecked Sendable {
    public init() {}

    public func recordUsage(model: String, response: [String: Any], latency: Int) {
        // 空操作，安全丢弃
    }

    public func recordRAGMetrics(
        query: String,
        response: String,
        context: String,
        sources: [KnowledgeSource]?,
        systemPrompt: String,
        modelName: String,
        latency: Int
    ) {
        // 空操作，安全丢弃
    }
}
