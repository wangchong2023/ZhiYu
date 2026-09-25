//
//  AccessibilityServiceTests.swift
//  ZhiYu
//
//  系统层级：[L0] 测试层
//  核心职责：验证 AccessibilityService 的 VoiceOver 公告生成与动画控制逻辑。
//

import XCTest
import CoreGraphics
@testable import ZhiYu

@MainActor
final class AccessibilityServiceTests: XCTestCase {

    private var service: AccessibilityService!

    override func setUp() {
        super.setUp()
        service = AccessibilityService()
    }

    override func tearDown() {
        service = nil
        super.tearDown()
    }

    // MARK: - 动画控制

    func testShouldAnimateReduceMotionOffReturnsTrue() {
        service.isReduceMotionEnabled = false
        XCTAssertTrue(service.shouldAnimate)
    }

    func testShouldAnimateReduceMotionOnReturnsFalse() {
        service.isReduceMotionEnabled = true
        XCTAssertFalse(service.shouldAnimate)
    }

    // MARK: - pageAnnouncement

    func testPageAnnouncementContainsTitle() {
        let announcement = AccessibilityService.pageAnnouncement(
            title: "我的笔记",
            pageTypeDisplay: "笔记",
            statusDisplay: "已完成",
            tags: [],
            wordCount: 100
        )
        XCTAssertTrue(announcement.contains("我的笔记"))
    }

    func testPageAnnouncementContainsPageType() {
        let announcement = AccessibilityService.pageAnnouncement(
            title: "标题",
            pageTypeDisplay: "文档",
            statusDisplay: "草稿",
            tags: [],
            wordCount: 0
        )
        XCTAssertTrue(announcement.contains("文档"))
    }

    func testPageAnnouncementContainsStatus() {
        let announcement = AccessibilityService.pageAnnouncement(
            title: "标题",
            pageTypeDisplay: "类型",
            statusDisplay: "已归档",
            tags: [],
            wordCount: 0
        )
        XCTAssertTrue(announcement.contains("已归档"))
    }

    func testPageAnnouncementWithTagsContainsTags() {
        let announcement = AccessibilityService.pageAnnouncement(
            title: "标题",
            pageTypeDisplay: "类型",
            statusDisplay: "状态",
            tags: ["Swift", "iOS"],
            wordCount: 0
        )
        XCTAssertTrue(announcement.contains("Swift"))
        XCTAssertTrue(announcement.contains("iOS"))
    }

    func testPageAnnouncementNoTagsNoTagPrefix() {
        let announcement = AccessibilityService.pageAnnouncement(
            title: "标题",
            pageTypeDisplay: "类型",
            statusDisplay: "状态",
            tags: [],
            wordCount: 0
        )
        XCTAssertFalse(announcement.contains("tags") || announcement.contains("标签"))
    }

    func testPageAnnouncementContainsWordCount() {
        let announcement = AccessibilityService.pageAnnouncement(
            title: "标题",
            pageTypeDisplay: "类型",
            statusDisplay: "状态",
            tags: [],
            wordCount: 250
        )
        XCTAssertTrue(announcement.contains("250"))
    }

    // MARK: - graphNodeAnnouncement

    func testGraphNodeAnnouncementContainsNodeTitle() {
        let node = GraphNode(id: UUID(), title: "图谱节点", pageType: .concept, position: .zero)
        let announcement = AccessibilityService.graphNodeAnnouncement(node, linkCount: 5)
        XCTAssertTrue(announcement.contains("图谱节点"))
    }

    func testGraphNodeAnnouncementContainsLinkCount() {
        let node = GraphNode(id: UUID(), title: "节点", pageType: .concept, position: .zero)
        let announcement = AccessibilityService.graphNodeAnnouncement(node, linkCount: 8)
        XCTAssertTrue(announcement.contains("8"))
    }

    // MARK: - Published 属性

    func testIsVoiceOverRunningDefaultFalse() {
        XCTAssertFalse(service.isVoiceOverRunning)
    }

    func testIsHighContrastEnabledDefaultFalse() {
        XCTAssertFalse(service.isHighContrastEnabled)
    }
}
