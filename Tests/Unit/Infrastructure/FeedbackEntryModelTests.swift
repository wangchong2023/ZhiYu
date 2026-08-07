//
//  FeedbackEntryModelTests.swift
//  ZhiYuTests
//
//  系统层级：[L1] 基础设施层测试
//  核心职责：验证 FeedbackEntry 模型、FeedbackStatus/FeedbackCategory displayName 与 Codable
//

import XCTest
@testable import ZhiYu

final class FeedbackEntryModelTests: XCTestCase {

    // MARK: - FeedbackStatus

    func testFeedbackStatusPendingDisplayName() {
        XCTAssertFalse(FeedbackStatus.pending.displayName.isEmpty)
    }

    func testFeedbackStatusSyncedDisplayName() {
        XCTAssertFalse(FeedbackStatus.synced.displayName.isEmpty)
    }

    func testFeedbackStatusFailedDisplayName() {
        XCTAssertFalse(FeedbackStatus.failed.displayName.isEmpty)
    }

    func testFeedbackStatusIsCaseIterable() {
        XCTAssertEqual(FeedbackStatus.allCases.count, 3)
    }

    // MARK: - FeedbackCategory

    func testFeedbackCategoryBugDisplayName() {
        XCTAssertFalse(FeedbackCategory.displayName(FeedbackCategory.bug).isEmpty)
    }

    func testFeedbackCategoryFeatureDisplayName() {
        XCTAssertFalse(FeedbackCategory.displayName(FeedbackCategory.feature).isEmpty)
    }

    func testFeedbackCategoryContentDisplayName() {
        XCTAssertFalse(FeedbackCategory.displayName(FeedbackCategory.content).isEmpty)
    }

    func testFeedbackCategoryOtherDisplayName() {
        XCTAssertFalse(FeedbackCategory.displayName(FeedbackCategory.other).isEmpty)
    }

    func testFeedbackCategoryUnknownReturnsRawValue() {
        let unknown = "unknown_category"
        XCTAssertEqual(FeedbackCategory.displayName(unknown), unknown)
    }

    func testFeedbackCategoryAllCasesContainsAll() {
        XCTAssertEqual(FeedbackCategory.allCases, [FeedbackCategory.bug, FeedbackCategory.feature, FeedbackCategory.content, FeedbackCategory.other])
    }

    // MARK: - FeedbackEntry 构造与 Codable

    func testFeedbackEntryInitWithDefaults() {
        let entry = FeedbackEntry(title: "T", category: "bug", rating: 5, content: "C")
        XCTAssertFalse(entry.id.isEmpty)
        XCTAssertEqual(entry.title, "T")
        XCTAssertEqual(entry.category, "bug")
        XCTAssertEqual(entry.rating, 5)
        XCTAssertEqual(entry.content, "C")
        XCTAssertEqual(entry.appVersion, "")
        XCTAssertEqual(entry.osVersion, "")
        XCTAssertEqual(entry.deviceModel, "")
        XCTAssertEqual(entry.status, .pending)
    }

    func testFeedbackEntryInitWithAllParameters() {
        let entry = FeedbackEntry(
            id: "custom-id",
            title: "Bug",
            category: "feature",
            rating: 3,
            content: "Content",
            appVersion: "1.0",
            osVersion: "17.0",
            deviceModel: "iPhone",
            status: .synced
        )
        XCTAssertEqual(entry.id, "custom-id")
        XCTAssertEqual(entry.appVersion, "1.0")
        XCTAssertEqual(entry.osVersion, "17.0")
        XCTAssertEqual(entry.deviceModel, "iPhone")
        XCTAssertEqual(entry.status, .synced)
    }

    func testFeedbackEntryCodableRoundTrip() throws {
        let entry = FeedbackEntry(
            id: "codec-id",
            title: "Title",
            category: "content",
            rating: 4,
            content: "Body",
            appVersion: "2.0",
            osVersion: "18.0",
            deviceModel: "Mac",
            status: .failed
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(entry)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(FeedbackEntry.self, from: data)

        XCTAssertEqual(decoded.id, entry.id)
        XCTAssertEqual(decoded.title, entry.title)
        XCTAssertEqual(decoded.category, entry.category)
        XCTAssertEqual(decoded.rating, entry.rating)
        XCTAssertEqual(decoded.content, entry.content)
        XCTAssertEqual(decoded.appVersion, entry.appVersion)
        XCTAssertEqual(decoded.osVersion, entry.osVersion)
        XCTAssertEqual(decoded.deviceModel, entry.deviceModel)
        XCTAssertEqual(decoded.status, entry.status)
    }

    func testFeedbackEntryDatabaseTableName() {
        XCTAssertFalse(FeedbackEntry.databaseTableName.isEmpty)
    }
}
