//
//  DocumentProcessor.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：文档处理器：Markdown 解析、文本分块、图谱布局、网页抓取。
//
import Foundation
import UFPCore
import Dependencies

/// 基础设施层内部的文档处理通用协议
protocol DocumentProcessor: Sendable {
    /// 提取文档中的文本内容
    func extractText(from url: URL) async throws -> String
}

/// 物理文档文本提取统一实现服务 (DocumentExtractionService)
/// 整合了 PDF, DOCX, XLSX 以及纯文本处理流程，通过抽象协议向业务功能层暴露能力。
public final class DocumentExtractionService: DocumentExtractionServiceProtocol {
    
    /// 构造方法
    public init() {}
    
    /// 判断是否支持指定的物理格式
    /// - Parameter format: 目标文件格式
    /// - Returns: 是否可解析
    public func canExtract(format: DocumentFormat) -> Bool {
        switch format {
        case .pdf, .docx, .xlsx, .markdown, .plainText:
            return true
        case .unknown:
            return false
        }
    }
    
    /// 抽取文件中的纯文本内容
    /// - Parameter url: 文件物理路径
    /// - Returns: 返回解析出的纯文本字符串
    public func extractText(from url: URL) async throws -> String {
        let format = DocumentFormat.detectFormat(from: url)
        guard let processor = getProcessor(for: format) else {
            throw ProcessorError.extractionFailed
        }
        return try await processor.extractText(from: url)
    }
    
    /// 工厂方法：根据格式实例化对应的解析代理处理器
    private func getProcessor(for format: DocumentFormat) -> (any DocumentProcessor)? {
        switch format {
        case .pdf:
            return PDFProcessorProxy()
        case .docx:
            return DocxProcessorProxy()
        case .xlsx:
            return XlsxProcessorProxy()
        case .markdown, .plainText:
            return TextProcessorProxy()
        default:
            return nil
        }
    }
}

// MARK: - 具体处理器代理 (适配现有底层解析实现)

/// PDF 格式处理器代理
struct PDFProcessorProxy: DocumentProcessor {
    /// 注入底层系统级 PDF 处理能力
    @Dependency(\.pdfService) private var pdfService: any PDFServiceProtocol

    /// 提取Text
    /// - Returns: 字符串
    func extractText(from url: URL) async throws -> String {
        guard let text = await pdfService.extractText(from: url) else {
            throw ProcessorError.extractionFailed
        }
        return text
    }
}

/// DOCX 格式处理器代理
struct DocxProcessorProxy: DocumentProcessor {

    /// 提取Text
    /// - Returns: 字符串
    func extractText(from url: URL) async throws -> String {
        guard let archive = ZipUtility.readZipArchive(at: url) else {
            throw ProcessorError.invalidArchive
        }

        guard let documentXML = archive[ProcessorConstants.OOXML.wordDocumentPath] else {
            throw ProcessorError.extractionFailed
        }

        let parser = DocxProcessor(xmlData: documentXML)
        if parser.parse() {
            return parser.extractedText
        } else {
            throw ProcessorError.extractionFailed
        }
    }
}

/// XLSX 表格格式处理器代理
struct XlsxProcessorProxy: DocumentProcessor {

    /// 提取 XLSX 中的文本内容。
    /// 流程：解压 → 提取共享字符串池 → 遍历子工作表 → 映射共享字符串索引 → 拼接输出。
    /// - Parameter url: XLSX 文件路径
    /// - Returns: 提取的纯文本
    func extractText(from url: URL) async throws -> String {
        guard let archive = ZipUtility.readZipArchive(at: url) else {
            throw ProcessorError.invalidArchive
        }

        var sharedStrings: [String] = []

        // Step 1: 提取共享字符串池（Excel 多单元格共享同一字符串以压缩体积）
        if let sharedStringsXML = archive[ProcessorConstants.OOXML.sharedStringsPath] {
            let parser = XlsxSharedStringsParser(xmlData: sharedStringsXML)
            if parser.parse() {
                sharedStrings = parser.strings
            }
        }

        var allText: [String] = []

        // Step 2: 遍历提取每个子工作表中的文字，映射共享字符串索引
        for (path, data) in archive {
            if path.hasPrefix(ProcessorConstants.OOXML.excelWorksheetPrefix) && path.hasSuffix(ProcessorConstants.OOXML.xmlExtension) {
                let parser = ExcelProcessor(xmlData: data)
                if parser.parse() {
                    // 解析共享字符串指针，映射回真实字符
                    for value in parser.values {
                        if value.hasPrefix(ProcessorConstants.OOXML.sharedStringIndexOpen) && value.hasSuffix(ProcessorConstants.OOXML.sharedStringIndexClose),
                           let index = Int(value.dropFirst().dropLast()),
                           index < sharedStrings.count {
                            allText.append(sharedStrings[index])
                        } else if !value.isEmpty && !value.hasPrefix(ProcessorConstants.OOXML.sharedStringIndexOpen) {
                            allText.append(value)
                        }
                    }
                }
            }
        }

        if allText.isEmpty {
            throw ProcessorError.extractionFailed
        }
        return allText.joined(separator: "\n")
    }
}

/// 纯文本与 Markdown 格式处理器代理
struct TextProcessorProxy: DocumentProcessor {

    /// 提取Text
    /// - Returns: 字符串
    func extractText(from url: URL) async throws -> String {
        do {
            return try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw ProcessorError.extractionFailed
        }
    }
}
