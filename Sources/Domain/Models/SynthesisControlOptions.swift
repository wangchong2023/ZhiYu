//
//  SynthesisControlOptions.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层
//  核心职责：定义合成前的生成控制维度模型（篇幅深度、目标受众、语气风格）。
//
import Foundation

/// 合成前控制维度配置
public struct SynthesisControlOptions: Sendable, Equatable {
    /// 篇幅深度
    public enum Depth: String, CaseIterable, Sendable {
        case concise
        case standard
        case detailed
    }

    /// 目标受众
    public enum Audience: String, CaseIterable, Sendable {
        case beginner
        case professional
        case executive
    }

    /// 语气风格
    public enum Tone: String, CaseIterable, Sendable {
        case academic
        case professional
        case casual
    }

    public var depth: Depth
    public var audience: Audience
    public var tone: Tone
    public var customPrompt: String

    public init(
        depth: Depth = .standard,
        audience: Audience = .professional,
        tone: Tone = .professional,
        customPrompt: String = ""
    ) {
        self.depth = depth
        self.audience = audience
        self.tone = tone
        self.customPrompt = customPrompt
    }
}
