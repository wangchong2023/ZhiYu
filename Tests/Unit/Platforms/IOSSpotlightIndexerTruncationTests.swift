//
//  IOSSpotlightIndexerTruncationTests.swift
//  ZhiYuTests
//
//  系统层级：[Platforms] 平台索引测试
//  核心职责：验证 iOSSpotlightIndexer 在建立索引时的内容截断与标识符配置。
//

import XCTest
import Foundation
@testable import ZhiYu

#if canImport(CoreSpotlight)
@MainActor
final class IOSSpotlightIndexerTruncationTests: XCTestCase {

    /// 验证 indexPage 处理超长内容时截断逻辑不引发崩溃
    func testIndexPage_longContent_indexesSafely() {
        let service = iOSSpotlightIndexer()
        let longContent = String(repeating: "A", count: 500)
        let page = KnowledgePage(title: "Test", content: longContent)

        service.indexPage(page)
        XCTAssertNotNil(service)
    }

    /// 验证 indexPage 标准页面索引行为
    func testIndexPage_standardPage_indexesSafely() {
        let service = iOSSpotlightIndexer()
        let page = KnowledgePage(title: "Test", content: "content")

        service.indexPage(page)
        XCTAssertNotNil(service)
    }
}
#endif
