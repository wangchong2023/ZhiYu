//
//  MindmapSynthesisStrategy.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：思维导图 (Mindmap) 合成策略实现。
//
import Foundation

public struct MindmapSynthesisStrategy: SynthesisStrategyProtocol {
    public let type: SynthesisStore.SynthesisType = .mindmap

    public init() {}

    public func process(rawContent: String, sourceContent: String) -> String {
        let formatted = SynthesisProcessor.formatMermaid(rawContent, fallbackPrefix: "mindmap")
        if formatted.isEmpty || formatted.utf8.count < AppConstants.ExportLimits.minValidSynthesisTextBytes {
            Logger.shared.addLog(action: .ingest, target: type.title, details: "[SynthesisStatus: SelfHealed] Reason: InvalidMermaid")
            return generateFallback(from: sourceContent, title: L10n.AI.Prompt.Expert.Mindmap.title)
        }
        return formatted
    }

    public func generateFallback(from sourceContent: String, title: String) -> String {
        return SynthesisProcessor.convertMarkdownToListMindmap(sourceContent, title: title)
    }
}
