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
import SwiftUI
import PDFKit
import Dependencies
import UFPDesignSystem

/// iOS/macOS PDF 处理实现
final class iOSPDFService: PDFServiceProtocol {
    private let documentsDirectory: URL
    @ObservationIgnored @Dependency(\.taskCenter) private var taskCenter

    /// PDF 页面安全渲染尺寸（经有限数校验与最大像素钳位）
    internal struct PDFRenderLayout: Equatable {
        let width: Int
        let height: Int
        let effectiveScale: CGFloat
    }

    init() {
        let baseDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        documentsDirectory = baseDir.appendingPathComponent(PlatformConstants.PDFSecurity.pdfDirectoryName, isDirectory: true)

        // Create directory if needed
        try? FileManager.default.createDirectory(at: documentsDirectory, withIntermediateDirectories: true)
    }

    // MARK: - File Management

    /// 校验并归一化安全的单层文件名，防御空串、"."、".."、路径分隔符与空字节
    internal func sanitizedSafeFileName(_ fileName: String) -> String? {
        let trimmed = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed != PlatformConstants.PDFSecurity.currentDirectoryMarker,
              !trimmed.contains(PlatformConstants.PDFSecurity.pathTraversalMarker),
              !trimmed.contains(PlatformConstants.PDFSecurity.pathSeparator),
              !trimmed.contains(PlatformConstants.PDFSecurity.backslashSeparator),
              !trimmed.unicodeScalars.contains(UnicodeScalar(0)) else {
            return nil
        }
        return trimmed
    }

    /// 校验 fileName 非空且不含路径穿越字符（.、..、/、\、空字节）
    /// - Parameter fileName: 待校验的文件名
    /// - Returns: 校验通过返回 true，为空或含路径穿越返回 false
    internal func isFileNameSafe(_ fileName: String) -> Bool {
        sanitizedSafeFileName(fileName) != nil
    }

    /// 保存PDF
    /// - Parameter data: data
    /// - Parameter fileName: fileName
    /// - Returns: 可选值
    func savePDF(data: Data, fileName: String) async -> URL? {
        // Bug #46 / #214 修复：校验并归一化 fileName，防止路径穿越与 "." 目录覆盖
        guard let safeName = sanitizedSafeFileName(fileName) else { return nil }
        let fileURL = documentsDirectory.appendingPathComponent(safeName)
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
        // Bug #47 / #214 修复：校验并归一化 fileName，防止 "." 删除整个 AppPDFs 目录
        guard let safeName = sanitizedSafeFileName(fileName) else { return false }
        let fileURL = documentsDirectory.appendingPathComponent(safeName)
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
                .filter { $0.pathExtension.lowercased() == PlatformConstants.PDFSecurity.pdfExtension }
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
        guard let safeName = sanitizedSafeFileName(fileName) else { return nil }
        let fileURL = documentsDirectory.appendingPathComponent(safeName)
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
            var visited: Set<ObjectIdentifier> = []
            buildOutlineMap(outline: outlineRoot, document: document, depth: 0, visited: &visited, map: &pageOutlines)
        }
        
