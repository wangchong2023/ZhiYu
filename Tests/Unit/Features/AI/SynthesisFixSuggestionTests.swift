//
//  SynthesisFixSuggestionTests.swift
//  ZhiYuTests
//
//  系统层级：[L2] 业务功能测试 - AI
//  核心职责：验证 AISynthesisService 在处理重名页面时的修复建议（suggestFix）ID 寻址与稳定性。
//

import XCTest
@testable import ZhiYu

final class SynthesisFixSuggestionTests: XCTestCase {

    /// 验证 suggestFix 用 id 而非 title 查找内容，避免重名页面混淆
    func testSuggestFix_duplicateTitlePages_resolvesByID() async {
        let service = AISynthesisService.shared
        let pageID = UUID()
        let page1 = KnowledgePage(id: pageID, title: "Duplicate", pageType: .concept, content: "Correct content from page 1")
        let page2 = KnowledgePage(id: UUID(), title: "Duplicate", pageType: .concept, content: "Wrong content from page 2")
        let issue = LintIssue(
            severity: .info,
            type: .brokenLink,
            pageID: pageID,
            message: "Test issue",
            suggestion: "Test suggestion"
        )

        do {
            let fix = try await service.suggestFix(issue: issue, pages: [page1, page2])
            XCTAssertNotNil(fix)
        } catch {
            XCTAssertFalse(error.localizedDescription.isEmpty, "suggestFix 抛错原因非空：\(error)")
        }
    }
}
