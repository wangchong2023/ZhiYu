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

/// 离线处理队列（带严格并发上限的 FIFO 调度器，防止批量导入触发 LLM 并发风暴）
@MainActor
final class IngestQueue: ObservableObject {
    static let shared = IngestQueue()

    internal enum QueueLimits {
        /// 最大并发执行摄入任务数
        static let maxConcurrentTasks: Int = 2
    }

    private struct QueuedIngestJob {
        let id: UUID
        let title: String
        let content: String
        let llmService: any LLMServiceProtocol
        let pages: [KnowledgePage]
        let onResult: @Sendable @MainActor (KnowledgePage) -> Void
        let generation: UInt64
    }

    @Published var pendingCount: Int = 0
    @Published var isProcessing: Bool = false

    private var pendingJobs: [QueuedIngestJob] = []
    private var activeTasks: [UUID: Task<Void, Never>] = [:]
    /// 当前并发运行中的任务数（供状态校验与单测验证并发上限）
    internal var activeTaskCount: Int { activeTasks.count }
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

    /// 拦截通知取消所有运行中与排队中的任务
    private func cancelAllTasks() {
        Logger.shared.debug(" [IngestQueue] Vault will switch, cancelling all pending tasks")
        generation &+= 1
        pendingJobs.removeAll()
        for task in activeTasks.values {
            task.cancel()
        }
        activeTasks.removeAll()
        pendingCount = 0
        isProcessing = false
    }

    /// 将导入任务加入队列（拦截纯空白内容，并严格按 maxConcurrentTasks 限流并发执行）
    func enqueue(title: String, content: String, llmService: any LLMServiceProtocol, pages: [KnowledgePage], onResult: @escaping @Sendable @MainActor (KnowledgePage) -> Void) {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let job = QueuedIngestJob(
            id: UUID(),
            title: title,
            content: content,
            llmService: llmService,
            pages: pages,
            onResult: onResult,
            generation: generation
        )
        pendingJobs.append(job)
        pendingCount += 1
        isProcessing = true
        drainPendingJobs()
    }

    /// 在并发槽位未满时从 FIFO 队列拉起下一批任务
    private func drainPendingJobs() {
        while activeTasks.count < QueueLimits.maxConcurrentTasks, !pendingJobs.isEmpty {
            let job = pendingJobs.removeFirst()
            startJob(job)
        }
    }

    private func startJob(_ job: QueuedIngestJob) {
        let task = Task { [weak self] in
            do {
                try Task.checkCancellation()
                Logger.shared.debug(FeatureConstants.LogDetails.ingestQueuePrefix + FeatureConstants.LogDetails.processingTask + " \(job.title)")
                let result = try await job.llmService.smartIngest(title: job.title, rawContent: job.content, pages: job.pages)
                try Task.checkCancellation()

                let page = KnowledgePage(title: job.title, content: result.compiledContent, tags: result.suggestedTags)

                await MainActor.run {
                    guard let self, !Task.isCancelled, self.generation == job.generation else { return }
                    job.onResult(page)
                    self.completeJob(id: job.id, generation: job.generation)
                }
            } catch is CancellationError {
                Logger.shared.debug(FeatureConstants.LogDetails.ingestQueuePrefix + FeatureConstants.LogDetails.taskCancelled + " \(job.title)")
                await MainActor.run {
                    self?.completeJob(id: job.id, generation: job.generation)
                }
            } catch {
                Logger.shared.error(FeatureConstants.LogDetails.taskFailedPrefix + job.title + FeatureConstants.LogDetails.errorPrefix + String(describing: error))
                await MainActor.run {
                    self?.completeJob(id: job.id, generation: job.generation)
                }
            }
        }
        activeTasks[job.id] = task
    }

    private func completeJob(id: UUID, generation capturedGeneration: UInt64) {
        guard self.generation == capturedGeneration else { return }
        activeTasks.removeValue(forKey: id)
        decrementCount()
        drainPendingJobs()
    }

    private func decrementCount() {
        pendingCount = max(0, pendingCount - 1)
        if pendingCount == 0 {
            isProcessing = false
        }
    }
}
