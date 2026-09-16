//
//  SynthesisStrategyBase.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/14.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：AI 知识合成策略公共默认实现（消除 6 个 Strategy 的 process/generateFallback 模板重复）。
//
import Foundation

// MARK: - 合成策略公共默认实现

/// 为基于 Markdown 清洗 + 字节数校验 + 兜底降级的策略提供公共 `process` 默认实现。
/// 子类型只需提供 `type`、`fallbackTitle`、`generateFallback` 即可获得标准化的 process 行为。
public extension SynthesisStrategyProtocol {

    /// 标准 process 流程：清洗 Markdown → 校验字节数 → 不足则记录自愈日志并降级。
    /// - Parameters:
    ///   - rawContent: LLM 返回的原始响应文本
    ///   - sourceContent: 上下文知识库源页面内容
    ///   - selfHealReason: 自愈日志原因描述
    ///   - fallbackTitle: 兜底标题
    /// - Returns: 处理完成的结构化文本
    func processWithByteValidation(
        rawContent: String,
        sourceContent: String,
        selfHealReason: String,
        fallbackTitle: String
    ) -> String {
        let cleaned = SynthesisProcessor.cleanMarkdown(rawContent)
        if cleaned.utf8.count >= AppConstants.ExportLimits.minValidSynthesisTextBytes {
            return cleaned
        }
        return logAndFallback(selfHealReason: selfHealReason, sourceContent: sourceContent, fallbackTitle: fallbackTitle)
    }

    /// 标准 process 流程（含额外内容校验）：清洗 Markdown → 校验字节数与额外条件 → 不足则降级。
    /// - Parameters:
    ///   - rawContent: LLM 返回的原始响应文本
    ///   - sourceContent: 上下文知识库源页面内容
    ///   - selfHealReason: 自愈日志原因描述
    ///   - fallbackTitle: 兜底标题
    ///   - extraValidation: 额外的有效性校验闭包（返回 false 触发降级）
    /// - Returns: 处理完成的结构化文本
    func processWithByteValidation(
        rawContent: String,
        sourceContent: String,
        selfHealReason: String,
        fallbackTitle: String,
        extraValidation: (String) -> Bool
    ) -> String {
        let cleaned = SynthesisProcessor.cleanMarkdown(rawContent)
        if cleaned.utf8.count >= AppConstants.ExportLimits.minValidSynthesisTextBytes, extraValidation(cleaned) {
            return cleaned
        }
        return logAndFallback(selfHealReason: selfHealReason, sourceContent: sourceContent, fallbackTitle: fallbackTitle)
    }

    /// Mermaid 专用 process 流程：格式化 Mermaid → 校验非空与字节数 → 不足则降级。
    /// 消除 InfographicSynthesisStrategy / MindmapSynthesisStrategy 两处重复的 formatMermaid + isEmpty + utf8.count + Logger + fallback 链。
    /// - Parameters:
    ///   - rawContent: LLM 返回的原始响应文本
    ///   - sourceContent: 上下文知识库源页面内容
    ///   - fallbackPrefix: Mermaid 语法前缀（如 graphTD / mindmap）
    ///   - selfHealReason: 自愈日志原因描述
    ///   - fallbackTitle: 兜底标题
    /// - Returns: 处理完成的 Mermaid 文本
    func processMermaidWithValidation(
        rawContent: String,
        sourceContent: String,
        fallbackPrefix: String,
        selfHealReason: String,
        fallbackTitle: String
    ) -> String {
        let formatted = SynthesisProcessor.formatMermaid(rawContent, fallbackPrefix: fallbackPrefix)
        if !formatted.isEmpty, formatted.utf8.count >= AppConstants.ExportLimits.minValidSynthesisTextBytes {
            return formatted
        }
        return logAndFallback(selfHealReason: selfHealReason, sourceContent: sourceContent, fallbackTitle: fallbackTitle)
    }

    /// 统一的自愈日志 + 兜底降级辅助，消除三处 process 方法尾部重复的 Logger + generateFallback 链。
    /// - Parameters:
    ///   - selfHealReason: 自愈日志原因描述
    ///   - sourceContent: 上下文知识库源页面内容
    ///   - fallbackTitle: 兜底标题
    /// - Returns: 兜底生成的结构化文本
    private func logAndFallback(selfHealReason: String, sourceContent: String, fallbackTitle: String) -> String {
        Logger.shared.addLog(action: .ingest, target: type.title, details: selfHealReason)
        return generateFallback(from: sourceContent, title: fallbackTitle)
    }
}
