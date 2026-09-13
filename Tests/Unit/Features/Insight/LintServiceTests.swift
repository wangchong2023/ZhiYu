//
//  LintServiceTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证知识库健康检查服务：孤岛/孤立、循环引用、断裂链接、存根/陈旧、重名、健康评分等边界语义。
//

import XCTest
@testable import ZhiYu

final class LintServiceBatch3Tests: XCTestCase {

    private let service = LintService()
    private let linkService = LinkService()

    // MARK: - 空输入

    func testRunLint_emptyPages_returnsNoIssues() async {
        let issues = await service.runLint(pages: [], linkService: linkService)
        XCTAssertTrue(issues.isEmpty)
    }

    // MARK: - 孤岛页面（无进出链接）

    func testRunLint_islandPage_detected() async {
        let page = KnowledgePage(title: "Island", content: "Some content here")
        let issues = await service.runLint(pages: [page], linkService: linkService)
        let islandIssues = issues.filter { $0.type == .island }
        XCTAssertEqual(islandIssues.count, 1)
        XCTAssertEqual(islandIssues[0].pageID, page.id)
        XCTAssertEqual(islandIssues[0].severity, .warning)
    }

    // MARK: - 孤立页面（有出链无入链）

    func testRunLint_orphanPage_detected() async {
        let pageA = KnowledgePage(title: "A", content: "[[B]]")
        let pageB = KnowledgePage(title: "B", content: "No links")
        let issues = await service.runLint(pages: [pageA, pageB], linkService: linkService)
        // B 有入链（A→B），A 有出链但无入链 → A 是 orphan
        let orphanIssues = issues.filter { $0.type == .orphan }
        XCTAssertTrue(orphanIssues.contains { $0.pageID == pageA.id })
    }

    // MARK: - 循环引用

    func testRunLint_circularReference_detected() async {
        let pageA = KnowledgePage(title: "A", content: "[[B]]")
        let pageB = KnowledgePage(title: "B", content: "[[A]]")
        let issues = await service.runLint(pages: [pageA, pageB], linkService: linkService)
        let cycleIssues = issues.filter { $0.type == .cycle }
        XCTAssertFalse(cycleIssues.isEmpty, "A→B→A 应检测到循环引用")
    }

    // MARK: - 断裂链接

    func testRunLint_brokenLink_detected() async {
        let page = KnowledgePage(title: "A", content: "[[NonExistent]]")
        let issues = await service.runLint(pages: [page], linkService: linkService)
        let brokenIssues = issues.filter { $0.type == .brokenLink }
        XCTAssertEqual(brokenIssues.count, 1)
        XCTAssertEqual(brokenIssues[0].severity, .error)
    }

    // MARK: - 存根页面

    func testRunLint_stubPage_detected() async {
        // isStub: content.count < stubPageWordCount
        let page = KnowledgePage(title: "Stub", content: "ab")
        let issues = await service.runLint(pages: [page], linkService: linkService)
        let stubIssues = issues.filter { $0.type == .stub }
        XCTAssertFalse(stubIssues.isEmpty, "内容过少应检测为存根")
    }

    // MARK: - 陈旧页面

    func testRunLint_stalePage_detected() async {
        let staleDate = Calendar.current.date(byAdding: .day, value: -45, to: Date()) ?? Date()
        let page = KnowledgePage(title: "Stale", content: "Some content here", updatedAt: staleDate)
        let issues = await service.runLint(pages: [page], linkService: linkService)
        let staleIssues = issues.filter { $0.type == .stale }
        XCTAssertFalse(staleIssues.isEmpty, "45 天前更新应检测为陈旧")
    }

    // MARK: - 重名页面

    func testRunLint_duplicateTitles_detected() async {
        let pageA = KnowledgePage(title: "Duplicate", content: "Content A")
        let pageB = KnowledgePage(title: "Duplicate", content: "Content B")
        let issues = await service.runLint(pages: [pageA, pageB], linkService: linkService)
        let dupIssues = issues.filter { $0.type == .generic }
        XCTAssertEqual(dupIssues.count, 2, "两个重名页面应各产生一条 issue")
    }

