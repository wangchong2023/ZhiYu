//
//  OnDeviceLLMSettingsView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：构建 OnDeviceLLMSettings 界面的 UI 视图层组件。
//
import SwiftUI
import UniformTypeIdentifiers

// MARK: - On-Device LLM Settings View
/// 设备端本地大模型配置面板视图
/// 用户可在该控制中心查看端侧 AI 可用性、检索并一键加载内置/外置 Core ML 语言模型、执行端侧推理基准测试（Playground），全面掌握离线隐私知识图谱的合成效率。
@MainActor
public struct OnDeviceLLMSettingsView: View {
    /// 独立托管的端侧推理及编译生命周期服务
    @StateObject private var onDeviceService = OnDeviceLLMService()
    
    /// 全局应用级数据 Store
    @Environment(AppStore.self) var store
    
    /// 全局主题美学管理器，驱动毛玻璃材质投影
    @Environment(ThemeManager.self) var themeManager
    
    /// 兼容引入全局云端 LLM 服务，便于后续做端云混合调度
    @EnvironmentObject var llmService: LLMService
    
    /// Haptic 触感生成器
    @State private var feedbackGenerator = UINotificationFeedbackGenerator()
    
    /// 对话测试沙盒 Prompt
    @State private var testPrompt = ""
    
    /// 对话推理生成的结果缓存
    @State private var testResult = ""
    
    /// 是否弹出文件导入器选择本地模型
    @State private var showImportPicker = false
    
    /// 是否弹出 Playground 测试调试 Sheet
    @State private var showTestSheet = false
    
    /// 是否弹出错误弹窗
    @State private var showError = false
    
    /// 具体的错误描述文字
    @State private var errorMessage = ""

    public init() {}

