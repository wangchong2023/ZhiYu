//
//  ImageExtractor.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/10.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：从 HTML/文档中提取图片 URL，下载并通过 OCR 识别嵌入文字到内容中

import Foundation
#if os(iOS)
import UIKit
#endif

/// 网页/PDF/Office 图片提取 + OCR 处理器
final class ImageExtractor: Sendable {

    private let maxImageSize = AppConstants.Keys.ImportLimits.maxImageSizeBytes
    private let maxImages = AppConstants.Keys.ImportLimits.maxImagesPerPage

    // MARK: - HTML

    /// 从 HTML 内容中提取图片、下载并 OCR，返回追加的 Markdown 文本
    func extractImagesFromHTML(_ html: String, baseURL: URL?) async -> String {
        let imgURLs = parseImageURLs(from: html, baseURL: baseURL)
        guard !imgURLs.isEmpty else { return "" }

        let urls = Array(imgURLs.prefix(maxImages))
        var results: [String] = []
        var okCount = 0

        for url in urls {
            guard let data = await downloadImage(url) else { continue }
            if data.count > maxImageSize { continue }
            guard let text = await ocrImage(data), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            okCount += 1
            results.append("> ![img_\(okCount)]: \(text)")
        }

        guard !results.isEmpty else { return "" }
        return "\n\n> \(L10n.Ingest.imageOCRLabel)\n\(results.joined(separator: "\n"))"
    }

    // MARK: - PDF

    /// 从 PDF 文件提取页面图像并 OCR
    func extractImagesFromPDF(at url: URL, pdfService: any PDFServiceProtocol) async -> String {
        let images = await pdfService.extractImages(from: url)
        return await ocrImageBatch(images, prefix: "pdf")
    }

    // MARK: - Office (DOCX/XLSX ZIP)

    /// 从 DOCX/XLSX 文件中提取嵌入图片并 OCR
    func extractImagesFromOfficeFile(at url: URL) async -> String {
        let imageFolders = ["word/media", "xl/media", "ppt/media"]
        var allData: [Data] = []

        guard let archive = ZipUtility.readZipArchive(at: url) else { return "" }
        for (path, data) in archive {
            let lower = path.lowercased()
            guard imageFolders.contains(where: { lower.hasPrefix($0) }) else { continue }
            guard AppConstants.Keys.ImportLimits.imageExtensions.contains(where: { lower.hasSuffix($0) }) else { continue }
            let excluded = AppConstants.Keys.ImportLimits.officeImageExcludeKeywords
            guard excluded.allSatisfy({ !lower.contains($0) }) else { continue }
            if data.count <= maxImageSize {
                allData.append(data)
            }
        }
        let limited = Array(allData.prefix(maxImages))
        return await ocrImageBatch(limited, prefix: "office")
    }

    // MARK: - OCR 批处理

    func ocrImageBatch(_ dataList: [Data], prefix: String) async -> String {
        var results: [String] = []
        var okCount = 0

        for data in dataList {
            guard data.count <= maxImageSize, let text = await ocrImage(data),
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            okCount += 1
            results.append("> ![\(prefix)_\(okCount)]: \(text)")
        }
        guard !results.isEmpty else { return "" }
        return "\n\n> \(L10n.Ingest.imageOCRLabel)\n\(results.joined(separator: "\n"))"
    }

    // MARK: - HTML 解析

    /// 从 HTML 中提取所有 <img> 标签的 src 属性
    func parseImageURLs(from html: String, baseURL: URL?) -> [URL] {
        let pattern = #/<img[^>]+src\s*=\s*["']([^"']+)["'][^>]*>/#
        var urls: [URL] = []
        for match in html.matches(of: pattern) {
            let src = String(match.output.1)
            guard let url = resolveURL(src, baseURL: baseURL) else { continue }
            // 过滤明显不是图片的 URL（SVG 跳过，图标太小）
            let ext = url.pathExtension.lowercased()
            guard ext != "svg" else { continue }
            // VULN-007 修复：SSRF 防护 — 拒绝内网/环回/链路本地图片地址
            guard SSRFGuard.isSafeURL(url) else { continue }
            urls.append(url)
        }
        return urls
    }

    // MARK: - 下载

    private func downloadImage(_ url: URL) async -> Data? {
        // VULN-007 修复：SSRF 防护 — 下载前再次校验（防止 resolveURL 绕过）
        guard SSRFGuard.isSafeURL(url) else { return nil }
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForResource = AppConstants.Keys.ImportLimits.imageDownloadTimeoutSeconds
        let session = URLSession(configuration: config)
        do {
            let (data, _) = try await session.data(from: url)
            return data
        } catch {
            return nil
        }
    }

    // MARK: - OCR

    private func ocrImage(_ data: Data) async -> String? {
        #if os(iOS)
        guard let image = AppImage(data: data) else { return nil }
        guard let service = ServiceContainer.shared.resolveOptional((any OCRServiceProtocol).self) else { return nil }
        return try? await service.recognizeText(from: image)
        #else
        return nil
        #endif
    }

    // MARK: - Helpers

    private func resolveURL(_ src: String, baseURL: URL?) -> URL? {
        if src.hasPrefix("http://") || src.hasPrefix("https://") {
            return URL(string: src)
        }
        if src.hasPrefix("//") {
            return URL(string: "https:\(src)")
        }
        if src.hasPrefix("/"), let base = baseURL {
            var components = URLComponents(url: base, resolvingAgainstBaseURL: true)
            components?.path = ""
            return components?.url?.appendingPathComponent(String(src.dropFirst()))
        }
        if let base = baseURL {
            return URL(string: src, relativeTo: base)?.absoluteURL
        }
        return nil
    }
}
