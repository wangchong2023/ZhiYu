//
//  ParameterPreset.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/12.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：定义大模型推理参数预设模板（创意/均衡/精准），封装各预设的温温度、Top-P、Top-K、
//  MaxTokens 默认值以及对应的展示名称与 SF Symbol 图标。
//

import Foundation

/// 推理参数预设模板
enum ParameterPreset: String, CaseIterable {
    case balanced
    case creative
    case precise

    var displayName: String {
        switch self {
        case .creative:
            return L10n.ModelManager.Parameters.presetCreative
        case .balanced:
            return L10n.ModelManager.Parameters.presetBalanced
        case .precise:
            return L10n.ModelManager.Parameters.presetPrecise
        }
    }

    var icon: String {
        switch self {
        case .creative:
            return "paintbrush.fill"
        case .balanced:
            return "scale.3d"
        case .precise:
            return "target"
        }
    }

    struct InferenceParams {
        var temperature: Double
        var topP: Double
        var topK: Int
        var maxTokens: Int
    }

    private enum PresetValues {
        static let creativeTemperature: Double = 1.2
        static let creativeTopP: Double = 0.95
        static let creativeTopK: Int = 50
        static let creativeMaxTokens: Int = 2048

        static let balancedTemperature: Double = 0.7
        static let balancedTopP: Double = 0.9
        static let balancedTopK: Int = 40
        static let balancedMaxTokens: Int = 2048

        static let preciseTemperature: Double = 0.3
        static let preciseTopP: Double = 0.85
        static let preciseTopK: Int = 20
        static let preciseMaxTokens: Int = 1024
    }

    var parameters: InferenceParams {
        switch self {
        case .creative:
            return InferenceParams(
                temperature: PresetValues.creativeTemperature,
                topP: PresetValues.creativeTopP,
                topK: PresetValues.creativeTopK,
                maxTokens: PresetValues.creativeMaxTokens
            )
        case .balanced:
            return InferenceParams(
                temperature: PresetValues.balancedTemperature,
                topP: PresetValues.balancedTopP,
                topK: PresetValues.balancedTopK,
                maxTokens: PresetValues.balancedMaxTokens
            )
        case .precise:
            return InferenceParams(
                temperature: PresetValues.preciseTemperature,
                topP: PresetValues.preciseTopP,
                topK: PresetValues.preciseTopK,
                maxTokens: PresetValues.preciseMaxTokens
            )
        }
    }
}
