//
//  IngestViewComponents.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：知识摄入：文档导入、URL 抓取、OCR 扫描、PDF 解析。
//
import SwiftUI
import UFPCore

// MARK: - URL Import Sheet
/// 批量网页链接导入面板（最多 10 个 URL，带格式校验）
struct URLImportSheet: View {
    @Binding var urlText: String
    let onImport: ([URL]) -> Void
    @Environment(\.dismiss) private var dismiss

    private let maxURLCount = AppConstants.Keys.ImportLimits.maxURLCount
    // Bug #98 修复：URL 超限警告状态
    @State private var urlExceedWarning: String?

    /// 解析所有非空行
    private var allLines: [String] {
        urlText.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// 去重后的有效 URL
    private var validURLs: [URL] {
        var seen = Set<String>()
        return allLines.compactMap { line -> URL? in
            guard let url = URL(string: line),
                  url.scheme == SystemConstants.URLScheme.httpLiteral || url.scheme == SystemConstants.URLScheme.httpsLiteral else { return nil }
            let normalized = url.absoluteString.lowercased()
            guard !seen.contains(normalized) else { return nil }
            seen.insert(normalized)
            return url
        }
    }

    /// 第一个无效行的行号（1-based）
    private var firstInvalidLine: Int? {
        let validSet = Set(validURLs.map { $0.absoluteString.lowercased() })
        for (i, line) in allLines.enumerated() {
            guard let url = URL(string: line),
                  url.scheme == SystemConstants.URLScheme.httpLiteral || url.scheme == SystemConstants.URLScheme.httpsLiteral,
                  validSet.contains(url.absoluteString.lowercased()) else {
                return i + 1
            }
        }
        return nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: DesignSystem.medium) {
                    Text(L10n.Ingest.batchURLPlaceholder)
                        .font(.caption)
                        .foregroundStyle(.appSecondary)

                    AdaptiveTextEditor(text: $urlText)
                    .font(Font.system(.body, design: Font.Design.monospaced))
                    .frame(maxWidth: CGFloat.infinity, maxHeight: CGFloat.infinity)
                    .padding(DesignSystem.small)
                    .background(Color.appCard)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.smallRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.smallRadius)
                            .stroke(
                                firstInvalidLine != nil ? Color.theme.red.opacity(SystemOpacity.faint) : Color.appAccent.opacity(SystemOpacity.glassStrong),
                                lineWidth: DesignSystem.borderWidth
                            )
                    )
                }
                .padding()

                VStack(alignment: .leading, spacing: DesignSystem.small) {
                    if let line = firstInvalidLine {
                        Label(String(format: L10n.Ingest.invalidURLAtLine(line)), systemImage: DesignSystem.Icons.warning)
                            .font(.caption2)
                            .foregroundStyle(Color.theme.red)
                    }
                    Label(String(format: L10n.Ingest.validURLCount(validURLs.count, maxURLCount)), systemImage: DesignSystem.Icons.link)
                        .font(.caption2)
                        .foregroundStyle(.appSecondary)

                    AppPrimaryButton(
                        title: L10n.Ingest.batchImport,
                        icon: DesignSystem.Icons.trayArrowDown,
                        isLoading: false
                    ) {
                        // Bug #98 修复：超限时显示警告，避免静默截断
                        if validURLs.count > maxURLCount {
                            urlExceedWarning = L10n.Ingest.urlExceedLimit(validURLs.count - maxURLCount, maxURLCount)
                        }
                        let urls = Array(validURLs.prefix(maxURLCount))
                        onImport(urls)
                    }
                    .disabled(validURLs.isEmpty)
                    .accessibilityIdentifier("urlImportSubmitButton") // 添加导入按钮测试标识符

                    // Bug #98 修复：超限警告展示
                    if let warning = urlExceedWarning {
                        Text(warning)
                            .font(.caption2)
                            .foregroundStyle(Color.theme.red)
                    }
                }
                .padding()
                .background(Color.appCard)
            }
            .accessibilityIdentifier("urlImportSheet") // 添加弹窗主面板测试标识符
            .navigationTitle(L10n.Ingest.batchURLTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(L10n.Common.cancel) { dismiss() }
                        .accessibilityIdentifier("urlImportCancelButton") // 添加取消按钮测试标识符
                }
            }
            .background(PageBackgroundView(accentColor: .appAccent))
        }
    }
}