    // MARK: - raw 类型页面跳过孤岛检查

    func testRunLint_rawPageType_skipsIslandCheck() async {
        let page = KnowledgePage(title: "Raw", pageType: .raw, content: "Some content")
        let issues = await service.runLint(pages: [page], linkService: linkService)
        let islandIssues = issues.filter { $0.type == .island }
        XCTAssertTrue(islandIssues.isEmpty, "raw 类型页面不应触发孤岛检查")
    }

    // MARK: - calculateHealthMetrics

    func testCalculateHealthMetrics_noIssues_excellentScore() {
        let (score, level) = service.calculateHealthMetrics(issues: [])
        XCTAssertEqual(score, 100)
        XCTAssertEqual(level, .excellent)
    }

    func testCalculateHealthMetrics_oneError_deducts10() {
        let issue = LintIssue(severity: .error, message: "test", suggestion: "fix")
        let (score, level) = service.calculateHealthMetrics(issues: [issue])
        XCTAssertEqual(score, 90)
        XCTAssertEqual(level, .excellent)
    }

    func testCalculateHealthMetrics_twoErrorsTwoWarnings_deducts30() {
        let issues = [
            LintIssue(severity: .error, message: "e1", suggestion: ""),
            LintIssue(severity: .error, message: "e2", suggestion: ""),
            LintIssue(severity: .warning, message: "w1", suggestion: ""),
            LintIssue(severity: .warning, message: "w2", suggestion: "")
        ]
        let (score, _) = service.calculateHealthMetrics(issues: issues)
        XCTAssertEqual(score, 70, "2*10 + 2*5 = 30, 100-30=70")
    }

    func testCalculateHealthMetrics_manyIssues_floorAtZero() {
        let issues = (0..<20).map { _ in LintIssue(severity: .error, message: "e", suggestion: "") }
        let (score, level) = service.calculateHealthMetrics(issues: issues)
        XCTAssertEqual(score, 0, "扣分不应低于 0")
        XCTAssertEqual(level, .poor)
    }

    func testCalculateHealthMetrics_infoOnly_deducts2() {
        let issue = LintIssue(severity: .info, message: "i", suggestion: "")
        let (score, level) = service.calculateHealthMetrics(issues: [issue])
        XCTAssertEqual(score, 98)
        XCTAssertEqual(level, .excellent)
    }

    // MARK: - HealthLevel 边界

    func testCalculateHealthMetrics_score75_isGoodLevel() {
        // 5 个 warning = 25 扣分 → 75 分 → good
        let issues = (0..<5).map { _ in LintIssue(severity: .warning, message: "w", suggestion: "") }
        let (score, level) = service.calculateHealthMetrics(issues: issues)
        XCTAssertEqual(score, 75)
        XCTAssertEqual(level, .good)
    }

    func testCalculateHealthMetrics_score50_isFairLevel() {
        // 10 个 warning = 50 扣分 → 50 分 → fair
        let issues = (0..<10).map { _ in LintIssue(severity: .warning, message: "w", suggestion: "") }
        let (score, level) = service.calculateHealthMetrics(issues: issues)
        XCTAssertEqual(score, 50)
        XCTAssertEqual(level, .fair)
    }

    // MARK: - HealthLevel 属性

    func testHealthLevel_title_nonEmpty() {
        for level in LintService.HealthLevel.allCases {
            XCTAssertFalse(level.title.isEmpty, "健康等级标题不应为空")
        }
    }

    func testHealthLevel_colorName_nonEmpty() {
        for level in LintService.HealthLevel.allCases {
            XCTAssertFalse(level.colorName.isEmpty, "健康等级颜色名不应为空")
        }
    }
}
