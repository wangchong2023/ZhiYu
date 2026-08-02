//
//  UnsupportedFileArchiver.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 底层基座层
//  核心职责：平台不支持功能的安全桩实现，遵循协议提供空操作或未实现提示。
//
import Foundation

/// 不支持的文件归档服务占位符
public final class UnsupportedFileArchiver: FileArchiverProtocol, @unchecked Sendable {
    public init() {}

    /// zip
    public func zip(directory sourceDir: URL, to destinationURL: URL) async throws {
        throw FileArchiverError.platformNotSupported
    }

    /// 当前平台不支持解压运算
    public func extractContents(from archiveURL: URL, to destinationURL: URL) throws {
        throw FileArchiverError.platformNotSupported
    }
}
