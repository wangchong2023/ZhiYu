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
        static let longTextRepeatCount: Int = 50
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
        service.postAnnouncement(TestConstants.announcementText)
        XCTAssertTrue(true, "postAnnouncement 应正常执行无崩溃")
    }

    /// 发布空字符串公告不应崩溃
    func testPostAnnouncementWithEmptyTextDoesNotCrash() {
        let service = iOSAccessibilityService()
        service.postAnnouncement(TestConstants.emptyText)
        XCTAssertTrue(true, "postAnnouncement 空字符串应正常执行")
    }

    /// 发布长文本公告不应崩溃
    func testPostAnnouncementWithLongTextDoesNotCrash() {
        let service = iOSAccessibilityService()
        service.postAnnouncement(TestConstants.longText)
        XCTAssertTrue(true, "postAnnouncement 长文本应正常执行")
    }

    // MARK: - 协议一致性

    /// 服务实例应可向上转型为 AccessibilityServiceProtocol
    func testConformsToAccessibilityServiceProtocol() {
        let service: any AccessibilityServiceProtocol = iOSAccessibilityService()
        service.postAnnouncement(TestConstants.announcementText)
        XCTAssertTrue(true, "协议转型与调用应成功")
    }
}
#endif
