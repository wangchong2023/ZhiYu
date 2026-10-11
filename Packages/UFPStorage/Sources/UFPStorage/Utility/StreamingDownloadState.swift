//
//  StreamingDownloadState.swift
//  UFPStorage
//
//  Created by Antigravity on 2026/10/11.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[UFPStorage] 通用存储引擎包
//  核心职责：通用流式下载器的任务状态枚举，与业务完全无关。
//

import Foundation

/// 通用流式下载任务状态枚举。
public enum StreamingDownloadState: Sendable, Equatable {
    /// 等待排队
    case pending
    /// 下载中，附带 0.0~1.0 进度、实时速率、已下载字节数与期望总字节数
    case downloading(
        progress: Double,
        bytesPerSecond: Double = 0,
        downloadedBytes: Int64 = 0,
        totalBytes: Int64 = 0
    )
    /// 暂停中（断点续传数据已捕获）
    case paused
    /// 校验签名与指纹中（100% 下载完成）
    case verifying
    /// 下载且校验完成，已安全移入目标目录
    case completed(localURL: URL)
    /// 用户主动取消下载
    case cancelled
    /// 下载或校验失败，记录异常信息
    case failed(error: String)
}