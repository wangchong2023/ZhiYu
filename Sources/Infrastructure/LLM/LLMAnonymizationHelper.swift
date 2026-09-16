//
//  LLMAnonymizationHelper.swift
//  ZhiYu
//
//  Created by CodeFree on 2026/09/14.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：集中端侧 NER 脱敏匿名化与还原逻辑，消除 ChatRunner/ChatLLMService 间的重复脱敏循环。
//

import Foundation

/// 端侧 NER 脱敏匿名化助手 (SR-12)
/// 封装 systemPrompt + query + history 的统一脱敏流程，返回匿名化数据包。
enum LLMAnonymizationHelper {
    /// 脱敏匿名化结果数据包
    struct AnonymizationResult {
        /// 匿名化后的系统提示词
        let anonSystemPrompt: String
        /// 匿名化后的用户查询
        let anonQuery: String
        /// 匿名化后的历史消息
        let anonHistory: [ChatMessageDTO]
        /// 累积的实体映射表（用于后续还原）
        let currentMapping: [String: String]
    }

    /// 对 systemPrompt、query 及 history 执行端侧 NER 脱敏匿名化
    /// - Parameters:
    ///   - systemPrompt: 原始系统提示词
    ///   - query: 原始用户查询
    ///   - history: 原始历史消息列表
    ///   - contextBuilder: 上下文构建器（提供 anonymize 能力）
    /// - Returns: 脱敏匿名化结果数据包
    static func anonymize(
        systemPrompt: String,
        query: String,
        history: [ChatMessageDTO],
        contextBuilder: LLMContextBuilder
    ) -> AnonymizationResult {
        // 🔒 端侧 NER 脱敏 (SR-12)
        let (anonSystemPrompt, mapping1) = contextBuilder.anonymize(systemPrompt)
        let (anonQuery, mapping2) = contextBuilder.anonymize(query, existingMapping: mapping1)

        var anonHistory: [ChatMessageDTO] = []
        var currentMapping = mapping2
        for msg in history {
            let (anonContent, nextMapping) = contextBuilder.anonymize(msg.content, existingMapping: currentMapping)
            currentMapping = nextMapping
            anonHistory.append(ChatMessageDTO(role: msg.role, content: anonContent))
        }

        return AnonymizationResult(
            anonSystemPrompt: anonSystemPrompt,
            anonQuery: anonQuery,
            anonHistory: anonHistory,
            currentMapping: currentMapping
        )
    }
}
