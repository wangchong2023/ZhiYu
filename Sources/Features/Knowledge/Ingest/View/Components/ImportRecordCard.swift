//
//  ImportRecordCard.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/10.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：导入原始内容卡片组件

import SwiftUI
import UFPCore

struct ImportRecordCard: View {
    let record: ImportRecord
    var onTap: (() -> Void)?
    var onPreview: (() -> Void)?
    var onOpenWith: (() -> Void)?
    var onEdit: (() -> Void)?

    private var categoryValue: ImportCategory? { ImportCategory(rawValue: record.category) }
    private var canOpenFile: Bool { record.filePath != nil }
    private var tagList: [String] {
        record.tags?.components(separatedBy: SystemConstants.Separator.commaSpace).filter { !$0.isEmpty } ?? []
    }

    var body: some View {
        HStack(spacing: DesignSystem.medium) {
            Image(systemName: categoryIcon)
                .font(.title3)
                .foregroundStyle(categoryColor)
                .frame(width: DesignSystem.Metrics.iconBoxSize, height: DesignSystem.Metrics.iconBoxSize)
                .background(categoryColor.opacity(DesignSystem.Opacity.subtle))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.smallRadius))

            VStack(alignment: .leading, spacing: DesignSystem.tiny) {
                Text(record.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                
                // 来源类型与 AI 标签行
                HStack(spacing: DesignSystem.atomic) {
                    // 来源类型胶囊标签 (使用高对比度的精致色彩背景)
                    Text(categoryDisplayName)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, DesignSystem.tightPadding)
                        .padding(.vertical, SystemSpacing.atomic)
                        .background(Capsule().fill(categoryColor))
                        .foregroundStyle(.white)
                    
                    if !tagList.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: DesignSystem.atomic) {
                                ForEach(tagList, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption2.weight(.medium))
                                        .padding(.horizontal, DesignSystem.tightPadding)
                                        .padding(.vertical, SystemSpacing.atomic)
                                        .background(Capsule().fill(Color.appAccent.opacity(DesignSystem.Opacity.subtle)))
                                        .foregroundStyle(.appAccent)
                                }
                            }
                        }
                    }
                }
                detailLine
                timeLine
            }
            Spacer()
            statusBadge
        }
        .padding(DesignSystem.medium)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cardRadius))
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
        .contextMenu {
            if canOpenFile {
                Button(action: { onOpenWith?() }) {
                    Label(L10n.Ingest.openWith, systemImage: DesignSystem.Icons.export)
                }
            }
        }
    }

    // MARK: - 信息行

    /// 计算导入内容的占用空间大小
    private var storageSize: String? {
        if let size = record.fileSize, size > 0 {
            return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        }
        if let text = record.rawText, !text.isEmpty {
            let bytes = Int64(text.lengthOfBytes(using: .utf8))
            return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        }
        return nil
    }

    @ViewBuilder
    private var detailLine: some View {
        HStack(spacing: DesignSystem.tightPadding) {
            switch categoryValue {
            case .file:
                HStack(spacing: DesignSystem.tightPadding) {
                    if let size = record.fileSize {
                        Label(ByteCountFormatter.string(fromByteCount: size, countStyle: .file), systemImage: DesignSystem.Icons.doc)
                    }
                    if let url = record.sourceURL, let host = URL(string: url)?.host {
                        Text(FeatureConstants.Decorator.middleDot)
                        Label(host, systemImage: DesignSystem.Icons.link)
                    }
                }
            case .link:
                if let url = record.sourceURL, let host = URL(string: url)?.host {
                    Label(host, systemImage: DesignSystem.Icons.link)
                }
            case .voice:
                Label(L10n.Ingest.voiceNote, systemImage: DesignSystem.Icons.waveform)
            default:
                EmptyView()
            }
            Spacer()
            if let size = storageSize {
                Text(size)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var timeLine: some View {
        HStack(spacing: DesignSystem.small) {
            Label(record.createdAt.formatted(date: .numeric, time: .shortened), systemImage: DesignSystem.Icons.clock)
                .font(.caption2)
            if record.status == ImportRecordStatus.done, let done = record.completedAt {
                Label(done.formatted(date: .numeric, time: .shortened), systemImage: DesignSystem.Icons.flagCheckered)
                    .font(.caption2)
            }
        }
        .foregroundStyle(.tertiary)
    }

    // MARK: - 状态

    @ViewBuilder
    private var statusBadge: some View {
        switch record.status {
        case FeatureConstants.ImportStatus.done:
            Image(systemName: DesignSystem.Icons.checkCircle).foregroundStyle(Color.theme.green)
        case ImportRecordStatus.failed:
            Image(systemName: DesignSystem.Icons.errorCircle).foregroundStyle(.red)
        default:
            ProgressView().scaleEffect(0.8)
        }
    }

    // MARK: - 分类与扩展名精细化识别

    /// 从文件路径或标题中智能化推断文件扩展名
    private var detectedExtension: String {
        if let path = record.filePath, !path.isEmpty {
            let ext = (path as NSString).pathExtension.lowercased()
            if !ext.isEmpty { return ext }
        }
        let titleExt = (record.title as NSString).pathExtension.lowercased()
        if !titleExt.isEmpty { return titleExt }

        let titleLower = record.title.lowercased()
        if titleLower.contains(".\(SystemConstants.FileExtension.pdf)") || titleLower.contains(SystemConstants.FileExtension.pdf) { return SystemConstants.FileExtension.pdf }
        if titleLower.contains(".\(SystemConstants.FileExtension.markdown)") || titleLower.contains(SystemConstants.FileExtension.markdownLong) { return SystemConstants.FileExtension.markdown }
        if titleLower.contains(".\(SystemConstants.FileExtension.doc)") || titleLower.contains(FeatureConstants.FileTypeName.word) { return SystemConstants.FileExtension.docx }
        if titleLower.contains(".\(SystemConstants.FileExtension.xls)") || titleLower.contains(FeatureConstants.FileTypeName.excel) { return SystemConstants.FileExtension.xlsx }
        if titleLower.contains(".\(SystemConstants.FileExtension.ppt)") { return SystemConstants.FileExtension.pptx }
        return ""
    }

    private var categoryDisplayName: String {
        switch categoryValue {
        case .file:
            switch detectedExtension {
            case FeatureConstants.FileExtension.pdf: return FeatureConstants.FileTypeName.pdf
            case FeatureConstants.FileExtension.md, FeatureConstants.FileExtension.markdown: return FeatureConstants.FileTypeName.markdown
            case FeatureConstants.FileExtension.doc, FeatureConstants.FileExtension.docx: return FeatureConstants.FileTypeName.word
            case FeatureConstants.FileExtension.xls, FeatureConstants.FileExtension.xlsx, FeatureConstants.FileExtension.csv: return FeatureConstants.FileTypeName.excel
            case FeatureConstants.FileExtension.ppt, FeatureConstants.FileExtension.pptx: return FeatureConstants.FileTypeName.ppt
            case FeatureConstants.FileExtension.txt, FeatureConstants.FileExtension.json, FeatureConstants.FileExtension.swift, FeatureConstants.FileExtension.py: return FeatureConstants.FileTypeName.txt
            default: return L10n.Ingest.fileImport
            }
        case .link: return L10n.Ingest.urlImport
        case .manual: return L10n.Ingest.manualEntry
        case .ocr: return L10n.Ingest.ocrScan
        case .voice: return L10n.Ingest.voiceNote
        default: return categoryValue?.displayName ?? L10n.Common.unknown
        }
    }

    private var fileIcon: String {
        switch detectedExtension {
        case FeatureConstants.FileExtension.pdf: return "doc.richtext.fill"
        case FeatureConstants.FileExtension.md, FeatureConstants.FileExtension.markdown: return "m.square.fill"
        case FeatureConstants.FileExtension.doc, FeatureConstants.FileExtension.docx: return "w.square.fill"
        case FeatureConstants.FileExtension.xls, FeatureConstants.FileExtension.xlsx, FeatureConstants.FileExtension.csv: return "x.square.fill"
        case FeatureConstants.FileExtension.ppt, FeatureConstants.FileExtension.pptx: return "p.square.fill"
        case FeatureConstants.FileExtension.png, FeatureConstants.FileExtension.jpg, FeatureConstants.FileExtension.jpeg, FeatureConstants.FileExtension.heic, FeatureConstants.FileExtension.webp: return "photo.fill"
        case FeatureConstants.FileExtension.mp3, FeatureConstants.FileExtension.m4a, FeatureConstants.FileExtension.wav: return "waveform.circle.fill"
        case FeatureConstants.FileExtension.txt, FeatureConstants.FileExtension.json, FeatureConstants.FileExtension.swift, FeatureConstants.FileExtension.py: return "doc.plaintext.fill"
        case FeatureConstants.FileExtension.zip, FeatureConstants.FileExtension.tar, FeatureConstants.FileExtension.gz: return "doc.zipper.fill"
        default: return "doc.text.fill"
        }
    }

    private var categoryIcon: String {
        switch categoryValue {
        case .link: return "safari.fill"
        case .file: return fileIcon
        case .manual: return "square.and.pencil"
        case .ocr: return "camera.viewfinder"
        case .clipboard: return "doc.on.clipboard.fill"
        case .voice: return "waveform"
        case nil: return "doc.fill"
        }
    }

    private var categoryColor: Color {
        switch categoryValue {
        case .file:
            switch detectedExtension {
            case FeatureConstants.FileExtension.pdf: return Color.theme.red
            case FeatureConstants.FileExtension.md, FeatureConstants.FileExtension.markdown: return Color.theme.blue
            case FeatureConstants.FileExtension.doc, FeatureConstants.FileExtension.docx: return Color.theme.blue
            case FeatureConstants.FileExtension.xls, FeatureConstants.FileExtension.xlsx, FeatureConstants.FileExtension.csv: return Color.theme.green
            case FeatureConstants.FileExtension.ppt, FeatureConstants.FileExtension.pptx: return Color.theme.orange
            case FeatureConstants.FileExtension.png, FeatureConstants.FileExtension.jpg, FeatureConstants.FileExtension.jpeg, FeatureConstants.FileExtension.heic, FeatureConstants.FileExtension.webp: return Color.theme.purple
            case FeatureConstants.FileExtension.txt, FeatureConstants.FileExtension.json, FeatureConstants.FileExtension.swift, FeatureConstants.FileExtension.py: return Color.theme.teal
            default: return Color.theme.orange
            }
        case .link: return Color.theme.cyan
        case .manual: return Color.theme.green
        case .ocr: return Color.theme.purple
        case .clipboard: return Color.theme.gray
        case .voice: return Color.theme.pink
        case nil: return .secondary
        }
    }
}
