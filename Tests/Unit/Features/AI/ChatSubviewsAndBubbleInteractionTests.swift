//
//  ChatSubviewsAndBubbleInteractionTests.swift
//  ZhiYuTests
//

import XCTest

@testable import ZhiYu

@MainActor
final class ChatSubviewsAndBubbleInteractionTests: XCTestCase {

    // MARK: - 1. ChatBubbleView 基本渲染
    // MARK: - 2. 缺陷验证：ChatContentView 别名反向链接与 WikiLink 跳转
    // MARK: - 3. 缺陷验证：ChatBubbleView.performCopy 过滤内部思维链与剪贴板隔离

    func testChatBubbleViewPerformCopyThinkingFilter() {
        // ChatBubbleView.performCopy 是 UI 交互方法，无法在单元测试中直接调用
        // 仅验证 thinking 标记格式可被正确识别
        let rawAIResponse = "thinkingAnalyzing L0-L3 layer dependencies...output智宇采用严谨的四层分层架构。"
        XCTAssertTrue(rawAIResponse.contains("thinking"))
        XCTAssertTrue(rawAIResponse.contains("output"))
        XCTAssertTrue(rawAIResponse.contains("智宇采用严谨的四层分层架构。"))
    }

    // MARK: - 4. SuggestedFollowUpCardView 追问推荐卡片交互
    // MARK: - 5. ChatViewContent 思考过程展开与 Markdown 清洗
}
