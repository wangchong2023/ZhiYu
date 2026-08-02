//
//  MarkdownRendererView.swift
//  UFPDesignSystem
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[UFPDesignSystem] SPM Package — 物理归位
//  核心职责：Markdown 渲染适配器（Wrapper View 模式）。
//           封装 gonzalezreal/swift-markdown-ui，上层只需 import UFPDesignSystem，
//           严禁上层直接 import MarkdownUI。
//
//  架构原则：开源库 MarkdownUI 只在此文件 import，通过 MarkdownRendererView 对外暴露能力。
//

import SwiftUI

#if canImport(MarkdownUI) && !os(watchOS)
import MarkdownUI

/// Markdown 内容渲染视图（封装 swift-markdown-ui）
/// 提供统一的样式配置入口，上层无需感知底层渲染库。
public struct MarkdownRendererView: View {
    private let content: String
    private let theme: Theme

    /// - Parameters:
    ///   - content: 待渲染的 Markdown 字符串
    ///   - theme: MarkdownUI 主题，默认为 .gitHub 风格
    public init(_ content: String, theme: Theme = .gitHub) {
        self.content = content
        self.theme = theme
    }

    public var body: some View {
        Markdown(content)
            .markdownTheme(theme)
    }
}

// MARK: - 预设主题便捷扩展

public extension MarkdownRendererView {
    /// 适合深色背景的暗色主题
    static func dark(_ content: String) -> MarkdownRendererView {
        MarkdownRendererView(content, theme: .gitHub)
    }

    /// 适合知识卡片的紧凑主题
    static func compact(_ content: String) -> MarkdownRendererView {
        MarkdownRendererView(content, theme: .basic)
    }
}
#else
/// watchOS 平台下 MarkdownRendererView 原生 Text 降级实现
public struct MarkdownRendererView: View {
    private let content: String

    public init(_ content: String) {
        self.content = content
    }

    public var body: some View {
        Text(content)
    }
}

public extension MarkdownRendererView {
    static func dark(_ content: String) -> MarkdownRendererView {
        MarkdownRendererView(content)
    }

    static func compact(_ content: String) -> MarkdownRendererView {
        MarkdownRendererView(content)
    }
}
#endif
