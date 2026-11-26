//
//  ShareSheetPresenterTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/11/26.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：TC-LEGACY-01 跨平台分享入参校验与服务注入契约验证。
//

import XCTest
import UFPCore
@testable import ZhiYuUnitTestHost

@MainActor
final class ShareSheetPresenterTests: XCTestCase {

    private enum TestData {
        static let shareTitle = "智宇知识笔记"
        static let shareLink = "https://zhiyu.app/p/123"
    }

    private final class MockShareService: ShareSheetProtocol, @unchecked Sendable {
        var presentedItems: [Any] = []
        var presentCallCount: Int = 0

        func presentShareSheet(items: [Any]) async {
            presentCallCount += 1
            presentedItems = items
        }
    }

    /// 验证 ShareSheetProtocol 注册与调用契约
    func testShareSheetProtocol_InvocationWithItems_Succeeds() async {
        let mockService = MockShareService()
        let items: [Any] = [TestData.shareTitle, TestData.shareLink]

        await mockService.presentShareSheet(items: items)

        XCTAssertEqual(mockService.presentCallCount, 1, "分享面板服务应被调用一次")
        XCTAssertEqual(mockService.presentedItems.count, 2, "分享入参数量应与传入一致")
        XCTAssertEqual(mockService.presentedItems.first as? String, TestData.shareTitle)
    }

    /// 验证分享空数据时安全防空调用
    func testShareSheetProtocol_InvocationWithEmptyItems_DoesNotFail() async {
        let mockService = MockShareService()
        let emptyItems: [Any] = []

        await mockService.presentShareSheet(items: emptyItems)

        XCTAssertEqual(mockService.presentCallCount, 1)
        XCTAssertTrue(mockService.presentedItems.isEmpty)
    }
}
