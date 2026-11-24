//
//  ModelLabLogic.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/12.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：实验室模型管理与推理参数持久化的逻辑辅助方法 —— 活跃模型检测、参数预设应用、
//  按模型 ID 加载/自动保存推理参数配置。
//

import SwiftUI
import UFPDesignSystem

// MARK: - 逻辑辅助

extension ModelLabView {

    func hasActiveLocalModel() -> Bool {
        // 白名单中任何一个模型在本地就绪，代表可以进入实验室
        for manifest in modelManager.remoteManifests where modelManager.isModelLocalReady(for: manifest.modelId) {
            return true
        }
        return false
    }

    func getActiveModel() -> LLMManifest? {
        let activeId = modelManager.activeModelId
        if let model = modelManager.remoteManifests.first(where: { $0.modelId == activeId }) {
            return model
        }
        // Fallback: 找第一个本地就绪的
        for manifest in modelManager.remoteManifests where modelManager.isModelLocalReady(for: manifest.modelId) {
            return manifest
        }
        return modelManager.remoteManifests.first
    }

    func applyPreset(_ preset: ParameterPreset) {
        let params = preset.parameters
        withAnimation(.easeInOut(duration: DesignTokens.Animations.springResponse)) {
            tempTemperature = params.temperature
            tempTopP = params.topP
            tempTopK = params.topK
            tempMaxTokens = params.maxTokens
        }
        HapticFeedback.shared.trigger(.success)
        autoSave()
    }

    func loadParametersForModel(_ modelId: String) {
        if let config = InferenceParametersStore.shared.loadParameters(for: modelId) {
            withAnimation(.easeInOut(duration: DesignTokens.Animations.springResponse)) {
                tempTemperature = config.temperature
                tempTopP = config.topP
                tempTopK = config.topK
                tempMaxTokens = config.maxTokens
            }
        } else {
            applyPreset(.balanced)
        }
    }

    func autoSave() {
        let activeId = getActiveModel()?.modelId ?? modelManager.activeModelId
        let config = InferenceParametersConfig(
            modelId: activeId,
            presetName: matchedPreset?.rawValue ?? "custom",
            temperature: tempTemperature,
            topP: tempTopP,
            topK: tempTopK,
            maxTokens: tempMaxTokens
        )
        InferenceParametersStore.shared.saveParameters(config)
        HapticFeedback.shared.trigger(.success)
    }
}
