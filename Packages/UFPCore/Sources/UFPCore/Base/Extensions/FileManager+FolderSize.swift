//
//  FileManager+FolderSize.swift
//  UFPCore
//
//  Created by Antigravity on 2026/10/11.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 基础设施层
//  核心职责：FileManager 便利扩展 — 递归统计指定目录下的文件总字节大小。
//

import Foundation

extension FileManager {
    /// 计算指定目录下的全部非隐藏文件总字节大小
    /// - Parameter url: 目标目录 URL
    /// - Returns: 目录总字节数（Int64）
    public func folderSize(at url: URL) -> Int64 {
        var totalSize: Int64 = 0
        guard let enumerator = enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) else {
            return 0
        }
        while let fileURL = enumerator.nextObject() as? URL {
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
               let fileSize = resourceValues.fileSize {
                totalSize += Int64(fileSize)
            }
        }
        return totalSize
    }
}
