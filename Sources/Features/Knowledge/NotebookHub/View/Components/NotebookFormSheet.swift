//
//  NotebookFormSheet.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：笔记本中心：入口页面、笔记本卡片、创建表单。
//
import SwiftUI
import UFPDesignSystem

@MainActor
struct CreateNotebookSheet: View {
    @Bindable var viewModel: NotebookHubViewModel
    var body: some View {
        NotebookFormSheet(
            title: L10n.Vault.new,
            submitLabel: L10n.Common.create,
            name: $viewModel.newNotebookName,
            icon: $viewModel.newNotebookIcon,
            description: $viewModel.newNotebookDescription,
            onSubmit: { viewModel.createNotebook() }
        )
    }
}

@MainActor
struct EditNotebookSheet: View {
    @Bindable var viewModel: NotebookHubViewModel
    var body: some View {
        NotebookFormSheet(
            title: L10n.Vault.edit,
            submitLabel: L10n.Common.save,
            name: $viewModel.editingName,
            icon: $viewModel.editingIcon,
            description: $viewModel.editingDescription,
            onSubmit: { viewModel.confirmEdit() }
        )
    }
}

@MainActor
struct NotebookFormSheet: View {
    let title: String
    let submitLabel: String
    @Binding var name: String
    @Binding var icon: String
    @Binding var description: String
    var onSubmit: () -> Void
    
    @Environment(\.dismiss) var dismiss
    @Environment(ThemeManager.self) var themeManager
    /// 笔记本可供选择的高品质 Emoji 图标数组，引用自 Shared 设计令牌
    private let iconOptions = DesignTokens.Icons.Notebook.options
    
    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.pageBackground()
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: DesignTokens.Spacing.huge) {
                        // 1. 图标选择
                        VStack(spacing: DesignTokens.Spacing.medium) {
                            ZStack {
                                Circle()
                                    .fill(Color.appAccent.opacity(DesignTokens.Opacity.subtle))
                                    .overlay(
                                        Circle()
                                            .strokeBorder(Color.appAccent.opacity(DesignTokens.Opacity.shadow), lineWidth: DesignTokens.SystemStroke.selected)
                                    )
                                    .frame(width: DesignTokens.Metrics.avatarPickerSize, height: DesignTokens.Metrics.avatarPickerSize)
                                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Spacing.mediumRadius, style: .continuous))
                                    .shadow(color: Color.appAccent.opacity(DesignTokens.Opacity.ghost), radius: DesignTokens.Spacing.smallRadius, y: 3)
                                
                                Text(icon.isEmpty ? "" : icon)
                                    .font(.largeTitle)
                            }
                            .buttonStyle(.plain)
                            .padding(.vertical, DesignTokens.Spacing.small)
                            
                            Text(L10n.Vault.iconLabel)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: DesignTokens.Spacing.small) {
                                    ForEach(iconOptions, id: \.self) { item in
                                        Button {
                                            icon = item
                                        } label: {
                                            ZStack {
                                                Circle()
                                                    .fill(icon == item ? Color.appAccent : Color.appCard)
                                                    .frame(width: DesignTokens.Metrics.colorOptionSize, height: DesignTokens.Metrics.colorOptionSize)
                                                .background(icon == item ? Color.appAccent.opacity(DesignTokens.Opacity.medium) : Color.primary.opacity(DesignTokens.Opacity.ghost))
                                                .clipShape(Circle())
                                                .overlay(
                                                    Circle()
                                                        .strokeBorder(icon == item ? Color.appAccent : Color.clear, lineWidth: DesignTokens.SystemStroke.selected)
                                                )
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.top, DesignTokens.Spacing.huge)
                        
                        // 2. 表单
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
                            formField(
                                label: L10n.Vault.nameLabel,
                                placeholder: L10n.Vault.namePlaceholder,
                                text: $name,
                                accessibilityID: FeatureConstants.AccessibilityID.notebookNameTextfield
                            )

                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.tiny) {
                                Text(L10n.Vault.descriptionLabel)
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)

                                TextField(L10n.Vault.descriptionPlaceholder, text: $description, axis: .vertical)
                                    .lineLimit(3...5)
                                    .notebookFormFieldStyle()
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.cancel) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(submitLabel) {
                        onSubmit()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    // MARK: [UI 测试自愈] 注入唯一的可测试性定位标识符，以精准点击提交表单按钮完成自愈笔记本的物理创建
                    .accessibilityIdentifier("notebook_submit_button")
                }
            }
        }
    }

    /// 表单字段（标签 + 输入框），消除 name 与 description 字段的重复布局
    @ViewBuilder
    private func formField(
        label: String,
        placeholder: String,
        text: Binding<String>,
        accessibilityID: String
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.tiny) {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            TextField(placeholder, text: text)
                .font(.title3.bold())
                .notebookFormFieldStyle()
                .accessibilityIdentifier(accessibilityID)
        }
    }
}

/// 笔记本表单字段统一卡片样式，消除 description TextField 与 formField 的重复 cardStyle 链
private extension View {
    @ViewBuilder
    func notebookFormFieldStyle() -> some View {
        self.cardStyle(
            horizontalPadding: DesignTokens.Spacing.standardPadding,
            verticalPadding: DesignTokens.Spacing.standardPadding,
            backgroundOpacity: DesignTokens.Opacity.dim,
            cornerRadius: DesignTokens.Spacing.cardRadius
        )
    }
}
