//
//  WebViewExportService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：实现 WebViewExport 模块的核心业务逻辑服务。
//
import Foundation
import UFPCore
import Dependencies

/// 导出服务门面 (L0 基础架构层)
/// 负责协调底层平台的导出实现（如 WebKit 或 Stub）。
@MainActor
final class WebViewExportService {
    static let shared = WebViewExportService()
    
    @Dependency(\.exportService) private var exportService: any ExportServiceProtocol
    
    private init() {}
    
    /// 将 Markdown 导出为 PDF
    func exportToPDF(markdown: String, fileName: String) async throws -> URL {
        try await exportService.exportToPDF(markdown: markdown, fileName: fileName)
    }

    /// 将 Mermaid 导出为 PDF
    func exportMindmapToPDF(mermaidCode: String, fileName: String) async throws -> URL {
        try await exportService.exportMindmapToPDF(mermaidCode: mermaidCode, fileName: fileName)
    }
    
    /// 将 Markdown 导出为 PPTX
    func exportToPPTX(markdown: String, fileName: String) async throws -> URL {
        try await exportService.exportToPPTX(markdown: markdown, fileName: fileName)
    }
}
