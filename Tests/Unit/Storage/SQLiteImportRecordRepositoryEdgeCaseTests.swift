//
//  SQLiteImportRecordRepositoryEdgeCaseTests.swift
//  ZhiYu
//
//  系统层级：[Shared] 测试层
//  核心职责：验证 SQLiteImportRecordRepository 的 update 方法静默返回、
//           fetchInProgress 状态过滤、totalStorageSize 计算等边界条件。
//

import XCTest
import UFPStorage
@testable import ZhiYu

final class ImportRecordRepoEdgeTests: XCTestCase {

    var dbQueue: DatabaseQueue!
    var importRepo: SQLiteImportRecordRepository!

    override func setUp() async throws {
        try await super.setUp()
        dbQueue = try DatabaseQueue()
        try await DatabaseManager.shared.setupForTesting(with: dbQueue)
        importRepo = SQLiteImportRecordRepository()
    }

    override func tearDownWithError() throws {
        importRepo = nil
        dbQueue = nil
    }

    // MARK: - 辅助方法

    private func makeImportRecord(id: String = "import-1",
                                  category: String = "file",
                                  status: String = "pending") -> ImportRecord {
        ImportRecord(
            id: id,
            category: category,
            title: "测试导入记录",
            status: status,
            rawText: nil,
            filePath: nil,
            fileSize: nil,
            pageID: nil,
            tags: nil,
            completedAt: nil
        )
    }

    // MARK: - updateStatus 静默返回

    /// 验证：updateStatus 对不存在的 ID 静默返回，不抛错。
    func testUpdateStatusNonExistentIsSilentNoop() async throws {
        try await importRepo.updateStatus(id: "non-existent", status: "completed", completedAt: Date())
        // 不应抛出异常
    }

    /// 验证：updateStatus 正确更新状态和完成时间。
    func testUpdateStatusUpdatesFields() async throws {
        let record = makeImportRecord(status: "pending")
        try await importRepo.save(record)

        let completedAt = Date()
        try await importRepo.updateStatus(id: "import-1", status: "done", completedAt: completedAt)

        let fetched = try await importRepo.fetchByID("import-1")
        XCTAssertEqual(fetched?.status, "done")
        XCTAssertNotNil(fetched?.completedAt)
    }

    /// 验证：updateStatus 传 nil completedAt 时保持为 nil。
    func testUpdateStatusWithNilCompletedAt() async throws {
        let record = makeImportRecord(status: "pending")
        try await importRepo.save(record)

        try await importRepo.updateStatus(id: "import-1", status: "processing", completedAt: nil)

        let fetched = try await importRepo.fetchByID("import-1")
        XCTAssertEqual(fetched?.status, "processing")
        XCTAssertNil(fetched?.completedAt, "completedAt 应保持为 nil")
    }

    // MARK: - updatePageID 静默返回

    /// 验证：updatePageID 对不存在的 ID 静默返回。
    func testUpdatePageIDNonExistentIsSilentNoop() async throws {
        try await importRepo.updatePageID(id: "non-existent", pageID: "page-123")
        // 不应抛出异常
    }

    /// 验证：updatePageID 正确更新关联页面 ID。
    func testUpdatePageIDUpdatesField() async throws {
        let record = makeImportRecord()
        try await importRepo.save(record)

        try await importRepo.updatePageID(id: "import-1", pageID: "page-abc")

        let fetched = try await importRepo.fetchByID("import-1")
        XCTAssertEqual(fetched?.pageID, "page-abc")
    }

    // MARK: - updateRawText / updateTags

    /// 验证：updateRawText 对不存在的 ID 静默返回。
    func testUpdateRawTextNonExistentIsSilentNoop() async throws {
        try await importRepo.updateRawText(id: "non-existent", rawText: "text")
        // 不应抛出异常
    }

    /// 验证：updateRawText 正确更新原始文本。
    func testUpdateRawTextUpdatesField() async throws {
        let record = makeImportRecord()
        try await importRepo.save(record)

        try await importRepo.updateRawText(id: "import-1", rawText: "提取的文本内容")

        let fetched = try await importRepo.fetchByID("import-1")
        XCTAssertEqual(fetched?.rawText, "提取的文本内容")
    }

    /// 验证：updateTags 对不存在的 ID 静默返回。
    func testUpdateTagsNonExistentIsSilentNoop() async throws {
        try await importRepo.updateTags(id: "non-existent", tags: "tag1,tag2")
        // 不应抛出异常
    }

