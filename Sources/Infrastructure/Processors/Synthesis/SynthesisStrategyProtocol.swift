//
//  SynthesisStrategyProtocol.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：定义 AI 知识合成策略接口规范 (Strategy Pattern)。
//
import Foundation

/// 统一的 AI 合成策略接口协议
public protocol SynthesisStrategyProtocol: Sendable {
    /// 合成类型标识
    var type: SynthesisStore.SynthesisType { get }

    /// 处理 LLM 生成内容并进行格式清洗与纠错
    /// - Parameters:
    ///   - rawContent: LLM 返回的原始响应文本
    ///   - sourceContent: 上下文知识库源页面内容（用于自愈降级）
    /// - Returns: 处理完成的结构化 Markdown 或代码文本
    func process(rawContent: String, sourceContent: String) -> String

    /// 生成自愈兜底文档
    /// - Parameters:
    ///   - sourceContent: 源知识库页面拼接内容
    ///   - title: 缺省标题
    /// - Returns: 柔性降级生成的完整结构化文档
    func generateFallback(from sourceContent: String, title: String) -> String
}