        var text = ""
        let start = max(0, pageRange.lowerBound)
        let end = min(document.pageCount, pageRange.upperBound)
        guard start < end else { return text }
        
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
                // 使用字符串插值替代 String(format:)，避免 %@ 与 Int 值类型在
                // va_list 传递时触发 _NSDescriptionWithStringProxyFunc SIGSEGV
                text += "\n\n--- \(L10n.Ingest.PDF.page) \(i + 1) ---\n\n"
            }
        }
        return text
    }

    /// 递归遍历大纲节点，建立物理页面索引到大纲标题的映射表（带深度上限与环检测，防栈溢出）
    private func buildOutlineMap(
        outline: PDFOutline,
        document: PDFDocument,
        depth: Int,
        visited: inout Set<ObjectIdentifier>,
        map: inout [Int: [String]]
    ) {
        guard depth <= PlatformConstants.PDFSecurity.maxOutlineDepth else { return }
        let identifier = ObjectIdentifier(outline)
        guard visited.insert(identifier).inserted else { return }

        if let label = outline.label, let destination = outline.destination, let page = destination.page {
            let pageIndex = document.index(for: page)
            if pageIndex != NSNotFound {
                map[pageIndex, default: []].append(label)
            }
        }

        // 遍历所有子节点
        for i in 0..<outline.numberOfChildren {
            if let child = outline.child(at: i) {
                buildOutlineMap(outline: child, document: document, depth: depth + 1, visited: &visited, map: &map)
            }
        }
    }

    // MARK: - Image Extraction

    /// 计算 PDF 页面的安全渲染像素尺寸与等比缩放因子（防御 NaN/Infinity/负值崩溃与超大页面 OOM）
    internal static func safeRenderLayout(for rect: CGRect, scale: CGFloat) -> PDFRenderLayout? {
        let sourceWidth = rect.size.width
        let sourceHeight = rect.size.height
        guard sourceWidth.isFinite, sourceHeight.isFinite, scale.isFinite,
              sourceWidth > 0, sourceHeight > 0, scale > 0 else {
            return nil
        }

        let maxDimension = PlatformConstants.PDFSecurity.maxRenderPixelDimension
        let rawWidth = sourceWidth * scale
        let rawHeight = sourceHeight * scale
        guard rawWidth.isFinite, rawHeight.isFinite else { return nil }

        let largestRawSide = max(rawWidth, rawHeight)
        let clampRatio = largestRawSide > maxDimension ? (maxDimension / largestRawSide) : 1.0
        let effectiveScale = scale * clampRatio
        let pixelWidth = max(PlatformConstants.PDFSecurity.minRenderPixelDimension, Int((sourceWidth * effectiveScale).rounded()))
        let pixelHeight = max(PlatformConstants.PDFSecurity.minRenderPixelDimension, Int((sourceHeight * effectiveScale).rounded()))
        return PDFRenderLayout(width: pixelWidth, height: pixelHeight, effectiveScale: effectiveScale)
    }

    func extractImages(from url: URL) async -> [Data] {
        guard let document = PDFDocument(url: url) else { return [] }
        let maxPages = AppConstants.Keys.ImportLimits.maxPagesForImageExtraction
        let pageCount = min(document.pageCount, maxPages)
        var images: [Data] = []

        for i in 0..<pageCount {
            guard let page = document.page(at: i) else { continue }
            // 渲染页面为图片（经有限数校验与最大像素钳位，防超大工程图/恶意 PDF 导致 OOM）
            let rect = page.bounds(for: .mediaBox)
            let scale = AppConstants.Keys.ImportLimits.pdfRenderScale
            guard let layout = Self.safeRenderLayout(for: rect, scale: scale) else { continue }
            let size = CGSize(width: CGFloat(layout.width), height: CGFloat(layout.height))

            // 用 CGContext 跨平台渲染 PDF 页面为位图（iOS/macOS 通用，替代 UIGraphicsImageRenderer）
            guard let context = CGContext(
                data: nil,
                width: layout.width,
                height: layout.height,
                bitsPerComponent: PlatformConstants.PDFSecurity.bitmapBitsPerComponent,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { continue }

            context.setFillColor(AppColorBridge.from(Color.theme.white).cgColor)
            context.fill(CGRect(origin: .zero, size: size))
            context.scaleBy(x: layout.effectiveScale, y: layout.effectiveScale)
            page.draw(with: .mediaBox, to: context)
            guard let image = context.makeImage() else { continue }

            if let jpegData = AppImageBridge.jpegData(from: image, compressionQuality: AppConstants.Keys.ImportLimits.imageJPEGQuality),
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
        let url = documentsDirectory.appendingPathComponent(PlatformConstants.PDFSecurity.metadataFileName)
        if let data = try? JSONEncoder().encode(docs) {
            try? data.write(to: url)
        }
    }

    /// 加载DocumentsInfo
    /// - Returns: 列表
    func loadDocumentsInfo() async -> [PDFDocumentInfo] {
        let url = documentsDirectory.appendingPathComponent(PlatformConstants.PDFSecurity.metadataFileName)
        guard let data = try? Data(contentsOf: url),
              let docs = try? JSONDecoder().decode([PDFDocumentInfo].self, from: data) else {
            return []
        }
        return docs
    }
}
#endif
