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

struct ImportRecordCard: View {
    let record: ImportRecord
    var onTap: (() -> Void)?
    var onPreview: (() -> Void)?
    var onOpenWith: (() -> Void)?
    var onEdit: (() -> Void)?

    private var categoryValue: ImportCategory? { ImportCategory(rawValue: record.category) }
    private var canPreview: Bool { record.filePath != nil || record.rawText != nil || record.sourceURL != nil }
    private var canViewPage: Bool { record.pageID != nil && record.status == ImportRecordStatus.done }
    private var canOpenFile: Bool { record.filePath != nil }
    private var tagList: [String] {
        record.tags?.components(separatedBy: ", ").filter { !$0.isEmpty } ?? []
    }

    var body: some View {
        HStack(spacing: DesignSystem.medium) {
            Image(systemName: categoryIcon)
                .font(.title3)
                .foregroundStyle(categoryColor)
                .frame(width: DesignSystem.Metrics.customSize36, height: DesignSystem.Metrics.customSize36)
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
                        .padding(.vertical, 2)
                        .background(Capsule().fill(categoryColor))
                        .foregroundStyle(.white)
                    
                    if !tagList.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: DesignSystem.atomic) {
                                ForEach(tagList, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption2.weight(.medium))
                                        .padding(.horizontal, DesignSystem.tightPadding)
                                        .padding(.vertical, 2)
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
                    Label(L10n.Ingest.openWith, systemImage: "square.and.arrow.up")
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
                        Label(ByteCountFormatter.string(fromByteCount: size, countStyle: .file), systemImage: "doc")
                    }
                    if let url = record.sourceURL, let host = URL(string: url)?.host {
                        Text("·")
                        Label(host, systemImage: "link")
                    }
                }
            case .link:
                if let url = record.sourceURL, let host = URL(string: url)?.host {
                    Label(host, systemImage: "link")
                }
            case .voice:
                Label(L10n.Ingest.voiceNote, systemImage: "waveform")
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
            Label(record.createdAt.formatted(date: .numeric, time: .shortened), systemImage: "clock")
                .font(.caption2)
            if record.status == ImportRecordStatus.done, let done = record.completedAt {
                Label(done.formatted(date: .numeric, time: .shortened), systemImage: "flag.checkered")
                    .font(.caption2)
            }
        }
        .foregroundStyle(.tertiary)
    }

    // MARK: - 状态

    @ViewBuilder
    private var statusBadge: some View {
        switch record.status {
        case "done":
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case ImportRecordStatus.failed:
            Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
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
        if titleLower.contains(".pdf") || titleLower.contains("pdf") { return "pdf" }
        if titleLower.contains(".md") || titleLower.contains("markdown") { return "md" }
        if titleLower.contains(".doc") || titleLower.contains("word") { return "docx" }
        if titleLower.contains(".xls") || titleLower.contains("excel") { return "xlsx" }
        if titleLower.contains(".ppt") { return "pptx" }
        return ""
    }

    private var categoryDisplayName: String {
        switch categoryValue {
        case .file:
            switch detectedExtension {
            case "pdf": return "PDF"
            case "md", "markdown": return "Markdown"
            case "doc", "docx": return "Word"
            case "xls", "xlsx", "csv": return "Excel"
            case "ppt", "pptx": return "PPT"
            case "txt", "json", "swift", "py": return "TXT"
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
        case "pdf": return "doc.richtext.fill"
        case "md", "markdown": return "m.square.fill"
        case "doc", "docx": return "w.square.fill"
        case "xls", "xlsx", "csv": return "x.square.fill"
        case "ppt", "pptx": return "p.square.fill"
        case "png", "jpg", "jpeg", "heic", "webp": return "photo.fill"
        case "mp3", "m4a", "wav": return "waveform.circle.fill"
        case "txt", "json", "swift", "py": return "doc.plaintext.fill"
        case "zip", "tar", "gz": return "doc.zipper.fill"
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
            case "pdf": return .red
            case "md", "markdown": return .blue
            case "doc", "docx": return .blue
            case "xls", "xlsx", "csv": return .green
            case "ppt", "pptx": return .orange
            case "png", "jpg", "jpeg", "heic", "webp": return .purple
            case "txt", "json", "swift", "py": return .teal
            default: return .orange
            }
        case .link: return .cyan
        case .manual: return .green
        case .ocr: return .purple
        case .clipboard: return .gray
        case .voice: return .pink
        case nil: return .secondary
        }
    }
}
