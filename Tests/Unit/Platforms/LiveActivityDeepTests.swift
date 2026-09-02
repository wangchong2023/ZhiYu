//
//  LiveActivityDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Unit] 单元测试层
//  核心职责：深度测试 AIProcessingAttributes 与 ActivityKind 灵动岛/锁屏实时活动状态模型。
//

import XCTest
import SwiftUI
import Dependencies
import UFPCore
@testable import ZhiYu

#if os(iOS) && !targetEnvironment(macCatalyst)
import ActivityKit
#endif

@MainActor
final class LiveActivityDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    func testActivityKind_AllCases() {
        let kinds: [ActivityKind] = [.synthesis, .ingestOCR, .voiceNote]
        for kind in kinds {
            XCTAssertFalse(kind.rawValue.isEmpty)
        }
    }

    func testAIProcessingAttributes_InitAndState() {
        let fixedDate = Date(timeIntervalSince1970: 1750000000)
        let attributes = AIProcessingAttributes(taskName: "《Karpathy LLM OS》知识摄取", startTime: fixedDate)
        XCTAssertEqual(attributes.taskName, "《Karpathy LLM OS》知识摄取")

        let state = AIProcessingAttributes.ContentState(
            progress: 0.75,
            status: "正在生成双链图谱与向量索引",
            kind: .synthesis,
            estimatedSecondsRemaining: 12
        )
        XCTAssertEqual(state.progress, 0.75)
        XCTAssertEqual(state.status, "正在生成双链图谱与向量索引")
        XCTAssertEqual(state.kind, .synthesis)
        XCTAssertEqual(state.estimatedSecondsRemaining, 12)
    }
}
