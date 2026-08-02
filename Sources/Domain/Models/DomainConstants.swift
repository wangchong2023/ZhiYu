//
//  DomainConstants.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层
//  核心职责：领域业务规则与算法常量的统一命名空间路由 (Domain Constants)。
//           具体物理定义已彻底解耦归位至 PromptConstants、GraphConstants 与 SearchConstants。
//

import Foundation

/// 领域业务规则与常量路由网关 (Domain Layer Constants)
public enum DomainConstants {
    
    // MARK: - AI & Prompt 领域常量 (转接至 PromptConstants)
    public struct AI {
        public static var charactersPerToken: Int { PromptConstants.TokenLimits.charactersPerToken }
        public static var maxChatHistorySize: Int { PromptConstants.TokenLimits.maxChatHistorySize }
        public static var maxUserInputLength: Int { PromptConstants.TokenLimits.maxUserInputLength }
        public static var maxSynthesisInputLength: Int { PromptConstants.TokenLimits.maxSynthesisInputLength }
        public static var maxOutputTokens: Int { PromptConstants.TokenLimits.defaultMaxOutputTokens }
        public static var defaultTextModel: String { PromptConstants.InferenceDefaults.defaultTextModel }
        public static var defaultEmbeddingModel: String { PromptConstants.InferenceDefaults.defaultEmbeddingModel }

        public typealias SynthesisControl = PromptConstants.SynthesisWordCount
    }
    
    // MARK: - RAG & 提示词策略 (转接至 PromptConstants / SearchConstants)
    public struct RAG {
        public static var maxEntityOverview: Int { PromptConstants.RAGPrompt.maxEntityOverview }
        public static var maxConceptOverview: Int { PromptConstants.RAGPrompt.maxConceptOverview }
        public static var maxSourceOverview: Int { PromptConstants.RAGPrompt.maxSourceOverview }
        public static var maxRecentOverview: Int { PromptConstants.RAGPrompt.maxRecentOverview }
        public static var contentPreviewLength: Int { PromptConstants.RAGPrompt.contentPreviewLength }
        public static var maxContextPages: Int { PromptConstants.RAGPrompt.maxContextPages }
        public static var contextPreviewLength: Int { PromptConstants.RAGPrompt.contextPreviewLength }

        // 检索参数转接至 SearchConstants
        public static var rrfK: Int { SearchConstants.rrfK }
        public static var semanticThresholdShort: Float { SearchConstants.semanticThresholdShort }
        public static var semanticThresholdLong: Float { SearchConstants.semanticThresholdLong }
        public static var semanticShortHighConfidence: Float { SearchConstants.semanticShortHighConfidence }
        public static var shortQueryThreshold: Int { SearchConstants.shortQueryThreshold }
    }

    // MARK: - 图谱物理仿真与布局 (转接至 GraphConstants)
    public typealias Graph = GraphConstants
}
