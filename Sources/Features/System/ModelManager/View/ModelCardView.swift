//
//  ModelCardView.swift
//  ZhiYu
//
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层 / 视图组件
//  核心职责：大模型卡片渲染 — 标题/参数/能力标签展示、硬件护栏 Banner、展开式 Spec Sheet 规格面板。
//
import SwiftUI
import UFPCore

// MARK: - 大模型卡片组件

/// 动态大模型卡片视图组件，承载模型的展示与下载/激活逻辑
struct ModelCardView: View {
    /// 模型元数据清单
    let manifest: LLMManifest

    /// 全局大模型中台管理器
    let modelManager: GlobalModelManager

    /// 警告弹窗的绑定值
    @Binding var alertManifest: LLMManifest?

    /// 展开状态下的模型 ID
    @Binding var expandedModelId: String?

    /// 进入测试实验室的回调
    let onGoToLab: () -> Void

    var body: some View {
        let isSelected = modelManager.activeModelId == manifest.modelId
        let eligibility = modelManager.evaluateEligibility(for: manifest)
        let downloadState = modelManager.downloadStates[manifest.modelId] ?? .failed(error: "Not Downloaded")
        let isLocalReady = modelManager.isModelLocalReady(for: manifest.modelId)

        let cardBackground = Color.appCard.opacity(eligibility == .restricted ? 0.4 : 0.8)
        let borderColor = isSelected ? Color.appAccent : (eligibility == .restricted ? Color.theme.red.opacity(DesignSystem.Opacity.disabled) : Color.appBorder.opacity(DesignSystem.Opacity.prominent))
        let shadowColor = isSelected ? Color.appAccent.opacity(DesignSystem.Opacity.medium) : Color.theme.black.opacity(DesignSystem.Opacity.ghost)

        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: DesignSystem.small) {
                // 头部：标题与状态标签
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: DesignSystem.tiny) {
                        HStack(spacing: DesignSystem.small) {
                            Text(manifest.displayName)
                                .font(.headline)
                                .foregroundStyle(eligibility == .restricted ? .appSecondary : .appText)

                            Text(manifest.parameterCount)
                                .font(.system(size: 10, weight: .bold, design: .monospaced)) // Dynamic Type
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.appAccent.opacity(DesignSystem.Opacity.glass))
                                .clipShape(Capsule())
                                .foregroundStyle(.appAccent)
                        }

                        Text(manifest.vendor)
                            .font(.caption2)
                            .foregroundStyle(.appSecondary)

                        // 独立的文件大小和状态行
                        HStack(spacing: DesignSystem.small) {
                            let statusIcon: String = {
                                if isLocalReady {
                                    return "checkmark.circle.fill"
                                } else {
                                    switch downloadState {
                                    case .downloading, .pending:
                                        return "arrow.down.circle.fill"
                                    default:
                                        return "questionmark.circle"
                                    }
                                }
                            }()
                            
                            let iconColor: Color = {
                                if isLocalReady {
                                    return .green
                                } else {
                                    switch downloadState {
                                    case .downloading, .pending:
                                        return .blue
                                    default:
                                        return .gray
                                    }
                                }
                            }()

                            HStack(spacing: 4) {
                                Image(systemName: statusIcon)
                                    .font(.caption2)
                                    .foregroundStyle(iconColor)
                                
                                Text(formattedSize(manifest.fileSizeInBytes))
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.appSecondary)
                            }
                            
