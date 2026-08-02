//
//  PDFComponents.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：知识摄入：文档导入、URL 抓取、OCR 扫描、PDF 解析。
//
import SwiftUI
#if canImport(PDFKit)
import PDFKit
#endif

// MARK: - PDF Ingest Sheet
/// PDF 资料入库配置面板组件
/// 负责配置 PDF 内容的提取方式（全文、范围或仅高亮），并设定目标 知识库 页面的元数据
struct PDFIngestSheet: View {
    let documentInfo: PDFDocumentInfo
    @Environment(AppStore.self) var store
    @Bindable var ingestStore: IngestStore
    #if canImport(PDFKit)
    let pdfDocument: PDFKit.PDFDocument?
    #endif
    
    @State private var ingestMode = "fullText"
    @State private var pageStart = 1
    @State private var pageEnd = 1
    @State private var targetType = PageType.source
    @State private var targetTitle = ""
    @State private var previewText = ""
    @State private var isLoadingPreview = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                targetSection
                rangeSection
                highlightsSection
                previewSection
            }
            .scrollContentBackground(.hidden)
            .background(PageBackgroundView(accentColor: .appAccent))
            .navigationTitle(L10n.Ingest.PDF.ingestToKnowledge)
.appNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(L10n.Ingest.PDF.ingest) {
                        Task {
                            await ingestContent()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(targetTitle.isEmpty || isLoadingPreview)
                }
            }
            .onAppear {
                targetTitle = documentInfo.title
                pageEnd = documentInfo.pageCount
                updatePreview()
            }
            .onChange(of: ingestMode) { updatePreview() }
            .onChange(of: pageStart) { updatePreview() }
            .onChange(of: pageEnd) { updatePreview() }
        }
    }
    
    // MARK: - Target Section
    private var targetSection: some View {
        Section {
            TextField(L10n.Ingest.PDF.pageTitle, text: $targetTitle)
                .foregroundStyle(.appText)
            
            Picker(L10n.Ingest.PDF.pageType, selection: $targetType) {
                // 遍历用户可见页面类型，屏蔽 raw 选项
                ForEach(PageType.allVisibleCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
        } header: {
            Text(L10n.Ingest.PDF.targetPage)
        }
    }
    
    // MARK: - Range Section
    private var rangeSection: some View {
        Section {
            Picker(L10n.Ingest.PDF.extractionMethod, selection: $ingestMode) {
                Text(L10n.Ingest.PDF.fullText).tag("fullText")
                Text(L10n.Ingest.PDF.pageRange).tag("pageRange")
                Text(L10n.Ingest.PDF.highlightsOnly).tag("highlights")
            }
            #if !os(watchOS)
                .pickerStyle(.segmented)
                #endif
            
            if ingestMode == "pageRange" {
                HStack {
                    Text(L10n.Ingest.PDF.fromPage)
                    TextField("1", value: $pageStart, format: .number)
                        .adaptiveNumberPadKeyboard()
                        .frame(width: Spacing.Metrics.heroValueSize * 1.9) // 50
                    Text(L10n.Ingest.PDF.toPage)
                    TextField("\(documentInfo.pageCount)", value: $pageEnd, format: .number)
                        .adaptiveNumberPadKeyboard()
                        .frame(width: Spacing.Metrics.heroValueSize * 1.9) // 50
                    Text(L10n.Ingest.PDF.page)
                }
                .foregroundStyle(.appText)
            }
        } header: {
            Text(L10n.Ingest.PDF.extractionRange)
        }
    }
    
    // MARK: - Highlights Section
    @ViewBuilder
    private var highlightsSection: some View {
        if ingestMode == "highlights" && documentInfo.highlights.isEmpty {
            Section {
                Text(L10n.Ingest.PDF.noHighlights)
                    .font(.caption)
                    .foregroundStyle(.appSecondary)
            }
        }
    }
    
    // MARK: - Preview Section
    private var previewSection: some View {
        Section {
            ScrollView {
                if isLoadingPreview {
                    ProgressView()
                        .padding()
                } else {
                    Text(previewText)
                        .font(.caption)
                        .foregroundStyle(.appSecondary)
                        .lineLimit(10)
                }
            }
            .frame(maxHeight: Spacing.Metrics.heroValueSize * 5.75) // 150
        } header: {
            Text(L10n.Ingest.PDF.contentPreview)
        }
    }
    
    // MARK: - Update Preview
    private func updatePreview() {
        Task {
            isLoadingPreview = true
            defer { isLoadingPreview = false }
            
            switch ingestMode {
            case "fullText":
                #if canImport(PDFKit)
                guard let pdfDoc = pdfDocument, let url = pdfDoc.documentURL else {
                    previewText = L10n.Ingest.PDF.cannotLoadPDF
                    return
                }
                let text = await ingestStore.extractPDFText(from: url, pageRange: 0..<min(2, pdfDoc.pageCount))
                previewText = String(text.prefix(500))
                #else
                previewText = "PDF extraction is not supported on this platform."
                #endif
            case "pageRange":
                #if canImport(PDFKit)
                guard let pdfDoc = pdfDocument, let url = pdfDoc.documentURL else {
                    previewText = ""
                    return
                }
                let start = max(0, pageStart - 1)
                let end = min(pdfDoc.pageCount, pageEnd)
                let text = await ingestStore.extractPDFText(from: url, pageRange: start..<end)
                previewText = String(text.prefix(500))
                #else
                previewText = ""
                #endif
            case "highlights":
                let texts = documentInfo.highlights.map { $0.text }
                previewText = String(texts.joined(separator: "\n\n").prefix(500))
            default:
                previewText = ""
            }
        }
    }
    
    // MARK: - Ingest Content
    private func ingestContent() async {
        var content = ""
        
        switch ingestMode {
        case "fullText":
            #if canImport(PDFKit)
            if let pdfDoc = pdfDocument, let url = pdfDoc.documentURL {
                content = await ingestStore.extractPDFText(from: url)
            }
            #endif
        case "pageRange":
            #if canImport(PDFKit)
            if let pdfDoc = pdfDocument, let url = pdfDoc.documentURL {
                let start = max(0, pageStart - 1)
                let end = min(pdfDoc.pageCount, pageEnd)
                content = await ingestStore.extractPDFText(from: url, pageRange: start..<end)
            }
            #endif
        case "highlights":
            content = documentInfo.highlights.map { highlight in
                var text = "> \(highlight.text)"
                if !highlight.note.isEmpty {
                    text += "\n\n\(L10n.Ingest.PDF.noteLabel) \(highlight.note)"
                }
                return text
            }.joined(separator: "\n\n---\n\n")
        default:
            break
        }
        
        Task {
            _ = await store.createPage(
                title: targetTitle,
                pageType: targetType,
                content: content,
                tags: ["PDF", L10n.Common.LogAction.ingest]
            )
            store.addLog(action: .importPDF, target: targetTitle, details: L10n.Ingest.pdfIngestModeFormat(ingestMode))
            await store.saveToDisk()
            dismiss()
        }
    }
}

// MARK: - PDF Document Row
/// PDF 文档列表行组件
/// 负责展示 PDF 文件的基本元数据（标题、页数、高亮统计）及预览图标
struct PDFDocumentRow: View {
    let doc: PDFDocumentInfo
    
    var body: some View {
        HStack(spacing: Spacing.medium) { // 12
            pdfIcon
            docInfo
            Spacer()
            Image(systemName: DesignSystem.Icons.forward)
                .font(.caption)
                .foregroundStyle(.appSecondary)
        }
        .padding(.vertical, Spacing.tiny) // 4
    }
    
    private var pdfIcon: some View {
        RoundedRectangle(cornerRadius: Spacing.microRadius)
            .fill(Color.appAccent.opacity(DesignSystem.Opacity.glass)) // 0.15
            .frame(width: Spacing.iconDisplay, height: Spacing.iconDisplay + Spacing.standardPadding) // 48, 64
            .overlay(
                VStack(spacing: Spacing.tiny) { // 4
                    Image(systemName: DesignSystem.Icons.docRichtext)
                        .font(.title3)
                        .foregroundStyle(.appAccent)
                    Text("\(doc.pageCount)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.appAccent)
                }
            )
    }
    
    private var docInfo: some View {
        VStack(alignment: .leading, spacing: Spacing.atomic * 2) { // 4
            Text(doc.title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.appText)
                .lineLimit(1)
            
            HStack(spacing: Spacing.small) { // 8
                Label(L10n.Ingest.pdfPageCountFormat(doc.pageCount), systemImage: "doc.text")
                    .font(.caption)
                    .foregroundStyle(.appSecondary)
                
                Label(L10n.Ingest.pdfHighlightCountFormat(doc.highlights.count), systemImage: "highlighter")
                    .font(.caption)
                    .foregroundStyle(.appSecondary)
            }
            
            Text(doc.addedDate.formatted(Date.FormatStyle(date: .numeric, time: .omitted, locale: Localized.currentLocale)))
                .font(.caption2)
                .foregroundStyle(.appSecondary)
        }
    }
}

#if canImport(PDFKit)
// MARK: - PDF Preview Wrapper
/// PDF 预览包装器组件
/// 负责在 SwiftUI 中嵌入原生 PDFView 渲染引擎，支持文档加载与自动缩放
struct PDFPreviewWrapper: UIViewRepresentable {
    let url: URL
    
    /// 创建UIView
    /// - Parameter context: context
    /// - Returns: 返回值
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = PDFKit.PDFDocument(url: url)
        pdfView.autoScales = true
        return pdfView
    }
    
    /// 更新UIView
    /// - Parameter uiView: uiView
    /// - Parameter context: context
    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document?.documentURL != url {
            uiView.document = PDFKit.PDFDocument(url: url)
        }
    }
}
#endif

// MARK: - Highlight Color Extension
extension Color {

    /// pdf高亮
    /// - Parameter name: name
    /// - Returns: 返回值
    static func pdfHighlight(_ name: String) -> Color {
        switch name {
        case "yellow": return .yellow
        case "green": return .green
        case "blue": return .blue
        case "pink": return .pink
        case "purple": return .purple
        default: return .yellow
        }
    }
}
