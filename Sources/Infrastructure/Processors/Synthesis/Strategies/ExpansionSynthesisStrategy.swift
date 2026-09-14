//
//  ExpansionSynthesisStrategy.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：知识深度扩写 (Expansion) 合成策略实现。
//
import Foundation

public struct ExpansionSynthesisStrategy: SynthesisStrategyProtocol {
    public let type: SynthesisStore.SynthesisType = .expansion

    public init() {}

    public func process(rawContent: String, sourceContent: String) -> String {
        processWithByteValidation(
            rawContent: rawContent,
            sourceContent: sourceContent,
            selfHealReason: ProcessorConstants.Synthesis.selfHealReasonInsufficientExpansion,
            fallbackTitle: L10n.AI.Prompt.Expert.Expansion.title
        )
    }

    public func generateFallback(from sourceContent: String, title: String) -> String {
        return SynthesisProcessor.generateFallbackExpansion(from: sourceContent, title: title)
    }
}
