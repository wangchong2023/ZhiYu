//
//  KnowledgePageRepository.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：持久化引擎：GRDB/SQLite 仓库、同步、加密、数据库管理。
//
import Foundation
import UFPCore
@preconcurrency import UFPStorage

// MARK: - 核心存储 (KnowledgePageRepository)

/// 知识库 页面存储：封装基于 GRDB 的高性能 CRUD 操作。
final class KnowledgePageRepository: KnowledgeRepository, DatabaseWriterProvider, Sendable {
    init(dbWriter _: any DatabaseWriter) {
        // 保留原构造函数，但内部实际上不持有静态 dbWriter，使用动态计算属性以支持多笔记本笔记本无缝热切换并消除 closed 连接挂起隐慢
    }

    // MARK: - 页面操作 (CRUD)

    /// 保存单个页面
    func save(_ page: KnowledgePage) async throws {
        let writer = try await dbWriter
        _ = try await writer.write { db in
            try self.save(page, in: db)
        }
    }

    /// 在已有数据库事务中保存页面及其关联链接，返回实际使用的 ID
    @discardableResult

    /// 保存
    /// - Parameter page: page
    /// - Returns: 唯一标识
    func save(_ page: KnowledgePage, in db: Database) throws -> UUID {
        let savedID = try upsert(page, in: db)
        try saveLinks(sourceID: savedID, targetTitles: page.outgoingLinks, in: db)
        return savedID
    }

    /// 执行具体的 Upsert 逻辑 (包含加密拦截)
    private func upsert(_ page: KnowledgePage, in db: Database) throws -> UUID {
        var p = page
        
        // --- 隐私加固：应用级内容加密 (@P0) ---
        if p.isPrivate {
            p.content = try SecurityManager.shared.encrypt(p.content)
            if let snippet = p.rawTextSnippet {
                p.rawTextSnippet = try SecurityManager.shared.encrypt(snippet)
            }
        }
        
        // 查找是否已存在相同 ID 或相同标题的记录
        let existingByID = try KnowledgePage.filter(KnowledgePage.Columns.id == page.id).fetchOne(db)
        let existingByTitle = existingByID == nil ? try KnowledgePage.filter(KnowledgePage.Columns.title == page.title).fetchOne(db) : nil
        
        if let existing = existingByID ?? existingByTitle {
            p.id = existing.id
            p.createdAt = existing.createdAt
            p.updatedAt = Date()
            try p.update(db)
            return existing.id
        } else {
            p.createdAt = Date()
            p.updatedAt = Date()
            try p.insert(db)
            return p.id
        }
    }

    /// 删除
    /// - Parameter id: id
    func delete(id: UUID) async throws {
        let writer = try await dbWriter
        _ = try await writer.write { db in
            try KnowledgePage.filter(KnowledgePage.Columns.id == id).deleteAll(db)
        }
    }

    // MARK: - 查询 (Queries)

    /// 拉取All
    /// - Returns: 列表
    func fetchAll() async throws -> [KnowledgePage] {
        try await fetchPagesOrdered { $0.order(KnowledgePage.Columns.updatedAt.desc) }
    }

    /// 拉取
    /// - Parameter id: id
    /// - Returns: 可选值
    func fetch(id: UUID) async throws -> KnowledgePage? {
        try await fetchOneFiltered { type in
            type.filter(KnowledgePage.Columns.id == id)
        }
    }

    /// 拉取
    /// - Parameter title: title
    /// - Returns: 可选值
    func fetch(title: String) async throws -> KnowledgePage? {
        try await fetchOneFiltered { type in
            type.filter(KnowledgePage.Columns.title == title)
        }
    }

