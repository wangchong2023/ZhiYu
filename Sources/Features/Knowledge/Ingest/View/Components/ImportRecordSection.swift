//
//  ImportRecordSection.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/10.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：导入原始内容分段 Tab + 卡片列表区域

import SwiftUI
import UFPCore
import QuickLook

struct ImportRecordSection: View {
    @State private var selectedCategory: String = "all"
    @State private var records: [ImportRecord] = []
    @State private var previewText: String?
    @State private var previewFilePath: String?
    @State private var previewRecord: ImportRecord?
    @State private var showTextPreview = false
    @State private var quickLookURL: URL?
    @Environment(Router.self) var router
    var onAITag: ((ImportRecord) -> Void)?
    var onManualEdit: ((ImportRecord) -> Void)?

    @Inject private var repo: any ImportRecordRepository
    @Inject private var urlOpener: any URLOpenerProtocol
    @Inject private var shareSheet: any ShareSheetProtocol

    private let tabs: [(key: String, label: String)] = {
        var items: [(String, String)] = [("all", L10n.Ingest.importAll)]
        for cat in ImportCategory.allCases {
            items.append((cat.rawValue, cat.displayName))
        }
        return items
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.medium) {
            AppSectionHeader(title: L10n.Ingest.importRecords, icon: "arrow.down.doc")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.small) {
                    ForEach(tabs, id: \.key) { tab in
                        categoryTab(tab.key, tab.label)
                    }
                }
            }

            if records.isEmpty {
                Text(L10n.Ingest.noImportRecords)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, DesignSystem.large)
                    .frame(maxWidth: .infinity)
            } else if selectedCategory == "all" {
                tagGroupedList
            } else {
                flatCardList(records)
            }
        }
        .sheet(isPresented: $showTextPreview) {
            textPreviewSheetContent
        }
        .quickLookPreview($quickLookURL)
        .task { await loadRecords() }
        .onChange(of: selectedCategory) { _, _ in Task { await loadRecords() } }
    }
    
    @ViewBuilder
    private var textPreviewSheetContent: some View {
        NavigationStack {
            Group {
                if previewRecord?.category == "ocr" {
                    ocrFullPreviewView
                } else {
                    standardPreviewScrollView
                }
            }
            .navigationTitle(previewRecord?.category == "ocr" ? (previewRecord?.title ?? L10n.Ingest.ocrScan) : L10n.Ingest.rawContentTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.Common.close) { showTextPreview = false }
                }
            }
        }
    }

    @ViewBuilder
    private var ocrFullPreviewView: some View {
        VStack(spacing: 0) {
            ocrPreviewHeader
        }
        .padding(DesignSystem.small)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var standardPreviewScrollView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.medium) {
                if previewRecord?.category == "voice" {
                    VoiceAudioPlayerView(
                        title: previewRecord?.title ?? "",
                        audioPath: previewFilePath,
                        transcribedText: previewText ?? ""
                    )
                } else {
                    HStack {
                        previewSourceBadge
                        Spacer()
                    }
                }
                
                if previewRecord?.category != "voice" {
                    if let path = previewFilePath, !isTextFile(path: path) {
                        FileTextPreviewView(filePath: path)
                    } else {
                        FormattedMarkdownText(text: cleanPreviewText(previewText ?? ""))
                            .padding(.top, DesignSystem.tiny)
                    }
                }
            }
            .padding()
        }
    }
    
    private func cleanPreviewText(_ text: String) -> String {
        text.replacingOccurrences(of: "[[", with: "「")
            .replacingOccurrences(of: "]]", with: "」")
    }

    // MARK: - 预览分发

    /// 校验是否是纯文本文件后缀
    private func isTextFile(path: String) -> Bool {
        let textExtensions = ["txt", "md", "json", "csv", "js", "py", "html", "xml", "css", "log", "swift", "yaml", "yml"]
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        return textExtensions.contains(ext)
    }

    private func previewContent(_ record: ImportRecord, forceRaw: Bool = false) {
        previewRecord = record
        
        #if canImport(UIKit)
        // 仅当文件确实是 PDF（扩展名是 .pdf 或 category 为 pdf）时才进行 PDF 构建与 QuickLook 弹窗
        let titleLower = record.title.lowercased()
        let catLower = record.category.lowercased()
        let isPDF = catLower == "pdf" || titleLower.hasSuffix(".pdf") || record.filePath?.lowercased().hasSuffix(".pdf") == true

        // 对于 OCR 扫描分类，强制走智宇原生带有手势捏合与缩放控制按钮的 ZoomableOCRImageView 预览弹窗
        if catLower == "ocr" {
            previewText = record.rawText ?? record.title
            previewFilePath = record.filePath
            showTextPreview = true
            return
        }

        if isPDF {
            let docURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let pdfFileName = (record.filePath as NSString?)?.lastPathComponent ?? "\(record.id).pdf"
            let targetPath = docURL.appendingPathComponent(pdfFileName).path
            
            if let pdfURL = DemoPDFBuilder.ensurePDFExists(at: targetPath, title: record.title, content: record.rawText ?? record.title) {
                quickLookURL = pdfURL
                return
            }
        }
        #endif

        let handler = ImportPreviewHandler(urlOpener: urlOpener, shareSheet: shareSheet, router: router)
        let action = handler.resolveAction(for: record, forceRaw: forceRaw)

        switch action {
        case .navigateToPage(let uuid):
            router.navigateToPage(id: uuid)
        case .manualEdit:
            onManualEdit?(record)
        case .localTextFile(let path):
            previewFilePath = path
            previewText = nil
            showTextPreview = true
        case .localBinaryFile(let url):
            quickLookURL = url
        case .openURL(let url):
            Task { await urlOpener.open(url) }
        case .rawTextPreview(let text):
            previewText = text
            previewFilePath = nil
            showTextPreview = true
        case .none:
            break
        }
    }

    // MARK: - 动态来源 Badge 胶囊与 Markdown 格式化渲染

    @ViewBuilder
    private var ocrPreviewHeader: some View {
        if let record = previewRecord {
            VStack(alignment: .leading, spacing: DesignSystem.small) {
                HStack {
                    Label(L10n.Ingest.ocrScan, systemImage: "camera.viewfinder")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, DesignSystem.medium)
                        .padding(.vertical, DesignSystem.tightPadding)
                        .background(Capsule().fill(Color.appAccent.opacity(DesignSystem.Opacity.subtle)))
                        .foregroundStyle(.appAccent)
                    
                    Spacer()
                    
                    Text(L10n.Ingest.imageOCRLabel)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                
                #if canImport(UIKit)
                let docURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let imgPath = (record.filePath as NSString?)?.lastPathComponent ?? "\(record.id).png"
                let targetPath = docURL.appendingPathComponent(imgPath).path
                
                if let uiImg = DemoImageBuilder.ensureImageExists(at: targetPath, title: record.title) {
                    ZoomableOCRImageView(image: uiImg)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.vertical, DesignSystem.tiny)
                }
                #endif
            }
        }
    }

    @ViewBuilder
    private var previewSourceBadge: some View {
        let cat = previewRecord?.category ?? "file"
        Label(badgeLabel(for: cat), systemImage: badgeIcon(for: cat))
            .font(.caption.weight(.bold))
            .padding(.horizontal, DesignSystem.medium)
            .padding(.vertical, DesignSystem.tightPadding)
            .background(Capsule().fill(badgeColor(for: cat).opacity(DesignSystem.Opacity.subtle)))
            .foregroundStyle(badgeColor(for: cat))
    }

    private func badgeLabel(for category: String) -> String {
        switch category {
        case "ocr": return L10n.Ingest.ocrScan
        case "voice": return L10n.Ingest.voiceNote
        case "link": return L10n.Ingest.urlImport
        case "manual": return L10n.Ingest.manualEntry
        default: return L10n.Ingest.fileImport
        }
    }

    private func badgeIcon(for category: String) -> String {
        switch category {
        case "ocr": return "camera.viewfinder"
        case "voice": return "waveform"
        case "link": return "link"
        case "manual": return "square.and.pencil"
        default: return "doc.text"
        }
    }

    private func badgeColor(for category: String) -> Color {
        switch category {
        case "ocr": return .purple
        case "voice": return .pink
        case "link": return .blue
        case "manual": return .orange
        default: return .appAccent
        }
    }

    // MARK: - 标签分组（仅在"全部"tab）

    private var tagGroupedList: some View {
        let grouped = ImportRecordTagGrouper.group(records, untaggedLabel: L10n.Ingest.untagged)
        return VStack(spacing: DesignSystem.small) {
            ForEach(grouped.keys.sorted(), id: \.self) { tag in
                VStack(alignment: .leading, spacing: DesignSystem.tightPadding) {
                    Text(tag)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.appAccent)
                        .padding(.horizontal, DesignSystem.tiny)
                    flatCardList(grouped[tag] ?? [], groupTag: tag)
                }
            }
        }
    }

    // MARK: - 平铺列表

    /// 包装结构体，为 SwiftUI 提供结合 tag 分组的联合唯一 ID，避免 ID 重复导致手势分发失效
    fileprivate struct GroupedRecord: Identifiable {
        let record: ImportRecord
        let tag: String
        var id: String { "\(tag)-\(record.id)" }
    }

    /// 平铺渲染卡片列表
    /// - Parameters:
    ///   - items: 待显示的导入记录数组
    ///   - groupTag: 当前的分组标签，用于防止重复 ID
    private func flatCardList(_ items: [ImportRecord], groupTag: String = "") -> some View {
        let groupedItems = items.map { GroupedRecord(record: $0, tag: groupTag) }
        return ForEach(groupedItems) { wrapper in
            let record = wrapper.record
            ImportRecordCard(
                record: record,
                onTap: { previewContent(record) },
                onPreview: { previewContent(record, forceRaw: true) },
                onOpenWith: {
                    guard let path = record.filePath else { return }
                    let fileURL = URL(fileURLWithPath: path)
                    Task { await shareSheet.presentShareSheet(items: [fileURL]) }
                },
                onEdit: { onManualEdit?(record) }
            )
        }
    }

    private func categoryTab(_ key: String, _ label: String) -> some View {
        let selected = selectedCategory == key
        return Button(action: { selectedCategory = key }) {
            Text(label)
                .font(.caption.weight(selected ? .semibold : .regular))
                .padding(.horizontal, DesignSystem.medium)
                .padding(.vertical, DesignSystem.tightPadding)
                .background(selected ? Capsule().fill(Color.appAccent) : Capsule().fill(Color.appCard))
                .foregroundStyle(selected ? .white : .secondary)
        }
    }

    private func loadRecords() async {
        let cat: String? = selectedCategory == "all" ? nil : selectedCategory
        let fetched = (try? await repo.fetchAll(category: cat, limit: 50)) ?? []
        records = fetched.map { sanitizeRecordSize($0) }
    }

    /// 对旧有 Demo 数据库残留小字节记录进行实时自愈与计算修愈
    private func sanitizeRecordSize(_ record: ImportRecord) -> ImportRecord {
        var rec = record
        let title = record.title
        
        let demoSnippetMap: [String: String] = [
            L10n.InitialNotebook.PKM.title1: L10n.InitialNotebook.Snippet.methodology,
            L10n.InitialNotebook.PKM.title4: L10n.InitialNotebook.Snippet.pkmVoiceForget,
            L10n.InitialNotebook.PKM.title5: L10n.InitialNotebook.Snippet.pkmRagLink,
            L10n.InitialNotebook.PKM.title2: L10n.InitialNotebook.Snippet.pkmOcrFolder,
            L10n.InitialNotebook.Coffee.title1: L10n.InitialNotebook.Snippet.luckin,
            L10n.InitialNotebook.Coffee.title2: L10n.InitialNotebook.Snippet.coffeeOcrManual,
            L10n.InitialNotebook.Coffee.title4: L10n.InitialNotebook.Snippet.coffeeVoiceProcure,
            L10n.InitialNotebook.Coffee.title5: L10n.InitialNotebook.Snippet.survey
        ]
        
        if let snippet = demoSnippetMap[title] {
            let size = Int64(snippet.utf8.count)
            if (rec.fileSize ?? 0) < size {
                rec.fileSize = size
                rec.rawText = snippet
            }
        }
        return rec
    }
}

