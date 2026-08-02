//
//  QuizSynthesisStrategy.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：知识测验 (Quiz) 合成策略实现。
//
import Foundation

public struct QuizSynthesisStrategy: SynthesisStrategyProtocol {
    public let type: SynthesisStore.SynthesisType = .quiz

    public init() {}

    public func process(rawContent: String, sourceContent: String) -> String {
        if QuizProcessor.canDecodeAsQuizModel(rawContent) {
            return rawContent
        }

        if let formatted = QuizProcessor.convertJSONToMarkdown(rawContent) {
            return formatted
        }

        if rawContent.utf8.count >= AppConstants.ExportLimits.minValidSynthesisTextBytes {
            return rawContent
        }

        Logger.shared.addLog(action: .ingest, target: type.title, details: "[SynthesisStatus: SelfHealed] Reason: InvalidQuizJSON")
        return generateFallback(from: sourceContent, title: L10n.AI.Prompt.Quiz.defaultTitle)
    }

    public func generateFallback(from sourceContent: String, title: String) -> String {
        return SynthesisProcessor.generateFallbackQuiz(from: sourceContent, title: title)
    }
}