    /// 共享的单条查询辅助：在 writer.read 闭包内直接构造过滤请求并解密，避免外部 QueryInterfaceRequest 跨 actor 捕获。
    private func fetchOneFiltered(
        _ queryBuilder: @escaping @Sendable (KnowledgePage.Type) -> QueryInterfaceRequest<KnowledgePage>
    ) async throws -> KnowledgePage? {
        let writer = try await dbWriter
        return try await writer.read { db in
            try queryBuilder(KnowledgePage.self).fetchOne(db).map { self.decryptIfPrivate($0) }
        }
    }

    /// 拉取RecentlyUpdated
    /// - Parameter limit: limit（非正数时直接返回空数组，防止 SQLite `LIMIT -1` 扫全表）
    /// - Returns: 列表
    func fetchRecentlyUpdated(limit: Int) async throws -> [KnowledgePage] {
        guard limit > 0 else { return [] }
        return try await fetchPagesOrdered { request in
            request.order(KnowledgePage.Columns.updatedAt.desc).limit(limit)
        }
    }

    /// 共享的多条查询辅助：按指定排序/限制请求查询并解密，消除 fetchAll / fetchRecentlyUpdated 间的 writer.read + decryptPages 样板。
    private func fetchPagesOrdered(
        _ requestBuilder: @escaping @Sendable (QueryInterfaceRequest<KnowledgePage>) -> QueryInterfaceRequest<KnowledgePage>
    ) async throws -> [KnowledgePage] {
        let writer = try await dbWriter
        return try await writer.read { db in
            let rawPages = try requestBuilder(KnowledgePage.all()).fetchAll(db)
            return self.decryptPages(rawPages)
        }
    }

    /// 搜索 —— 双阶段检索策略：FTS5 优先（精排）→ CJK LIKE 后备（模糊）
    ///
    /// FTS5 (unicode61 分词器) 对 ASCII/拉丁词序列效果极佳，但对连续 CJK 字符流无法做子词分割。
    /// 当 FTS5 匹配无法建立模式（中文查询词不含空格分隔符时）或返回空集合时，
    /// 自动降级到 LIKE 模糊匹配，覆盖中文标题与正文的「包含」检索场景。
    ///
    /// - Parameter query: 搜索关键词，支持中英文及中英混合
    /// - Returns: 按相关度排序的页面列表
    func search(query: String) async throws -> [KnowledgePage] {
        guard SQLQuerySanitizer.isValidQuery(query) else { return [] }
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let writer = try await dbWriter
        return try await writer.read { db in
            // 阶段一：FTS5 全文搜索（对英文及带空格的中文分词友好）
            // 注意：加密后的私密内容无法通过 FTS5 全文搜索，但标题仍可被搜索到
            if let pattern = FTS5Pattern(matchingAnyTokenIn: trimmedQuery) {
                let ftsResults = try KnowledgePage
                    .joining(required: KnowledgePage.contentSnapshot.filter(Column(AppConstants.Storage.Tables.pagesFTS).match(pattern)))
                    .order(sql: StorageConstants.SQL.rank)
                    .fetchAll(db)
                if !ftsResults.isEmpty {
                    return self.decryptPages(ftsResults)
                }
            }

            // 阶段二：CJK LIKE 后备检索（转义 % / _ / \ 通配符，防止全表扫描穿透与误匹配）
            let likePattern = SQLQuerySanitizer.makeLikePattern(trimmedQuery)
            let escapeToken = SystemConstants.Character.backslash
            let rawPages = try KnowledgePage.filter(
                KnowledgePage.Columns.title.like(likePattern, escape: escapeToken) ||
                KnowledgePage.Columns.content.like(likePattern, escape: escapeToken)
            ).order(KnowledgePage.Columns.updatedAt.desc).fetchAll(db)
            return self.decryptPages(rawPages)
        }
    }

    // MARK: - 反向链接 (Links)

    /// 拉取Backlinks
    /// - Returns: 列表
    func fetchBacklinks(for targetID: UUID) async throws -> [UUID] {
        let writer = try await dbWriter
        return try await writer.read { db in
            let links = try PageLink.filter(PageLink.Columns.targetID == targetID).fetchAll(db)
            return links.map { $0.sourceID }
        }
    }

