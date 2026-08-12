//
//  FileArchiverProtocol.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 底层基座层
//  核心职责：定义 FileArchiver 模块的抽象契约接口。
//
import Foundation
import Dependencies
import UFPCore

/// 文件归档协议
public protocol FileArchiverProtocol: Sendable {
    /// 将指定目录的内容压缩为 ZIP 文件
    /// - Parameters:
    ///   - sourceDir: 待压缩的源目录
    ///   - destinationURL: 目标文件路径 (应以 .zip 或 .pptx 结尾)
    func zip(directory sourceDir: URL, to destinationURL: URL) async throws

    /// 将 ZIP 归档文件解压到指定目录（含路径穿越防护）
    /// - Parameters:
    ///   - archiveURL: 待解压的 ZIP/归档文件 URL
    ///   - destinationURL: 目标解压目录
    /// - Throws: `FileArchiverError.extractionFailed` 或路径穿越错误
    func extractContents(from archiveURL: URL, to destinationURL: URL) throws
}

// MARK: - DependencyKey 注册

/// FileArchiverProtocol 的 DependencyKey（P7 迁移：过渡期 liveValue 从 ServiceContainer 解析）
public enum FileArchiverKey: DependencyKey {
    public static var liveValue: any FileArchiverProtocol {
        ServiceContainer.shared.resolve((any FileArchiverProtocol).self)
    }
    public static var testValue: any FileArchiverProtocol { NoOpFileArchiver() }
    public static var previewValue: any FileArchiverProtocol { NoOpFileArchiver() }
}

extension DependencyValues {
    /// 文件归档服务依赖
    public var fileArchiver: any FileArchiverProtocol {
        get { self[FileArchiverKey.self] }
        set { self[FileArchiverKey.self] = newValue }
    }
}

/// 无操作文件归档服务（测试/预览占位）
public final class NoOpFileArchiver: FileArchiverProtocol, @unchecked Sendable {
    public init() {}
    public func zip(directory sourceDir: URL, to destinationURL: URL) async throws {
        throw FileArchiverError.platformNotSupported
    }
    public func extractContents(from archiveURL: URL, to destinationURL: URL) throws {
        throw FileArchiverError.extractionFailed(reason: "NoOp")
    }
}

/// 文件归档过程中抛出的强类型异常枚举
public enum FileArchiverError: Error, Sendable {
    /// 目标平台不支持压缩归档操作 (替代原 405 错误码)
    case platformNotSupported
    /// 压缩流写入异常或物理磁盘空间不足
    case compressionFailed
    /// 解压失败（归档损坏、格式不支持等）
    case extractionFailed(reason: String)
}