    public var body: some View {
        ZStack {
            // 背景统一使用主题管理器驱动的通透背景，透射毛玻璃
            themeManager.pageBackground()
                .ignoresSafeArea()
            
            Form {
                // HERO 标头区域
                Section {
                    headerSection
                }
                .appListRowBackground()
                
                // 1. 可用性与硬件检测区域
                Section(header: Text(L10n.AI.OnDevice.available)) {
                    availabilitySection
                }
                .appListRowBackground()
                
                // 2. 本地可用模型选型列表
                Section(header: Text(L10n.AI.OnDevice.models)) {
                    modelSelectionSection
                }
                .appListRowBackground()
                
                // 3. 模型生命周期装载/卸载与文件导入
                Section(header: Text(L10n.AI.OnDevice.loadModel)) {
                    modelManagementSection
                }
                .appListRowBackground()
                
                // 4. 离线基准性能测试 Playground
                Section(header: Text(L10n.AI.OnDevice.test)) {
                    testSection
                }
                .appListRowBackground()
                
                // 5. 离线隐私与安全声明
                Section(header: Text(L10n.AI.OnDevice.info)) {
                    infoSection
                }
                .appListRowBackground()
            }
            .insetGroupedListStyleIfIOS()
            .scrollContentBackground(.hidden) // 隐藏 Form 默认的白色背景，实现高端毛玻璃穿透
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationTitle(L10n.Settings.onDeviceLLM)
.appNavigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showTestSheet) {
            OnDeviceTestView(onDeviceService: onDeviceService)
        }
        .alert(L10n.AI.OnDevice.Error.inferenceFailed, isPresented: $showError) {
            Button(L10n.Common.ok, role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            onDeviceService.discoverModels()
        }
    }
    
    // MARK: - Hero Header
    private var headerSection: some View {
        VStack(spacing: DesignSystem.medium) {
            Spacer(minLength: 4)
            Image(systemName: "cpu")
                .font(.system(size: DesignSystem.displayFontSize * 1.3))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.appSource, .appAccent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.appAccent.opacity(DesignSystem.Opacity.shadow), radius: 8, y: 4)
            
            Text(L10n.AI.OnDevice.subtitle)
                .font(.subheadline)
                .foregroundStyle(.appSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer(minLength: 4)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, DesignSystem.small)
    }
    
    // MARK: - 可用性与硬件参数视图
    private var availabilitySection: some View {
        HStack(spacing: 14) {
            Image(systemName: onDeviceService.isAvailable ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(onDeviceService.isAvailable ? .green : .red)
            
            VStack(alignment: .leading, spacing: DesignSystem.tiny) {
                Text(onDeviceService.isAvailable ? L10n.AI.OnDevice.available : L10n.AI.OnDevice.unavailable)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.appText)
                
                if onDeviceService.isAvailable {
                    if #available(iOS 18.2, *) {
                        Text(L10n.AI.OnDevice.supportsFoundation)
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        Text(L10n.AI.OnDevice.supportsCoreML)
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                } else {
                    Text(L10n.AI.OnDevice.requiresIOS17)
                        .font(.caption)
                        .foregroundStyle(.appSecondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, DesignSystem.tiny)
    }
    
    // MARK: - 模型选型列表
    private var modelSelectionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if onDeviceService.availableModels.isEmpty {
                VStack(spacing: DesignSystem.small) {
                    Image(systemName: "square.dashed")
                        .font(.title3)
                        .foregroundStyle(.appSecondary)
                    Text(L10n.AI.OnDevice.noModels)
                        .font(.caption)
                        .foregroundStyle(.appSecondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
            } else {
                ForEach(onDeviceService.availableModels) { model in
                    OnDeviceModelRow(
                        model: model,
                        isSelected: onDeviceService.selectedModelID == model.id,
                        onSelect: {
                            onDeviceService.selectedModelID = model.id
                            feedbackGenerator.notificationOccurred(.success)
                        }
                    )
                }
            }
        }
        .padding(.vertical, DesignSystem.tiny)
    }
    
    // MARK: - 加载/卸载/管理模型
    private var modelManagementSection: some View {
        VStack(spacing: DesignSystem.medium) {
            if onDeviceService.isModelLoaded {
                HStack(spacing: DesignSystem.medium) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: DesignSystem.atomic) {
                        Text(L10n.AI.OnDevice.modelLoaded)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.appText)
                        Text(onDeviceService.loadedModelName)
                            .font(.caption)
                            .foregroundStyle(.appSecondary)
                    }
                    Spacer()
                    
                    Button(action: {
                        onDeviceService.unloadModel()
                        feedbackGenerator.notificationOccurred(.warning)
                    }) {
                        Text(L10n.AI.OnDevice.unload)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 10)
                            .padding(.vertical, DesignSystem.tightPadding)
                            .background(Color.theme.red.opacity(DesignSystem.Opacity.subtle))
                            .clipShape(Capsule())
                    }
                }
                .padding()
                .background(Color.appAccent.opacity(DesignSystem.Opacity.ghost))
                .clipShape(RoundedRectangle(cornerRadius: Spacing.cardRadius))
            } else {
                Button(action: loadModel) {
                    HStack(spacing: DesignSystem.small) {
                        if onDeviceService.isGenerating {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "arrow.down.circle.fill")
                        }
                        Text(L10n.AI.OnDevice.loadModel)
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.medium)
                    .background(onDeviceService.selectedModelID.isEmpty ? Color.theme.gray : Color.appAccent)
                    .clipShape(RoundedRectangle(cornerRadius: Spacing.cardRadius))
                }
                .disabled(onDeviceService.selectedModelID.isEmpty || onDeviceService.isGenerating)
            }
            
            // 物理模型本地导入入口
            Button(action: { showImportPicker = true }) {
                HStack(spacing: DesignSystem.small) {
                    Image(systemName: DesignSystem.Icons.importIcon)
                    Text(L10n.AI.OnDevice.importModel)
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.appAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(Color.appAccent.opacity(DesignSystem.Opacity.subtle))
                .clipShape(RoundedRectangle(cornerRadius: Spacing.cardRadius))
            }
            .skipOnWatch { $0.fileImporter(
                isPresented: $showImportPicker,
                allowedContentTypes: {
                    var types: [UTType] = []
                    if let ml = UTType(filenameExtension: "mlmodel") { types.append(ml) }
                    if let mlc = UTType(filenameExtension: "mlmodelc") { types.append(mlc) }
                    return types.isEmpty ? [.data] : types
                }(),
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        Task {
                            do {
                                try await onDeviceService.importModel(from: url)
                                feedbackGenerator.notificationOccurred(.success)
                            } catch {
                                errorMessage = error.localizedDescription
                                showError = true
                                feedbackGenerator.notificationOccurred(.error)
                            }
                        }
                    }
                case .failure:
                    break
                }
            } }
        }
        .padding(.vertical, DesignSystem.tiny)
    }
    
    // MARK: - 测试 Playground 入口
    private var testSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: {
                showTestSheet = true
                feedbackGenerator.notificationOccurred(.success)
            }) {
                HStack(spacing: DesignSystem.small) {
                    Image(systemName: "text.bubble.fill")
                    Text(L10n.AI.OnDevice.testGeneration)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.medium)
                .background(onDeviceService.isModelLoaded ? Color.theme.green : Color.theme.gray.opacity(DesignSystem.Opacity.dim))
                .clipShape(RoundedRectangle(cornerRadius: Spacing.cardRadius))
            }
            .disabled(!onDeviceService.isModelLoaded)
            
            if onDeviceService.inferenceSpeed > 0 {
                HStack {
                    Label(
                        L10n.AI.OnDevice.inferenceSpeed,
                        systemImage: "gauge.with.needle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(.appSecondary)
                    
                    Spacer()
                    
                    Text(String(format: "%.1f tok/s", onDeviceService.inferenceSpeed))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.green)
                }
                .padding(.top, DesignSystem.tiny)
            }
        }
        .padding(.vertical, DesignSystem.tiny)
    }
    
    // MARK: - 隐私和属性提示
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.medium) {
            OnDeviceInfoRow(
                icon: "lock.shield.fill",
                text: L10n.AI.OnDevice.Info.privacy
            )
            
            OnDeviceInfoRow(
                icon: "wifi.slash",
                text: L10n.AI.OnDevice.Info.offline
            )
            
            OnDeviceInfoRow(
                icon: "bolt.fill",
                text: L10n.AI.OnDevice.Info.ne
            )
            
            OnDeviceInfoRow(
                icon: "memorychip.fill",
                text: L10n.AI.OnDevice.Info.memory
            )
        }
        .padding(.vertical, DesignSystem.tightPadding)
    }
    
    // MARK: - 异步加载模型动作
    private func loadModel() {
        feedbackGenerator.prepare()
        Task {
            do {
                try await onDeviceService.loadModel()
                feedbackGenerator.notificationOccurred(.success)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
                feedbackGenerator.notificationOccurred(.error)
            }
        }
    }
}
