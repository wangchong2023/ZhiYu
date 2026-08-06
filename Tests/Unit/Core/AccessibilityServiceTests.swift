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

    func testShouldAnimate_reduceMotion关闭_返回true() {
        service.isReduceMotionEnabled = false
        XCTAssertTrue(service.shouldAnimate)
    }

    func testShouldAnimate_reduceMotion开启_返回false() {
        service.isReduceMotionEnabled = true
        XCTAssertFalse(service.shouldAnimate)
    }

    // MARK: - pageAnnouncement

    func testPageAnnouncement_包含标题() {
        let announcement = AccessibilityService.pageAnnouncement(
            title: "我的笔记",
            pageTypeDisplay: "笔记",
            statusDisplay: "已完成",
            tags: [],
            wordCount: 100
        )
        XCTAssertTrue(announcement.contains("我的笔记"))
    }

    func testPageAnnouncement_包含页面类型() {
        let announcement = AccessibilityService.pageAnnouncement(
            title: "标题",
            pageTypeDisplay: "文档",
            statusDisplay: "草稿",
            tags: [],
            wordCount: 0
        )
        XCTAssertTrue(announcement.contains("文档"))
    }

    func testPageAnnouncement_包含状态() {
        let announcement = AccessibilityService.pageAnnouncement(
            title: "标题",
            pageTypeDisplay: "类型",
            statusDisplay: "已归档",
            tags: [],
            wordCount: 0
        )
        XCTAssertTrue(announcement.contains("已归档"))
    }

    func testPageAnnouncement_有标签_包含标签() {
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

    func testPageAnnouncement_无标签_不包含标签前缀() {
        let announcement = AccessibilityService.pageAnnouncement(
            title: "标题",
            pageTypeDisplay: "类型",
            statusDisplay: "状态",
            tags: [],
            wordCount: 0
        )
        XCTAssertFalse(announcement.contains("tags") || announcement.contains("标签"))
    }

    func testPageAnnouncement_包含字数() {
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

    func testGraphNodeAnnouncement_包含节点标题() {
        let node = GraphNode(id: UUID(), title: "图谱节点", pageType: .concept, position: .zero)
        let announcement = AccessibilityService.graphNodeAnnouncement(node, linkCount: 5)
        XCTAssertTrue(announcement.contains("图谱节点"))
    }

    func testGraphNodeAnnouncement_包含链接数() {
        let node = GraphNode(id: UUID(), title: "节点", pageType: .concept, position: .zero)
        let announcement = AccessibilityService.graphNodeAnnouncement(node, linkCount: 8)
        XCTAssertTrue(announcement.contains("8"))
    }

    // MARK: - Published 属性

    func testIsVoiceOverRunning_默认false() {
        XCTAssertFalse(service.isVoiceOverRunning)
    }

    func testIsHighContrastEnabled_默认false() {
        XCTAssertFalse(service.isHighContrastEnabled)
    }
}
