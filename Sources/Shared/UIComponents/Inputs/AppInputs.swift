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
            .background(Color.appCard)
            .clipShape(RoundedRectangle(cornerRadius: Spacing.standardRadius))
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
        VStack(alignment: .leading, spacing: Spacing.small) {
            // 使用 FlowLayout 自动换行排列标签
            FlowLayout(spacing: DesignSystem.Grid.flowSpacing) {
                ForEach(tags, id: \.self) { tag in
                    HStack(spacing: SystemSpacing.tight) {
                        Text(tag)
                            .font(.system(size: Reference.FontSize.micro))
                        
                        Button(action: { 
                            withAnimation(DesignSystem.Animation.standard) {
                                tags.removeAll { $0 == tag }
                            }
                        }) {
                            Image(systemName: DesignSystem.Icons.xmark)
                                .font(.system(size: Reference.FontSize.micro))
                                .foregroundStyle(.appSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, DesignSystem.small)
                    .padding(.vertical, DesignSystem.tiny)
                    .background(Color.appAccent.opacity(SystemOpacity.glass))
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
            .padding(.horizontal, Spacing.medium)
            .padding(.vertical, Spacing.small)
            .background(Color.appCard)
            .clipShape(RoundedRectangle(cornerRadius: Spacing.standardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.standardRadius)
                    .stroke(Color.appBorder.opacity(Colors.disabledOpacity), lineWidth: Spacing.borderWidth)
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
            .padding(Spacing.medium)
            .background(Color.appCard)
            .clipShape(RoundedRectangle(cornerRadius: Spacing.standardRadius))
        #else
        TextEditor(text: $text)
            .font(.system(.body, design: .monospaced))
            .scrollContentBackground(.hidden)
            .foregroundStyle(.appText)
            .frame(minHeight: minHeight)
            .padding(Spacing.medium)
            .background(Color.appCard)
            .clipShape(RoundedRectangle(cornerRadius: Spacing.standardRadius))
        #endif
    }
}
