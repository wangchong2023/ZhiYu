//
//  KnowledgePageRepositoryUpsertTests.swift
//  ZhiYu
//
//  系统层级：[Shared] 测试层
//  核心职责：验证 KnowledgePageRepository 的 upsert 语义、标签管理 LIKE 子串误匹配、
//           链接解析静默跳过等边界条件，发现数据丢失和误匹配问题。
//

import XCTest
import UFPStorage
@testable import ZhiYu

final class KnowledgePageUpsertTests: XCTestCase {

    var dbQueue: DatabaseQueue!
    var repository: KnowledgePageRepository!

    override func setUp() async throws {
        try await super.setUp()
        dbQueue = try DatabaseQueue()
        try await DatabaseManager.shared.setupForTesting(with: dbQueue)
        repository = KnowledgePageRepository(dbWriter: dbQueue)
    }

    override func tearDownWithError() throws {
        repository = nil
        dbQueue = nil
    }

    // MARK: - 同名标题覆盖语义

    /// 验证：保存与已有页面同标题的新页面时，应覆盖已有页面而非创建副本。
    /// 这是 upsert 语义的核心契约——按 title 判重。
    func testSaveSameTitleOverwritesExistingPage() async throws {
        let original = KnowledgePage(title: "Duplicate", content: "原始内容", tags: ["original"])
        try await repository.save(original)

        let duplicate = KnowledgePage(title: "Duplicate", content: "新内容覆盖", tags: ["new"])
        try await repository.save(duplicate)

        let all = try await repository.fetchAll()
        XCTAssertEqual(all.count, 1, "同标题页面应覆盖而非创建副本")
        XCTAssertEqual(all.first?.content, "新内容覆盖", "内容应被新页面覆盖")
        XCTAssertEqual(all.first?.tags, ["new"], "标签应被新页面覆盖")
    }

    /// 验证：覆盖时保留原始 ID 和 createdAt，仅更新 updatedAt。
    func testSaveSameTitlePreservesOriginalIDAndCreatedAt() async throws {
        let original = KnowledgePage(title: "KeepID", content: "v1")
        try await repository.save(original)

        let fetchedOriginal = try await repository.fetch(title: "KeepID")
        let originalID = fetchedOriginal?.id
        let originalCreatedAt = fetchedOriginal?.createdAt

        // 等待至少 1 秒确保 updatedAt 不同
        try await Task.sleep(nanoseconds: 1_100_000_000)

        let updated = KnowledgePage(title: "KeepID", content: "v2")
        try await repository.save(updated)

        let fetchedUpdated = try await repository.fetch(title: "KeepID")
        XCTAssertEqual(fetchedUpdated?.id, originalID, "覆盖后 ID 应保持不变")
        XCTAssertEqual(fetchedUpdated?.createdAt, originalCreatedAt, "覆盖后 createdAt 应保持不变")
        XCTAssertNotEqual(fetchedUpdated?.updatedAt, originalCreatedAt, "updatedAt 应被刷新")
    }

    /// 验证：不同标题的页面应独立创建。
    func testSaveDifferentTitlesCreatesSeparatePages() async throws {
        let page1 = KnowledgePage(title: "PageA", content: "A")
        let page2 = KnowledgePage(title: "PageB", content: "B")
        try await repository.save(page1)
        try await repository.save(page2)

        let all = try await repository.fetchAll()
        XCTAssertEqual(all.count, 2, "不同标题应创建独立页面")
    }

    // MARK: - 标签 LIKE 子串误匹配

    /// 验证：renameTag 使用 LIKE %"tag"% 模式，子串标签不应被误匹配。
    /// 例如重命名 "ai" 不应影响包含 "aim" 或 "brain" 的页面。
    /// 注意：LIKE %"ai"% 匹配 JSON 中 "ai" 子串，但 "aim" 的 JSON 是 "aim"，
    /// 不包含 "ai" 后跟引号，所以不应被匹配。但 "ai" 出现在 "brain" 中时，
    /// JSON 是 "brain"，其中 "ai" 后面不是引号，所以也不应匹配。
    func testRenameTagDoesNotMatchSubstring() async throws {
        let page1 = KnowledgePage(title: "PageWithAI", content: "c1", tags: ["ai"])
        let page2 = KnowledgePage(title: "PageWithAim", content: "c2", tags: ["aim"])
        let page3 = KnowledgePage(title: "PageWithBrain", content: "c3", tags: ["brain"])
        try await repository.save(page1)
        try await repository.save(page2)
        try await repository.save(page3)

        try await repository.renameTag(old: "ai", to: "artificial-intelligence")

        let all = try await repository.fetchAll()
        let aiPage = all.first { $0.title == "PageWithAI" }
        let aimPage = all.first { $0.title == "PageWithAim" }
        let brainPage = all.first { $0.title == "PageWithBrain" }

        XCTAssertEqual(aiPage?.tags, ["artificial-intelligence"], "ai 标签应被重命名")
        XCTAssertEqual(aimPage?.tags, ["aim"], "aim 标签不应被误匹配")
        XCTAssertEqual(brainPage?.tags, ["brain"], "brain 标签不应被误匹配")
    }

