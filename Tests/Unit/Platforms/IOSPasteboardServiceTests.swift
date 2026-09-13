//
//  IOSPasteboardServiceTests.swift
//  ZhiYu
//
//  Created by CodeFree on 2026/08/24.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：iOSPasteboardService 单元测试，覆盖剪贴板读写、nil 清空等场景。
//

#if os(iOS) && !os(watchOS)
import UIKit
import XCTest
@testable import ZhiYu

@MainActor
final class IOSPasteboardServiceTests: XCTestCase {

    // MARK: - 测试常量

    private enum TestConstants {
        static let sampleText: String = "ZhiYu_Pasteboard_Test_\(UUID().uuidString)"
        static let chineseText: String = "智宇剪贴板测试"
        static let emptyText: String = ""
    }

    // MARK: - 读写往返

    /// 写入字符串后再读取，应返回相同内容
    func testStringReadWriteRoundTrip() {
        let service = iOSPasteboardService()
        service.string = TestConstants.sampleText
        XCTAssertEqual(service.string, TestConstants.sampleText)
    }

    /// 写入中文字符后再读取，应正确返回中文内容
    func testStringReadWriteChineseContent() {
        let service = iOSPasteboardService()
        service.string = TestConstants.chineseText
        XCTAssertEqual(service.string, TestConstants.chineseText)
    }

    // MARK: - nil 清空

    /// 设置为 nil 后读取应返回 nil
    func testStringSetNilClearsPasteboard() {
        let service = iOSPasteboardService()
        service.string = TestConstants.sampleText
        XCTAssertNotNil(service.string)
        service.string = nil
        XCTAssertNil(service.string)
    }

    /// 空字符串写入后读取应返回空字符串而非 nil
    func testStringEmptyValuePreserved() {
        let service = iOSPasteboardService()
        service.string = TestConstants.emptyText
        XCTAssertEqual(service.string, TestConstants.emptyText)
    }
}
#endif