    private func saveLinks(sourceID: UUID, targetTitles: [String], in db: Database) throws {
        try PageLink.filter(PageLink.Columns.sourceID == sourceID).deleteAll(db)
        for title in targetTitles {
            if let target = try KnowledgePage.filter(KnowledgePage.Columns.title == title).fetchOne(db) {
                let link = PageLink(sourceID: sourceID, targetID: target.id, createdAt: Date())
                try link.insert(db)
            }
        }
    }

    // MARK: - 标签管理 (Tag Management)

    /// 重命名Tag
    func renameTag(old oldTag: String, to newTag: String) async throws {
        let writer = try await dbWriter
        try await writer.write { db in
            try self.updatePagesWithTag(oldTag, in: db) { idx, updatedPage in
                var page = updatedPage
                page.tags[idx] = newTag
                return page
            }
        }
    }

    /// 删除Tag
    /// - Parameter tag: tag
    func deleteTag(_ tag: String) async throws {
        let writer = try await dbWriter
        try await writer.write { db in
            try self.updatePagesWithTag(tag, in: db) { idx, updatedPage in
                var page = updatedPage
                page.tags.remove(at: idx)
                return page
            }
        }
    }

    /// 统一的标签批量更新辅助：查询包含指定标签的页面，对每个页面执行变换闭包后写回数据库。
    /// 消除 renameTag / deleteTag 两处重复的 filter + fetchAll + firstIndex + update 样板。
    /// - Parameters:
    ///   - tag: 目标标签
    ///   - db: 数据库连接
    ///   - transform: 对 (标签索引, 页面副本) 执行变换并返回更新后的页面
    private func updatePagesWithTag(_ tag: String, in db: Database, transform: (Int, KnowledgePage) -> KnowledgePage) throws {
        let pagesToUpdate = try KnowledgePage.filter(KnowledgePage.Columns.tags.like("%\"\(tag)\"%")).fetchAll(db)
        for p in pagesToUpdate {
            guard let idx = p.tags.firstIndex(of: tag) else { continue }
            let updatedPage = transform(idx, p)
            try updatedPage.update(db)
        }
    }

    /// 删除All
    func deleteAll() async throws {
        let writer = try await dbWriter
        _ = try await writer.write { db in
            try KnowledgePage.deleteAll(db)
            try PageLink.deleteAll(db)
        }
    }

    // MARK: - 统计 (Stats)

    /// 计数
    /// - Returns: 数值
    func count() async throws -> Int {
        let writer = try await dbWriter
        return try await writer.read { db in
            try KnowledgePage.fetchCount(db)
        }
    }

    // MARK: - 辅助解密逻辑

    /// 批量解密私有页面（消除多处 `rawPages.map { self.decryptIfPrivate($0) }` 重复）。
    private func decryptPages(_ pages: [KnowledgePage]) -> [KnowledgePage] {
        pages.map { decryptIfPrivate($0) }
    }

    private func decryptIfPrivate(_ page: KnowledgePage) -> KnowledgePage {
        guard page.isPrivate else { return page }
        var p = page
        do {
            p.content = try SecurityManager.shared.decrypt(p.content)
            if let snippet = p.rawTextSnippet {
                p.rawTextSnippet = try SecurityManager.shared.decrypt(snippet)
            }
        } catch {
            Logger.shared.error("Failed to" + " decrypt private" + " page: \(page.title)", error: error)
        }
        return p
    }
}

// MARK: - GRDB 关联定义

extension KnowledgePage {
    // GRDB 关联声明要求 static let，且 GRDB 的 belongsTo 返回类型非 Sendable。
    // 该常量仅在 GRDB 查询构建时使用，无并发变异风险。
    nonisolated(unsafe) static let contentSnapshot = belongsTo(KnowledgePageFTS.self, using: ForeignKey(["id"], to: ["id"]))
}
