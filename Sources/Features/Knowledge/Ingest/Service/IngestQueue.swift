//
//  IngestQueue.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：知识摄入：文档导入、URL 抓取、OCR 扫描、PDF 解析。
//
import Foundation
import UFPCore
import Combine

/// 离线处理队列
@MainActor
final class IngestQueue: ObservableObject {
    static let shared = IngestQueue()

    @Published var pendingCount: Int = 0
    @Published var isProcessing: Bool = false

    private let operationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 2 
        queue.qualityOfService = .utility
        return queue
    }()

    private var activeTasks: [UUID: Task<Void, Never>] = [:]
    /// 单调递增代数标记：每次 Vault 切换取消任务时递增，杜绝旧 Vault 异步结果写穿新 Vault
    private var generation: UInt64 = 0
    private var cancellables: Set<AnyCancellable> = []

    private init() {
        NotificationCenter.default.publisher(for: .vaultWillSwitch)
            .sink { [weak self] _ in
                self?.cancelAllTasks()
            }
            .store(in: &cancellables)
    }

    /// 拦截通知取消所有任务
    private func cancelAllTasks() {
        Logger.shared.debug(" [IngestQueue] Vault will switch, cancelling all pending tasks")
        generation &+= 1
        operationQueue.cancelAllOperations()
        for task in activeTasks.values {
            task.cancel()
        }
        activeTasks.removeAll()
        pendingCount = 0
        isProcessing = false
    }

    /// 将导入任务加入队列
    func enqueue(title: String, content: String, llmService: any LLMServiceProtocol, pages: [KnowledgePage], onResult: @escaping @Sendable @MainActor (KnowledgePage) -> Void) {
        let taskID = UUID()
        let capturedGeneration = generation
        pendingCount += 1
        isProcessing = true

        // 在 @MainActor 同步登记 activeTasks，消除旧 OperationQueue -> DispatchQueue.main.async 登记窗口竞态
        let task = Task { [weak self] in
            do {
                try Task.checkCancellation()
                Logger.shared.debug(FeatureConstants.LogDetails.ingestQueuePrefix + FeatureConstants.LogDetails.processingTask + " \(title)")
                let result = try await llmService.smartIngest(title: title, rawContent: content, pages: pages)
                try Task.checkCancellation()

                let page = KnowledgePage(title: title, content: result.compiledContent, tags: result.suggestedTags)

                await MainActor.run {
                    guard let self, !Task.isCancelled, self.generation == capturedGeneration else { return }
                    onResult(page)
                    self.activeTasks.removeValue(forKey: taskID)
                    self.decrementCount()
                }
            } catch is CancellationError {
                Logger.shared.debug(FeatureConstants.LogDetails.ingestQueuePrefix + FeatureConstants.LogDetails.taskCancelled + " \(title)")
                await MainActor.run {
                    guard let self, self.generation == capturedGeneration else { return }
                    self.activeTasks.removeValue(forKey: taskID)
                    self.decrementCount()
                }
            } catch {
                Logger.shared.error(FeatureConstants.LogDetails.taskFailedPrefix + title + FeatureConstants.LogDetails.errorPrefix + String(describing: error))
                await MainActor.run {
                    guard let self, self.generation == capturedGeneration else { return }
                    self.activeTasks.removeValue(forKey: taskID)
                    self.decrementCount()
                }
            }
        }

        activeTasks[taskID] = task
    }

    private func decrementCount() {
        pendingCount = max(0, pendingCount - 1)
        if pendingCount == 0 {
            isProcessing = false
        }
    }
}