                            if let urlString = manifest.huggingfaceURLString ?? manifest.modelscopeURLString,
                               let url = URL(string: urlString) {
                                HStack(spacing: 2) {
                                    Image(systemName: "arrow.up.right.square")
                                        .font(.caption2)
                                        .foregroundStyle(.appAccent)
                                    Link(L10n.ModelManager.Card.learnMore, destination: url)
                                        .font(.caption2)
                                        .foregroundStyle(.appAccent)
                                }
                            }
                        }
                    }

                    Spacer()

                    HStack(spacing: DesignSystem.small) {
                        if isLocalReady {
                            HStack(spacing: 2) {
                                Image(systemName: "checkmark.shield.fill")
                                Text(L10n.ModelManager.Card.ready)
                            }
                            .font(.caption2.bold())
                            .foregroundStyle(.green)
                        }
                        
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                expandedModelId = (expandedModelId == manifest.modelId) ? nil : manifest.modelId
                            }
                        } label: {
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                                .foregroundStyle(.appSecondary)
                                .padding(DesignSystem.tiny)
                                .background(Color.appCard.opacity(DesignSystem.Opacity.soft))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                // 说明文案
                Text(manifest.description)
                    .font(.caption)
                    .foregroundStyle(.appSecondary)
                    .lineLimit(2)

                // 场景能力标签 (Chips)
                if !manifest.displayTasks.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DesignSystem.tiny) {
                            ForEach(manifest.displayTasks, id: \.self) { task in
                                Text(taskLabel(for: task))
                                    .font(.system(size: DesignSystem.microFontSize, weight: .medium))
                                    .padding(.horizontal, DesignSystem.small)
                                    .padding(.vertical, DesignSystem.atomic)
                                    .background(taskColor(for: task).opacity(DesignSystem.Opacity.subtle))
                                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.chipRadius))
                                    .foregroundStyle(taskColor(for: task))
                            }
                        }
                    }
                    .padding(.vertical, DesignSystem.atomic)
                }

                // 硬件防爆护栏层
                if eligibility == .restricted {
                    restrictedBanner(for: manifest)
                } else if eligibility == .warning {
                    warningBanner
                }

                Divider()
                    .foregroundStyle(Color.appBorder.opacity(DesignSystem.Opacity.soft))

                // 底部下载/激活状态交互组
                HStack {
                    ModelDownloadStatusBar(manifest: manifest, downloadState: downloadState, modelManager: modelManager)

                    Spacer()

                    ModelActionButton(
                        manifest: manifest,
                        eligibility: eligibility,
                        isSelected: isSelected,
                        isLocalReady: isLocalReady,
                        downloadState: downloadState,
                        modelManager: modelManager,
                        alertManifest: $alertManifest,
                        onGoToLab: onGoToLab
                    )
                }
            }
            .padding()
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.mediumRadius))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.mediumRadius)
                    .stroke(borderColor, lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: shadowColor, radius: 8, x: 0, y: 4)
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.3)) {
                    expandedModelId = (expandedModelId == manifest.modelId) ? nil : manifest.modelId
                }
            }

            // 展开的 Model Spec Sheet
            if expandedModelId == manifest.modelId {
                modelSpecSheet(for: manifest)
            }
        }
    }

    // MARK: - Model Spec Sheet

    @ViewBuilder
    private func modelSpecSheet(for manifest: LLMManifest) -> some View {
        let specBg = Color.appCard.opacity(DesignSystem.Opacity.dim)
        VStack(alignment: .leading, spacing: DesignSystem.small) {
            Divider().foregroundStyle(Color.appBorder.opacity(DesignSystem.Opacity.soft))

            Text(manifest.description)
                .font(.subheadline).foregroundStyle(.appText).fixedSize(horizontal: false, vertical: true)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DesignSystem.small) {
                specItem(icon: "cpu", label: L10n.ModelManager.Spec.memory, value: String(format: "%.0f GB", manifest.minDeviceMemoryInGb))
                specItem(icon: "arrow.down.doc", label: L10n.ModelManager.Spec.downloadSize, value: formattedSize(manifest.fileSizeInBytes))
                specItem(icon: "square.3.layers.3d", label: L10n.ModelManager.Spec.parameters, value: manifest.parameterCount)
                specItem(icon: "number", label: L10n.ModelManager.Spec.checksum, value: String(manifest.sha256Checksum.prefix(12)) + "...")
            }

            if !manifest.displayTasks.isEmpty {
                HStack(spacing: DesignSystem.tiny) {
                    Text(L10n.ModelManager.Spec.tasks).font(.caption).foregroundStyle(.appSecondary)
                    ForEach(manifest.displayTasks, id: \.self) { t in
                        HStack(spacing: 3) {
                            // 胶囊引入微型功能图标，增强视觉可读性
                            Image(systemName: taskIcon(for: t))
                                .font(.system(size: 8)) // Dynamic Type
                            Text(taskLabel(for: t))
                                .font(.caption2)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(taskColor(for: t).opacity(DesignSystem.Opacity.subtle)).clipShape(Capsule())
                        .foregroundStyle(taskColor(for: t))
                    }
                }
            }
        }
        .padding(DesignSystem.medium)
        .background(specBg)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.smallRadius))
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }

    private func specItem(icon: String, label: String, value: String) -> some View {
        HStack(spacing: DesignSystem.tiny) {
            Image(systemName: icon).font(.caption2).foregroundStyle(.appAccent).frame(width: DesignSystem.IconSize.micro)
            VStack(alignment: .leading, spacing: DesignSystem.atomic) {
                Text(value).font(.subheadline.weight(.medium)).foregroundStyle(.appText)
                Text(label).font(.system(size: DesignSystem.microFontSize)).foregroundStyle(.appSecondary)
            }
        }
        .padding(DesignSystem.small)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appBackground.opacity(DesignSystem.Opacity.shadow))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.smallRadius))
    }

    // MARK: - Banner 信息条

    /// 强物理内存拦截红条
    private func restrictedBanner(for manifest: LLMManifest) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(" \(String(format: "%.1f", manifest.minDeviceMemoryInGb)) GB  OOM")
                .font(.system(size: 10)) // Dynamic Type
                .foregroundStyle(.red)
            Spacer()
        }
        .padding(DesignSystem.tightPadding)
        .background(Color.theme.red.opacity(DesignSystem.Opacity.subtle))
        .clipShape(RoundedRectangle(cornerRadius: Spacing.Chip.cornerRadius))
    }

    /// 临界运存警告黄条
    private var warningBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.orange)
            Text(L10n.ModelManager.Card.warningLowMemory)
                .font(.system(size: 10)) // Dynamic Type
                .foregroundStyle(.orange)
            Spacer()
        }
        .padding(DesignSystem.tightPadding)
        .background(Color.theme.orange.opacity(DesignSystem.Opacity.subtle))
        .clipShape(RoundedRectangle(cornerRadius: Spacing.Chip.cornerRadius))
    }

    // MARK: - 辅助计算

    /// 格式化大小
    private func formattedSize(_ bytes: Int64) -> String {
        ByteFormatter.formatCustom(bytes)
    }

    // MARK: - 任务标签

    func taskLabel(for task: String) -> String {
        switch task {
        case "chat": return L10n.ModelManager.Task.chat
        case "completion": return L10n.ModelManager.Task.completion
        case "reasoning": return L10n.ModelManager.Task.reasoning
        case "code": return L10n.ModelManager.Task.code
        case "rag": return L10n.ModelManager.Task.rag
        case "translation": return L10n.ModelManager.Task.translation
        default: return task
        }
    }

    func taskColor(for task: String) -> Color {
        switch task {
        case "chat": return .blue
        case "completion": return .green
        case "reasoning": return .purple
        case "code": return .orange
        case "rag": return .pink
        case "translation": return .teal
        default: return .appSecondary
        }
    }

    /// 映射模型能力任务对应的 SF Symbols 图标名称
    func taskIcon(for task: String) -> String {
        switch task {
        case "chat": return "bubble.left.and.bubble.right.fill"
        case "completion": return "checklist.checked"
        case "reasoning": return "brain.head.profile"
        case "code": return "chevron.left.forwardslash.chevron.right"
        case "rag": return "doc.text.magnifyingglass"
        case "translation": return "character.book.closed.fill"
        default: return "sparkles"
        }
    }
}
