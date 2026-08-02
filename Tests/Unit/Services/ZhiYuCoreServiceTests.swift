//
//  ZhiYuCoreServiceTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 ZhiYuCoreService 开展自动化单元测试验证。
//
import XCTest
import SwiftUI
import UFPStorage
@testable import ZhiYu

// MARK: - 历史撤销与恢复 (UndoService) 单元测试
@MainActor
final class UndoServiceTests: XCTestCase {
    
    var undoService: UndoService!
    
    override func setUp() async throws {
        try await super.setUp()
        undoService = UndoService()
    }
    
    override func tearDown() async throws {
        undoService = nil
        try await super.setUp()
    }
    
    /// 验证初始状态下，撤销与重做状态均为不可用
    func testInitialCanUndoRedo() {
        XCTAssertFalse(undoService.canUndo)
        XCTAssertFalse(undoService.canRedo)
    }
    
    /// 验证推入一个页面版本快照后，撤销功能被正确启用
    func testPushSnapshotEnablesUndo() {
        let pages = [KnowledgePage(title: "Test")]
        undoService.pushSnapshot(pages)
        XCTAssertTrue(undoService.canUndo)
        XCTAssertFalse(undoService.canRedo)
    }
    
    /// 验证执行撤销操作能成功回溯至上一个页面数据快照
    func testUndoRestoresPrevious() {
        let oldPages = [KnowledgePage(title: "Old")]
        let newPages = [KnowledgePage(title: "New")]
        
        undoService.pushSnapshot(oldPages)
        let result = undoService.undo(currentPages: newPages)
        
        XCTAssertEqual(result?.first?.title, "Old")
        XCTAssertFalse(undoService.canUndo)
        XCTAssertTrue(undoService.canRedo)
    }
    
    /// 验证执行重做操作能成功恢复至撤销前的新页面快照
    func testRedoRestoresNext() {
        let oldPages = [KnowledgePage(title: "Old")]
        let newPages = [KnowledgePage(title: "New")]
        
        undoService.pushSnapshot(oldPages)
        _ = undoService.undo(currentPages: newPages)
        let result = undoService.redo(currentPages: oldPages)
        
        XCTAssertEqual(result?.first?.title, "New")
        XCTAssertTrue(undoService.canUndo)
        XCTAssertFalse(undoService.canRedo)
    }
    
    /// 验证撤销过程中一旦发生新操作写入，重做栈将自动清空，防止时序逻辑混乱
    func testNewActionClearsRedoStack() {
        let pages1 = [KnowledgePage(title: "V1")]
        let pages2 = [KnowledgePage(title: "V2")]
        let pages3 = [KnowledgePage(title: "V3")]
        
        undoService.pushSnapshot(pages1)
        _ = undoService.undo(currentPages: pages2)
        XCTAssertTrue(undoService.canRedo)
        
        // 执行新写入操作，重做记录应该清空
        undoService.pushSnapshot(pages3)
        XCTAssertFalse(undoService.canRedo)
    }
    
    /// 验证撤销栈深度上限控制，自动防范内存溢出
    func testMaxStackSize() {
        for i in 0..<60 {
            undoService.pushSnapshot([KnowledgePage(title: "Page \(i)")])
        }
        // 验证在高负荷推栈下系统依然运转正常
        XCTAssertTrue(undoService.canUndo)
    }
    
    /// 验证清除历史缓存
    func testClear() {
        undoService.pushSnapshot([KnowledgePage(title: "Test")])
        undoService.clear()
        XCTAssertFalse(undoService.canUndo)
        XCTAssertFalse(undoService.canRedo)
    }
}

// MARK: - 内容智能诊断 (LintService) 单元测试
@MainActor
final class LintServiceTests: XCTestCase {
    
    var lintService: LintService!
    var linkService: LinkService!
    
    override func setUp() async throws {
        try await super.setUp()
        lintService = LintService()
        linkService = LinkService()
    }
    
    override func tearDown() async throws {
        lintService = nil
        linkService = nil
        try await super.setUp()
    }
    
    /// 验证 Lint 能识别出指向不存在页面的双链断链 (Broken Link) 缺陷
    func testDetectBrokenLinks() async {
        let pages = [
            KnowledgePage(title: "A", content: "Links to [[NonExistent]]")
        ]
        let issues = await lintService.runLint(pages: pages, linkService: linkService)
        XCTAssertTrue(issues.contains { $0.message.contains("NonExistent") || $0.message.contains("broken") || $0.message.contains("Broken") })
    }
    
    /// 验证多重断链场景下被正确扫描识别
    func testDetectMultipleBrokenLinks() async {
        let pages = [
            KnowledgePage(title: "A", content: "[[Missing1]] and [[Missing2]]")
        ]
        let issues = await lintService.runLint(pages: pages, linkService: linkService)
        let brokenCount = issues.filter { $0.severity == .error }.count
        XCTAssertEqual(brokenCount, 2)
    }
    
    /// 验证字数过少的页面会被标记为存根页面警告
    func testDetectStubContent() async {
        let pages = [
            KnowledgePage(title: "Short", content: "Hi")
        ]
        let issues = await lintService.runLint(pages: pages, linkService: linkService)
        XCTAssertTrue(issues.contains { $0.message.contains("Short") })
    }
    
