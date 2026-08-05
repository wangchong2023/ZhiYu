//
//  PerformanceService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0.5] 系统集成层
//  核心职责：实现 Performance 模块的核心业务逻辑服务。
//
import Foundation
import UFPCore
#if canImport(MachO)
import MachO
#endif

// MARK: - Performance Service
/// Runtime performance monitoring and diagnostics for Knowledge Base.
@MainActor
final class PerformanceService: ObservableObject {
    @Published var metrics: PerformanceMetrics = PerformanceMetrics()
    @Published var isMonitoring: Bool = false
    
    /// 性能指标类型
    enum MetricType: Sendable {
        case databaseLoad
        case databaseSave
        case ragChain
        case search
        case graphLayout
        case lint
    }

    struct PerformanceMetrics: Identifiable {
        let id = UUID()
        var pageCount: Int = 0
        var totalWords: Int = 0
        var graphNodeCount: Int = 0
        var graphEdgeCount: Int = 0
        var memoryUsageMB: Double = 0
        var saveDuration: TimeInterval = 0
        var loadDuration: TimeInterval = 0
        var lintDuration: TimeInterval = 0
        var graphLayoutDuration: TimeInterval = 0
        var searchDuration: TimeInterval = 0
        
        // RAG & AI 指标
        var ragChainDuration: TimeInterval = 0
        var llmCallCount: Int = 0
        var aiSuccessRate: Double = 1.0
        
        var lastUpdated: Date = Date()
    }
    
    // MARK: - Timing Helpers

    /// 记录特定类型的耗时
    func record(_ type: MetricType, duration: TimeInterval) {
        switch type {
        case .databaseLoad: updateMetric("load", duration: duration)
        case .databaseSave: updateMetric("save", duration: duration)
        case .ragChain: updateMetric("ragChain", duration: duration)
        case .search: updateMetric("search", duration: duration)
        case .graphLayout: updateMetric("graphLayout", duration: duration)
        case .lint: updateMetric("lint", duration: duration)
        }
    }

    /// 测量
    /// - Parameter label: label
    /// - Parameter operation: operation
    /// - Returns: 返回值
    func measure<T>(_ label: String, operation: () -> T) -> T {
        let start = CFAbsoluteTimeGetCurrent()
        let result = operation()
        let duration = CFAbsoluteTimeGetCurrent() - start
        updateMetric(label, duration: duration)
        return result
    }

    /// 异步测量支持
    func measureAsync<T>(_ label: String, operation: () async throws -> T) async throws -> T {
        let start = CFAbsoluteTimeGetCurrent()
        do {
            let result = try await operation()
            let duration = CFAbsoluteTimeGetCurrent() - start
            updateMetric(label, duration: duration)
            return result
        } catch {
            // 记录失败率
            metrics.aiSuccessRate = (metrics.aiSuccessRate * Double(metrics.llmCallCount) + 0.0) / Double(metrics.llmCallCount + 1)
            throw error
        }
    }

    private func updateMetric(_ label: String, duration: TimeInterval) {
        switch label {
        case "save": metrics.saveDuration = duration
        case "load": metrics.loadDuration = duration
        case "lint": metrics.lintDuration = duration
        case "graphLayout": metrics.graphLayoutDuration = duration
        case "search": metrics.searchDuration = duration
        case "ragChain": metrics.ragChainDuration = duration
        default: break
        }
        
        if label.contains(CoreConstants.PerformanceLabel.ai) || label.contains(CoreConstants.PerformanceLabel.llm) || label == CoreConstants.PerformanceLabel.ragChain {
            metrics.llmCallCount += 1
        }
        
        metrics.lastUpdated = Date()
    }
    
    // MARK: - Memory
    /// 更新MemoryUsage
    func updateMemoryUsage() {
        // Use task_info via Mach API
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / SystemConstants.bytesPerIntegerT)
        let kernReturn: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        if kernReturn == KERN_SUCCESS {
            metrics.memoryUsageMB = Double(info.resident_size) / SystemConstants.bytesPerKB / SystemConstants.bytesPerKB
        }
    }
    
    // MARK: - Page Metrics
    /// 更新PageMetrics
    /// - Parameter pageCount: 页面总数
    /// - Parameter totalWords: 总字数
    func updatePageMetrics(pageCount: Int, totalWords: Int) {
        metrics.pageCount = pageCount
        metrics.totalWords = totalWords
        metrics.lastUpdated = Date()
    }
    
    // MARK: - Graph Metrics
    /// 更新GraphMetrics
    /// - Parameter nodes: nodes
    /// - Parameter edges: edges
    func updateGraphMetrics(nodes: Int, edges: Int) {
        metrics.graphNodeCount = nodes
        metrics.graphEdgeCount = edges
        metrics.lastUpdated = Date()
    }
    
    // MARK: - Summary
    var summary: String {
        """
        \(L10n.Common.Perf.summary.title)
        
        \(L10n.Common.Perf.summary.pages): \(metrics.pageCount) (\(metrics.totalWords) \(L10n.Common.Perf.summary.words))
        \(L10n.Common.Perf.summary.graph): \(metrics.graphNodeCount) \(L10n.Common.Perf.summary.nodes), \(metrics.graphEdgeCount) \(L10n.Common.Perf.summary.edges)
        \(L10n.Common.Perf.summary.memory): \(String(format: "%.1f", metrics.memoryUsageMB)) MB
        \(L10n.Common.Perf.summary.save): \(String(format: "%.3f", metrics.saveDuration))s
        \(L10n.Common.Perf.summary.load): \(String(format: "%.3f", metrics.loadDuration))s
        \(L10n.Common.Perf.summary.lint): \(String(format: "%.3f", metrics.lintDuration))s
        \(L10n.Common.Perf.summary.graphLayout): \(String(format: "%.3f", metrics.graphLayoutDuration))s
        \(L10n.Common.Perf.summary.search): \(String(format: "%.3f", metrics.searchDuration))s
        """
    }
}
