//
//  PageStoreCapabilitiesTests.swift
//  ZhiYuTests
//
//  系统层级：[L1] 存储与仓储测试
//  核心职责：验证 AnyPageStoreCapabilities 协议默认实现的页面创建与参数穿透能力。
//

import XCTest
import UFPCore
@testable import ZhiYu

final class PageStoreCapabilitiesTests: XCTestCase {

    /// 验证 anyCreatePage 正常路径返回非 nil KnowledgePage
    @MainActor
    func testAnyCreatePage_validParameters_returnsKnowledgePage() async {
        setupFullMockEnvironment()

        let mock = NoOpPageStoreCapabilities()
        let result = await mock.anyCreatePage(
            title: "CapabilitiesTest",
            pageType: .concept,
            customIcon: nil,
            content: "test content",
            tags: [],
            sourceURL: nil,
            rawSnippet: nil,
            fileSize: nil,
            sourceType: nil,
            forceDeepScan: false
        )

        XCTAssertNotNil(result, "正常创建应返回非 nil KnowledgePage")
    }
}
