//
//  PerformanceBenchmarker.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：性能基准测试：测量核心操作的吞吐量与延迟。
//
import Foundation

/// 性能压测工具 (仅限 Debug/Internal 使用)
/// 专门用于验证 50,000+ 文档规模下的系统承载力
@MainActor
final class PerformanceBenchmarker {
    static let shared = PerformanceBenchmarker()

    /// 模拟海量文档导入并测量索引耗时
    func runStressTest(count: Int = 50000, store: any AnyPageStore) async {
        Logger.shared.info(" [Benchmark]  \(count) ...")

        let startTime = CFAbsoluteTimeGetCurrent()

        // 批量创建模拟数据
        for i in 1...count {
            if i % 5000 == 0 {
                let currentTotal = await store.pages.count
                Logger.shared.info(" [Benchmark]  \(i) ...  DB : \(currentTotal)")
            }

            _ = try? await store.createPage(
                title: "\(CoreConstants.Benchmark.stressTestPagePrefix)\(i)",
                pageType: .raw,
                customIcon: nil,
                content: "\(CoreConstants.Benchmark.stressTestContentPrefix)\(i)" + CoreConstants.Benchmark.stressTestContentMiddle + "\(CoreConstants.Benchmark.stressTestContentSuffix)\(UUID().uuidString)",
                tags: [CoreConstants.Benchmark.tagBenchmark, CoreConstants.Benchmark.tagStressTest],
                sourceURL: nil,
                rawSnippet: nil,
                fileSize: nil,
                sourceType: nil
            )
        }

        let duration = CFAbsoluteTimeGetCurrent() - startTime
        Logger.shared.info(" [Benchmark] ")
        Logger.shared.info(" : \(String(format: "%.2f", duration))s")
        Logger.shared.info(" : \(String(format: "%.2f", Double(count)/duration)) docs/s")

        // 触发一次全量搜索测试
        await measureSearchPerformance(store: store)
    }

    private func measureSearchPerformance(store: any AnyPageStore) async {
        let query = CoreConstants.Benchmark.searchQuery
        let startTime = CFAbsoluteTimeGetCurrent()

        let results = await store.searchPages(query: query)

        let duration = CFAbsoluteTimeGetCurrent() - startTime
        Logger.shared.info(" [Benchmark] \"\(query)\"")
        Logger.shared.info(" : \(String(format: "%.2f", duration * 1000))ms")
        Logger.shared.info(" : \(results.count)")

        if duration > 0.8 {
            Logger.shared.warning(" [Warning]  800ms ")
        }
    }
}
