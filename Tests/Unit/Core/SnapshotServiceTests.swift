//
//  SnapshotServiceTests.swift
//  ZhiYu
//
//  系统层级：[L0] 测试层
//  核心职责：验证 SnapshotService 知识版本快照的保存、历史查询、回滚与 Frontmatter 剥离逻辑。
//

import XCTest
@testable import ZhiYu

final class SnapshotServiceTests: XCTestCase {

    private var service: SnapshotService!
    private var tempDir: URL!
    private let pageID = UUID()

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("SnapshotTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        service = SnapshotService()
    }

    override func tearDown() {
        if let tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        service = nil
        super.tearDown()
    }

    // MARK: - saveSnapshot + getHistory

    func testSaveSnapshot_创建快照文件() {
        service.saveSnapshot(pageID: pageID, title: "测试页面", content: "正文内容")
        let history = service.getHistory(for: pageID)
        XCTAssertGreaterThanOrEqual(history.count, 1, "应至少有 1 个快照")
    }

    func testSaveSnapshot_多次保存_历史按时间倒序() {
        service.saveSnapshot(pageID: pageID, title: "v1", content: "内容1")
        Thread.sleep(forTimeInterval: 1.1)
        service.saveSnapshot(pageID: pageID, title: "v2", content: "内容2")
        Thread.sleep(forTimeInterval: 1.1)
        service.saveSnapshot(pageID: pageID, title: "v3", content: "内容3")

        let history = service.getHistory(for: pageID)
        XCTAssertGreaterThanOrEqual(history.count, 3, "应至少有 3 个快照")
        // 倒序：最新的在前
        XCTAssertGreaterThan(history[0].date, history[1].date, "应按时间倒序")
    }

    func testGetHistory_无快照_返回空数组() {
        let otherPageID = UUID()
        let history = service.getHistory(for: otherPageID)
        XCTAssertTrue(history.isEmpty)
    }

    // MARK: - rollback

    func testRollback_返回剥离Frontmatter的内容() {
        service.saveSnapshot(pageID: pageID, title: "标题", content: "原始正文")
        let history = service.getHistory(for: pageID)
        XCTAssertFalse(history.isEmpty)

        let content = service.rollback(to: history[0])
        XCTAssertNotNil(content)
        XCTAssertTrue(content?.contains("原始正文") == true, "回滚内容应包含原始正文")
    }

    func testRollback_内容不含Frontmatter标记() {
        service.saveSnapshot(pageID: pageID, title: "标题", content: "正文")
        let history = service.getHistory(for: pageID)
        XCTAssertFalse(history.isEmpty)

        let content = service.rollback(to: history[0])
        XCTAssertNotNil(content)
        // 回滚后的内容不应包含 Frontmatter 的 Snapshot-Date 等元数据
        XCTAssertFalse(content?.contains("Snapshot-Date") == true, "应剥离 Frontmatter")
        XCTAssertFalse(content?.contains("Original-Title") == true, "应剥离 Frontmatter")
    }

    func testRollback_文件不存在_返回nil() {
        let fakeSnapshot = SnapshotInfo(
            url: tempDir.appendingPathComponent("nonexistent.md"),
            date: Date()
        )
        let content = service.rollback(to: fakeSnapshot)
        XCTAssertNil(content)
    }

    // MARK: - SnapshotInfo

    func testSnapshotInfo_id_等于urlPath() {
        let url = tempDir.appendingPathComponent("test.md")
        let info = SnapshotInfo(url: url, date: Date())
        XCTAssertEqual(info.id, url.path)
    }

    // MARK: - 边界情况

    func testSaveSnapshot_空内容_仍创建快照() {
        service.saveSnapshot(pageID: pageID, title: "空页面", content: "")
        let history = service.getHistory(for: pageID)
        XCTAssertGreaterThanOrEqual(history.count, 1)
    }

    func testSaveSnapshot_特殊字符标题_正常保存() {
        let specialTitle = "标题/with\\special:chars"
        service.saveSnapshot(pageID: pageID, title: specialTitle, content: "内容")
        let history = service.getHistory(for: pageID)
        XCTAssertGreaterThanOrEqual(history.count, 1)
    }
}
