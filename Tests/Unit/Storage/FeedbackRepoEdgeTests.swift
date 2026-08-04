//
//  FeedbackRepoEdgeTests.swift
//  ZhiYu
//
//  系统层级：[Shared] 测试层
//  核心职责：验证 SQLiteFeedbackRepository 的 updateStatus 原生 SQL、
//           fetchAll limit 边界、fetchByID 主键查询等边界条件。
//

import XCTest
import UFPStorage
@testable import ZhiYu

final class FeedbackRepoEdgeTests: XCTestCase {

    var dbQueue: DatabaseQueue!
    var feedbackRepo: SQLiteFeedbackRepository!

    override func setUp() async throws {
        try await super.setUp()
        dbQueue = try DatabaseQueue()
        try await DatabaseManager.shared.setupForTesting(with: dbQueue)
        feedbackRepo = SQLiteFeedbackRepository()
    }

    override func tearDownWithError() throws {
        feedbackRepo = nil
        dbQueue = nil
    }

    // MARK: - 辅助方法

    private func makeFeedback(id: String = "fb-1",
                              title: String = "测试反馈",
                              category: String = "bug",
                              rating: Int = 3,
                              status: FeedbackStatus = .pending) -> FeedbackEntry {
        FeedbackEntry(
            id: id,
            title: title,
            category: category,
            rating: rating,
            content: "反馈内容",
            appVersion: "1.0.0",
            osVersion: "17.0",
            deviceModel: "iPhone 17",
            status: status
        )
    }

    // MARK: - save / fetchByID

    /// 验证：save 插入新反馈，fetchByID 能检索到。
    func testSaveAndFetchByID() async throws {
        let entry = makeFeedback(id: "fb-save", title: "保存测试")
        try await feedbackRepo.save(entry)

        let fetched = try await feedbackRepo.fetchByID(id: "fb-save")
        XCTAssertNotNil(fetched, "应能检索到保存的反馈")
        XCTAssertEqual(fetched?.title, "保存测试")
        XCTAssertEqual(fetched?.rating, 3)
    }

    /// 验证：save 对同 ID 执行更新（GRDB save 语义）。
    func testSaveUpdatesExisting() async throws {
        let original = makeFeedback(id: "fb-dup", title: "原始", rating: 1)
        try await feedbackRepo.save(original)

        let updated = makeFeedback(id: "fb-dup", title: "更新后", rating: 5)
        try await feedbackRepo.save(updated)

        let fetched = try await feedbackRepo.fetchByID(id: "fb-dup")
        XCTAssertEqual(fetched?.title, "更新后", "同 ID 应更新")
        XCTAssertEqual(fetched?.rating, 5)
    }

    /// 验证：fetchByID 对不存在的 ID 返回 nil。
    func testFetchByIDNonExistentReturnsNil() async throws {
        let fetched = try await feedbackRepo.fetchByID(id: "non-existent")
        XCTAssertNil(fetched, "不存在的 ID 应返回 nil")
    }

    // MARK: - fetchAll limit 边界

    /// 验证：fetchAll 按 createdAt 降序排列。
    func testFetchAllOrderedByCreatedAtDesc() async throws {
        try await feedbackRepo.save(makeFeedback(id: "fb1", title: "第一"))
        try await Task.sleep(nanoseconds: 50_000_000)
        try await feedbackRepo.save(makeFeedback(id: "fb2", title: "第二"))

        let results = try await feedbackRepo.fetchAll(limit: 10)
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results.first?.id, "fb2", "最新的应排在前面")
    }

    /// 验证：fetchAll limit=0 返回空数组。
    func testFetchAllWithZeroLimitReturnsEmpty() async throws {
        try await feedbackRepo.save(makeFeedback())
        let results = try await feedbackRepo.fetchAll(limit: 0)
        XCTAssertTrue(results.isEmpty, "limit=0 应返回空")
    }

    /// 验证：fetchAll limit 超过记录数时返回全部。
    func testFetchAllLimitExceedsCount() async throws {
        try await feedbackRepo.save(makeFeedback(id: "fb1"))
        let results = try await feedbackRepo.fetchAll(limit: 100)
        XCTAssertEqual(results.count, 1, "应返回全部记录")
    }

    /// 验证：fetchAll 无记录时返回空。
    func testFetchAllEmptyWhenNone() async throws {
        let results = try await feedbackRepo.fetchAll(limit: 10)
        XCTAssertTrue(results.isEmpty, "无记录时应返回空")
    }

    // MARK: - updateStatus 原生 SQL

    /// 验证：updateStatus 正确更新状态字段。
    func testUpdateStatusChangesStatus() async throws {
        try await feedbackRepo.save(makeFeedback(id: "fb-status", status: .pending))

        try await feedbackRepo.updateStatus(id: "fb-status", status: .synced)

        let fetched = try await feedbackRepo.fetchByID(id: "fb-status")
        XCTAssertEqual(fetched?.status, .synced, "状态应更新为 synced")
    }

    /// 验证：updateStatus 对不存在的 ID 静默返回（原生 SQL UPDATE 不抛错）。
    func testUpdateStatusNonExistentIsSilentNoop() async throws {
        try await feedbackRepo.updateStatus(id: "non-existent", status: .failed)
        // 不应抛出异常
    }

    /// 验证：updateStatus 多次更新状态。
    func testUpdateStatusMultipleTimes() async throws {
        try await feedbackRepo.save(makeFeedback(id: "fb-multi", status: .pending))

        try await feedbackRepo.updateStatus(id: "fb-multi", status: .synced)
        try await feedbackRepo.updateStatus(id: "fb-multi", status: .failed)
        try await feedbackRepo.updateStatus(id: "fb-multi", status: .pending)

        let fetched = try await feedbackRepo.fetchByID(id: "fb-multi")
        XCTAssertEqual(fetched?.status, .pending, "最终状态应为 pending")
    }

    // MARK: - rating 边界值

    /// 验证：rating=0 和 rating=5 都能正常保存。
    func testRatingBoundaries() async throws {
        try await feedbackRepo.save(makeFeedback(id: "fb-r0", rating: 0))
        try await feedbackRepo.save(makeFeedback(id: "fb-r5", rating: 5))

        let r0 = try await feedbackRepo.fetchByID(id: "fb-r0")
        XCTAssertEqual(r0?.rating, 0, "rating=0 应能保存")

        let r5 = try await feedbackRepo.fetchByID(id: "fb-r5")
        XCTAssertEqual(r5?.rating, 5, "rating=5 应能保存")
    }

    /// 验证：负 rating 也能保存（无约束）。
    func testNegativeRatingSaved() async throws {
        try await feedbackRepo.save(makeFeedback(id: "fb-neg", rating: -1))

        let fetched = try await feedbackRepo.fetchByID(id: "fb-neg")
        XCTAssertEqual(fetched?.rating, -1, "负 rating 应能保存（无 DB 约束）")
    }
}
