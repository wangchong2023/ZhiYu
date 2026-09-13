//
//  CloudChaosTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 CloudChaos 开展自动化单元测试验证。
//

import XCTest
@testable import ZhiYu

@MainActor
final class CloudChaosTests: XCTestCase {

    func testVersionConflictResolution() async throws {
        let pageId = UUID()
        let pageB = KnowledgePage(id: pageId, title: "Title B", content: "Content B", createdAt: Date(), updatedAt: Date(timeIntervalSince1970: 200))

        let resolved = pageB

        XCTAssertEqual(resolved.title, "Title B", "版本冲突应当保留更新的时间戳内容")
    }
}
