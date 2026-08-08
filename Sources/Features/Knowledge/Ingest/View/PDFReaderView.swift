//
//  PDFReaderView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：构建 PDFReader 界面的 UI 视图层组件。
//
import SwiftUI
#if canImport(PDFKit)
import PDFKit
#endif
import UniformTypeIdentifiers

// MARK: - PDF Reader View (Full Screen)
struct PDFReaderView: View {
    let documentInfo: PDFDocumentInfo
    @Environment(AppStore.self) var store
    @Environment(IngestStore.self) var ingestStore
    @Environment(\.interfaceIdiom) private var idiom

    @State private var currentPage = 0
    @State private var highlights: [PDFHighlight] = []
    @State private var showHighlightPanel = false
    @State private var showIngestSheet = false
    @State private var selectedText = ""
    @State private var highlightColor = "yellow"
    @State private var highlightNote = ""
    @State private var pdfDocument: PDFKit.PDFDocument?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if idiom == .watch {
            WatchFeaturePlaceholderView(placeholderMessage: L10n.Watch.pdfReaderPlaceholder)
        } else {
            NavigationStack {
                ZStack {
                    PageBackgroundView(accentColor: .appAccent)
                        .ignoresSafeArea()

                    VStack(spacing: 0) {
                        pdfContent
                        bottomBar
                    }
                }
                .navigationTitle(documentInfo.title)
                .appNavigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .automatic) {
                        Button(action: { showHighlightPanel.toggle() }) {
                            Image(systemName: showHighlightPanel ? DesignSystem.Icons.highlighterFill : DesignSystem.Icons.highlighter)
                        }

                        Button(action: { showIngestSheet = true }) {
                            Image(systemName: DesignSystem.Icons.arrowDownDoc)
                        }
                    }
                }
                .sheet(isPresented: $showIngestSheet) {
                    PDFIngestSheet(documentInfo: documentInfo, ingestStore: ingestStore, pdfDocument: pdfDocument)
                }
            }
            .onAppear {
                Task {
                    if let url = await ingestStore.loadPDFDocument(fileName: documentInfo.fileName) {
                        #if canImport(PDFKit)
                        pdfDocument = PDFDocument(url: url)
                        #endif
                    }
                    highlights = documentInfo.highlights
                    currentPage = documentInfo.lastReadPage
                }
            }
        }
    }

    // MARK: - PDF Content
    @ViewBuilder
    private var pdfContent: some View {
        #if canImport(PDFKit)
        if let pdfDoc = pdfDocument {
            PDFKitRepresentedView(
                document: pdfDoc,
                currentPage: $currentPage,
                onTextSelected: { selectedText = $0 }
            )
            .ignoresSafeArea()
        } else {
            ContentUnavailableView(L10n.Ingest.PDF.cannotLoadPDF, systemImage: DesignSystem.Icons.warning)
        }
        #else
        ContentUnavailableView(L10n.Ingest.PDF.notSupported, systemImage: DesignSystem.Icons.warning, description: Text(L10n.Ingest.PDF.notSupportedDesc))
        #endif
    }

    // MARK: - Bottom Bar
    private var bottomBar: some View {
        VStack(spacing: 0) {
            if showHighlightPanel && !selectedText.isEmpty {
                highlightEditor
            }

            HStack {
                #if canImport(PDFKit)
                Text("\(currentPage + 1) / \(pdfDocument?.pageCount ?? 0)")
                    .font(.caption)
                    .foregroundStyle(.appSecondary)
                #else
                Text("0 / 0")
                    .font(.caption)
                    .foregroundStyle(.appSecondary)
                #endif

                Spacer()

                if !highlights.isEmpty {
                    Button(action: { showHighlightPanel.toggle() }) {
                        Label("\(highlights.count)", systemImage: DesignSystem.Icons.highlighter)
                            .font(.caption)
                            .foregroundStyle(.appAccent)
                    }
                }
            }
            .padding(.horizontal, DesignSystem.standardPadding)
            .padding(.vertical, DesignSystem.small)
            .background(Color.appCard)
        }
    }

    // MARK: - Highlight Editor
    private var highlightEditor: some View {
        VStack(alignment: .leading, spacing: DesignSystem.small) {
            Text(L10n.Ingest.PDF.annotateSelected)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.appText)

            Text(selectedText)
                .font(.caption)
                .foregroundStyle(.appSecondary)
                .lineLimit(3)

            HStack(spacing: DesignSystem.small) {
                ForEach(["yellow", "green", "blue", "pink", "purple"], id: \.self) { color in
                    Button(action: { highlightColor = color }) {
                        Circle()
                            .fill(Color.pdfHighlight(color))
                            .frame(width: DesignSystem.IconSize.standard, height: DesignSystem.IconSize.standard)
                            .overlay(
                                Circle()
                                    .stroke(Color.appText, lineWidth: highlightColor == color ? 2 : 0)
                            )
                    }
                }
                Spacer()
            }

            TextField(L10n.Ingest.PDF.addNote, text: $highlightNote)
                .font(.caption)
        .roundedBorderTextFieldStyle()

            Button(action: saveHighlight) {
                Text(L10n.Ingest.PDF.saveAnnotation)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.medium)
                    .padding(.vertical, Spacing.small)
                    .background(Color.appAccent)
                    .clipShape(RoundedRectangle(cornerRadius: Spacing.smallRadius))
            }
        }
        .padding(DesignSystem.medium)
        .background(Color.appCard)
    }

    // MARK: - Actions
    private func saveHighlight() {
        let highlight = PDFHighlight(
            pageIndex: currentPage,
            text: selectedText,
            color: highlightColor,
            note: highlightNote
        )
        highlights.append(highlight)

        Task {
            var docs = await ingestStore.loadPDFDocuments()
            if let index = docs.firstIndex(where: { $0.id == documentInfo.id }) {
                docs[index].highlights = highlights
                await ingestStore.savePDFDocuments(docs)
            }
        }

        selectedText = ""
        highlightNote = ""
        showHighlightPanel = false

        store.addLog(action: .highlight, target: documentInfo.title, details: L10n.Ingest.pdfPageNumber(currentPage + 1))
    }
}