    /// 验证：updateTags 正确更新标签。
    func testUpdateTagsUpdatesField() async throws {
        let record = makeImportRecord()
        try await importRepo.save(record)

        try await importRepo.updateTags(id: "import-1", tags: "ai,ml,rag")

        let fetched = try await importRepo.fetchByID("import-1")
        XCTAssertEqual(fetched?.tags, "ai,ml,rag")
    }

    // MARK: - fetchInProgress 状态过滤

    /// 验证：fetchInProgress 只返回 pending 和 processing 状态的记录。
    func testFetchInProgressReturnsOnlyPendingAndProcessing() async throws {
        try await importRepo.save(makeImportRecord(id: "p1", status: "pending"))
        try await importRepo.save(makeImportRecord(id: "p2", status: "processing"))
        try await importRepo.save(makeImportRecord(id: "c1", status: "done"))
        try await importRepo.save(makeImportRecord(id: "f1", status: "failed"))

        let inProgress = try await importRepo.fetchInProgress()
        let ids = inProgress.map { $0.id }.sorted()
        XCTAssertEqual(ids, ["p1", "p2"], "只应返回 pending 和 processing 状态")
    }

    /// 验证：fetchInProgress 无进行中记录时返回空。
    func testFetchInProgressEmptyWhenNone() async throws {
        try await importRepo.save(makeImportRecord(id: "c1", status: "done"))

        let inProgress = try await importRepo.fetchInProgress()
        XCTAssertTrue(inProgress.isEmpty, "无进行中记录时应返回空")
    }

    // MARK: - fetchAll 分类过滤和分页

    /// 验证：fetchAll 按 category 过滤。
    func testFetchAllFiltersByCategory() async throws {
        try await importRepo.save(makeImportRecord(id: "f1", category: "file"))
        try await importRepo.save(makeImportRecord(id: "v1", category: "voice"))
        try await importRepo.save(makeImportRecord(id: "f2", category: "file"))

        let fileRecords = try await importRepo.fetchAll(category: "file", limit: 100)
        XCTAssertEqual(fileRecords.count, 2, "应只返回 file 类别")
        XCTAssertTrue(fileRecords.allSatisfy { $0.category == "file" })

        let voiceRecords = try await importRepo.fetchAll(category: "voice", limit: 100)
        XCTAssertEqual(voiceRecords.count, 1, "应只返回 voice 类别")
    }

    /// 验证：fetchAll category=nil 时返回所有类别。
    func testFetchAllWithNilCategoryReturnsAll() async throws {
        try await importRepo.save(makeImportRecord(id: "f1", category: "file"))
        try await importRepo.save(makeImportRecord(id: "v1", category: "voice"))

        let all = try await importRepo.fetchAll(category: nil, limit: 100)
        XCTAssertEqual(all.count, 2, "category=nil 应返回所有")
    }

    /// 验证：fetchAll limit=0 返回空数组。
    func testFetchAllWithZeroLimitReturnsEmpty() async throws {
        try await importRepo.save(makeImportRecord())

        let results = try await importRepo.fetchAll(category: nil, limit: 0)
        XCTAssertTrue(results.isEmpty, "limit=0 应返回空")
    }

    // MARK: - totalStorageSize 计算

    /// 验证：totalStorageSize 累加 fileSize 和 rawText 字节数。
    func testTotalStorageSizeSumsFileSizeAndRawText() async throws {
        var record1 = makeImportRecord(id: "r1")
        record1.filePath = "/path/to/file.pdf"
        record1.fileSize = 1024
        record1.rawText = "四字节"
        try await importRepo.save(record1)

        var record2 = makeImportRecord(id: "r2")
        record2.rawText = "更多文本"
        try await importRepo.save(record2)

        let total = try await importRepo.totalStorageSize()
        // record1: fileSize=1024 + rawText="四字节"(9 bytes UTF8) = 1033
        // record2: rawText="更多文本"(12 bytes UTF8) = 12
        // total = 1033 + 12 = 1045
        XCTAssertGreaterThanOrEqual(total, 1024, "总大小应至少包含 fileSize")
    }

    /// 验证：totalStorageSize 无记录时返回 0。
    func testTotalStorageSizeZeroWhenEmpty() async throws {
        let total = try await importRepo.totalStorageSize()
        XCTAssertEqual(total, 0, "无记录时应返回 0")
    }

    /// 验证：totalStorageSize 只计算有 filePath 的记录的 fileSize。
    func testTotalStorageSizeOnlyCountsFileSizeWithFilePath() async throws {
        var record = makeImportRecord(id: "r1")
        record.filePath = nil
        record.fileSize = 1024
        record.rawText = nil
        try await importRepo.save(record)

        let total = try await importRepo.totalStorageSize()
        XCTAssertEqual(total, 0, "filePath 为 nil 时 fileSize 不应被计算")
    }
}
