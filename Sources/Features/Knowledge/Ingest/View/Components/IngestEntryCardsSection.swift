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

// MARK: - Ingest Entry Cards Section
/// 导入入口卡片组组件
/// 负责展示文件导入、手动录入、网页导入、OCR 扫描等多种导入方式的启动网格
struct IngestEntryCardsSection: View {
    @Binding var showManualForm: Bool
    @Binding var showOCRScan: Bool
    @Binding var newType: PageType
    @Binding var showFileImporter: Bool
    @Binding var showVoiceNote: Bool
    @Binding var showURLImport: Bool
    let isLLMConfigured: Bool
    let onLLMNotConfigured: () -> Void
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// 响应式列配置：iPhone 2列，iPad 自适应多列
    private var columns: [GridItem] {
        if horizontalSizeClass == .regular {
            Array(repeating: GridItem(.flexible(minimum: DesignSystem.Metrics.heroValueSize * FeatureConstants.IngestGrid.flexibleMinMultiplier, maximum: DesignSystem.Metrics.heroValueSize * FeatureConstants.IngestGrid.flexibleMaxMultiplier), spacing: DesignSystem.medium), count: FeatureConstants.IngestGrid.regularColumns) // 80, 180, 12
        } else {
            [GridItem(.flexible()), GridItem(.flexible())]
        }
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: DesignSystem.medium) {
            // 1. File import card
            Button(action: {
                guard isLLMConfigured else { onLLMNotConfigured(); return }
                showFileImporter = true
            }) {
                entryCardContent(
                    title: L10n.Ingest.fileImport,
                    icon: DesignSystem.Icons.docBadgePlus,
                    color: Color.theme.blue
                )
            }
            .buttonStyle(AppCardButtonStyle())
            .accessibilityIdentifier("ingest.file")
            .accessibilityLabel(L10n.Ingest.fileImport)
            .accessibilityAddTraits(.isButton)

            // 2. Manual entry card
            Button(action: {
                guard isLLMConfigured else { onLLMNotConfigured(); return }
                showManualForm = true
            }) {
                entryCardContent(
                    title: L10n.Ingest.manualEntry,
                    icon: DesignSystem.Icons.pencilClipboard,
                    color: Color.theme.orange
                )
            }
            .buttonStyle(AppCardButtonStyle())
            .accessibilityIdentifier("ingest.manual")
            .accessibilityLabel(L10n.Ingest.manualEntry)
            .accessibilityAddTraits(.isButton)

            // 3. URL import card
            Button(action: {
                guard isLLMConfigured else { onLLMNotConfigured(); return }
                showURLImport = true
            }) {
                entryCardContent(
                    title: L10n.Ingest.urlImport,
                    icon: DesignSystem.Icons.link,
                    color: Color.theme.teal
                )
            }
            .buttonStyle(AppCardButtonStyle())
            .accessibilityIdentifier("ingest.url")
            .accessibilityLabel(L10n.Ingest.urlImport)
            .accessibilityAddTraits(.isButton)

            // 4. OCR entry card
            Button(action: {
                guard isLLMConfigured else { onLLMNotConfigured(); return }
                showOCRScan = true
            }) {
                entryCardContent(
                    title: L10n.Ingest.ocrScan,
                    icon: DesignSystem.Icons.ocr,
                    color: Color.theme.purple
                )
            }
            .buttonStyle(AppCardButtonStyle())
            .accessibilityIdentifier("ingest.ocr")
            .accessibilityLabel(L10n.Ingest.ocrScan)
            .accessibilityAddTraits(.isButton)

            // 5. Clipboard import card
            Button(action: {
                guard isLLMConfigured else { onLLMNotConfigured(); return }
                NotificationCenter.default.post(name: .importFromClipboard, object: nil)
            }) {
                entryCardContent(
                    title: L10n.Ingest.clipboardImport,
                    icon: DesignSystem.Icons.docOnClipboard,
                    color: Color.theme.green
                )
            }
            .buttonStyle(AppCardButtonStyle())
            .accessibilityIdentifier("ingest.clipboard")
            .accessibilityLabel(L10n.Ingest.clipboardImport)
            .accessibilityAddTraits(.isButton)

            // 6. Voice note card
            Button(action: {
                guard isLLMConfigured else { onLLMNotConfigured(); return }
                showVoiceNote = true
            }) {
                entryCardContent(
                    title: L10n.Ingest.voiceNote,
                    icon: DesignSystem.Icons.waveform,
                    color: Color.theme.red
                )
            }
            .buttonStyle(AppCardButtonStyle())
            .accessibilityIdentifier("ingest.voice")
            .accessibilityLabel(L10n.Ingest.voiceNote)
            .accessibilityAddTraits(.isButton)
        }
    }

    private func entryCardContent(title: String, icon: String, color: Color) -> some View {
        VStack(spacing: DesignSystem.tiny) {
            ZStack {
                Circle()
                    .fill(color.opacity(Reference.Opacity.ten)) // 0.1 最近档舍入
                    .frame(width: DesignSystem.Metrics.largeIconBoxSize, height: DesignSystem.Metrics.largeIconBoxSize)
                Image(systemName: icon)
                    .font(.system(size: DesignSystem.iconMedium, weight: .semibold))
                    .foregroundStyle(color)
            }
            
            Text(title)
                .font(.system(size: DesignSystem.Metrics.dashboardLabelSize, weight: .bold))
                .foregroundStyle(.appText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.standardPadding)
        .appMetricCardStyle(color: color, cornerRadius: DesignSystem.standardRadius)
    }
}
