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

// MARK: - 文件类型分类器（消除 categoryDisplayName/fileIcon/categoryColor 的重复 case 块）
/// 根据文件扩展名统一推断显示名、图标与颜色
private enum FileTypeClassifier {
    enum FileKind {
        case pdf, markdown, word, excel, ppt, image, audio, text, archive, other
    }

    /// 根据扩展名推断文件类型
    static func kind(for ext: String) -> FileKind {
        switch ext {
        case FeatureConstants.FileExtension.pdf: return .pdf
        case FeatureConstants.FileExtension.md, FeatureConstants.FileExtension.markdown: return .markdown
        case FeatureConstants.FileExtension.doc, FeatureConstants.FileExtension.docx: return .word
        case FeatureConstants.FileExtension.xls, FeatureConstants.FileExtension.xlsx, FeatureConstants.FileExtension.csv: return .excel
        case FeatureConstants.FileExtension.ppt, FeatureConstants.FileExtension.pptx: return .ppt
        case FeatureConstants.FileExtension.png, FeatureConstants.FileExtension.jpg, FeatureConstants.FileExtension.jpeg, FeatureConstants.FileExtension.heic, FeatureConstants.FileExtension.webp: return .image
        case FeatureConstants.FileExtension.mp3, FeatureConstants.FileExtension.m4a, FeatureConstants.FileExtension.wav: return .audio
        case FeatureConstants.FileExtension.txt, FeatureConstants.FileExtension.json, FeatureConstants.FileExtension.swift, FeatureConstants.FileExtension.py: return .text
        case FeatureConstants.FileExtension.zip, FeatureConstants.FileExtension.tar, FeatureConstants.FileExtension.gz: return .archive
        default: return .other
        }
    }

    /// 文件类型显示名
    static func displayName(for ext: String) -> String {
        switch kind(for: ext) {
        case .pdf: return FeatureConstants.FileTypeName.pdf
        case .markdown: return FeatureConstants.FileTypeName.markdown
        case .word: return FeatureConstants.FileTypeName.word
        case .excel: return FeatureConstants.FileTypeName.excel
        case .ppt: return FeatureConstants.FileTypeName.ppt
        case .text: return FeatureConstants.FileTypeName.txt
        case .image, .audio, .archive, .other: return L10n.Ingest.fileImport
        }
    }

    /// 文件类型 SF Symbol 图标
    static func icon(for ext: String) -> String {
        switch kind(for: ext) {
        case .pdf: return "doc.richtext.fill"
        case .markdown: return "m.square.fill"
        case .word: return "w.square.fill"
        case .excel: return "x.square.fill"
        case .ppt: return "p.square.fill"
        case .image: return "photo.fill"
        case .audio: return "waveform.circle.fill"
        case .text: return "doc.plaintext.fill"
        case .archive: return "doc.zipper.fill"
        case .other: return "doc.text.fill"
        }
    }

    /// 文件类型主题色
    static func color(for ext: String) -> Color {
        switch kind(for: ext) {
        case .pdf: return Color.theme.red
        case .markdown: return Color.theme.blue
        case .word: return Color.theme.blue
        case .excel: return Color.theme.green
        case .ppt: return Color.theme.orange
        case .image: return Color.theme.purple
        case .text: return Color.theme.teal
        case .audio, .archive, .other: return Color.theme.orange
        }
    }
}

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
                    categoryPill(text: categoryDisplayName, color: categoryColor, textColor: .white)

                    if !tagList.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: DesignSystem.atomic) {
                                ForEach(tagList, id: \.self) { tag in
                                    categoryPill(
                                        text: tag,
                                        color: Color.appAccent.opacity(DesignSystem.Opacity.subtle),
                                        textColor: .appAccent,
                                        weight: .medium
                                    )
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
        .cardStyle(
            horizontalPadding: DesignSystem.medium,
            verticalPadding: DesignSystem.medium,
            backgroundOpacity: DesignSystem.Opacity.dim,
            cornerRadius: DesignSystem.cardRadius
        )
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
            timestampLabel(record.createdAt, icon: DesignSystem.Icons.clock)
            if record.status == ImportRecordStatus.done, let done = record.completedAt {
                timestampLabel(done, icon: DesignSystem.Icons.flagCheckered)
            }
        }
        .foregroundStyle(.tertiary)
    }

    /// 时间戳 Label，消除 timeLine 中 createdAt/completedAt 两处重复的 formatted+font 链
    private func timestampLabel(_ date: Date, icon: String) -> some View {
        Label(date.formatted(date: .numeric, time: .shortened), systemImage: icon)
            .font(.caption2)
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
            return FileTypeClassifier.displayName(for: detectedExtension)
        case .link: return L10n.Ingest.urlImport
        case .manual: return L10n.Ingest.manualEntry
        case .ocr: return L10n.Ingest.ocrScan
        case .voice: return L10n.Ingest.voiceNote
        default: return categoryValue?.displayName ?? L10n.Common.unknown
        }
    }

    private var fileIcon: String {
        FileTypeClassifier.icon(for: detectedExtension)
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
            return FileTypeClassifier.color(for: detectedExtension)
        case .link: return Color.theme.cyan
        case .manual: return Color.theme.green
        case .ocr: return Color.theme.purple
        case .clipboard: return Color.theme.gray
        case .voice: return Color.theme.pink
        case nil: return .secondary
        }
    }

    /// 分类胶囊标签，消除来源类型与 AI 标签的重复修饰符链
    @ViewBuilder
    private func categoryPill(text: String, color: Color, textColor: Color, weight: Font.Weight = .bold) -> some View {
        Text(text)
            .font(.caption2.weight(weight))
            .padding(.horizontal, DesignSystem.tightPadding)
            .padding(.vertical, SystemSpacing.atomic)
            .background(Capsule().fill(color))
            .foregroundStyle(textColor)
    }
}
