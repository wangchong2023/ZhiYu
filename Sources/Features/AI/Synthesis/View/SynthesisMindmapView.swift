//
//  SynthesisMindmapView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：渲染思维导图与信息图表合成输出，提取 Markdown 标题与 Mermaid 代码块。
//

import SwiftUI
import UFPCore

// MARK: - 思维导图内容视图

/// Mermaid 节点语法冲突字符（标题净化时需清除，避免破坏图表语法）
private enum MermaidConflictChar {
    static let openParen: String = SystemConstants.Character.openParen
    static let closeParen: String = SystemConstants.Character.closeParen
    static let openBracket: String = SystemConstants.Character.openBracket
    static let closeBracket: String = SystemConstants.Character.closeBracket
}

/// Mermaid 代码块提取正则模式（匹配 ```mermaid ... ``` 或 ``` ... ``` 代码块内容）
private enum MermaidPattern {
    static let codeBlock: String = "```(?:mermaid)?\\n([\\s\\S]*?)```"
}

/// 渲染思维导图 / 信息图类型的合成文档内容
/// 从文档 Markdown 内容中提取标题与 Mermaid 代码，驱动 MermaidWebView 进行可视化渲染
struct SynthesisMindmapView: View {
    let doc: SynthesisStore.SynthesisDocument
    @State private var selectedDisplayMode = 0 // 0: 可视化图表, 1: 文本报告

    private var mermaidCode: String {
        extractMermaidCode(from: doc.content)
    }

    var body: some View {
        VStack(spacing: DesignSystem.medium) {
            Picker("", selection: $selectedDisplayMode) {
                Text(L10n.AI.Synthesis.actions).tag(0)
                Text(L10n.AI.Synthesis.documentList).tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, DesignSystem.standardPadding)
            .padding(.top, DesignSystem.small)

            if selectedDisplayMode == 0 {
                if !mermaidCode.isEmpty && SynthesisProcessor.isValidMermaidSyntax(mermaidCode) {
                    VStack(spacing: DesignSystem.standardPadding) {
                        if let title = extractTitle(from: doc.content) {
                            Text(title)
                                .font(.title2.bold())
                                .padding(.top, DesignSystem.small)
                                .padding(.horizontal)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }

                        MermaidWebView(mermaidCode: mermaidCode)
                            .id(doc.id)
                    }
                } else {
                    SynthesisErrorStateView(
                        docType: doc.type,
                        onSwitchToText: {
                            withAnimation { selectedDisplayMode = 1 }
                        }
                    )
                    .onAppear {
                        Logger.shared.error("[SYNTH_ERR_MERMAID]" + " \(doc.type.rawValue)")
                    }
                }
            } else {
                SynthesisReportView(doc: doc)
            }
        }
    }

    // MARK: - 辅助解析

    private func extractTitle(from content: String) -> String? {
        let lines = content.components(separatedBy: .newlines)
        if let firstLine = lines.map({ $0.trimmingCharacters(in: .whitespaces) }).first(where: { !$0.isEmpty }),
           firstLine.hasPrefix(SystemConstants.MarkdownSyntax.h1Prefix) {
            return firstLine.replacingOccurrences(of: SystemConstants.MarkdownSyntax.h1Prefix, with: "")
        }
        return nil
    }

    private func extractMermaidCode(from content: String) -> String {
        if let regex = try? NSRegularExpression(pattern: MermaidPattern.codeBlock, options: []),
           let match = regex.firstMatch(in: content, options: [], range: NSRange(content.startIndex..., in: content)),
           let range = Range(match.range(at: 1), in: content) {
            let extracted = String(content[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !extracted.isEmpty {
                return extracted
            }
        }

        let lines = content.components(separatedBy: .newlines)
        let filtered = lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return !trimmed.hasPrefix(SystemConstants.Character.hash) && !trimmed.hasPrefix(SystemConstants.MarkdownSyntax.codeFence) && !trimmed.isEmpty
        }
        .joined(separator: "\n")
        .trimmingCharacters(in: .whitespacesAndNewlines)

        if filtered.hasPrefix(ProcessorConstants.MermaidSyntax.mindmap) || filtered.hasPrefix(ProcessorConstants.MermaidSyntax.graph) || filtered.hasPrefix(ProcessorConstants.MermaidSyntax.sequenceDiagram) || filtered.hasPrefix(ProcessorConstants.MermaidSyntax.gantt) || filtered.hasPrefix(ProcessorConstants.MermaidSyntax.pie) {
            return filtered
        }
        
        // 自动自愈补充基础思维导图/架构图声明
        if doc.type == .mindmap {
            let sanitizedTitle = (extractTitle(from: content) ?? L10n.AI.Synthesis.title)
                .replacingOccurrences(of: MermaidConflictChar.openParen, with: "")
                .replacingOccurrences(of: MermaidConflictChar.closeParen, with: "")
                .replacingOccurrences(of: MermaidConflictChar.openBracket, with: "")
                .replacingOccurrences(of: MermaidConflictChar.closeBracket, with: "")
            let sanitizedBody = filtered
                .replacingOccurrences(of: MermaidConflictChar.openParen, with: "")
                .replacingOccurrences(of: MermaidConflictChar.closeParen, with: "")
                .replacingOccurrences(of: MermaidConflictChar.openBracket, with: "")
                .replacingOccurrences(of: MermaidConflictChar.closeBracket, with: "")
                .replacingOccurrences(of: "：", with: " ")
                .replacingOccurrences(of: ":", with: " ")
                .replacingOccurrences(of: SystemConstants.Character.newline, with: FeatureConstants.MarkdownIndent.newlineIndent)
            return "mindmap\n  root((\(sanitizedTitle)))\n    \(sanitizedBody)"
        } else if doc.type == .infographic {
            return "graph TD\n  A[\(extractTitle(from: content) ?? L10n.AI.Synthesis.title)] --> B[\(filtered.prefix(100))]"
        }
        return filtered
    }
}
