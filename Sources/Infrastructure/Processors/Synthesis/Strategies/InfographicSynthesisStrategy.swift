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
        let formatted = SynthesisProcessor.formatMermaid(rawContent, fallbackPrefix: "graph TD")
        if formatted.isEmpty || formatted.utf8.count < AppConstants.ExportLimits.minValidSynthesisTextBytes {
            Logger.shared.addLog(action: .ingest, target: type.title, details: "[SynthesisStatus: SelfHealed] Reason: InvalidInfographicMermaid")
            return generateFallback(from: sourceContent, title: L10n.Knowledge.Page.AI.infographic)
        }
        return formatted
    }

    public func generateFallback(from sourceContent: String, title: String) -> String {
        return SynthesisProcessor.generateFallbackInfographic(from: sourceContent, title: title)
    }
}
