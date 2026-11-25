//
//  StreamingDownloadDelegateHelper.swift
//  UFPStorage
//
//  Created by Antigravity on 2026/11/25.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[UFPStorage] 通用存储引擎包 / URLSession 代理桥接
//  核心职责：桥接 URLSessionDownloadDelegate 回调至 StreamingDownloadManager Actor，
//           严格校验 HTTP 2xx 状态码，阻断错误页污染进度与本地文件。
//

import Foundation

/// URLSession 代理协助类。负责无声桥接后台系统通知至 Actor。
internal final class StreamingDownloadDelegateHelper: NSObject, URLSessionDownloadDelegate, Sendable {

    /// 持有弱引用的 Actor 控制器
    private let manager: StreamingDownloadManager

    init(manager: StreamingDownloadManager) {
        self.manager = manager
        super.init()
    }

    /// URLSession 下载进度回调，更新下载进度
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let taskID = downloadTask.taskDescription, totalBytesExpectedToWrite > 0 else { return }

        // 拦截 4xx/5xx 错误响应体进度上报，防止将错误页的几十字节覆盖为模型真实文件大小
        if let httpResponse = downloadTask.response as? HTTPURLResponse,
           !StreamingDownloadConstants.httpSuccessStatusRange.contains(httpResponse.statusCode) {
            return
        }

        Task {
            await manager.updateProgress(for: taskID, totalBytesWritten: totalBytesWritten, totalBytesExpectedToWrite: totalBytesExpectedToWrite)
        }
    }

    /// URLSession 下载完成回调，将临时文件移交至管理器处理
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let taskID = downloadTask.taskDescription else { return }

        // 严格校验 HTTP 状态码，拦截 404/500 等异常请求，防止将错误页面保存
        if let httpResponse = downloadTask.response as? HTTPURLResponse,
           !StreamingDownloadConstants.httpSuccessStatusRange.contains(httpResponse.statusCode) {
            Task {
                await manager.updateState(for: taskID, to: .failed(error: "Network error: HTTP \(httpResponse.statusCode)"))
                await manager.clearActiveTask(for: taskID)
            }
            return
        }

        // 创建临时安全副本，防止系统委托在退出 didFinishDownloading 瞬间删除文件
        let tempDirectory = FileManager.default.temporaryDirectory
        let safeTempURL = tempDirectory.appendingPathComponent(UUID().uuidString + ".bin")

        do {
            try FileManager.default.moveItem(at: location, to: safeTempURL)
            let defaultVerificationFailedMessage = "verification failed"
            Task {
                await manager.completeDownload(for: taskID, tempFileURL: safeTempURL, verificationFailedMessage: defaultVerificationFailedMessage)
            }
        } catch {
            Task {
                await manager.updateState(for: taskID, to: .failed(error: "temporary copy failed: \(error.localizedDescription)"))
                await manager.clearActiveTask(for: taskID)
            }
        }
    }

    /// URLSession 任务完成回调，处理下载错误（自动忽略用户主动取消）
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let taskDescription = task.taskDescription else { return }

        if let error = error {
            let nsError = error as NSError
            // 如果是用户主动取消任务，忽略报错
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                return
            }

            Task {
                await manager.handleDownloadError(for: taskDescription, error: error)
            }
        }
    }
}
