//
//  TranscriptionEditor.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/13.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：转写文本编辑器组件，消除 VoiceNoteComponents 与 VoiceNoteView 间重复的 TextEditor/TextField 链。
//

import SwiftUI

/// 转写文本编辑器组件
/// 根据 idiom 自动切换 TextEditor（非 watch）或 TextField（watch），消除两处重复的编辑器样式链
struct TranscriptionEditor: View {
    let text: Binding<String>
    let idiom: InterfaceIdiom
    var minHeight: CGFloat
    var maxHeight: CGFloat
    var padding: CGFloat
    var cornerRadius: CGFloat
    var showBorder: Bool = true

    var body: some View {
        if idiom != .watch {
            TextEditor(text: text)
                .font(.body)
                .foregroundStyle(.appText)
                .frame(minHeight: minHeight, maxHeight: maxHeight)
                .padding(padding)
                .appCardClip(cornerRadius: cornerRadius)
                .overlay(
                    Group {
                        if showBorder {
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .stroke(Color.appBorder, lineWidth: DesignSystem.borderWidth)
                        }
                    }
                )
        } else {
            TextField("", text: text)
                .font(.body)
                .foregroundStyle(.appText)
                .padding(padding)
                .appCardClip(cornerRadius: cornerRadius)
        }
    }
}
