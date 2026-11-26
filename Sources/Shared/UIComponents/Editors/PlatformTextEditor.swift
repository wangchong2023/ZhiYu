//
//  PlatformTextEditor.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/07.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 平台适配层
//  核心职责：跨平台文本编辑器——iOS/macOS 用 TextEditor，watchOS 降级为 TextField。
//
import SwiftUI

/// 跨平台文本编辑器
/// iOS/macOS：多行 TextEditor（富文本输入）
/// watchOS：单行 TextField（手表端限制）
@MainActor
public struct PlatformTextEditor: View {
    @Binding var text: String
    var minHeight: CGFloat

    /// 创建跨平台文本编辑器
    /// - Parameters:
    ///   - text: 绑定的文本内容
    ///   - minHeight: iOS/macOS 上的最小高度（watchOS 忽略）
    public init(text: Binding<String>, minHeight: CGFloat = 100) {
        self._text = text
        self.minHeight = minHeight
    }

    @Environment(\.interfaceIdiom) private var idiom

    public var body: some View {
        if idiom == .watch {
            TextField("", text: $text, axis: .vertical)
                .font(.body)
        } else {
            TextEditor(text: $text)
                .font(.body)
                .frame(minHeight: minHeight)
        }
    }
}