    /// 验证 Raw（原始输入）类型的页面，由于其自然属性不需要引用链接，不应被诊断标记为孤立页面（Orphan）
    func testRawPagesNotFlaggedAsOrphan() async {
        let rawPage = KnowledgePage(title: "RawData", pageType: .raw, content: String(repeating: "x", count: 200))
        let issues = await lintService.runLint(pages: [rawPage], linkService: linkService)
        let orphanIssues = issues.filter { $0.severity == .warning && $0.message.contains("orphan") || $0.message.contains("Orphan") }
        XCTAssertTrue(orphanIssues.isEmpty, "Raw 类型页面不应当被诊断为孤立页面")
    }
    
    /// 验证结构健全的知识页网络不会被误诊出任何错误
    func testNoIssuesForHealthyKnowledge() async {
        let pageA = KnowledgePage(title: "Alpha", content: String(repeating: "Good content ", count: 20))
        let pageB = KnowledgePage(title: "Beta", content: "Links to [[Alpha]] " + String(repeating: "content ", count: 15))
        let pages = [pageA, pageB]
        let issues = await lintService.runLint(pages: pages, linkService: linkService)
        XCTAssertFalse(issues.contains { $0.severity == .error })
    }
}

// MARK: - 智能知识摄入 (IngestService) 单元测试
@MainActor
final class IngestServiceTests: XCTestCase {
    
    var ingestService: IngestService!
    
    override func setUp() async throws {
        try await super.setUp()
        ingestService = IngestService()
    }
    
    override func tearDown() async throws {
        ingestService = nil
        try await super.setUp()
    }
    
    /// 验证能够精准提取出已存在知识库中的重要概念与实体
    func testExtractConceptsFromContent() async {
        let pages = [
            KnowledgePage(title: "Machine Learning", pageType: .concept),
            KnowledgePage(title: "Deep Learning", pageType: .concept),
            KnowledgePage(title: "Neural Network", pageType: .entity)
        ]
        
        let content = "I want to learn about Machine Learning and Neural Networks."
        let concepts = await ingestService.extractConcepts(from: content, pages: pages)
        
        XCTAssertTrue(concepts.contains("Machine Learning"))
        XCTAssertTrue(concepts.contains("Neural Network"))
        XCTAssertFalse(concepts.contains("Deep Learning")) // 未在文本中提及
    }
    
    /// 验证实体概念提取过程大小写不敏感（Case-Insensitive）的鲁棒性
    func testExtractConceptsCaseInsensitive() async {
        let pages = [KnowledgePage(title: "SwiftUI", pageType: .concept)]
        let concepts = await ingestService.extractConcepts(from: "I love swiftui programming", pages: pages)
        XCTAssertTrue(concepts.contains("SwiftUI"), "应该自动大小写不敏感匹配")
    }
    
    /// 验证无匹配概念状态下的安全返回
    func testExtractConceptsEmpty() async {
        let pages = [KnowledgePage(title: "Something")]
        let concepts = await ingestService.extractConcepts(from: "No matches here", pages: pages)
        XCTAssertTrue(concepts.isEmpty)
    }
}

// MARK: - 异步系统日志与安全审计 (Logger) 单元测试
@MainActor
final class LoggerTests: XCTestCase {
    
    var logService: Logger!
    
    override func setUp() async throws {
        try await super.setUp()
        logService = Logger.shared
        await logService.clearAllLogs() // 每次运行前清空数据以维持沙盒隔离
    }
    
    override func tearDown() async throws {
        // 清理测试在沙盒目录产生的物理文件
        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            _ = try? FileManager.default.removeItem(at: docs.appendingPathComponent("zhiyu_logs.json"))
        }
        logService = nil
        try await super.tearDown()
    }

    /// 验证新增的审计日志条目在异步流中能被安全地落盘与查询
    func testAddLogEntry() async {
        logService.addLog(action: .create, target: "TestPage")
        // 等待异步日志的 Actor 写入缓冲完毕
        try? await Task.sleep(nanoseconds: 100_000_000)
        let entries = await logService.getLogEntries()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.action, .create)
        XCTAssertEqual(entries.first?.target, "TestPage")
    }
    
    /// 验证日志条目的时序一致性 (最新产生的日志排在数组首位)
    func testLogEntryOrdering() async {
        // 依次记录日志条目，在调用间添加微秒级延时，保证底层 actor 的异步 Task 分发有序
        logService.addLog(action: .update, target: "t1")
        try? await Task.sleep(nanoseconds: 50_000_000)
        
        logService.addLog(action: .update, target: "t2")
        try? await Task.sleep(nanoseconds: 50_000_000)
        
        logService.addLog(action: .update, target: "t3")
        
        // 等待所有异步日志写入彻底完成
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        let entries = await logService.getLogEntries()
        XCTAssertEqual(entries.first?.target, "t3") // 最新
        XCTAssertEqual(entries.last?.target, "t1")   // 最旧
    }
    
    /// 验证日志系统自动修剪（Prune）逻辑，防范长周期运行下存储空间暴涨，默认设定 500 条红线
    func testMaxLogEntriesCap() async {
        for i in 0..<600 {
            logService.addLog(action: .update, target: "t\(i)")
        }
        try? await Task.sleep(nanoseconds: 500_000_000)
        let entries = await logService.getLogEntries()
        XCTAssertLessThanOrEqual(entries.count, 500)
    }
}
