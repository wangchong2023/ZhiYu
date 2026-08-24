//
//  OnDeviceComponents.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：系统设置：LLM 配置、性能监控、插件管理、iCloud、备份。
//
import SwiftUI

// MARK: - On-Device Test View
/// 设备端大语言模型推理测试沙盒视图
/// 提供直观的用户交互沙盒，用于输入提示词、触发离线文本生成、实时监测进度、查看生成结果并复制，以及衡量硬件在端侧大模型上的生成速率 (Token/s)。
@MainActor
public struct OnDeviceTestView: View {
    /// 绑定的本地大模型服务实例
    @ObservedObject var onDeviceService: OnDeviceLLMService
    
    /// 用于关闭当前 Sheet 的系统环境变量
    @Environment(\.dismiss) private var dismiss
    
    /// 输入的测试提示词
    @State private var prompt = ""
    
    /// 推理输出的完整文本
    @State private var result = ""
    
    /// 标识当前是否正在进行 Token 生成
    @State private var isGenerating = false
    
    /// 触发 Haptic 触感反馈的局部状态
    @State private var feedbackGenerator = UINotificationFeedbackGenerator()

    public init(onDeviceService: OnDeviceLLMService) {
        self.onDeviceService = onDeviceService
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: DesignSystem.wide) {
                promptInputSection
                generateButton
                progressIndicator
                resultSection
                Spacer()
            }
            .padding()
            .background(PageBackgroundView(accentColor: .appAccent))
            .navigationTitle(L10n.AI.OnDevice.test)
.appNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.cancel) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - 提示词输入区域
    private var promptInputSection: some View {
        VStack(alignment: .leading, spacing: SystemSpacing.element) {
            Text(L10n.AI.OnDevice.testPrompt)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.appSecondary)
                .tracking(DesignSystem.Tracking.tight)
            
            AdaptiveTextEditor(text: $prompt)
            .font(.body)
            .frame(height: DesignSystem.Metrics.largeIconBoxSize)
            .padding(SystemSpacing.element) /* 10pt = 2+8 */
            .scrollContentBackground(.hidden)
            .background(Color.appCard.opacity(DesignSystem.Opacity.disabled))
            .clipShape(RoundedRectangle(cornerRadius: Spacing.standardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.standardRadius)
                    .strokeBorder(Color.appAccent.opacity(DesignSystem.Opacity.medium), lineWidth: SystemStroke.emphasis)
            )
        }
    }
    
    // MARK: - 一键生成按钮
    private var generateButton: some View {
        Button(action: generate) {
            HStack(spacing: SystemSpacing.element) {
                if isGenerating {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "sparkles")
                }
                Text(isGenerating ? L10n.AI.OnDevice.generating : L10n.AI.OnDevice.generate)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, SystemSpacing.medium)
            .background(
                LinearGradient(
                    // swiftlint:disable:next magic_numbers_opacity
                    colors: isGenerating ? [.gray, .gray.opacity(DesignSystem.Opacity.prominent)] : [.appAccent, .appAccent.opacity(0.85)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: Spacing.cardRadius))
            .shadow(color: Color.appAccent.opacity(isGenerating ? 0 : 0.2), radius: SystemShadow.radiusMedium, y: SystemShadow.offsetSmall)
        }
        .disabled(isGenerating || prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
    
    // MARK: - 生成进度指示条
    @ViewBuilder
    private var progressIndicator: some View {
        if isGenerating {
            VStack(spacing: SystemSpacing.element) {
                ProgressView(value: onDeviceService.generationProgress)
                    .tint(.appAccent)
                    .progressViewStyle(.linear)
                
                Text(String(format: "%.0f%%", onDeviceService.generationProgress * 100))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.appAccent)
            }
            .transition(.opacity.combined(with: .scale))
        }
    }
    
    // MARK: - 结果展示与拷贝
    @ViewBuilder
    private var resultSection: some View {
        if !result.isEmpty {
            VStack(alignment: .leading, spacing: SystemSpacing.element) {
                HStack {
                    Label(
                        L10n.AI.OnDevice.result,
                        systemImage: "doc.text.magnifyingglass"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.appSecondary)
                    
                    Spacer()
                    
                    Button(action: {
                        AppPasteboard.string = result
                        feedbackGenerator.notificationOccurred(.success)
                    }) {
                        Label(L10n.Common.copy, systemImage: "doc.on.doc.fill")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.appAccent)
                            .padding(.horizontal, SystemSpacing.element)
                            .padding(.vertical, DesignSystem.tiny)
                            .background(Color.appAccent.opacity(DesignSystem.Opacity.subtle))
                            .clipShape(Capsule())
                    }
                }
                
                ScrollView {
                    Text(result)
                        .font(.body)
                        .foregroundStyle(.appText)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .frame(maxHeight: Spacing.Grid.emptyStateHeight)
                .background(Color.appCard.opacity(DesignSystem.Opacity.shadow))
                .clipShape(RoundedRectangle(cornerRadius: Spacing.standardRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: Spacing.standardRadius)
                        .strokeBorder(Color.appText.opacity(DesignSystem.Opacity.ghost), lineWidth: SystemStroke.divider)
                )
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
    
    // MARK: - 触发推理生成逻辑
    private func generate() {
        guard !prompt.isEmpty else { return }
        
        isGenerating = true
        result = ""
        feedbackGenerator.prepare()
        
        Task {
            do {
                let generated = try await onDeviceService.generate(prompt: prompt)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    result = generated
                }
            } catch {
                withAnimation(.spring()) {
                    result = "\(L10n.Common.error): \(error.localizedDescription)"
                }
            }
            isGenerating = false
        }
    }
}

// MARK: - On-Device Model Row
/// 设备端本地模型卡片列表项行组件
/// 负责精细渲染大模型卡片信息，支持动态判断内置/下载/系统类型，展示文件大小标签，并配合磨砂高亮微动画提供卓越的物理触碰回馈。
@MainActor
public struct OnDeviceModelRow: View {
    /// 模型元数据
    public let model: OnDeviceModel
    
    /// 是否已被当前偏好选中
    public let isSelected: Bool
    
    /// 当用户轻触点击时的触发回调
    public let onSelect: () -> Void
    
    public init(model: OnDeviceModel, isSelected: Bool, onSelect: @escaping () -> Void) {
        self.model = model
        self.isSelected = isSelected
        self.onSelect = onSelect
    }
    
    public var body: some View {
        HStack(spacing: SystemSpacing.medium) {
            // 左侧精美模型图标
            ZStack {
                let circleBgColor = isSelected ? Color.appAccent.opacity(DesignSystem.Opacity.glass) : Color.appSecondary.opacity(DesignSystem.Opacity.light)
                let iconColor = isSelected ? Color.appAccent : Color.appSecondary
                Circle()
                    .fill(circleBgColor)
                    .frame(width: Spacing.Sidebar.backButtonWidth, height: Spacing.Sidebar.backButtonWidth)
                
                Image(systemName: model.icon)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(iconColor)
            }
            
            // 中间模型名称及来源描述
            VStack(alignment: .leading, spacing: DesignSystem.tiny) {
                Text(model.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.appText)
                
                HStack(spacing: SystemSpacing.element) {
                    if model.size > 0 {
                        Text(model.sizeLabel)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.appSecondary)
                    }
                    
                    Text(modelTypeLabel)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, SystemSpacing.element)
                        .padding(.vertical, SystemSpacing.atomic)
                        .background(isSelected ? Color.appAccent.opacity(SystemOpacity.glass) : Color.appSecondary.opacity(DesignSystem.Opacity.subtle))
                        .foregroundStyle(isSelected ? .appAccent : .appSecondary)
                        .clipShape(Capsule())
                }
            }
            
            Spacer()
            
            // 右侧精美单选对勾
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.green)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Circle()
                    .stroke(Color.appSecondary.opacity(DesignSystem.Opacity.shadow), lineWidth: SystemStroke.emphasis)
                    .frame(width: DesignSystem.IconSize.small, height: DesignSystem.IconSize.small)
            }
        }
        .padding(.vertical, DesignSystem.medium)
        .padding(.horizontal, DesignSystem.standardPadding)
        .background(
            RoundedRectangle(cornerRadius: Spacing.cardRadius)
                // swiftlint:disable:next magic_numbers_opacity
                .fill(isSelected ? Color.appAccent.opacity(0.06) : Color.appCard.opacity(DesignSystem.Opacity.shadow))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.cardRadius)
                .strokeBorder(isSelected ? Color.appAccent.opacity(DesignSystem.Opacity.shadow) : Color.appText.opacity(DesignSystem.Opacity.ghost), lineWidth: SystemStroke.emphasis)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                onSelect()
            }
        }
    }
    
    /// 本地化的模型类别说明文字
    private var modelTypeLabel: String {
        switch model.type {
        case .bundled:
            return L10n.AI.OnDevice.system
        case .downloaded:
            return L10n.AI.OnDevice.local
        case .system:
            return L10n.AI.OnDevice.appleIntelligence
        }
    }
}

// MARK: - On-Device Info Row
/// 描述项视图组件，用于详细展示安全和推理描述
@MainActor
struct OnDeviceInfoRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: SystemSpacing.element) {
            Image(systemName: icon)
                .font(.footnote)
                .foregroundStyle(.appAccent)
                .frame(width: DesignSystem.large)
            
            Text(text)
                .font(.caption)
                .foregroundStyle(.appSecondary)
                .lineSpacing(2)
            
            Spacer()
        }
    }
}