    /// 验证：deleteTag 使用 LIKE %"tag"% 模式，子串标签不应被误删除。
    func testDeleteTagDoesNotMatchSubstring() async throws {
        let page1 = KnowledgePage(title: "HasAI", content: "c1", tags: ["ai", "keep"])
        let page2 = KnowledgePage(title: "HasAim", content: "c2", tags: ["aim", "keep"])
        try await repository.save(page1)
        try await repository.save(page2)

        try await repository.deleteTag("ai")

        let all = try await repository.fetchAll()
        let aiPage = all.first { $0.title == "HasAI" }
        let aimPage = all.first { $0.title == "HasAim" }

        XCTAssertEqual(aiPage?.tags, ["keep"], "ai 标签应被删除，保留 keep")
        XCTAssertEqual(aimPage?.tags, ["aim", "keep"], "aim 标签不应被误删除")
    }

    /// 验证：重命名不存在的标签时不应报错也不应修改任何页面。
    func testRenameNonExistentTagIsNoop() async throws {
        let page = KnowledgePage(title: "Test", content: "c", tags: ["real"])
        try await repository.save(page)

        try await repository.renameTag(old: "nonexistent", to: "new")

        let all = try await repository.fetchAll()
        XCTAssertEqual(all.first?.tags, ["real"], "不存在的标签重命名不应影响现有页面")
    }

    /// 验证：删除不存在的标签时不应报错。
    func testDeleteNonExistentTagIsNoop() async throws {
        let page = KnowledgePage(title: "Test", content: "c", tags: ["real"])
        try await repository.save(page)

        try await repository.deleteTag("nonexistent")

        let all = try await repository.fetchAll()
        XCTAssertEqual(all.first?.tags, ["real"], "不存在的标签删除不应影响现有页面")
    }

    // MARK: - 链接解析静默跳过

    /// 验证：saveLinks 对目标页面不存在的链接标题静默跳过，不创建链接记录。
    func testSaveLinksSkipsNonExistentTargets() async throws {
        let source = KnowledgePage(
            title: "Source",
            content: "链接到 [[Target]] 和 [[NonExistent]]",
            tags: []
        )
        try await repository.save(source)

        let target = KnowledgePage(title: "Target", content: "目标页面")
        try await repository.save(target)

        // 重新保存 source 以触发 saveLinks（此时 Target 已存在）
        try await repository.save(source)

        let backlinks = try await repository.fetchBacklinks(for: target.id)
        XCTAssertTrue(backlinks.contains(source.id), "已存在的目标页面应建立反向链接")

        // NonExistent 页面不存在，不应创建链接记录
        let nonExistentPage = try await repository.fetch(title: "NonExistent")
        XCTAssertNil(nonExistentPage, "不存在的目标页面不应被创建")
    }

    /// 验证：saveLinks 先删除旧链接再插入新链接，重复保存不应产生重复链接。
    func testSaveLinksDoesNotDuplicateOnResave() async throws {
        let source = KnowledgePage(title: "Src", content: "链接到 [[Target]]")
        let target = KnowledgePage(title: "Target", content: "t")
        try await repository.save(target)
        try await repository.save(source)
        try await repository.save(source)
        try await repository.save(source)

        let backlinks = try await repository.fetchBacklinks(for: target.id)
        let sourceBacklinks = backlinks.filter { $0 == source.id }
        XCTAssertEqual(sourceBacklinks.count, 1, "重复保存不应产生重复链接记录")
    }

    // MARK: - 空标题和特殊字符

    /// 验证：空标题页面可以正常保存和检索。
    func testSaveEmptyTitlePage() async throws {
        let page = KnowledgePage(title: "", content: "空标题内容")
        try await repository.save(page)

        let fetched = try await repository.fetch(title: "")
        XCTAssertNotNil(fetched, "空标题页面应能被检索")
        XCTAssertEqual(fetched?.content, "空标题内容")
    }

    /// 验证：标题包含 SQL 特殊字符（单引号、分号）时不导致 SQL 注入。
    func testSaveTitleWithSQLSpecialCharacters() async throws {
        let maliciousTitle = "Page'; DROP TABLE pages;--"
        let page = KnowledgePage(title: maliciousTitle, content: "恶意标题")
        try await repository.save(page)

        let all = try await repository.fetchAll()
        XCTAssertEqual(all.count, 1, "SQL 特殊字符标题不应导致表被删除")
        XCTAssertEqual(all.first?.title, maliciousTitle, "标题应原样保存")

        // 验证 pages 表仍然存在
        let count = try await repository.count()
        XCTAssertEqual(count, 1, "pages 表应完好无损")
    }

