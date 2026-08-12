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
    private let iconOptions = DesignSystem.Icons.Notebook.options
    
    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.pageBackground()
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: DesignSystem.huge) {
                        // 1. 图标选择
                        VStack(spacing: DesignSystem.medium) {
                            ZStack {
                                Circle()
                                    .fill(Color.appAccent.opacity(DesignSystem.Opacity.subtle))
                                    .overlay(
                                        Circle()
                                            .strokeBorder(Color.appAccent.opacity(DesignSystem.Opacity.shadow), lineWidth: 2)
                                    )
                                    .frame(width: DesignSystem.Metrics.avatarPickerSize, height: DesignSystem.Metrics.avatarPickerSize)
                                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.mediumRadius, style: .continuous))
                                    .shadow(color: Color.appAccent.opacity(DesignSystem.Opacity.ghost), radius: DesignSystem.smallRadius, y: 3)
                                
                                Text(icon.isEmpty ? "" : icon)
                                    .font(.largeTitle)
                            }
                            .buttonStyle(.plain)
                            .padding(.vertical, DesignSystem.small)
                            
                            Text(L10n.Vault.iconLabel)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: DesignSystem.small) {
                                    ForEach(iconOptions, id: \.self) { item in
                                        Button {
                                            icon = item
                                        } label: {
                                            ZStack {
                                                Circle()
                                                    .fill(icon == item ? Color.appAccent : Color.appCard)
                                                    .frame(width: DesignSystem.Metrics.colorOptionSize, height: DesignSystem.Metrics.colorOptionSize)
                                                .background(icon == item ? Color.appAccent.opacity(DesignSystem.Opacity.medium) : Color.primary.opacity(DesignSystem.Opacity.ghost))
                                                .clipShape(Circle())
                                                .overlay(
                                                    Circle()
                                                        .strokeBorder(icon == item ? Color.appAccent : Color.clear, lineWidth: 2)
                                                )
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.top, DesignSystem.huge)
                        
                        // 2. 表单
                        VStack(alignment: .leading, spacing: DesignSystem.medium) {
                            VStack(alignment: .leading, spacing: DesignSystem.tiny) {
                                Text(L10n.Vault.nameLabel)
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                
                                TextField(L10n.Vault.namePlaceholder, text: $name)
                                    .font(.title3.bold())
                                    .padding()
                                    .background(Color.appCard)
                                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cardRadius))
                                    // MARK: [UI 测试自愈] 注入唯一的可测试性定位标识符，以便在新建笔记本笔记本表单弹窗中精准定位名字输入框
                                    .accessibilityIdentifier("notebook_name_textfield")
                            }
                            
                            VStack(alignment: .leading, spacing: DesignSystem.tiny) {
                                Text(L10n.Vault.descriptionLabel)
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                
                                TextField(L10n.Vault.descriptionPlaceholder, text: $description, axis: .vertical)
                                    .lineLimit(3...5)
                                    .padding()
                                    .background(Color.appCard)
                                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cardRadius))
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
}
