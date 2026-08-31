//
//  ModelLabView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/12.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：大模型多用例测试实验室主容器视图，负责状态持有、用例格栅与沙盒面板的分发组合，
//  以及配置弹窗与拦截遮罩的统一挂载。各功能子视图已拆分至 View/Sections/ 目录下的独立文件。
//

import SwiftUI
import Dependencies

/// 大模型测试实验室主视图
@MainActor
public struct ModelLabView: View {

    // MARK: - 环境与外部依赖

    @State var modelManager = GlobalModelManager.shared
    @State var labManager = ModelLabManager()
    @Environment(ThemeManager.self) private var themeManager
    @Dependency(\.toastService) var toastManager

    /// 当需要跳回商店时的外部闭包回调
    public var onGoToStore: () -> Void

    // MARK: - 局部交互状态

    @FocusState var isPromptFocused: Bool
    @State var testPrompt: String = ""
    /// Bug #73 修复：标记是否已为当前用例设置过默认 prompt，避免 onAppear 重复触发时覆盖用户输入。
    @State var hasSetupPrompt: Set<String> = []
    @State var tempTemperature: Double = FeatureConstants.InferenceParam.defaultTemperature
    @State var tempTopP: Double = FeatureConstants.InferenceParam.defaultTopP
    @State var tempTopK: Int = FeatureConstants.InferenceParam.defaultTopK
    @State var tempMaxTokens: Int = FeatureConstants.InferenceParam.defaultMaxTokens

    // 参数配置面板
    @State var showConfigSheet: Bool = false
    @State var useGPU: Bool = false
    @State var enableThinking: Bool = false
    @State var enableSpeculativeDecoding: Bool = false

    @State var selectedConfigTab: Int = 0
    @State var systemPromptText: String = L10n.ModelManager.Lab.defaultSystemPrompt

    /// Bug #115 修复：存储 runSimulation Task 引用，视图销毁时取消避免泄漏
    @State var simulationTask: Task<Void, Never>?

    var matchedPreset: ParameterPreset? {
        for p in ParameterPreset.allCases {
            let v = p.parameters
            if abs(tempTemperature - v.temperature) < FeatureConstants.InferenceParam.presetMatchTolerance,
               abs(tempTopP - v.topP) < FeatureConstants.InferenceParam.presetMatchTolerance,
               tempTopK == v.topK,
               tempMaxTokens == v.maxTokens { return p }
        }
        return nil
    }

    var isCustomMode: Bool { matchedPreset == nil }

    // 多模态/视觉特定状态
    @State var isImageSelected: Bool = false

    // 语音速记特定状态
    @State var isAudioRecording: Bool = false
    @State var isAudioCompleted: Bool = false

    // 多轮对话特定状态
    @State var chatHistory: [LabChatMessage] = []
    @State var chatInputText: String = ""

    // MARK: - 布局网格

    let columns = [
        GridItem(.adaptive(minimum: DesignSystem.Vault.gridCardMin, maximum: DesignSystem.Vault.gridCardMax), spacing: DesignSystem.medium)
    ]

    /// 是否需要外层 ScrollView 包装，用于扁平化整合单页滚动
    public var embedInScrollView: Bool = true

    public init(embedInScrollView: Bool = true, onGoToStore: @escaping () -> Void) {
        self.embedInScrollView = embedInScrollView
        self.onGoToStore = onGoToStore
    }

    public var body: some View {
        ZStack {
            if embedInScrollView {
                ScrollView {
                    contentStack
                }
            } else {
                contentStack
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: labManager.selectedUseCase)
        .sheet(isPresented: $showConfigSheet) {
            configurationSheet
        }
        .fullScreenCover(item: $labManager.selectedUseCase) { useCase in
            useCaseDetailPanel(for: useCase)
        }
        .onChange(of: tempTemperature) { _, _ in autoSave() }
        .onChange(of: tempTopP) { _, _ in autoSave() }
        .onChange(of: tempTopK) { _, _ in autoSave() }
        .onChange(of: tempMaxTokens) { _, _ in autoSave() }
        .onAppear {
            if let activeModel = getActiveModel() {
                loadParametersForModel(activeModel.modelId)
            }
        }
        .onChange(of: modelManager.activeModelId) { _, newModelId in
            loadParametersForModel(newModelId)
        }
    }

    @ViewBuilder
    private var contentStack: some View {
        VStack(spacing: DesignSystem.large) {
            if !hasActiveLocalModel() {
                // 如果没有激活的模型，直接在局域展示未激活提示卡，不阻拦上方的商店
                noModelMaskView
            } else {
                // 展示格栅主页
                labHeaderView
                useCaseGridView
            }
        }
        .padding(DesignSystem.medium)
    }
}
