//
//  InsightSourceButton.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/14.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：Insight 模块通用来源信息按钮，消除 PageDetailView 与 PageDetailMetadataSection 中重复的
//  来源图标 + 来源名称 + 复制/打开按钮布局链。
//

import SwiftUI
import Dependencies

/// [L3] 表现层：通用来源信息按钮
///
/// 统一封装来源图标 + 来源名称 + 复制路径/打开链接的按钮布局，
/// 通过 `mode` 参数区分本地文件（复制路径）与远程链接（打开 URL）两种交互。
struct InsightSourceButton: View {
    let sourceURL: String
    let displaySourceIcon: String
    let displaySourceName: String
    let isLocalFile: Bool
    var copiedURL: String?
    var onCopy: ((String) -> Void)?
    var onOpen: ((URL) -> Void)?

    var body: some View {
        if isLocalFile {
            Button(action: {
                onCopy?(sourceURL)
            }) {
                sourceLabel(text: copiedURL == sourceURL
                    ? L10n.Knowledge.Page.Source.copied
                    : "\(displaySourceName) (\(L10n.Knowledge.Page.Source.copyPath))")
            }
            .buttonStyle(.plain)
        } else {
            Button(action: {
                if let url = URL(string: sourceURL) {
                    onOpen?(url)
                }
            }) {
                sourceLabel(text: displaySourceName)
            }
            .buttonStyle(.plain)
        }
    }

    /// 来源按钮统一标签：图标 + 文本 + 蓝色前景
    @ViewBuilder
    private func sourceLabel(text: String) -> some View {
        HStack(spacing: DesignSystem.tiny) {
            Image(systemName: displaySourceIcon)
                .font(.caption2)
            Text(text)
                .font(.caption)
                .lineLimit(1)
        }
        .foregroundStyle(Color.theme.blue)
    }
}