// MARK: - 预览动作分发处理器（支持单元测试）

enum PreviewAction: Equatable {
    case navigateToPage(id: UUID)
    case manualEdit
    case localTextFile(path: String)
    case localBinaryFile(url: URL)
    case openURL(url: URL)
    case rawTextPreview(text: String)
    case none
}

struct ImportPreviewHandler {
    let urlOpener: any URLOpenerProtocol
    let shareSheet: any ShareSheetProtocol
    let router: Router
    
    /// 根据导入记录的状态和内容，决定预览分发动作
    func resolveAction(for record: ImportRecord, forceRaw: Bool = false) -> PreviewAction {
        // 1. 对于用户手工输入的记录，优先分派编辑事件以拉起输入编辑表单
        if !forceRaw, record.category == ImportCategory.manual.rawValue {
            return .manualEdit
        }

        // 2. 本地磁盘文件校验（自动进行相对路径/绝对路径寻址补全与自愈）
        if let path = resolveExistingFilePath(record.filePath) {
            if isTextFile(path: path) {
                return .localTextFile(path: path)
            }
            return .localBinaryFile(url: URL(fileURLWithPath: path))
        }
        
        // 3. 原始文本预览（支持 OCR 扫描文本、语音转文字速记、网页抓取文本弹窗预览）
        if let rawText = record.rawText, !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .rawTextPreview(text: rawText)
        }

