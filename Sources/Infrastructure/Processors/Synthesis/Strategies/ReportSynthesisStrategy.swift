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
        let cleaned = SynthesisProcessor.cleanMarkdown(rawContent)
        if cleaned.utf8.count >= AppConstants.ExportLimits.minValidSynthesisTextBytes, cleaned.contains("#") {
            return cleaned
        }
        Logger.shared.addLog(action: .ingest, target: type.title, details: "[SynthesisStatus: SelfHealed] Reason: InsufficientReportContent")
        return generateFallback(from: sourceContent, title: L10n.AI.Prompt.Expert.Report.title)
    }

    public func generateFallback(from sourceContent: String, title: String) -> String {
        return SynthesisProcessor.generateFallbackReport(from: sourceContent, title: title)
    }
}
