//
//  SourceDetailBodyView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/21.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：渲染“来源 (Source)”类型页面的差异化排版，根据多维物理载体展示播放器/画布，展现提取出的知识关系溯源双向跳转链路。
//

import SwiftUI
import UFPCore
import UFPDesignSystem

/// [L3] 表现层：来源页面差异化详情视图
struct SourceDetailBodyView: View {
    let page: KnowledgePage
    let onLinkTap: (String) -> Void
    
    @State private var frontmatter: SourceFrontmatter?
    @State private var bodyText: String = ""
    
    // 音频播放控制相关的交互状态
    @State private var isPlaying = false
    @State private var playProgress: Double = 0.0
    @State private var timer: Timer?
    
    // 布局常量，防止魔鬼数字
    private static let canvasHeight: CGFloat = 160
    private static let waveMaxHeight: CGFloat = 50
    private static let ocrBoxBorderWidth: CGFloat = 1.0
    private static let defaultWaveform: [Double] = [0.15, 0.45, 0.72, 0.88, 0.52, 0.22, 0.65, 0.81, 0.35, 0.12]
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.standardPadding) {
            // 1. 物理载体展示窗口 (Source Player / Canvas)
            playerCanvasSection
            
            // 2. 提取关系溯源链 (Extraction Lineage)
            extractionLineageSection
            
            DetailBodyEpilogue(page: page, bodyText: bodyText, onLinkTap: onLinkTap, sectionTitle: L10n.Ingest.PDF.contentPreview)
        }
        .detailBodyOnAppear(
            content: page.content,
            frontmatterType: SourceFrontmatter.self,
            bodyText: $bodyText,
            frontmatter: $frontmatter
        )
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
    
    // MARK: - 1. 物理载体展示窗口 (Source Player / Canvas)
    private var playerCanvasSection: some View {
        let type = frontmatter?.type ?? page.sourceType?.lowercased() ?? ""
        
        return Group {
            if type == FeatureConstants.SourceType.voice || type == FeatureConstants.SourceType.audio || type == SystemConstants.FileExtension.mp3 || type == SystemConstants.FileExtension.m4a || type == SystemConstants.FileExtension.wav {
                audioPlayerWindow
            } else if type == FeatureConstants.SourceType.ocr || type == SystemConstants.FileExtension.png || type == SystemConstants.FileExtension.jpg || type == SystemConstants.FileExtension.jpeg {
                ocrCanvasWindow
            } else {
                documentPreviewWindow
            }
        }
    }
    
    /// 语音/音频播放器窗口
    private var audioPlayerWindow: some View {
        VStack(spacing: DesignTokens.Spacing.medium) {
            // 播放器状态栏
            HStack {
                Label(L10n.Ingest.audioSubtitle, systemImage: DesignTokens.Icons.waveformCircleFill)
                    .font(.subheadline.bold())
                    .foregroundStyle(.appAccent)
                Spacer()
                Text(L10n.Dashboard.totalStorage) // 用大资产做格式化
                    .font(.caption2)
                    .foregroundStyle(.appSecondary)
            }
            
            // 发光声波波形图
            let waves = frontmatter?.voiceAmplitudeWaveform ?? Self.defaultWaveform
            HStack(spacing: DesignTokens.Spacing.small) {
                ForEach(Array(waves.enumerated()), id: \.offset) { _, wave in
                    let scale = isPlaying ? Double.random(in: 0.6...1.2) : 1.0
                    RoundedRectangle(cornerRadius: DesignTokens.Spacing.microRadius)
                        .fill(
                            LinearGradient(
                                colors: [Color.appAccent, Color.appAccent.opacity(DesignTokens.Opacity.disabled)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(
                            width: DesignTokens.Spacing.small,
                            height: CGFloat(wave) * Self.waveMaxHeight * CGFloat(scale)
                        )
                        .animation(.easeInOut(duration: 0.2), value: scale)
                }
            }
            .frame(height: Self.waveMaxHeight)
            
            // 播放控制器
            HStack(spacing: DesignTokens.Spacing.wide) {
                Button(action: {
                    isPlaying.toggle()
                    if isPlaying {
                        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                            Task { @MainActor in
                                if playProgress < 1.0 {
                                    playProgress += FeatureConstants.PlaybackProgress.step
                                } else {
                                    playProgress = 0.0
                                    isPlaying = false
                                    timer?.invalidate()
                                }
                            }
                        }
                    } else {
                        timer?.invalidate()
                    }
                }) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: DesignTokens.Spacing.large))
                        .foregroundStyle(.appAccent)
                }
                .buttonStyle(.plain)
                
                // 播放进度条
                GeometryReader { geo in
                    InsightProgressBar(progress: Double(playProgress))
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }
                .frame(height: DesignTokens.Spacing.atomic)
            }
        }
        .appCardStyle(cornerRadius: DesignTokens.Spacing.standardRadius)
    }
    
    /// OCR 扫描图片文字窗口
    private var ocrCanvasWindow: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
            InsightSectionHeader(title: L10n.Ingest.OCR.previewTitle, icon: DesignTokens.Icons.viewfinder)
            
            ZStack {
                // 毛玻璃渐变大卡底板，模拟照片画板
                RoundedRectangle(cornerRadius: DesignTokens.Spacing.standardRadius)
                    .fill(Color.appCard.opacity(DesignTokens.Opacity.subtle))
                    .frame(height: Self.canvasHeight)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Spacing.standardRadius)
                            .stroke(Color.appBorder, lineWidth: DesignTokens.Spacing.borderWidth)
                    )
                
                // 模拟高亮点击文字热区
                VStack(spacing: DesignTokens.Spacing.small) {
                    Text(L10n.Vault.raw.ocrSimulated)
                        .font(.caption2)
                        .foregroundStyle(.appSecondary)
                    
                    HStack(spacing: DesignTokens.Spacing.small) {
                        Text(L10n.Vault.raw.detectedTextZone)
                            .font(.system(size: DesignTokens.SystemFontSize.nano, design: .monospaced)) // Dynamic Type
                            .foregroundStyle(.appAccent)
                            .padding(.horizontal, DesignTokens.Spacing.tiny)
                            .padding(.vertical, DesignTokens.Spacing.atomic)
                            .background(Color.appAccent.opacity(DesignTokens.Colors.subtleFillOpacity))
                            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Spacing.microRadius))
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignTokens.Spacing.microRadius)
                                    .stroke(Color.appAccent.opacity(DesignTokens.Opacity.disabled), lineWidth: Self.ocrBoxBorderWidth)
                            )
                    }
                    .shadow(color: Color.appAccent.opacity(DesignTokens.Opacity.shadow), radius: 5)
                }
            }
        }
    }
    
    /// 物理文档预览窗口
    private var documentPreviewWindow: some View {
        HStack(spacing: DesignTokens.Spacing.medium) {
            AccentIconBox(iconName: DesignTokens.Icons.docRichtext)
            
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.atomic) {
                Text(frontmatter?.fileName ?? page.displaySourceName)
                    .font(.caption.bold())
                    .foregroundStyle(.appText)
                    .lineLimit(1)
                
                HStack(spacing: DesignTokens.Spacing.small) {
                    Text(page.sourceType?.uppercased() ?? "FILE")
                        .font(.system(size: DesignTokens.SystemFontSize.nano, weight: .heavy)) // Dynamic Type
                        .foregroundStyle(.appAccent)
                        .padding(.horizontal, DesignTokens.Spacing.tiny)
                        .padding(.vertical, DesignTokens.SystemSpacing.divider)
                        .background(Color.appAccent.opacity(DesignTokens.Colors.subtleFillOpacity))
                        .cornerRadius(DesignTokens.Spacing.microRadius)
                    
                    if let size = frontmatter?.fileSize ?? page.fileSize {
                        Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                            .font(.caption2)
                            .foregroundStyle(.appSecondary)
                    }
                }
            }
        }
        .infoCardStyle(backgroundOpacity: DesignTokens.Opacity.ghost, cornerRadius: DesignTokens.Spacing.standardRadius, useBorder: true)
    }

    // MARK: - 2. 提取关系溯源链 (Extraction Lineage)
    private var extractionLineageSection: some View {
        let refs = frontmatter?.extractedPageIDs ?? []
        
        return Group {
            if !refs.isEmpty {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
                    InsightSectionHeader(title: L10n.Ingest.resultTitle, icon: DesignTokens.Icons.sparkles, color: .appAccent)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DesignTokens.Spacing.small) {
                            ForEach(refs, id: \.pageID) { ref in
                                Button(action: {
                                    onLinkTap(ref.name)
                                }) {
                                    HStack(spacing: DesignTokens.Spacing.atomic) {
                                        Image(systemName: ref.type == FeatureConstants.SourceType.concept ? DesignTokens.Icons.library : DesignTokens.Icons.entity)
                                            .font(.system(size: DesignTokens.SystemFontSize.nano))
                                        Text(ref.name)
                                            .font(.caption2.bold())
                                    }
                                    .foregroundStyle(ref.type == FeatureConstants.SourceType.concept ? Color.theme.teal : Color.theme.yellow)
                                    .insightTagChipStyle(InsightTagChipStyle(
                                        backgroundColor: .appCard,
                                        backgroundOpacity: DesignTokens.Opacity.subtle,
                                        borderColor: ref.type == FeatureConstants.SourceType.concept ? Color.theme.teal : Color.theme.yellow,
                                        borderWidth: DesignTokens.SystemStroke.divider,
                                        borderOpacity: DesignTokens.Opacity.disabled
                                    ))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 来源信息卡片修饰符
// 已迁移至 DesignSystem: View.infoCardStyle(backgroundOpacity:cornerRadius:useBorder:)
