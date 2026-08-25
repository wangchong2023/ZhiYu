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
        VStack(alignment: .leading, spacing: DesignSystem.standardPadding) {
            // 1. 物理载体展示窗口 (Source Player / Canvas)
            playerCanvasSection
            
            // 2. 提取关系溯源链 (Extraction Lineage)
            extractionLineageSection
            
            Divider()
                .opacity(DesignSystem.softOpacity)
            
            // 3. 正文转录详细内容区
            VStack(alignment: .leading, spacing: DesignSystem.small) {
                Text(L10n.Ingest.PDF.contentPreview)
                    .font(.caption2.bold())
                    .foregroundStyle(.appSecondary)
                
                MarkdownRendererView(
                    content: bodyText.isEmpty ? page.content : bodyText,
                    isPrivate: page.isPrivate,
                    onLinkTap: onLinkTap
                )
            }
        }
        .onAppear {
            parseMarkdownData()
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
    
    /// 解析 Markdown 及头部 Frontmatter
    private func parseMarkdownData() {
        let (fmStr, bodyPart) = FrontmatterParser.split(content: page.content)
        self.bodyText = bodyPart
        if let fm = fmStr, let decoded = FrontmatterParser.parse(SourceFrontmatter.self, from: fm) {
            self.frontmatter = decoded
        }
    }
    
    // MARK: - 1. 物理载体展示窗口 (Source Player / Canvas)
    private var playerCanvasSection: some View {
        let type = frontmatter?.type ?? page.sourceType?.lowercased() ?? ""
        
        return Group {
            if type == "voice" || type == "audio" || type == "mp3" || type == "m4a" || type == "wav" {
                audioPlayerWindow
            } else if type == "ocr" || type == "png" || type == "jpg" || type == "jpeg" {
                ocrCanvasWindow
            } else {
                documentPreviewWindow
            }
        }
    }
    
    /// 语音/音频播放器窗口
    private var audioPlayerWindow: some View {
        VStack(spacing: DesignSystem.medium) {
            // 播放器状态栏
            HStack {
                Label(L10n.Ingest.audioSubtitle, systemImage: "waveform.circle.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.appAccent)
                Spacer()
                Text(L10n.Dashboard.totalStorage) // 用大资产做格式化
                    .font(.caption2)
                    .foregroundStyle(.appSecondary)
            }
            
            // 发光声波波形图
            let waves = frontmatter?.voiceAmplitudeWaveform ?? Self.defaultWaveform
            HStack(spacing: Spacing.small) {
                ForEach(Array(waves.enumerated()), id: \.offset) { _, wave in
                    let scale = isPlaying ? Double.random(in: 0.6...1.2) : 1.0
                    RoundedRectangle(cornerRadius: Spacing.microRadius)
                        .fill(
                            LinearGradient(
                                colors: [Color.appAccent, Color.appAccent.opacity(DesignSystem.Opacity.disabled)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(
                            width: Spacing.small,
                            height: CGFloat(wave) * Self.waveMaxHeight * CGFloat(scale)
                        )
                        .animation(.easeInOut(duration: 0.2), value: scale)
                }
            }
            .frame(height: Self.waveMaxHeight)
            
            // 播放控制器
            HStack(spacing: DesignSystem.wide) {
                Button(action: {
                    isPlaying.toggle()
                    if isPlaying {
                        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                            Task { @MainActor in
                                if playProgress < 1.0 {
                                    playProgress += 0.01
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
                        .font(.system(size: DesignSystem.large))
                        .foregroundStyle(.appAccent)
                }
                .buttonStyle(.plain)
                
                // 播放进度条
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.appBorder)
                            .frame(height: Spacing.atomic)
                        Capsule()
                            .fill(Color.appAccent)
                            .frame(width: geo.size.width * CGFloat(playProgress), height: Spacing.atomic)
                    }
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }
                .frame(height: Spacing.atomic)
            }
        }
        .padding(DesignSystem.standardPadding)
        .background(Color.appCard.opacity(DesignSystem.Opacity.ghost))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.standardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.standardRadius)
                .stroke(Color.appBorder, lineWidth: DesignSystem.borderWidth)
        )
    }
    
    /// OCR 扫描图片文字窗口
    private var ocrCanvasWindow: some View {
        VStack(alignment: .leading, spacing: DesignSystem.medium) {
            Label(L10n.Ingest.OCR.previewTitle, systemImage: "viewfinder")
                .font(.subheadline.bold())
                .foregroundStyle(.appSecondary)
            
            ZStack {
                // 毛玻璃渐变大卡底板，模拟照片画板
                RoundedRectangle(cornerRadius: DesignSystem.standardRadius)
                    .fill(Color.appCard.opacity(DesignSystem.Opacity.subtle))
                    .frame(height: Self.canvasHeight)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.standardRadius)
                            .stroke(Color.appBorder, lineWidth: DesignSystem.borderWidth)
                    )
                
                // 模拟高亮点击文字热区
                VStack(spacing: Spacing.small) {
                    Text(L10n.Vault.raw.ocrSimulated)
                        .font(.caption2)
                        .foregroundStyle(.appSecondary)
                    
                    HStack(spacing: Spacing.small) {
                        Text(L10n.Vault.raw.detectedTextZone)
                            .font(.system(size: SystemFontSize.nano, design: .monospaced)) // Dynamic Type
                            .foregroundStyle(.appAccent)
                            .padding(.horizontal, Spacing.tiny)
                            .padding(.vertical, Spacing.atomic)
                            .background(Color.appAccent.opacity(DesignSystem.subtleFillOpacity))
                            .clipShape(RoundedRectangle(cornerRadius: Spacing.microRadius))
                            .overlay(
                                RoundedRectangle(cornerRadius: Spacing.microRadius)
                                    .stroke(Color.appAccent.opacity(DesignSystem.Opacity.disabled), lineWidth: Self.ocrBoxBorderWidth)
                            )
                    }
                    .shadow(color: Color.appAccent.opacity(DesignSystem.Opacity.shadow), radius: 5)
                }
            }
        }
    }
    
    /// 物理文档预览窗口
    private var documentPreviewWindow: some View {
        HStack(spacing: DesignSystem.medium) {
            Image(systemName: "doc.richtext.fill")
                .font(.system(size: DesignSystem.large))
                .foregroundStyle(.appAccent)
                .frame(width: DesignSystem.Metrics.largeIconBoxSize, height: DesignSystem.Metrics.largeIconBoxSize)
                .background(Color.appAccent.opacity(DesignSystem.glassOpacity))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.smallRadius))
            
            VStack(alignment: .leading, spacing: DesignSystem.atomic) {
                Text(frontmatter?.fileName ?? page.displaySourceName)
                    .font(.caption.bold())
                    .foregroundStyle(.appText)
                    .lineLimit(1)
                
                HStack(spacing: Spacing.small) {
                    Text(page.sourceType?.uppercased() ?? "FILE")
                        .font(.system(size: SystemFontSize.nano, weight: .heavy)) // Dynamic Type
                        .foregroundStyle(.appAccent)
                        .padding(.horizontal, Spacing.tiny)
                        .padding(.vertical, SystemSpacing.divider)
                        .background(Color.appAccent.opacity(DesignSystem.subtleFillOpacity))
                        .cornerRadius(Spacing.microRadius)
                    
                    if let size = frontmatter?.fileSize ?? page.fileSize {
                        Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                            .font(.caption2)
                            .foregroundStyle(.appSecondary)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appCard.opacity(DesignSystem.Opacity.ghost))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.standardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.standardRadius)
                .stroke(Color.appBorder, lineWidth: DesignSystem.borderWidth)
        )
    }
    
    // MARK: - 2. 提取关系溯源链 (Extraction Lineage)
    private var extractionLineageSection: some View {
        let refs = frontmatter?.extractedPageIDs ?? []
        
        return Group {
            if !refs.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.small) {
                    Label(L10n.Ingest.resultTitle, systemImage: "sparkles")
                        .font(.subheadline.bold())
                        .foregroundStyle(.appAccent)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Spacing.small) {
                            ForEach(refs, id: \.pageID) { ref in
                                Button(action: {
                                    onLinkTap(ref.name)
                                }) {
                                    HStack(spacing: Spacing.atomic) {
                                        Image(systemName: ref.type == "concept" ? "books.vertical.fill" : "person.text.rectangle.fill")
                                            .font(.system(size: SystemFontSize.nano)) // Dynamic Type
                                        Text(ref.name)
                                            .font(.caption2.bold())
                                    }
                                    .foregroundStyle(ref.type == "concept" ? Color.theme.teal : Color.theme.yellow)
                                    .padding(.horizontal, Spacing.Chip.horizontalPadding)
                                    .padding(.vertical, Spacing.atomic)
                                    .background(Color.appCard.opacity(DesignSystem.Opacity.subtle))
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .stroke(ref.type == "concept" ? Color.theme.teal.opacity(DesignSystem.Opacity.disabled) : Color.theme.yellow.opacity(DesignSystem.Opacity.disabled), lineWidth: SystemStroke.divider)
                                    )
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
