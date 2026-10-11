//
//  Inputs.swift
//  UFPDesignSystem
//
//  Created by Antigravity on 2026/06/04.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[UFPDesignSystem] SPM Package — 物理归位
//  核心职责：通用输入组件集 —— 跨平台自适应文本编辑器。
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