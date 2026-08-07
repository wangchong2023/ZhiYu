//
//  ModelDownloadCapabilities.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/29.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层 / 协议契约
//  核心职责：定义后台静默下载大模型权重文件、断点续传管理以及下载状态事件分发的规范，解耦基础设施的具体类。
//

import Foundation

/// 任务下载状态枚举
public enum DownloadState: Codable, Sendable, Equatable {
    case pending         // 等待排队
    case downloading(progress: Double, bytesPerSecond: Double = 0) // 下载中，附带 0.0 到 1.0 的百分比进度与实时下载速率
    case paused          // 暂停中 (包含断点续传数据已捕获)
    case verifying       // 校验签名与指纹中 (100% 下载完成)
    case completed(localURL: URL) // 下载且校验完成，模型已安全移入沙盒 Document 目录
    case cancelled       // 用户主动取消下载
    case failed(error: String)  // 下载或校验失败，记录异常信息
}

/// 大模型权重后台静默下载能力契约
public protocol ModelDownloadCapabilities: Sendable {
    
    /// 开始下载大模型权重文件（支持后台静默下载及多网自动容灾）
    /// - Parameters:
    ///   - modelId: 模型唯一标识 ID
    ///   - remoteURL: 远程 CDN 权重包下载 URL
    /// - Throws: 任务发起失败异常
    func startDownload(modelId: String, remoteURL: URL) async throws
    
    /// 暂停正在下载的权重任务，捕获断点续传数据 (resumeData)
    /// - Parameter modelId: 模型唯一标识 ID
    /// - Throws: 任务暂停失败异常
    func pauseDownload(modelId: String) async throws
    
    /// 恢复下载已经暂停的权重任务 (利用之前捕获的 resumeData)
    /// - Parameter modelId: 模型唯一标识 ID
    /// - Throws: 续传失败异常
    func resumeDownload(modelId: String) async throws
    
    /// 取消下载任务，彻底清除临时下载数据
    /// - Parameter modelId: 模型唯一标识 ID
    /// - Throws: 任务取消异常
    func cancelDownload(modelId: String) async throws
    
    /// 监听特定大模型任务的实时状态与进度变化流
    /// - Parameter modelId: 模型唯一标识 ID
    /// - Returns: 返回状态流转的异步 AsyncStream 序列，便于上层进行声明式渲染
    func observeDownloadState(for modelId: String) async -> AsyncStream<DownloadState>
}
