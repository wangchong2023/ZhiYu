//
//  Inputs.swift
//  UFPDesignSystem
//
//  Created by Antigravity on 2026/06/04.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[UFPDesignSystem] SPM Package — 物理归位
//  核心职责：通用输入组件集 —— 跨平台自适应文本编辑器、统一样式文本输入框、标签/令牌输入框、等宽编辑器。
//           沉淀自 ZhiYu App 层 Shared/UIComponents，供包内组件与上层共享。
//

import SwiftUI

/// 跨平台自适应文本编辑器
///
/// watchOS 上 `TextEditor` 不可用，降级为带垂直轴的 `TextField`；
/// iOS / macOS 上使用原生 `TextEditor`。
public struct AdaptiveTextEditor: View {
    @Binding private var text: String

    /// 创建自适应文本编辑器
    /// - Parameter text: 绑定的文本内容
    public init(text: Binding<String>) {
        self._text = text
    }

    public var body: some View {
        #if os(watchOS)
        TextField("", text: $text, axis: .vertical)
        #else
        TextEditor(text: $text)
        #endif
    }
}

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
            FlowLayout(spacing: DesignTokens.Spacing.Grid.flowSpacing) {
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

#if !os(watchOS)
// MARK: - App Text Editor

/// 统一输入文本编辑器
/// 解决了 SwiftUI 原生 TextEditor 缺乏 Placeholder 的痛点，提供磨砂毛玻璃边框和计数展示。
public struct AppTextEditor: View {
    /// 绑定的多行文本内容
    @Binding public var text: String
    /// 未输入文字时的占位提示语（由调用方通过 L10n 提供）
    public let placeholder: String
    /// 允许输入的最大字符长度上限，为 nil 时代表无限制
    public let maxCharacters: Int?

    /// 键盘聚焦控制属性
    @FocusState private var isFocused: Bool

    /// 初始化输入文本编辑器
    /// - Parameters:
    ///   - text: 内容绑定
    ///   - placeholder: 占位文本（由调用方提供本地化文案）
    ///   - maxCharacters: 字符最大数量，可选
    public init(
        text: Binding<String>,
        placeholder: String,
        maxCharacters: Int? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.maxCharacters = maxCharacters
    }

    public var body: some View {
        VStack(alignment: .trailing, spacing: DesignTokens.SystemSpacing.small) {
            ZStack(alignment: .topLeading) {
                // 占位文本层：当内容为空且未输入时展示
                if text.isEmpty {
                    Text(placeholder)
                        .font(.system(size: DesignTokens.SystemFontSize.subheadline)) // Dynamic Type
                        .foregroundColor(.secondary.opacity(DesignTokens.Opacity.dim))
                        .padding(.horizontal, DesignTokens.SystemSpacing.small)
                        .padding(.vertical, DesignTokens.SystemSpacing.element)
                        .allowsHitTesting(false) // 允许点击穿透到底层 TextEditor
                }

                // 原生编辑器层
                TextEditor(text: $text)
                    .font(.system(size: DesignTokens.SystemFontSize.subheadline)) // Dynamic Type
                    .scrollContentBackground(.hidden) // 隐藏原生背景以便显示自定义半透明底色
                    .background(Color.clear)
                    .focused($isFocused)
                    .onChange(of: text) { _, newValue in
                        // 1. 若超限，则进行物理字符剪切，起到硬阻拦作用
                        if let limit = maxCharacters, newValue.count > limit {
                            text = String(newValue.prefix(limit))
                        }
                    }
            }
            .padding(DesignTokens.SpacingToken.tiny.value)
            .background(Color.primary.opacity(DesignTokens.Opacity.atomic))
            // Bug #102 修复：硬编码 8 改用 DesignTokens.Radius.small
            .cornerRadius(DesignTokens.Radius.small)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Spacing.smallRadius)
                    .stroke(
                        isFocused ? Color.theme.blue.opacity(DesignTokens.Opacity.dim) : Color.primary.opacity(DesignTokens.Opacity.subtle),
                        lineWidth: DesignTokens.SystemStroke.divider
                    )
            )
            // Bug #102 修复：硬编码 4/2 改用 DesignTokens.Shadows.standard
            .shadow(color: isFocused ? Color.theme.blue.opacity(DesignTokens.Opacity.light) : Color.clear,
                    radius: DesignTokens.Shadows.standard.radius,
                    x: DesignTokens.Shadows.standard.x,
                    y: DesignTokens.Shadows.standard.y)
            .frame(minHeight: DesignTokens.Spacing.Gallery.modalMaxWidth)

            // 字数限额计数条
            if let limit = maxCharacters {
                Text("\(text.count)/\(limit)")
                    .font(.system(size: DesignTokens.SystemFontSize.microLarge, weight: .medium, design: .monospaced)) // Dynamic Type
                    .foregroundColor(text.count >= limit ? Color.theme.red : .secondary)
            }
        }
    }
}
#endif