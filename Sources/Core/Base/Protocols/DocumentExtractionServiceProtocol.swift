//
//  DocumentExtractionServiceProtocol.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 底层基座层
//  核心职责：定义 DocumentExtractionService 模块的抽象契约接口。
//
import Foundation

/// 物理文档文本提取服务契约 (DocumentExtractionServiceProtocol)
/// 实现此协议的底层基础设施能够读取各种后缀文件并将其还原为纯文本内容。
public protocol DocumentExtractionServiceProtocol: Sendable {
    /// 检查服务是否支持处理指定的文档物理格式
    /// - Parameter format: 文档格式枚举类型
    /// - Returns: 是否支持该格式的解析提取
    func canExtract(format: DocumentFormat) -> Bool

    /// 从指定物理路径的文件中解析并提取出文本内容
    /// - Parameter url: 待解析的文件绝对路径或共享沙盒路径
    /// - Returns: 提取完毕后的无排版格式纯字符串内容
    /// - Throws: `ProcessorError` 或系统 I/O 读写异常
    func extractText(from url: URL) async throws -> String
}

/// 文档处理器运行中可能抛出的标准异常枚举
public enum ProcessorError: Error, Sendable {
    /// 提取文档文本失败或物理流读取中断
    case extractionFailed
    /// 文件已被损坏或不是合规的 Zip 归档格式
    case invalidArchive
    /// 物理文件在磁盘中不存在
    case fileNotFound
}

// MARK: - DependencyKey

import Dependencies
import UFPCore

public enum DocumentExtractionServiceKey: DependencyKey {
    public static var liveValue: any DocumentExtractionServiceProtocol {
        ServiceContainer.shared.resolveOptional((any DocumentExtractionServiceProtocol).self) ?? NoOpDocumentExtractionService()
    }
    public static var testValue: any DocumentExtractionServiceProtocol {
        ServiceContainer.shared.resolveOptional((any DocumentExtractionServiceProtocol).self) ?? NoOpDocumentExtractionService()
    }
    public static var previewValue: any DocumentExtractionServiceProtocol { NoOpDocumentExtractionService() }
}

extension DependencyValues {
    public var documentExtractionService: any DocumentExtractionServiceProtocol {
        get { self[DocumentExtractionServiceKey.self] }
        set { self[DocumentExtractionServiceKey.self] = newValue }
    }
}

/// 无操作文档提取服务（测试/预览占位，DI 未就绪时降级）
public final class NoOpDocumentExtractionService: DocumentExtractionServiceProtocol, Sendable {
    public init() {}
    public func canExtract(format: DocumentFormat) -> Bool { false }
    public func extractText(from url: URL) async throws -> String { "" }
}
