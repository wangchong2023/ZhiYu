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

// MARK: - 思维导图内容视图

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
           firstLine.hasPrefix("# ") {
            return firstLine.replacingOccurrences(of: "# ", with: "")
        }
        return nil
    }

    private func extractMermaidCode(from content: String) -> String {
        if let regex = try? NSRegularExpression(pattern: "```(?:mermaid)?\\n([\\s\\S]*?)```", options: []),
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
            return !trimmed.hasPrefix("#") && !trimmed.hasPrefix("```") && !trimmed.isEmpty
        }
        .joined(separator: "\n")
        .trimmingCharacters(in: .whitespacesAndNewlines)

        if filtered.hasPrefix("mindmap") || filtered.hasPrefix("graph") || filtered.hasPrefix("sequenceDiagram") || filtered.hasPrefix("gantt") || filtered.hasPrefix("pie") {
            return filtered
        }
        
        // 自动自愈补充基础思维导图/架构图声明
        if doc.type == .mindmap {
            let sanitizedTitle = (extractTitle(from: content) ?? L10n.AI.Synthesis.title)
                .replacingOccurrences(of: "(", with: "")
                .replacingOccurrences(of: ")", with: "")
                .replacingOccurrences(of: "[", with: "")
                .replacingOccurrences(of: "]", with: "")
            let sanitizedBody = filtered
                .replacingOccurrences(of: "(", with: "")
                .replacingOccurrences(of: ")", with: "")
                .replacingOccurrences(of: "[", with: "")
                .replacingOccurrences(of: "]", with: "")
                .replacingOccurrences(of: "：", with: " ")
                .replacingOccurrences(of: ":", with: " ")
                .replacingOccurrences(of: "\n", with: "\n    ")
            return "mindmap\n  root((\(sanitizedTitle)))\n    \(sanitizedBody)"
        } else if doc.type == .infographic {
            return "graph TD\n  A[\(extractTitle(from: content) ?? L10n.AI.Synthesis.title)] --> B[\(filtered.prefix(100))]"
        }
        return filtered
    }
}
