//
//  SlidesSynthesisStrategy.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：演示文稿 (Slides) 合成策略实现。
//
import Foundation

public struct SlidesSynthesisStrategy: SynthesisStrategyProtocol {
    public let type: SynthesisStore.SynthesisType = .slides

    public init() {}

    public func process(rawContent: String, sourceContent: String) -> String {
        let cleaned = SynthesisProcessor.cleanMarkdown(rawContent)
        if cleaned.utf8.count >= AppConstants.ExportLimits.minValidSynthesisTextBytes {
            return SynthesisProcessor.formatSlidesIfNeeded(cleaned, fallbackTitle: L10n.AI.Prompt.Expert.Slides.title)
        }
        Logger.shared.addLog(action: .ingest, target: type.title, details: "[SynthesisStatus: SelfHealed] Reason: InsufficientBytes")
        return generateFallback(from: sourceContent, title: L10n.AI.Prompt.Expert.Slides.title)
    }

    public func generateFallback(from sourceContent: String, title: String) -> String {
        return SynthesisProcessor.generateFallbackPresentation(from: sourceContent, title: title)
    }
}
