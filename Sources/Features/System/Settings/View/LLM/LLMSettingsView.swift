//
//  LLMSettingsView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：构建 LLMSettings 界面的 UI 视图层组件。
//
import SwiftUI

// MARK: - LLM Settings View
@MainActor
struct LLMSettingsView: View {
    @Environment(AppStore.self) var store
    @Environment(ThemeManager.self) var themeManager
    @Environment(Router.self) var router
    @EnvironmentObject var llmService: LLMService
    @Environment(LLMConfigManager.self) var config
    @State private var testing = false
    @State private var testResult: TestResult?
    @State private var showAPIKey = false
    @State private var isProvidersExpanded = true  // 默认展开方便用户直观查看与切换提供商
    @State private var isCustomModelInput = false  // 非自定义提供商下是否切为手动输入模式
    
    enum TestResult {
        case success(latency: Int, streamOK: Bool, streamTested: Bool)
        case failure(code: String, message: String, latency: Int?, streamTested: Bool)
    }
    
    var body: some View {
        @Bindable var config = config
        Form {
            // 1. 服务开关
            Section {
                Toggle(isOn: $config.isEnabled) {
                    Label(L10n.AI.LLM.enableAssistant, systemImage: DesignSystem.Icons.sparkles)
                        .foregroundStyle(.appText)
                }
                .tint(.appAccent)
                
                Toggle(isOn: Binding(
                    get: { config.autoScan && config.autoRefactor },
                    set: { newValue in
                        config.autoScan = newValue
                        config.autoRefactor = newValue
                    }
                )) {
                    VStack(alignment: .leading, spacing: DesignSystem.tiny) {
                        Text(L10n.AI.OnDevice.assistMode)
                            .font(.body.bold())
                            .foregroundStyle(.appText)
                        Text(L10n.AI.OnDevice.assistDesc)
                            .font(.caption)
                            .foregroundStyle(.appText.opacity(DesignSystem.subtleOpacity))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, DesignSystem.tiny)
                }
                .tint(.appAccent)
            } header: {
                Text(L10n.AI.LLM.serviceStatus)
            }
            .appListRowBackground()
            
            // 2. 提供商选择与详细参数配置
            Section {
                DisclosureGroup(isExpanded: $isProvidersExpanded) {
                    VStack(alignment: .leading, spacing: DesignSystem.medium) {
                        ForEach(LLMProvider.allCases) { provider in
                            Button(action: {
                                testResult = nil
                                config.provider = provider
                                isCustomModelInput = false
                                if !provider.suggestedModels.contains(config.model) {
                                    config.model = provider.defaultModel
                                }
                            }) {
                                HStack {
                                    Image(systemName: provider.icon)
                                        .frame(width: DesignSystem.titleIconSize, alignment: .center)
                                        .foregroundStyle(config.provider == provider ? .appAccent : .appSecondary)
                                    Text(provider.displayName)
                                        .foregroundStyle(.appText)
                                    Spacer()
                                    if config.provider == provider {
                                        Image(systemName: DesignSystem.Icons.check)
                                            .font(.body.bold())
                                            .foregroundStyle(.appAccent)
                                    }
                                }
                                .padding(.vertical, DesignSystem.tiny)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Divider()
                            .padding(.vertical, DesignSystem.small)
                        
                        // 联动参数配置块
                        configurationContent
                    }
                    .padding(.top, DesignSystem.small)
                } label: {
                    HStack {
                        Label(L10n.AI.LLM.Provider.title, systemImage: "cpu")
                            .foregroundStyle(.appText)
                        Spacer()
                        Text(config.provider.displayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.appAccent)
                    }
                }
            } header: {
                HStack {
                    Text(L10n.AI.LLM.providerConfig)
                    Spacer()
                    Button(action: {
                        testResult = nil
                        config.provider = .deepSeek
                        isCustomModelInput = false
                    }) {
                        Text(L10n.Common.reset)
                            .font(.caption)
                            .foregroundStyle(.appAccent)
                    }
                    .buttonStyle(.plain)
                }
            }
            .appListRowBackground()
            
            // 3. 连通性测试验证
            Section {
                Button(action: testConnection) {
                    HStack {
                        if testing {
                            ProgressView()
                                .tint(.appAccent)
                        } else {
                            Image(systemName: DesignSystem.Icons.bolt)
                                .foregroundStyle(.appAccent)
                        }
                        Text(testing ? L10n.AI.LLM.testing : L10n.AI.LLM.testConnection)
                            .foregroundStyle(.appText)
                    }
                }
                .disabled(testing || config.apiKey.isEmpty || (config.provider == .custom && config.baseURL.isEmpty))
                .opacity(config.apiKey.isEmpty ? 0.6 : 1.0)
                
                if let result = testResult {
                    VStack(alignment: .leading, spacing: DesignSystem.small) {
                        switch result {
                        case .success(let latency, _, _):
                          HStack {
                              Image(systemName: DesignSystem.Icons.checkCircle)
                                  .foregroundStyle(.green)
                              Text(L10n.AI.OnDevice.connected)
                                  .font(.subheadline.bold())
                                  .foregroundStyle(.green)
                              Spacer()
                              Text(L10n.AI.LLM.latency("\(latency) \(L10n.Dashboard.unitMs)"))
                                  .font(.caption.monospaced())
                                  .foregroundStyle(.appSecondary)
                          }
                        case .failure(let code, let message, let latency, _):
                          HStack(alignment: .top) {
                              Image(systemName: DesignSystem.Icons.errorCircle)
                                  .foregroundStyle(.red)
                              VStack(alignment: .leading, spacing: DesignSystem.tiny) {
                                  Text(L10n.AI.OnDevice.errorFormat("\(code)"))
                                      .font(.subheadline.bold())
                                  Text(message)
                                      .font(.caption)
                                      .foregroundStyle(.appSecondary)
                              }
                              Spacer()
                              if let latency = latency {
                                  Text(L10n.AI.LLM.latency("\(latency) \(L10n.Dashboard.unitMs)"))
                                      .font(.caption.monospaced())
                                      .foregroundStyle(.appSecondary)
                              }
                          }
                        }
                    }
                    .padding(.vertical, DesignSystem.tiny)
                }
            } header: {
                Text(L10n.AI.LLM.validation)
            }
            .appListRowBackground()
        }
        .insetGroupedListStyleIfIOS()
        .scrollContentBackground(.hidden)
    }
    
    /// 配置内容视图（API Key / Base URL / Model 选择与编辑）
    private var configurationContent: some View {
        @Bindable var config = config
        let validation = config.provider.validateAPIKeyFormat(config.apiKey)
        
        return VStack(spacing: DesignSystem.wide) {
            // API Key
            VStack(alignment: .leading, spacing: DesignSystem.tightPadding) {
                HStack {
                    Text(L10n.AI.LLM.apiKey)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.appSecondary)
                    Spacer()
                    if !config.apiKey.isEmpty, let msg = validation.message, !validation.isValid {
                        Text(msg)
                            .font(.caption2)
                            .foregroundStyle(Color.appAlert)
                    }
                }
                HStack {
                    if showAPIKey {
                        TextField(config.provider.apiKeyPlaceholder, text: $config.apiKey)
                            .textFieldStyle(.plain)
                            .foregroundStyle(.appText)
                            .font(.system(.body, design: .monospaced))
                    } else {
                        SecureField(config.provider.apiKeyPlaceholder, text: $config.apiKey)
                            .textFieldStyle(.plain)
                            .foregroundStyle(.appText)
                            .font(.system(.body, design: .monospaced))
                    }
                    Button(action: { showAPIKey.toggle() }) {
                        Image(systemName: showAPIKey ? "eye.slash" : "eye")
                            .foregroundStyle(.appSecondary)
                    }
                }
                .padding()
                .background(Color.appCard.opacity(DesignSystem.Opacity.prominent))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.smallRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.smallRadius)
                        .stroke(validation.isValid || config.apiKey.isEmpty ? Color.appBorder.opacity(DesignSystem.Opacity.prominent) : Color.appAlert.opacity(DesignSystem.Opacity.prominent), lineWidth: 1)
                )
            }
            
            // Base URL
            VStack(alignment: .leading, spacing: DesignSystem.tightPadding) {
                Text(L10n.AI.LLM.apiAddress)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.appSecondary)
                TextField("https://api.example.com/v1", text: $config.baseURL)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.appText)
                    .padding()
                    .background(Color.appCard.opacity(DesignSystem.Opacity.prominent))
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.smallRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.smallRadius)
                            .stroke(Color.appBorder.opacity(DesignSystem.Opacity.prominent), lineWidth: 1)
                    )
                    .skipOnWatch { $0.autocapitalization(.none).keyboardType(.URL) }
            }
            
            // Model (非自定义模式呈现 Picker 下拉菜单，自定义模式或手动模式呈现 TextField)
            VStack(alignment: .leading, spacing: DesignSystem.tightPadding) {
                HStack {
                    Text(L10n.AI.LLM.model)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.appSecondary)
                    Spacer()
                    if config.provider != .custom && !config.provider.suggestedModels.isEmpty {
                        Button(action: {
                            isCustomModelInput.toggle()
                            if !isCustomModelInput && !config.provider.suggestedModels.contains(config.model) {
                                config.model = config.provider.defaultModel
                            }
                        }) {
                            Text(isCustomModelInput ? L10n.AI.LLM.Model.preset : L10n.AI.LLM.Model.custom)
                                .font(.caption2)
                                .foregroundStyle(.appAccent)
                        }
                    }
                }
                
                if config.provider == .custom || isCustomModelInput || config.provider.suggestedModels.isEmpty {
                    // 自定义输入框
                    TextField("model-name", text: $config.model)
                        .textFieldStyle(.plain)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.appText)
                        .padding()
                        .background(Color.appCard.opacity(DesignSystem.Opacity.prominent))
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.smallRadius))
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.smallRadius)
                                .stroke(Color.appBorder.opacity(DesignSystem.Opacity.prominent), lineWidth: 1)
                        )
                        .skipOnWatch { $0.autocapitalization(.none) }
                } else {
                    // 官方提供商 Dropdown 下拉选择菜单
                    Menu {
                        Picker(L10n.AI.LLM.model, selection: $config.model) {
                            ForEach(config.provider.suggestedModels, id: \.self) { modelName in
                                Text(modelName).tag(modelName)
                            }
                        }
                    } label: {
                        HStack {
                            Text(config.model.isEmpty ? config.provider.defaultModel : config.model)
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.appText)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption)
                                .foregroundStyle(.appSecondary)
                        }
                        .padding()
                        .background(Color.appCard.opacity(DesignSystem.Opacity.prominent))
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.smallRadius))
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.smallRadius)
                                .stroke(Color.appBorder.opacity(DesignSystem.Opacity.prominent), lineWidth: 1)
                        )
                    }
                }
            }
        }
        .padding(.vertical, DesignSystem.small)
    }
    
    func testConnection() {
        testing = true
        testResult = nil
        
        Task {
            do {
                let res = try await llmService.validateAPIKey()
                await MainActor.run {
                    testing = false
                    if res.isSuccess {
                        testResult = .success(latency: res.latencyMS, streamOK: res.streamOK, streamTested: res.streamTested)
                    } else {
                        testResult = .failure(code: res.errorCode ?? "ERR", message: res.errorMessage ?? "Unknown_Error", latency: res.latencyMS, streamTested: res.streamTested)
                    }
                }
            } catch {
                await MainActor.run {
                    testing = false
                    testResult = .failure(code: "CATCH", message: error.localizedDescription, latency: nil, streamTested: false)
                }
            }
        }
    }
}
