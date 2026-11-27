//
//  SearchStore.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：全局搜索：混合 FTS5+向量检索、命令面板。
//
import Foundation
import UFPCore
import Observation
import Combine

/// 搜索状态存储，负责处理搜索过滤、防抖及结果缓存。
@MainActor
@Observable
public final class SearchStore {
    public var searchText: String = "" {
        didSet { performDebouncedSearch(query: searchText) }
    }
    public var searchResults: [KnowledgePage] = []
    public var isSearching = false
    public var lastSearchDiagnostic: SearchDiagnosticInfo?
    public var isAdvancedSearching = false

    private enum SearchLimits {
        /// 防抖延迟（300ms）
        static let debounceDelayNanoseconds: UInt64 = 300_000_000
    }

    @ObservationIgnored private var searchTask: Task<Void, Never>?
    /// 搜索代次递增计数器（防御快速键入取消旧任务误清新任务 isSearching、乱序结果覆盖与跨 Vault 泄露）
    @ObservationIgnored private var searchGeneration: UInt64 = 0
    @ObservationIgnored @Inject private var linkService: LinkService  // inject_exempt: DI 就绪后由 AppEnvironment 实例化
    @ObservationIgnored @Inject private var pageStore: any AnyPageStoreCapabilities  // inject_exempt: DI 就绪后由 AppEnvironment 实例化

    @ObservationIgnored private var cancellables = Set<AnyCancellable>()

    init() {
        AppEventBus.shared.subscribeClearAllData { [weak self] in
            self?.clearAll()
        }
        .store(in: &cancellables)

        // 多 Vault 切换时立即取消防抖搜索并清空旧笔记本搜索结果与诊断信息，防止跨 Vault 泄露
        NotificationCenter.default.publisher(for: .vaultWillSwitch)
            .sink { [weak self] _ in
                self?.clearAll()
            }
            .store(in: &cancellables)
    }

    /// 执行高级（混合）搜索（带代次守卫，防止切库或并发搜索乱序覆写）
    func performAdvancedSearch(query: String) async -> [KnowledgePage] {
        searchTask?.cancel()
        searchGeneration &+= 1
        let capturedGeneration = searchGeneration

        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            lastSearchDiagnostic = nil
            isSearching = false
            return []
        }

        isSearching = true
        defer {
            if searchGeneration == capturedGeneration {
                isSearching = false
            }
        }

        let res = await linkService.hybridSearchWithDiagnostics(
            query: query,
            in: await pageStore.pages,
            embeddingProvider: pageStore.embeddingProvider
        )

        guard searchGeneration == capturedGeneration else { return [] }
        lastSearchDiagnostic = res.diagnostic
        searchResults = res.results
        return res.results
    }

    private func performDebouncedSearch(query: String) {
        searchTask?.cancel()
        searchGeneration &+= 1
        let capturedGeneration = searchGeneration

        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            lastSearchDiagnostic = nil
            isSearching = false
            return
        }

        isSearching = true
        searchTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: SearchLimits.debounceDelayNanoseconds)
            guard !Task.isCancelled, self.searchGeneration == capturedGeneration else { return }

            let res = await self.linkService.hybridSearchWithDiagnostics(
                query: query,
                in: await self.pageStore.pages,
                embeddingProvider: self.pageStore.embeddingProvider
            )

            guard !Task.isCancelled, self.searchGeneration == capturedGeneration else { return }
            self.searchResults = res.results
            self.lastSearchDiagnostic = res.diagnostic
            self.isSearching = false
        }
    }

    /// 清除All
    func clearAll() {
        searchGeneration &+= 1
        searchTask?.cancel()
        searchTask = nil
        searchText = ""
        searchResults = []
        isSearching = false
        lastSearchDiagnostic = nil
        isAdvancedSearching = false
    }
}
