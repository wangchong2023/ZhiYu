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

    @ObservationIgnored private var searchTask: Task<Void, Never>?
    @ObservationIgnored @Inject private var linkService: LinkService  // inject_exempt: DI 就绪后由 AppEnvironment 实例化
    @ObservationIgnored @Inject private var pageStore: any AnyPageStoreCapabilities  // inject_exempt: DI 就绪后由 AppEnvironment 实例化

    @ObservationIgnored private var cancellables = Set<AnyCancellable>()

    init() {
        AppEventBus.shared.subscribe()
            .sink { [weak self] in if case .clearAllDataRequested = $0 { self?.clearAll() } }
            .store(in: &cancellables)
    }

    /// 执行高级（混合）搜索
    func performAdvancedSearch(query: String) async -> [KnowledgePage] {
        isSearching = true
        defer { isSearching = false }

        let res = await linkService.hybridSearchWithDiagnostics(
            query: query,
            in: await pageStore.pages,
            embeddingProvider: pageStore.embeddingProvider
        )

        lastSearchDiagnostic = res.diagnostic
        searchResults = res.results
        return res.results
    }

    private func performDebouncedSearch(query: String) {
        searchTask?.cancel()

        guard !query.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }

        searchTask = Task {
            isSearching = true
            // 300ms 防抖
            try? await Task.sleep(nanoseconds: 300_000_000)
            if Task.isCancelled { return }

            let res = await linkService.hybridSearchWithDiagnostics(
                query: query,
                in: await pageStore.pages,
                embeddingProvider: pageStore.embeddingProvider
            )

            if !Task.isCancelled {
                searchResults = res.results
                lastSearchDiagnostic = res.diagnostic
                isSearching = false
            }
        }
    }

    /// 清除All
    func clearAll() {
        searchTask?.cancel()
        searchText = ""
        searchResults = []
        isSearching = false
        lastSearchDiagnostic = nil
        isAdvancedSearching = false
    }
}
