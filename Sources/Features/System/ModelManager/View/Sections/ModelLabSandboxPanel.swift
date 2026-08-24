//
//  ModelLabSandboxPanel.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/12.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：实验室沙盒面板的顶部导航栏（返回、模型选择、配置入口）与通用单轮沙盒交互视图
//  （Prompt 编辑、运行控制按键），按用例类型分发特殊输入源组件。
//

import SwiftUI

// MARK: - 沙盒面板

extension ModelLabView {

    // MARK: - 实验室专属沙盒交互面板

    func useCaseDetailPanel(for useCase: UseCaseType) -> some View {
        NavigationStack {
            ZStack {
                // 配色与系统保持一致，背景铺满全屏，强制忽略所有安全区
                PageBackgroundView(accentColor: .appAccent)
                    .ignoresSafeArea(.all)

                VStack(spacing: DesignSystem.medium) {
                    if useCase == .aiChat {
                        aiChatSandboxView
                    } else {
                        // 使用 ScrollView 包裹标准交互沙盒，防止多参数导致内容溢出挤压安全区
                        ScrollView(.vertical, showsIndicators: false) {
                            standardSandboxView(for: useCase)
                                .padding(.vertical, SystemSpacing.atomic)
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.medium)
                .padding(.bottom, SystemSpacing.element)
            }
            .navigationTitle(useCase.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Common.done) {
                        HapticFeedback.shared.trigger(.selection)
                        labManager.stopSimulation()
                        labManager.selectedUseCase = nil
                    }
                    .bold()
                }
            }
        }
        .ignoresSafeArea(.keyboard) // 仅忽略键盘，不忽略容器安全区
    }