        // 4. 网页链接 → 默认浏览器 / Web Preview 打开
        if let urlStr = record.sourceURL, let url = URL(string: urlStr) {
            return .openURL(url: url)
        }

        // 5. 若无原始文本/文件，则降级跳转至已合成的知识页面
        if let pageID = record.pageID, let uuid = UUID(uuidString: pageID) {
            return .navigateToPage(id: uuid)
        }
        
        return .none
    }
    
    /// 自愈补全相对路径或校验物理存在的沙盒绝对路径
    private func resolveExistingFilePath(_ rawPath: String?) -> String? {
        guard let path = rawPath, !path.isEmpty else { return nil }
        
        // A. 原始绝对路径存在
        if FileManager.default.fileExists(atPath: path) {
            return path
        }
        
        // B. 路径自愈：尝试结合当前 App 沙盒 Documents 目录寻找文件
        let docURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = (path as NSString).lastPathComponent
        let resolvedURL = docURL.appendingPathComponent(fileName)
        
        if FileManager.default.fileExists(atPath: resolvedURL.path) {
            return resolvedURL.path
        }
        
        return nil
    }

    private func isTextFile(path: String) -> Bool {
        let textExtensions = ["txt", "md", "json", "csv", "js", "py", "html", "xml", "css", "log", "swift", "yaml", "yml"]
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        return textExtensions.contains(ext)
    }
}
