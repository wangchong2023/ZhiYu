//
//  LocalAnalyticsServiceTests.swift
//  ZhiYu
//
//  系统层级：[L0] 测试层
//  核心职责：验证 LocalAnalyticsService 事件追踪与 JSON 持久化的正确性。
//

import XCTest
@testable import ZhiYu

@MainActor
final class LocalAnalyticsServiceTests: XCTestCase {

    var tempLogURL: URL!
    var service: LocalAnalyticsService!

    override func setUp() {
        super.setUp()
        tempLogURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-analytics-\(UUID().uuidString).json")
        service = LocalAnalyticsService(logURL: tempLogURL)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempLogURL)
        service = nil
        super.tearDown()
    }

    // MARK: - trackEvent 持久化

    /// trackEvent 后日志文件应被创建（异步，需等待）
    func testTrackEvent_写入后_文件存在() async {
        service.trackEvent("test_event", properties: ["key": "value"])
        // 等待异步 DispatchQueue.global 写入完成
        try? await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertTrue(
            FileManager.default.fileExists(atPath: tempLogURL.path),
            "trackEvent 后日志文件应被创建"
        )
    }

    /// trackEvent 内容应包含事件名（异步等待后验证）
    func testTrackEvent_写入内容_包含事件名() async throws {
        service.trackEvent("page_created", properties: [:])
        try? await Task.sleep(nanoseconds: 500_000_000)

        let data = try Data(contentsOf: tempLogURL)
        let logs = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        XCTAssertNotNil(logs)
        XCTAssertEqual(logs?.count, 1)
        XCTAssertEqual(logs?[0]["name"] as? String, "page_created")
    }

    /// trackEvent 内容应包含 properties 键值
    func testTrackEvent_写入properties_包含键值() async throws {
        service.trackEvent("page_updated", properties: ["pageId": "page-123", "userId": "user-456"])
        try? await Task.sleep(nanoseconds: 500_000_000)

        let data = try Data(contentsOf: tempLogURL)
        let logs = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        let properties = logs?[0]["properties"] as? [String: Any]
        XCTAssertEqual(properties?["pageId"] as? String, "page-123")
        XCTAssertEqual(properties?["userId"] as? String, "user-456")
    }

    // MARK: - 空 properties

    /// properties 为 nil 应正常写入（不崩溃）
    func testTrackEvent_nilProperties_不崩溃() async {
        service.trackEvent("test_event", properties: nil)
        try? await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempLogURL.path))
    }

    // MARK: - 多次写入追加

    /// 多次 trackEvent 应追加写入（JSON 数组追加，非覆盖）
    func testTrackEvent_多次写入_追加模式() async throws {
        service.trackEvent("event1", properties: nil)
        try? await Task.sleep(nanoseconds: 300_000_000)
        service.trackEvent("event2", properties: nil)
        try? await Task.sleep(nanoseconds: 300_000_000)
        service.trackEvent("event3", properties: nil)
        try? await Task.sleep(nanoseconds: 500_000_000)

        let data = try Data(contentsOf: tempLogURL)
        let logs = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        XCTAssertEqual(logs?.count, 3, "应追加 3 条事件")
        XCTAssertEqual(logs?[0]["name"] as? String, "event1")
        XCTAssertEqual(logs?[1]["name"] as? String, "event2")
        XCTAssertEqual(logs?[2]["name"] as? String, "event3")
    }

    // MARK: - trackError 不崩溃

    /// trackError 应不崩溃（仅打印日志，不写文件）
    func testTrackError_不崩溃() {
        service.trackError(NSError(domain: "test", code: 1), details: "test details")
        // trackError 不写文件，仅打印日志
    }

    // MARK: - 单例一致性

    func testShared_多次访问_同一实例() {
        let a = LocalAnalyticsService.shared
        let b = LocalAnalyticsService.shared
        XCTAssertTrue(a === b)
    }
}