    /// 实验室沙盒面板的模型选择下拉菜单视图，仅列出本地已下载就绪的模型
    /// - Parameter useCase: 当前使用的用例类型
    /// - Returns: 模型选择的 Menu 下拉视图
    func modelSelectionMenu(for useCase: UseCaseType) -> some View {
        Menu {
            Picker("", selection: Binding(
                get: { getActiveModel()?.modelId ?? modelManager.activeModelId },
                set: { newId in
                    HapticFeedback.shared.trigger(.selection)
                    modelManager.activeModelId = newId
                    loadParametersForModel(newId)
                }
            )) {
                ForEach(modelManager.remoteManifests.filter { modelManager.isModelLocalReady(for: $0.modelId) }) { model in
                    Text(model.displayName).tag(model.modelId)
                }
            }
        } label: {
            HStack(spacing: SystemSpacing.tiny) {
                Text(getActiveModel()?.displayName ?? useCase.title)
                    .font(.headline)
                    .foregroundStyle(.appText)
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.cyan)
            }
            .padding(.horizontal, SystemSpacing.medium)
            .padding(.vertical, SystemSpacing.small)
            .background(Color.appCard.opacity(DesignSystem.Opacity.dim))
            .clipShape(Capsule())
        }
    }

    /// 设置特定用例场景的初始预设 prompt
    func setupDefaultPrompt(for useCase: UseCaseType) {
        switch useCase {
        case .askImage:
            testPrompt = L10n.ModelManager.Lab.Prompt.askImage
        case .aiChat:
            testPrompt = L10n.ModelManager.Lab.Prompt.chat
        case .agentSkills:
            testPrompt = L10n.ModelManager.Lab.Prompt.agentSkills
        case .promptLab:
            testPrompt = L10n.ModelManager.Lab.Prompt.promptLab
        case .tinyGarden:
            testPrompt = L10n.ModelManager.Lab.Prompt.tinyGarden
        case .mobileActions:
            testPrompt = L10n.ModelManager.Lab.Prompt.mobileActions
        default:
            testPrompt = ""
        }
    }

    /// 通用 Prompt 文本域（如适用）
    @ViewBuilder
    func promptEditorView(for useCase: UseCaseType) -> some View {
        if useCase != .audioScribe {
            TextEditor(text: $testPrompt)
                .focused($isPromptFocused)
                .padding(DesignSystem.standardPadding)
                .frame(height: ComponentSpacing.colossal)
                .background(Color.theme.white.opacity(DesignSystem.Opacity.ghost))
                .cornerRadius(SystemRadius.small)
                .overlay(
                    RoundedRectangle(cornerRadius: SystemRadius.small)
                        .stroke(
                            isPromptFocused ?
                            LinearGradient(colors: [.cyan, .purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing) :
                            LinearGradient(colors: [Color.theme.white.opacity(DesignSystem.Opacity.glass)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: isPromptFocused ? 1.5 : 1.0
                        )
                )
                .shadow(color: isPromptFocused ? .cyan.opacity(DesignSystem.disabledOpacity) : .clear, radius: isPromptFocused ? 6 : 0, x: 0, y: 0)
                .overlay(
                    Group {
                        if testPrompt.isEmpty {
                            Text(L10n.ModelManager.Lab.placeholderInput)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, DesignSystem.standardPadding + 4)
                                .padding(.vertical, DesignSystem.standardPadding + 4)
                        }
                    },
                    alignment: .topLeading
                )
                .font(.body)
                .foregroundStyle(Color.theme.text)
        }
    }

    /// 运行控制按键组件
    @ViewBuilder
    func controlButton(for useCase: UseCaseType) -> some View {
        if labManager.isGenerating {
            Button(action: {
                labManager.stopSimulation()
            }) {
                Text(L10n.ModelManager.Lab.stopInference)
                    .padding(.horizontal, DesignSystem.large - 8)
                    .padding(.vertical, DesignSystem.standardPadding + 2)
                    .background(Color.theme.red.opacity(DesignSystem.Opacity.shadow))
                    .foregroundStyle(Color.theme.red)
                    .cornerRadius(SystemRadius.small)
            }
        } else {
            Button(action: {
                Task {
                    guard let model = getActiveModel() else { return }
                    HapticFeedback.shared.trigger(.selection)
                    await labManager.runSimulation(for: useCase, model: model, prompt: testPrompt)
                }
            }) {
                Text(L10n.ModelManager.Lab.runTest)
                    .bold()
                    .padding(.horizontal, DesignSystem.large - 4)
                    .padding(.vertical, DesignSystem.standardPadding + 2)
                    .background(
                        LinearGradient(
                            colors: [Color.theme.cyan, Color.theme.blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundStyle(Color.theme.white)
                    .cornerRadius(SystemRadius.small)
                    .shadow(color: Color.theme.cyan.opacity(DesignSystem.Opacity.shadow), radius: DesignSystem.shadowRadius)
            }
            .disabled(testPrompt.isEmpty && useCase != .audioScribe)
            .opacity((testPrompt.isEmpty && useCase != .audioScribe) ? DesignSystem.Opacity.soft : DesignSystem.Opacity.solid)
        }
    }

    /// 大模型选择与配置控制栏组件，供实验室各测试面板使用
    func modelAndConfigControlBar(for useCase: UseCaseType) -> some View {
        HStack {
            modelSelectionMenu(for: useCase)
            
            Spacer()
            
            Button(action: {
                HapticFeedback.shared.trigger(.selection)
                showConfigSheet = true
            }) {
                HStack(spacing: SystemSpacing.tiny) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.caption)
                    Text(L10n.ModelManager.parametersTitle)
                        .font(.caption)
                }
                .foregroundStyle(.cyan)
                .padding(.horizontal, SystemSpacing.medium)
                .padding(.vertical, SystemSpacing.small)
                .background(Color.appCard.opacity(DesignSystem.Opacity.dim))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    /// 单轮沙盒交互测试视图
    @ViewBuilder
    func standardSandboxView(for useCase: UseCaseType) -> some View {
        VStack(spacing: DesignSystem.medium) {
            // 大模型选择与参数配置栏
            modelAndConfigControlBar(for: useCase)

            // 实时性能评估看板
            metricsMonitorBoard

            // 核心功能测试交互区
            VStack(alignment: .leading, spacing: DesignSystem.medium) {
                Text(L10n.ModelManager.Lab.configureInputs)
                    .font(.subheadline.bold())
                    .foregroundStyle(.appText)

                // 根据用例分发特殊输入源组件
                switch useCase {
                case .askImage:
                    askImageInputs
                case .audioScribe:
                    audioScribeInputs
                case .promptLab:
                    promptLabSliders
                default:
                    EmptyView()
                }

                promptEditorView(for: useCase)

                HStack {
                    Spacer()
                    controlButton(for: useCase)
                }
            }
            .padding(DesignSystem.medium)
            .background(Color.appCard.opacity(DesignSystem.Opacity.dim))
            .cornerRadius(DesignSystem.mediumRadius)

            // 推理流输出展示板
            outputScribeBoard
        }
        .id(useCase.rawValue)
        .onAppear {
            setupDefaultPrompt(for: useCase)
        }
    }
}
