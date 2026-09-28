//
//  AppInputs.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：可复用 UI 组件库：编辑器、卡片、加载态、空状态等通用视图。
//
import SwiftUI
import UFPDesignSystem

// 输入框最小宽度（组件特定值）
private let inputFieldMinWidth: CGFloat = 110

// MARK: - App Text Field

/// 统一样式的文本输入框
/// 提供标准的卡片背景与内边距。
public struct AppTextField: View {
    public let placeholder: String
    @Binding public var text: String

    public init(placeholder: String, text: Binding<String>) {
        self.placeholder = placeholder
        self._text = text
    }

    public var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .padding()
            .appCardClip(cornerRadius: DesignTokens.Spacing.standardRadius)
            .foregroundStyle(.appText)
    }
}

// MARK: - App Tag Field

/// 标签/令牌输入框
/// 支持芯片式展示、自动分词及删除交互。
public struct AppTagField: View {
    public let placeholder: String
    @Binding public var tags: [String]
    @State private var newTag: String = ""

    public init(placeholder: String, tags: Binding<[String]>) {
        self.placeholder = placeholder
        self._tags = tags
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            // 使用 FlowLayout 自动换行排列标签
            FlowLayout(spacing: DesignSystem.Grid.flowSpacing) {
                ForEach(tags, id: \.self) { tag in
                    HStack(spacing: DesignTokens.SystemSpacing.tight) {
                        Text(tag)
                            .font(.system(size: DesignTokens.Reference.FontSize.micro))
                        
                        Button(action: { 
                            withAnimation(DesignTokens.Animation.standard) {
                                tags.removeAll { $0 == tag }
                            }
                        }) {
                            Image(systemName: DesignTokens.Icons.xmark)
                                .font(.system(size: DesignTokens.Reference.FontSize.micro))
                                .foregroundStyle(.appSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, DesignTokens.Spacing.small)
                    .padding(.vertical, DesignTokens.Spacing.tiny)
                    .background(Color.appAccent.opacity(DesignTokens.SystemOpacity.glass))
                    .clipShape(Capsule())
                    .foregroundStyle(.appAccent)
                }
                
                // 标签输入框
                TextField(placeholder, text: $newTag)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                    .onChange(of: newTag) { _, newValue in
                        // 自动检测空格、逗号或中文逗号进行分词
                        if newValue.hasSuffix(" ") || newValue.hasSuffix(",") || newValue.hasSuffix(",") {
                            addCurrentTag()
                        }
                    }
                    .onSubmit {
                        addCurrentTag()
                    }
                    .frame(minWidth: inputFieldMinWidth)
                    .foregroundStyle(.appText)
            }
            .padding(.horizontal, DesignTokens.Spacing.medium)
            .padding(.vertical, DesignTokens.Spacing.small)
            .appCardClip(cornerRadius: DesignTokens.Spacing.standardRadius)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Spacing.standardRadius)
                    .stroke(Color.appBorder.opacity(DesignTokens.Colors.disabledOpacity), lineWidth: DesignTokens.Spacing.borderWidth)
            )
        }
    }
    
    /// 将当前输入的内容添加为标签并清空输入框
    private func addCurrentTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespaces.union(.init(charactersIn: ",")))
            .replacingOccurrences(of: "#", with: "")
        if !trimmed.isEmpty && !tags.contains(trimmed) {
            withAnimation(.appStandard) {
                tags.append(trimmed)
            }
        }
        newTag = ""
    }
}

// MARK: - App Monospaced Editor

/// 等宽文本编辑器
/// 适用于 Markdown、代码或需要精确排版的文本录入。
public struct AppMonospacedEditor: View {
    @Binding public var text: String
    public var minHeight: CGFloat = 200

    public init(text: Binding<String>, minHeight: CGFloat = 200) {
        self._text = text
        self.minHeight = minHeight
    }

    public var body: some View {
        #if os(watchOS)
        TextField("", text: $text, axis: .vertical)
            .font(.system(.body, design: .monospaced))
            .foregroundStyle(.appText)
            .padding(DesignTokens.Spacing.medium)
            .appCardClip(cornerRadius: DesignTokens.Spacing.standardRadius)
        #else
        TextEditor(text: $text)
            .font(.system(.body, design: .monospaced))
            .scrollContentBackground(.hidden)
            .foregroundStyle(.appText)
            .frame(minHeight: minHeight)
            .padding(DesignTokens.Spacing.medium)
            .appCardClip(cornerRadius: DesignTokens.Spacing.standardRadius)
        #endif
    }
}
