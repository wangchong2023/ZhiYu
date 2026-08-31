//
//  AppTextEditor.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：可复用 UI 组件库：编辑器、卡片、加载态、空状态等通用视图。
//
import SwiftUI

#if !os(watchOS)
/// 统一输入文本编辑器
/// 解决了 SwiftUI 原生 TextEditor 缺乏 Placeholder 的痛点，提供磨砂毛玻璃边框和计数展示。
public struct AppTextEditor: View {
    /// 绑定的多行文本内容
    @Binding public var text: String
    /// 未输入文字时的占位提示语
    public let placeholder: String
    /// 允许输入的最大字符长度上限，为 nil 时代表无限制
    public let maxCharacters: Int?
    
    /// 键盘聚焦控制属性
    @FocusState private var isFocused: Bool
    
    /// 初始化输入文本编辑器
    /// - Parameters:
    ///   - text: 内容绑定
    ///   - placeholder: 占位文本
    ///   - maxCharacters: 字符最大数量，可选
    public init(
        text: Binding<String>,
        placeholder: String = L10n.Shared.editorPlaceholder,
        maxCharacters: Int? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.maxCharacters = maxCharacters
    }
    
    public var body: some View {
        VStack(alignment: .trailing, spacing: SystemSpacing.small) {
            ZStack(alignment: .topLeading) {
                // 占位文本层：当内容为空且未输入时展示
                if text.isEmpty {
                    Text(placeholder)
                        .font(.system(size: SystemFontSize.subheadline)) // Dynamic Type
                        .foregroundColor(.secondary.opacity(DesignSystem.Opacity.dim))
                        .padding(.horizontal, SystemSpacing.small)
                        .padding(.vertical, SystemSpacing.element)
                        .allowsHitTesting(false) // 允许点击穿透到底层 TextEditor
                }
                
                // 原生编辑器层
                TextEditor(text: $text)
                    .font(.system(size: SystemFontSize.subheadline)) // Dynamic Type
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
            .padding(DesignSystem.SpacingToken.tiny.value)
            .background(Color.primary.opacity(DesignSystem.Opacity.atomic))
            // Bug #102 修复：硬编码 8 改用 DesignSystem.Radius.small
            .cornerRadius(DesignSystem.Radius.small)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.smallRadius)
                    .stroke(
                        isFocused ? Color.theme.blue.opacity(DesignSystem.Opacity.dim) : Color.primary.opacity(DesignSystem.Opacity.subtle),
                        lineWidth: SystemStroke.divider
                    )
            )
            // Bug #102 修复：硬编码 4/2 改用 DesignSystem.Shadows.standard
            .shadow(color: isFocused ? Color.theme.blue.opacity(DesignSystem.Opacity.light) : Color.clear,
                    radius: DesignSystem.Shadows.standard.radius,
                    x: DesignSystem.Shadows.standard.x,
                    y: DesignSystem.Shadows.standard.y)
            .frame(minHeight: DesignSystem.Gallery.modalMaxWidth)
            
            // 字数限额计数条
            if let limit = maxCharacters {
                Text("\(text.count)/\(limit)")
                    .font(.system(size: SystemFontSize.microLarge, weight: .medium, design: .monospaced)) // Dynamic Type
                    .foregroundColor(text.count >= limit ? Color.theme.red : .secondary)
            }
        }
    }
}
#endif
