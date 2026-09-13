//
//  LWWSyncConflictResolverTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/11.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 LWW (Last-Writer-Wins) 冲突合并算法开展自动化单元测试。
//

import XCTest
@testable import ZhiYu

final class LWWSyncConflictResolverTests: XCTestCase {

    private let resolver = LWWSyncConflictResolver()

    // MARK: - mergePages

    func testMergePages_noConflict_appendsNewPages() {
        let local = [KnowledgePage(title: "A")]
        let remote = [KnowledgePage(title: "B")]
        let result = resolver.mergePages(local: local, remote: remote)
        XCTAssertEqual(result.count, 2)
    }

    func testMergePages_sameUUID_takesNewer() {
        let id = UUID()
        let older = KnowledgePage(id: id, title: "Old", updatedAt: Date(timeIntervalSince1970: 100))
        let newer = KnowledgePage(id: id, title: "New", updatedAt: Date(timeIntervalSince1970: 200))
        let result = resolver.mergePages(local: [older], remote: [newer])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "New")
    }

    func testMergePages_sameUUID_keepsLocalIfNewer() {
        let id = UUID()
        let newer = KnowledgePage(id: id, title: "Local", updatedAt: Date(timeIntervalSince1970: 200))
        let older = KnowledgePage(id: id, title: "Remote", updatedAt: Date(timeIntervalSince1970: 100))
        let result = resolver.mergePages(local: [newer], remote: [older])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "Local")
    }

    func testMergePages_differentUUID_sameTitle_skipsDuplicate() {
        let local = KnowledgePage(id: UUID(), title: "Duplicate")
        let remote = KnowledgePage(id: UUID(), title: "Duplicate")
        let result = resolver.mergePages(local: [local], remote: [remote])
        XCTAssertEqual(result.count, 1, "同名但不同 UUID 的页面应跳过追加")
    }

    func testMergePages_multipleConflicts_resolvesEach() {
        let id1 = UUID()
        let id2 = UUID()
        let local = [
            KnowledgePage(id: id1, title: "A", updatedAt: Date(timeIntervalSince1970: 100)),
            KnowledgePage(id: id2, title: "B", updatedAt: Date(timeIntervalSince1970: 300))
        ]
        let remote = [
            KnowledgePage(id: id1, title: "A2", updatedAt: Date(timeIntervalSince1970: 200)),
            KnowledgePage(id: id2, title: "B2", updatedAt: Date(timeIntervalSince1970: 250))
        ]
        let result = resolver.mergePages(local: local, remote: remote)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.first(where: { $0.id == id1 })?.title, "A2")
        XCTAssertEqual(result.first(where: { $0.id == id2 })?.title, "B")
    }

    func testMergePages_identicalLocalAndRemote() {
        let page = KnowledgePage(title: "Same", updatedAt: Date(timeIntervalSince1970: 100))
        let result = resolver.mergePages(local: [page], remote: [page])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "Same")
    }

    func testMergePages_emptyLocal() {
        let remote = [KnowledgePage(title: "Remote")]
        let result = resolver.mergePages(local: [], remote: remote)
        XCTAssertEqual(result, remote)
    }

    func testMergePages_emptyRemote() {
        let local = [KnowledgePage(title: "Local")]
        let result = resolver.mergePages(local: local, remote: [])
        XCTAssertEqual(result, local)
    }

    func testMergePages_bothEmpty() {
        let result = resolver.mergePages(local: [], remote: [])
        XCTAssertEqual(result, [])
    }

    // MARK: - mergeLogs

    func testMergeLogs_noConflict_appendsNewLogs() {
        let local = [LogEntry(action: .create, target: "A")]
        let remote = [LogEntry(action: .create, target: "B")]
        let result = resolver.mergeLogs(local: local, remote: remote)
        XCTAssertEqual(result.count, 2)
    }

    func testMergeLogs_deduplicatesByID() {
        let id = UUID()
        let log1 = LogEntry(id: id, action: .create, target: "Target", timestamp: Date(timeIntervalSince1970: 100))
        let log2 = LogEntry(id: id, action: .create, target: "Target", timestamp: Date(timeIntervalSince1970: 100))
        let result = resolver.mergeLogs(local: [log1], remote: [log2])
        XCTAssertEqual(result.count, 1, "相同 ID 的日志应去重")
    }

    func testMergeLogs_sortedByTimestampDescending() {
        let older = LogEntry(action: .create, target: "Old", timestamp: Date(timeIntervalSince1970: 100))
        let newer = LogEntry(action: .create, target: "New", timestamp: Date(timeIntervalSince1970: 200))
        let result = resolver.mergeLogs(local: [older], remote: [newer])
        XCTAssertEqual(result.first?.target, "New")
    }

    func testMergeLogs_respects200Limit() {
        let local = (0..<150).map { i in
            LogEntry(action: .create, target: "Local\(i)", timestamp: Date(timeIntervalSince1970: TimeInterval(i)))
        }
        let remote = (0..<100).map { i in
            LogEntry(action: .create, target: "Remote\(i)", timestamp: Date(timeIntervalSince1970: TimeInterval(200 + i)))
        }
        let result = resolver.mergeLogs(local: local, remote: remote)
        XCTAssertEqual(result.count, 200, "合并后最多保留 200 条")
        XCTAssertTrue(result.first?.target.hasPrefix("Remote") ?? false, "最新的日志应在最前面")
    }

    func testMergeLogs_under200Limit() {
        let logs = (0..<50).map { i in
            LogEntry(action: .create, target: "\(i)", timestamp: Date(timeIntervalSince1970: TimeInterval(i)))
        }
        let result = resolver.mergeLogs(local: [], remote: logs)
        XCTAssertEqual(result.count, 50)
    }

    func testMergeLogs_emptyLocal() {
        let remote = [LogEntry(action: .create, target: "R")]
        let result = resolver.mergeLogs(local: [], remote: remote)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.target, "R")
    }

    func testMergeLogs_emptyRemote() {
        let local = [LogEntry(action: .create, target: "L")]
        let result = resolver.mergeLogs(local: local, remote: [])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.target, "L")
    }

    func testMergeLogs_bothEmpty() {
        let result = resolver.mergeLogs(local: [], remote: [])
        XCTAssertTrue(result.isEmpty)
    }
}
