//
//  PDFServiceProtocol.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层
//  核心职责：定义 PDFService 模块的抽象契约接口。
//
import Foundation
import Dependencies
import UFPCore

/// PDF 处理服务协议
@MainActor
public protocol PDFServiceProtocol: Sendable {
    /// 保存 PDF 数据
    func savePDF(data: Data, fileName: String) async -> URL?
    
    /// 删除 PDF 文件
    func deletePDF(fileName: String) async -> Bool
    
    /// 获取所有 PDF 文件名
    func allPDFFilenames() async -> [String]
    
    /// 获取指定 PDF 文件的物理路径
    func getPDFURL(fileName: String) -> URL?
    
    /// 提取全量文本内容
    func extractText(from url: URL) async -> String?
    
    /// 提取指定页码范围的文本内容
    func extractText(from url: URL, pageRange: Range<Int>) async -> String?

    /// 提取 PDF 中的嵌入图片数据（用于 OCR）
    func extractImages(from url: URL) async -> [Data]

    /// 保存元数据
    func saveDocumentsInfo(_ docs: [PDFDocumentInfo]) async
    
    /// 加载元数据
    func loadDocumentsInfo() async -> [PDFDocumentInfo]
}

// MARK: - DependencyKey 注册

/// PDFServiceProtocol 的 DependencyKey（P7 迁移：过渡期 liveValue 从 ServiceContainer 解析）
public enum PDFServiceKey: DependencyKey {
    @MainActor
    public static var liveValue: any PDFServiceProtocol {
        ServiceContainer.shared.resolve((any PDFServiceProtocol).self)
    }
    @MainActor
    public static var testValue: any PDFServiceProtocol { NoOpPDFService() }
    @MainActor
    public static var previewValue: any PDFServiceProtocol { NoOpPDFService() }
}

extension DependencyValues {
    /// PDF 服务依赖
    public var pdfService: any PDFServiceProtocol {
        get { self[PDFServiceKey.self] }
        set { self[PDFServiceKey.self] = newValue }
    }
}

/// 无操作 PDF 服务（测试/预览占位）
@MainActor
public final class NoOpPDFService: PDFServiceProtocol, @unchecked Sendable {
    public init() {}
    public func savePDF(data: Data, fileName: String) async -> URL? { nil }
    public func deletePDF(fileName: String) async -> Bool { false }
    public func allPDFFilenames() async -> [String] { [] }
    public func getPDFURL(fileName: String) -> URL? { nil }
    public func extractText(from url: URL) async -> String? { nil }
    public func extractText(from url: URL, pageRange: Range<Int>) async -> String? { nil }
    public func extractImages(from url: URL) async -> [Data] { [] }
    public func saveDocumentsInfo(_ docs: [PDFDocumentInfo]) async {}
    public func loadDocumentsInfo() async -> [PDFDocumentInfo] { [] }
}
