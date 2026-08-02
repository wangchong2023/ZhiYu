//
//  SynthesisStrategyFactory.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：AI 知识合成策略简单工厂 (Strategy Pattern Factory)。
//
import Foundation

public enum SynthesisStrategyFactory {
    /// 根据合成类型派发对应的策略实例
    /// - Parameter type: 合成类型
    /// - Returns: 遵循 SynthesisStrategyProtocol 的策略处理器
    public static func strategy(for type: SynthesisStore.SynthesisType) -> any SynthesisStrategyProtocol {
        switch type {
        case .mindmap:
            return MindmapSynthesisStrategy()
        case .slides:
            return SlidesSynthesisStrategy()
        case .quiz:
            return QuizSynthesisStrategy()
        case .report:
            return ReportSynthesisStrategy()
        case .infographic:
            return InfographicSynthesisStrategy()
        case .expansion:
            return ExpansionSynthesisStrategy()
        }
    }
}
