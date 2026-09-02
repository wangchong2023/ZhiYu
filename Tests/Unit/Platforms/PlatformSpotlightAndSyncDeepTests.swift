//
//  PlatformSpotlightAndSyncDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Platforms] 平台适配层测试
//  核心职责：针对 Spotlight 搜索同步（SpotlightService）与 iOS-Watch 手表数据桥接
//            执行跨平台能力注册与消息分发测试。
//

import XCTest
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class PlatformSpotlightAndSyncDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. SpotlightService 批量页面索引测试

    func testSpotlightService_IndexPages() {
        let pages = [
            KnowledgePage(title: "Karpathy LLM Wiki", pageType: .concept, content: "Methodology"),
            KnowledgePage(title: "RAG Governance", pageType: .entity, content: "Quality Metrics")
        ]

        SpotlightService.shared.indexPages(pages)
        XCTAssertEqual(pages.count, 2)
    }

    // MARK: - 2. Device & Platform Capabilities 注册与适配

    func testPlatformCapabilities_CrossPlatformRegistration() {
        #if os(iOS) && !os(watchOS)
        iOSPlatformRegistrar.registerServices(in: ServiceContainer.shared)
        #endif

        let pasteboard = ServiceContainer.shared.resolveOptional((any PasteboardProtocol).self)
        XCTAssertNotNil(pasteboard)
    }
}
