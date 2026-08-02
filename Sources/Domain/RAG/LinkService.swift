//
//  LinkService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层
//  核心职责：实现 Link 模块的核心业务逻辑服务。
//
import Foundation

/// [L1] 领域层：处理链接解析、反向链接、搜索与标签聚合
/// Actor 模式确保大规模并发下的线程安全。
/// 搜索结果包装结构
public struct SearchResult: Sendable {
    public let results: [KnowledgePage]
    public let diagnostic: SearchDiagnosticInfo
}

actor LinkService {

    // MARK: - Link Resolution
    
    /// 根据标题或别名查找页面 (不区分大小写)
    /// - Parameters:
    ///   - title: 目标标题
    ///   - pages: 搜索范围
    /// - Returns: 匹配到的页面，若未找到返回 nil
    func pageByTitle(_ title: String, in pages: [KnowledgePage]) -> KnowledgePage? {
        pages.first { $0.title.lowercased() == title.lowercased() }
            ?? pages.first { $0.aliases.contains(where: { $0.lowercased() == title.lowercased() }) }
    }

    /// 获取引用了指定页面的所有反向链接页面
    /// - Parameters:
    ///   - pageID: 目标页面 ID
    ///   - pages: 搜索范围
    /// - Returns: 引用者页面列表
    func backlinks(for pageID: UUID, in pages: [KnowledgePage]) -> [KnowledgePage] {
        guard let page = pages.first(where: { $0.id == pageID }) else { return [] }
        return pages.filter { p in
            p.relatedPageIDs.contains(pageID) ||
            p.outgoingLinks.contains(where: { link in
                link.lowercased() == page.title.lowercased() ||
                page.aliases.contains(where: { $0.lowercased() == link.lowercased() })
            })
        }
    }

    /**
     * @description: 根据 ID 获取页面
     * @param {UUID} id 目标 ID
     * @param {[KnowledgePage]} pages 搜索范围
     * @return {KnowledgePage?} 匹配到的页面
     */

    /// pageByID
    /// - Parameter id: id
    /// - Returns: 可选值
    func pageByID(_ id: UUID, in pages: [KnowledgePage]) -> KnowledgePage? {
        pages.first { $0.id == id }
    }

    // MARK: - Search
    /// 关键词全文搜索，在页面标题、正文、标签、别名中匹配查询词。
    /// 结果按四级相关性强制排序，短查询场景下标题完全匹配权重最高。
    /// - Parameter query: 搜索关键词
    /// - Parameter pages: 搜索范围（知识页面全集）
    /// - Returns: 按相关性降序排列的匹配页面列表
    func search(query: String, in pages: [KnowledgePage]) -> [KnowledgePage] {
        guard !query.isEmpty else { return pages }
        let lowercasedQuery = query.lowercased()

        // Step 1: 多字段模糊匹配过滤（标题 / 正文 / 标签 / 别名）
        let filtered = pages.filter { page in
            page.title.lowercased().contains(lowercasedQuery) ||
            page.content.lowercased().contains(lowercasedQuery) ||
            page.tags.contains(where: { $0.lowercased().contains(lowercasedQuery) }) ||
            page.aliases.contains(where: { $0.lowercased().contains(lowercasedQuery) })
        }

        // Step 2: 四级相关性强制排序：精确标题 > 前缀标题 > 包含标题 > 正文含关键词
        return filtered.sorted { p1, p2 in
            let t1 = p1.title.lowercased()
            let t2 = p2.title.lowercased()

            // Level 1: 标题完全一致（最高优先级）
            let exact1 = (t1 == lowercasedQuery)
            let exact2 = (t2 == lowercasedQuery)
            if exact1 != exact2 { return exact1 }

            // Level 2: 标题前缀匹配
            let prefix1 = t1.hasPrefix(lowercasedQuery)
            let prefix2 = t2.hasPrefix(lowercasedQuery)
            if prefix1 != prefix2 { return prefix1 }

            // Level 3: 标题包含匹配
            let contains1 = t1.contains(lowercasedQuery)
            let contains2 = t2.contains(lowercasedQuery)
            if contains1 != contains2 { return contains1 }

            // Level 4: 同层保持原始稳定性
            return false
        }
    }

    /// 混合检索（关键词 + 语义向量），使用 RRF 算法融合排序，并附带诊断信息。
    /// 短查询（< 阈值）自动提升关键词权重以降低语义噪音。
    /// - Parameter query: 搜索查询
    /// - Parameter pages: 搜索范围
    /// - Parameter embeddingProvider: 向量嵌入服务
    /// - Returns: 包含排序结果和诊断信息的 SearchResult
    func hybridSearchWithDiagnostics(query: String, in pages: [KnowledgePage], embeddingProvider: any EmbeddingProvider) async -> SearchResult {
        // Step 1: 关键词检索
        let keywordResults = search(query: query, in: pages)
        // Step 2: 语义向量检索
        let semanticScored = await embeddingProvider.search(query: query, topK: 50)
        let semanticResults = filterSemanticResults(semanticScored, query: query, pages: pages)

        let k = SearchConstants.rrfK
        var scores: [UUID: Double] = [:]
        var diagMap: [UUID: (fts: Int, vec: Int)] = [:]

        // Step 3: 动态权重 — 短查询（如"3D"）关键词匹配更可靠
        let keywordWeight = query.count < SearchConstants.shortQueryThreshold ? 1.5 : 1.0
        let semanticWeight = 1.0

        // Step 4: RRF 分数累加 — 关键词结果
        for (index, page) in keywordResults.enumerated() {
            scores[page.id, default: 0.0] += (1.0 / Double(k + index + 1)) * keywordWeight
            diagMap[page.id] = (index + 1, -1)
        }

        // Step 5: RRF 分数累加 — 语义结果
        for (index, page) in semanticResults.enumerated() {
            scores[page.id, default: 0.0] += (1.0 / Double(k + index + 1)) * semanticWeight
            let existing = diagMap[page.id] ?? (-1, -1)
            diagMap[page.id] = (existing.fts, index + 1)
        }

        // Step 6: 按融合分数降序排列并去重
        let sortedIDs = scores.keys.sorted { (scores[$0] ?? 0) > (scores[$1] ?? 0) }
        let results = sortedIDs.compactMap { id in pages.first { $0.id == id } }

        // Step 7: 构建诊断信息（Top-10 结果的详细排名）
        let topDiagnostics = results.prefix(10).compactMap { page -> SearchDiagnosticInfo.ResultScore? in
            guard let ranks = diagMap[page.id] else { return nil }
            return SearchDiagnosticInfo.ResultScore(
                id: page.id,
                title: page.title,
                ftsRank: ranks.fts,
                vectorRank: ranks.vec,
                finalScore: scores[page.id] ?? 0
            )
        }

        let diagnosticInfo = SearchDiagnosticInfo(
            query: query,
            rewrittenQuery: query,
            ftsCount: keywordResults.count,
            vectorCount: semanticResults.count,
            rrfTopResults: topDiagnostics
        )

        return SearchResult(results: results, diagnostic: diagnosticInfo)
    }

    /// 按动态相似度门禁过滤语义搜索结果。
    /// 短查询使用更高门槛以减少噪音，但高置信度结果（> 0.85）始终保留。
    /// - 短查询策略：仅保留 score > 高置信阈值 或标题含查询词的候选
    /// - 长查询策略：保留 score > 动态阈值的所有候选
    private func filterSemanticResults(
        _ scored: [(id: UUID, score: Float)],
        query: String,
        pages: [KnowledgePage]
    ) -> [KnowledgePage] {
        let similarityThreshold: Float = query.count < SearchConstants.shortQueryThreshold
            ? SearchConstants.semanticThresholdShort
            : SearchConstants.semanticThresholdLong
        return scored
            .filter { res in
                if query.count < SearchConstants.shortQueryThreshold {
                    if res.score > SearchConstants.semanticShortHighConfidence { return true }
                    if let page = pages.first(where: { $0.id == res.id }) {
                        return page.title.lowercased().contains(query.lowercased())
                    }
                    return false
                }
                return res.score > similarityThreshold
            }
            .compactMap { res in pages.first(where: { $0.id == res.id }) }
    }

    /// Reciprocal Rank Fusion (RRF) 算法 — 融合关键词与语义排序结果。
    /// 公式: score = Σ 1 / (k + rank_i)，k 为平滑常数（默认 60）。
    /// 同一页面出现在两路结果中时分数累加，最终按 RRF 总分降序去重。
    func rrf(keywordResults: [KnowledgePage], semanticResults: [KnowledgePage], k: Int = 60) -> [KnowledgePage] {
        var scores: [UUID: Double] = [:]

        // Step 1: 关键词结果 RRF 打分
        for (index, page) in keywordResults.enumerated() {
            scores[page.id, default: 0] += 1.0 / Double(k + index + 1)
        }

        // Step 2: 语义结果 RRF 打分（与关键词结果累加）
        for (index, page) in semanticResults.enumerated() {
            scores[page.id, default: 0] += 1.0 / Double(k + index + 1)
        }

        // Step 3: 按 RRF 总分降序排列，从并集中去重映射回 KnowledgePage
        let sortedIDs = scores.keys.sorted { (scores[$0] ?? 0) > (scores[$1] ?? 0) }

        let allCandidates = Set(keywordResults + semanticResults)
        return sortedIDs.compactMap { id in allCandidates.first { $0.id == id } }
    }

    /**
     * @description: 提取全库所有标签及其引用计数，并按热度降序排列
     * @param {[KnowledgePage]} pages 页面全集
     * @return {[(tag: String, count: Int)]} 标签元组数组
     */

    /// allTags
    /// - Returns: 列表
    func allTags(in pages: [KnowledgePage]) -> [(tag: String, count: Int)] {
        var tagCount: [String: Int] = [:]
        for page in pages {
            for tag in page.tags {
                let cleanedTag = tag.replacingOccurrences(of: "#", with: "")
                tagCount[cleanedTag, default: 0] += 1
            }
        }
        return tagCount.map { ($0.key, $0.value) }.sorted {
            if $0.1 != $1.1 { return $0.1 > $1.1 }
            return $0.0 < $1.0
        }
    }

    // MARK: - Refactoring Logic

    /**
     * @description: 准备页面重命名流程，扫描库中所有对该页面的 [[]] 引用并执行替换
     * @param {KnowledgePage} page 待重命名的原始页面
     * @param {String} newTitle 新标题
     * @param {[KnowledgePage]} allPages 页面全集
     * @return {[KnowledgePage]} 返回所有受影响且已更新内容的页面列表
     */

    /// 准备重命名
    /// - Parameter page: page
    /// - Returns: 列表
    func prepareRename(page: KnowledgePage, to newTitle: String, in allPages: [KnowledgePage]) -> [KnowledgePage] {
        let oldTitle = page.title
        var modifiedPages: [KnowledgePage] = []

        // 1. 处理主页面
        var updatedMainPage = page
        updatedMainPage.title = newTitle
        updatedMainPage.updatedAt = Date()
        modifiedPages.append(updatedMainPage)

        // 2. 扫描并替换其他页面中的反向链接
        for p in allPages where p.id != page.id {
            if p.content.contains("[[\(oldTitle)]]") {
                var refPage = p
                refPage.content = refPage.content.replacingOccurrences(of: "[[\(oldTitle)]]", with: "[[\(newTitle)]]")
                refPage.updatedAt = Date()
                modifiedPages.append(refPage)
            }
        }

        return modifiedPages
    }
}