    /// 验证：搜索词包含 FTS5 特殊字符时不崩溃。
    func testSearchWithFTS5SpecialCharacters() async throws {
        let page = KnowledgePage(title: "Test", content: "content with special chars")
        try await repository.save(page)

        // FTS5 特殊字符：双引号、星号、括号
        // 应降级到 LIKE 搜索而不崩溃
        let results1 = try await repository.search(query: "\"test\"")
        XCTAssertFalse(results1.isEmpty, "双引号搜索词应降级到 LIKE 并匹配")

        let results2 = try await repository.search(query: "test*")
        XCTAssertFalse(results2.isEmpty, "星号搜索词应降级到 LIKE 并匹配")

        let results3 = try await repository.search(query: "(test)")
        XCTAssertFalse(results3.isEmpty, "括号搜索词应降级到 LIKE 并匹配")
    }

    // MARK: - deleteAll 清空语义

    /// 验证：deleteAll 同时清空 pages 和 page_links 表。
    func testDeleteAllClearsPagesAndLinks() async throws {
        let source = KnowledgePage(title: "Src", content: "链接到 [[Target]]")
        let target = KnowledgePage(title: "Target", content: "t")
        try await repository.save(target)
        try await repository.save(source)

        let countBefore = try await repository.count()
        XCTAssertEqual(countBefore, 2)

        try await repository.deleteAll()

        let countAfter = try await repository.count()
        XCTAssertEqual(countAfter, 0, "deleteAll 后 pages 表应为空")
        let backlinks = try await repository.fetchBacklinks(for: target.id)
        XCTAssertTrue(backlinks.isEmpty, "deleteAll 后 page_links 表应为空")
    }

    // MARK: - fetchRecentlyUpdated 分页边界

    /// 验证：fetchRecentlyUpdated(limit: 0) 返回空数组而不崩溃。
    func testFetchRecentlyUpdatedWithZeroLimit() async throws {
        let page = KnowledgePage(title: "Test", content: "c")
        try await repository.save(page)

        let results = try await repository.fetchRecentlyUpdated(limit: 0)
        XCTAssertTrue(results.isEmpty, "limit=0 应返回空数组")
    }

    /// 验证：fetchRecentlyUpdated(limit:) 超过实际数量时返回全部。
    func testFetchRecentlyUpdatedWithLimitExceedingCount() async throws {
        for i in 0..<3 {
            let page = KnowledgePage(title: "Page\(i)", content: "c\(i)")
            try await repository.save(page)
        }

        let results = try await repository.fetchRecentlyUpdated(limit: 100)
        XCTAssertEqual(results.count, 3, "limit 超过实际数量时应返回全部")
    }

    // MARK: - 私密页面加密与安全断言

    /// 验证：私密页面内容在持久化时被加密，底层数据库中不包含明文内容。
    func testSavePrivatePageEncryptsContentInDatabase() async throws {
        let plainContent = "Top Secret Financial Data 2026"
        let snippet = "Financial Data Snippet"
        let page = KnowledgePage(title: "Secret Vault", content: plainContent, tags: ["private", "confidential"], rawTextSnippet: snippet)
        
        try await repository.save(page)

        // 1. 从 Repository 读取应自动解密还原明文
        let fetched = try await repository.fetch(title: "Secret Vault")
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.content, plainContent)
        XCTAssertEqual(fetched?.rawTextSnippet, snippet)

        // 2. 直接绕过 Repository 检查 SQLite 原始行，验证底层存储的确实不是明文
        let rawRow = try await dbQueue.read { db in
            try Row.fetchOne(db, sql: "SELECT content, raw_snippet FROM pages WHERE title = ?", arguments: ["Secret Vault"])
        }
        XCTAssertNotNil(rawRow)
        let rawStoredContent: String = rawRow?["content"] ?? ""
        let rawStoredSnippet: String? = rawRow?["raw_snippet"]
        
        XCTAssertNotEqual(rawStoredContent, plainContent, "SQLite 底层存储绝不能为未加密的明文")
        if let storedSnippet = rawStoredSnippet {
            XCTAssertNotEqual(storedSnippet, snippet, "SQLite 底层存储的摘要绝不能为明文")
        }
    }

    /// 验证：空内容页面、空标签页面保存安全
    func testSavePageWithEmptyContentAndTags() async throws {
        let page = KnowledgePage(title: "EmptyPage", content: "", tags: [])
        try await repository.save(page)

        let fetched = try await repository.fetch(title: "EmptyPage")
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.content, "")
        XCTAssertTrue(fetched?.tags.isEmpty ?? false)
    }
}
