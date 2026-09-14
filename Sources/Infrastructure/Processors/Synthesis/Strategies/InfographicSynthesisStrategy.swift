//
//  InfographicSynthesisStrategy.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：生成知识信息图 (Infographic) 合成策略实现。
//
import Foundation

public struct InfographicSynthesisStrategy: SynthesisStrategyProtocol {
    public let type: SynthesisStore.SynthesisType = .infographic

    public init() {}

    public func process(rawContent: String, sourceContent: String) -> String {
        processMermaidWithValidation(
            rawContent: rawContent,
            sourceContent: sourceContent,
            fallbackPrefix: ProcessorConstants.MermaidSyntax.graphTD,
            selfHealReason: ProcessorConstants.Synthesis.selfHealReasonInvalidInfographic,
            fallbackTitle: L10n.Knowledge.Page.AI.infographic
        )
    }

    public func generateFallback(from sourceContent: String, title: String) -> String {
        return SynthesisProcessor.generateFallbackInfographic(from: sourceContent, title: title)
    }
}
