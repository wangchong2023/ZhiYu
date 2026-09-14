//
//  ReportSynthesisStrategy.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：深度报告 (Report) 合成策略实现。
//
import Foundation

public struct ReportSynthesisStrategy: SynthesisStrategyProtocol {
    public let type: SynthesisStore.SynthesisType = .report

    public init() {}

    public func process(rawContent: String, sourceContent: String) -> String {
        processWithByteValidation(
            rawContent: rawContent,
            sourceContent: sourceContent,
            selfHealReason: ProcessorConstants.Synthesis.selfHealReasonInsufficientReport,
            fallbackTitle: L10n.AI.Prompt.Expert.Report.title,
            extraValidation: { $0.contains(ProcessorConstants.MarkdownSyntax.hash) }
        )
    }

    public func generateFallback(from sourceContent: String, title: String) -> String {
        return SynthesisProcessor.generateFallbackReport(from: sourceContent, title: title)
    }
}
