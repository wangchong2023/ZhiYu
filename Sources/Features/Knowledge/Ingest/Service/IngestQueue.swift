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
        let operation = BlockOperation { [weak self] in
            guard let self = self else { return }

            DispatchQueue.main.async { self.isProcessing = true }

            let task = Task {
                do {
                    try Task.checkCancellation()
                    Logger.shared.debug(" [IngestQueue]" + " Processing task:" + " \(title)")
                    let result = try await llmService.smartIngest(title: title, rawContent: content, pages: pages)
                    try Task.checkCancellation()
                    
                    let page = KnowledgePage(title: title, content: result.compiledContent, tags: result.suggestedTags)

                    await MainActor.run {
                        onResult(page)
                        self.activeTasks.removeValue(forKey: taskID)
                        self.decrementCount()
                    }
                } catch is CancellationError {
                    Logger.shared.debug(" [IngestQueue]" + " Task cancelled:" + " \(title)")
                } catch {
                    Logger.shared.error(" [IngestQueue] Task failed: " + title + ", Error: " + String(describing: error))
                    await MainActor.run { 
                        self.activeTasks.removeValue(forKey: taskID)
                        self.decrementCount() 
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.activeTasks[taskID] = task
            }
        }

        pendingCount += 1
        operationQueue.addOperation(operation)
    }

    private func decrementCount() {
        pendingCount = max(0, pendingCount - 1)
        if pendingCount == 0 {
            isProcessing = false
        }
    }
}

// MARK: - Sendable 合规声明
extension IngestQueue: @unchecked Sendable {}
