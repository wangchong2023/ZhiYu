//
//  IOSShareSheetServiceTests.swift
//  ZhiYu
//
//  Created by CodeFree on 2026/08/24.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：iOSShareSheetService 单元测试，覆盖分享面板展示与无窗口降级场景。
//

#if os(iOS) && !os(watchOS)
import XCTest
import UIKit
@testable import ZhiYu

@MainActor
final class IOSShareSheetServiceTests: XCTestCase {

    // MARK: - 测试常量

    private enum TestConstants {
        static let shareText: String = "智宇知识分享内容"
        static let shareURL: String = "https://example.com/zhiyu"
    }

    // MARK: - presentShareSheet

    /// 分享文本在无 keyWindow 时应静默返回不崩溃
    func testPresentShareSheetWithTextDoesNotCrash() async {
        let service = iOSShareSheetService()
        XCTAssertFalse(TestConstants.shareText.isEmpty)
        await service.presentShareSheet(items: [TestConstants.shareText])
    }

    /// 分享 URL 在无 keyWindow 时应静默返回不崩溃
    func testPresentShareSheetWithURLDoesNotCrash() async {
        let service = iOSShareSheetService()
        let url = URL(string: TestConstants.shareURL)
        XCTAssertNotNil(url)
        await service.presentShareSheet(items: [url as Any])
    }

    /// 分享空 items 数组不应崩溃
    func testPresentShareSheetWithEmptyItemsDoesNotCrash() async {
        let service = iOSShareSheetService()
        let emptyItems: [Any] = []
        XCTAssertTrue(emptyItems.isEmpty)
        await service.presentShareSheet(items: emptyItems)
    }

    /// 分享多种类型混合 items 不应崩溃
    func testPresentShareSheetWithMixedItemsDoesNotCrash() async {
        let service = iOSShareSheetService()
        let url = URL(string: TestConstants.shareURL)
        XCTAssertNotNil(url)
        await service.presentShareSheet(items: [TestConstants.shareText, url as Any])
    }

    // MARK: - 协议一致性

    /// 服务实例应可向上转型为 ShareSheetProtocol
    func testConformsToShareSheetProtocol() async {
        let service: any ShareSheetProtocol = iOSShareSheetService()
        XCTAssertNotNil(service)
        await service.presentShareSheet(items: [TestConstants.shareText])
    }

    /// NoOpShareSheet 调用应不崩溃
    func testNoOpShareSheetDoesNotCrash() async {
        let noOp = NoOpShareSheet()
        XCTAssertNotNil(noOp)
        await noOp.presentShareSheet(items: [TestConstants.shareText])
    }
}
#endif
