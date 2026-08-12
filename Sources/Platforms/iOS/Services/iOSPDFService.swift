//
//  iOSPDFService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 平台适配层
//  核心职责：实现 iOSPDF 模块的核心业务逻辑服务。
//
#if !os(watchOS)
import Foundation
import PDFKit
import Dependencies

/// iOS/macOS PDF 处理实现
final class iOSPDFService: PDFServiceProtocol {
    private let documentsDirectory: URL
    @ObservationIgnored @Dependency(\.taskCenter) private var taskCenter

    init() {
        documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AppPDFs", isDirectory: true)

        // Create directory if needed
        try? FileManager.default.createDirectory(at: documentsDirectory, withIntermediateDirectories: true)
    }

    // MARK: - File Management

    /// 保存PDF
    /// - Parameter data: data
    /// - Parameter fileName: fileName
    /// - Returns: 可选值
    func savePDF(data: Data, fileName: String) async -> URL? {
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            return nil
        }
    }

    /// 删除PDF
    /// - Parameter fileName: fileName
    /// - Returns: 是否成功
    func deletePDF(fileName: String) async -> Bool {
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        do {
            try FileManager.default.removeItem(at: fileURL)
            return true
        } catch {
            return false
        }
    }

    /// allPDFFilenames
    /// - Returns: 列表
    func allPDFFilenames() async -> [String] {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
            return files
                .filter { $0.pathExtension == "pdf" }
                .map { $0.lastPathComponent }
                .sorted()
        } catch {
            return []
        }
    }

    /// 获取PDFURL
    /// - Parameter fileName: fileName
    /// - Returns: 可选值
    func getPDFURL(fileName: String) -> URL? {
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : nil
    }

    // MARK: - Text Extraction

    /// 提取Text
    /// - Returns: 可选值
    func extractText(from url: URL) async -> String? {
        guard let document = PDFDocument(url: url) else { return nil }
        return await extractText(from: url, pageRange: 0..<document.pageCount)
    }

    /// 提取Text
    /// - Parameter pageRange: pageRange
    /// - Returns: 可选值
    func extractText(from url: URL, pageRange: Range<Int>) async -> String? {
        guard let document = PDFDocument(url: url) else { return nil }
        
        // 1. 获取大纲层次结构并建立页面到大纲标题的映射
        var pageOutlines: [Int: [String]] = [:]
        if let outlineRoot = document.outlineRoot {
            buildOutlineMap(outline: outlineRoot, document: document, map: &pageOutlines)
        }
        
        var text = ""
        let start = max(0, pageRange.lowerBound)
        let end = min(document.pageCount, pageRange.upperBound)
        
        for i in start..<end {
            if let page = document.page(at: i) {
                // 实时推送当前正在处理的 PDF 物理页状态
                Task { @MainActor in
                    taskCenter.addIngestSubLog("Extracting_Page_\(i + 1)_of_\(document.pageCount)")
                }
                
                // 2. 在提取当前页面文本前，织入当前页关联的大纲层级标题
                if let outlines = pageOutlines[i], !outlines.isEmpty {
                    for title in outlines {
                        text += "\n# \(title)\n"
                    }
                }
                
                text += page.string ?? ""
                text += String(format: L10n.Ingest.PDF.pageSeparator, i + 1)
            }
        }
        return text
    }

    /// 递归遍历大纲节点，建立物理页面索引到大纲标题的映射表
    private func buildOutlineMap(outline: PDFOutline, document: PDFDocument, map: inout [Int: [String]]) {
        if let label = outline.label, let destination = outline.destination, let page = destination.page {
            let pageIndex = document.index(for: page)
            if pageIndex != NSNotFound {
                map[pageIndex, default: []].append(label)
            }
        }
        
        // 遍历所有子节点
        for i in 0..<outline.numberOfChildren {
            if let child = outline.child(at: i) {
                buildOutlineMap(outline: child, document: document, map: &map)
            }
        }
    }

    // MARK: - Image Extraction

    func extractImages(from url: URL) async -> [Data] {
        guard let document = PDFDocument(url: url) else { return [] }
        let maxPages = AppConstants.Keys.ImportLimits.maxImagesPerPage
        let pageCount = min(document.pageCount, maxPages)
        var images: [Data] = []

        for i in 0..<pageCount {
            guard let page = document.page(at: i) else { continue }
            // 渲染页面为图片（缩放到合理尺寸）
            let rect = page.bounds(for: .mediaBox)
            let scale = AppConstants.Keys.ImportLimits.pdfRenderScale
            let size = CGSize(width: rect.width * scale, height: rect.height * scale)

            let renderer = UIGraphicsImageRenderer(size: size)
            let image = renderer.image { ctx in
                UIColor.theme.white.setFill()
                ctx.fill(CGRect(origin: .zero, size: size))
                ctx.cgContext.scaleBy(x: scale, y: scale)
                page.draw(with: .mediaBox, to: ctx.cgContext)
            }

            if let jpegData = image.jpegData(compressionQuality: AppConstants.Keys.ImportLimits.imageJPEGQuality),
               jpegData.count <= AppConstants.Keys.ImportLimits.maxImageSizeBytes {
                images.append(jpegData)
            }
        }
        return images
    }

    // MARK: - Metadata Persistence

    /// 保存DocumentsInfo
    /// - Parameter docs: docs
    func saveDocumentsInfo(_ docs: [PDFDocumentInfo]) async {
        let url = documentsDirectory.appendingPathComponent("pdf_metadata.json")
        if let data = try? JSONEncoder().encode(docs) {
            try? data.write(to: url)
        }
    }

    /// 加载DocumentsInfo
    /// - Returns: 列表
    func loadDocumentsInfo() async -> [PDFDocumentInfo] {
        let url = documentsDirectory.appendingPathComponent("pdf_metadata.json")
        guard let data = try? Data(contentsOf: url),
              let docs = try? JSONDecoder().decode([PDFDocumentInfo].self, from: data) else {
            return []
        }
        return docs
    }
}
#endif
