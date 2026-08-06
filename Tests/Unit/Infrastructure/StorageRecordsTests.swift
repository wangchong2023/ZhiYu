//
//  StorageRecordsTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 StorageRecords 各 Record 实体的表名绑定、Codable 往返与默认值。
//

import XCTest
@testable import ZhiYu

final class StorageRecordsTests: XCTestCase {

    /// 将 UUID 转换为 16 字节二进制数据，匹配数据库 page_id 列存储格式
    private func uuidData(_ uuid: UUID = UUID()) -> Data {
        var bytes = uuid.uuid
        return Data(bytes: &bytes, count: 16)
    }

    // MARK: - TagRecord

    func testTagRecord_databaseTableName_isTags() {
        XCTAssertEqual(TagRecord.databaseTableName, "tags")
    }

    func testTagRecord_init_storesProperties() {
        let date = Date(timeIntervalSince1970: 1000)
        let record = TagRecord(id: "swift", name: "Swift", createdAt: date)

        XCTAssertEqual(record.id, "swift")
        XCTAssertEqual(record.name, "Swift")
        XCTAssertEqual(record.createdAt, date)
    }

    func testTagRecord_codableRoundTrip_preservesData() throws {
        let original = TagRecord(id: "tag1", name: "Tag One", createdAt: Date(timeIntervalSince1970: 2000))
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TagRecord.self, from: encoded)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.createdAt, original.createdAt)
    }

    func testTagRecord_decodesSnakeCaseCreatedAt() throws {
        let json = #"{"id":"t1","name":"T1","created_at":3000}"#
        let decoded = try JSONDecoder().decode(TagRecord.self, from: Data(json.utf8))

        XCTAssertEqual(decoded.id, "t1")
        XCTAssertEqual(decoded.name, "T1")
        // JSONDecoder 默认使用 .referenceDate 策略（自 2001-01-01 起的秒数）
        XCTAssertEqual(decoded.createdAt, Date(timeIntervalSinceReferenceDate: 3000))
    }

    // MARK: - PageTagRecord

    func testPageTagRecord_databaseTableName_isPageTags() {
        XCTAssertEqual(PageTagRecord.databaseTableName, "page_tags")
    }

    func testPageTagRecord_init_storesProperties() {
        let pageData = uuidData()
        let record = PageTagRecord(pageID: pageData, tagID: "tag1")

        XCTAssertEqual(record.pageID, pageData)
        XCTAssertEqual(record.tagID, "tag1")
    }

    func testPageTagRecord_codableRoundTrip_preservesData() throws {
        let pageData = uuidData()
        let original = PageTagRecord(pageID: pageData, tagID: "tag1")
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PageTagRecord.self, from: encoded)

        XCTAssertEqual(decoded.pageID, original.pageID)
        XCTAssertEqual(decoded.tagID, original.tagID)
    }

    // MARK: - SRSMetadataRecord

    func testSRSMetadataRecord_databaseTableName_isSrsMetadata() {
        XCTAssertEqual(SRSMetadataRecord.databaseTableName, "srs_metadata")
    }

    func testSRSMetadataRecord_initWithDefaults_usesDefaultEaseFactor() {
        let record = SRSMetadataRecord(pageID: uuidData())

        XCTAssertEqual(record.easeFactor, 2.5, "默认 easeFactor 应为 2.5")
        XCTAssertEqual(record.repetitions, 0)
        XCTAssertEqual(record.reviewInterval, 0)
    }

    func testSRSMetadataRecord_initWithCustomValues_storesProperties() {
        let pageData = uuidData()
        let nextReview = Date(timeIntervalSince1970: 5000)
        let created = Date(timeIntervalSince1970: 1000)
        let updated = Date(timeIntervalSince1970: 2000)

        let record = SRSMetadataRecord(
            pageID: pageData,
            easeFactor: 1.8,
            repetitions: 3,
            reviewInterval: 7,
            nextReviewAt: nextReview,
            createdAt: created,
            updatedAt: updated
        )

        XCTAssertEqual(record.pageID, pageData)
        XCTAssertEqual(record.easeFactor, 1.8)
        XCTAssertEqual(record.repetitions, 3)
        XCTAssertEqual(record.reviewInterval, 7)
        XCTAssertEqual(record.nextReviewAt, nextReview)
        XCTAssertEqual(record.createdAt, created)
        XCTAssertEqual(record.updatedAt, updated)
    }

    func testSRSMetadataRecord_codableRoundTrip_preservesData() throws {
        let original = SRSMetadataRecord(
            pageID: uuidData(),
            easeFactor: 2.0,
            repetitions: 5,
            reviewInterval: 10
        )
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SRSMetadataRecord.self, from: encoded)

        XCTAssertEqual(decoded.pageID, original.pageID)
        XCTAssertEqual(decoded.easeFactor, 2.0)
        XCTAssertEqual(decoded.repetitions, 5)
        XCTAssertEqual(decoded.reviewInterval, 10)
    }

    // MARK: - GlobalSettingRecord

    func testGlobalSettingRecord_databaseTableName_isGlobalSettings() {
        XCTAssertEqual(GlobalSettingRecord.databaseTableName, "global_settings")
    }

    func testGlobalSettingRecord_init_storesProperties() {
        let date = Date(timeIntervalSince1970: 1000)
        let record = GlobalSettingRecord(key: "theme", value: "dark", updatedAt: date)

        XCTAssertEqual(record.key, "theme")
        XCTAssertEqual(record.value, "dark")
        XCTAssertEqual(record.updatedAt, date)
    }

    func testGlobalSettingRecord_codableRoundTrip_preservesData() throws {
        let original = GlobalSettingRecord(key: "k1", value: "v1", updatedAt: Date(timeIntervalSince1970: 2000))
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(GlobalSettingRecord.self, from: encoded)

        XCTAssertEqual(decoded.key, original.key)
        XCTAssertEqual(decoded.value, original.value)
        XCTAssertEqual(decoded.updatedAt, original.updatedAt)
    }

    // MARK: - AuditLogRecord

    func testAuditLogRecord_databaseTableName_isAuditLogs() {
        XCTAssertEqual(AuditLogRecord.databaseTableName, "audit_logs")
    }

    func testAuditLogRecord_initWithDefaults_idIsNil() {
        let record = AuditLogRecord(action: "login")

        XCTAssertNil(record.id, "默认 id 应为 nil")
        XCTAssertEqual(record.action, "login")
        XCTAssertNil(record.details)
    }

    func testAuditLogRecord_initWithCustomValues_storesProperties() {
        let date = Date(timeIntervalSince1970: 1000)
        let record = AuditLogRecord(id: 42, action: "api_call", details: #"{"model":"gpt-4"}"#, createdAt: date)

        XCTAssertEqual(record.id, 42)
        XCTAssertEqual(record.action, "api_call")
        XCTAssertEqual(record.details, #"{"model":"gpt-4"}"#)
        XCTAssertEqual(record.createdAt, date)
    }

    func testAuditLogRecord_codableRoundTrip_preservesData() throws {
        let original = AuditLogRecord(id: 10, action: "test_action", details: "details")
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AuditLogRecord.self, from: encoded)

        XCTAssertEqual(decoded.id, 10)
        XCTAssertEqual(decoded.action, "test_action")
        XCTAssertEqual(decoded.details, "details")
    }
}
