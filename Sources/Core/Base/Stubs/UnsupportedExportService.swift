//
//  UnsupportedExportService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 底层基座层
//  核心职责：实现 UnsupportedExport 模块的核心业务逻辑服务。
//
import Foundation
import UFPCore

/// 不支持导出的平台实现
final class UnsupportedExportService: ExportServiceProtocol, Sendable {

    /// 导出ToPDF
    /// - Parameter markdown: markdown
    /// - Parameter fileName: fileName
    /// - Returns: 链接
    func exportToPDF(markdown: String, fileName: String) async throws -> URL {
        throw NSError(domain: CoreConstants.ErrorDomain.export, code: SystemConstants.HTTPStatusCode.notImplemented, userInfo: [NSLocalizedDescriptionKey: CoreConstants.Export.unsupportedMessage])
    }
    
    /// 导出MindmapToPDF
    /// - Parameter mermaidCode: mermaidCode
    /// - Parameter fileName: fileName
    /// - Returns: 链接
    func exportMindmapToPDF(mermaidCode: String, fileName: String) async throws -> URL {
        throw NSError(domain: CoreConstants.ErrorDomain.export, code: SystemConstants.HTTPStatusCode.notImplemented, userInfo: [NSLocalizedDescriptionKey: CoreConstants.Export.unsupportedMessage])
    }
    
    /// 导出ToPPTX
    /// - Parameter markdown: markdown
    /// - Parameter fileName: fileName
    /// - Returns: 链接
    func exportToPPTX(markdown: String, fileName: String) async throws -> URL {
        throw NSError(domain: CoreConstants.ErrorDomain.export, code: SystemConstants.HTTPStatusCode.notImplemented, userInfo: [NSLocalizedDescriptionKey: CoreConstants.Export.unsupportedMessage])
    }
}
