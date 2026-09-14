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
        Logger.shared.addLog(action: .ingest, target: type.title, details: selfHealReason)
        return generateFallback(from: sourceContent, title: fallbackTitle)
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
        Logger.shared.addLog(action: .ingest, target: type.title, details: selfHealReason)
        return generateFallback(from: sourceContent, title: fallbackTitle)
    }
}
