//
//  iOSFileArchiver.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 平台适配层
//  核心职责：iOS 平台实现：后台任务、Widget、文件归档、Spotlight 索引。
//
import Foundation
import ZIPFoundation

/// iOS/watchOS 归档实现 (基于 ZIPFoundation)
final class iOSFileArchiver: FileArchiverProtocol, Sendable {

    /// zip
    func zip(directory sourceDir: URL, to destinationURL: URL) async throws {
        try FileManager.default.zipItem(at: sourceDir, to: destinationURL)
    }
}
