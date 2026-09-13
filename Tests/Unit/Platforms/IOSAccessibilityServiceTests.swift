//
//  IOSAccessibilityServiceTests.swift
//  ZhiYu
//
//  Created by CodeFree on 2026/08/24.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：iOSAccessibilityService 单元测试，覆盖 VoiceOver 公告发布场景。
//

#if os(iOS) || targetEnvironment(macCatalyst)
import UIKit
import XCTest
@testable import ZhiYu

@MainActor
final class IOSAccessibilityServiceTests: XCTestCase {

    // MARK: - 测试常量

    private enum TestConstants {
        static let announcementText: String = "导出已完成"
        static let emptyText: String = ""
        static let longTextRepeatCount: Int = 51
        static let longText: String = String(repeating: "智宇", count: longTextRepeatCount)
    }

    // MARK: - 初始化

    /// 服务应可无参初始化
    func testInitSucceedsWithoutArguments() {
        let service = iOSAccessibilityService()
        XCTAssertNotNil(service)
    }

    // MARK: - postAnnouncement

    /// 发布普通中文公告不应抛出异常或崩溃
    func testPostAnnouncementWithChineseTextDoesNotCrash() {
        let service = iOSAccessibilityService()
        XCTAssertFalse(TestConstants.announcementText.isEmpty)
        service.postAnnouncement(TestConstants.announcementText)
    }

    /// 发布空字符串公告不应崩溃
    func testPostAnnouncementWithEmptyTextDoesNotCrash() {
        let service = iOSAccessibilityService()
        XCTAssertTrue(TestConstants.emptyText.isEmpty)
        service.postAnnouncement(TestConstants.emptyText)
    }

    /// 发布长文本公告不应崩溃
    func testPostAnnouncementWithLongTextDoesNotCrash() {
        let service = iOSAccessibilityService()
        XCTAssertGreaterThan(TestConstants.longText.count, 100)
        service.postAnnouncement(TestConstants.longText)
    }

    // MARK: - 协议一致性

    /// 服务实例应可向上转型为 AccessibilityServiceProtocol
    func testConformsToAccessibilityServiceProtocol() {
        let service: any AccessibilityServiceProtocol = iOSAccessibilityService()
        XCTAssertNotNil(service)
        service.postAnnouncement(TestConstants.announcementText)
    }
}
#endif
