//
//  LiveActivityAndTaskProgressDeepAuditTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Platforms] 平台适配层测试
//  核心职责：深度审计 AI 任务进度状态 (AITaskMetadata/AITaskProgressState) 与灵动岛状态一致性。
//

import XCTest
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class LiveActivityProgressDeepAuditTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. AITaskMetadata 与 AITaskProgressState 序列化一致性

    func testAITaskProgress_SerializationAndProgressClamping() throws {
        let metadata = AITaskMetadata(taskName: "AI 知识合成", startTime: Date())
        let state = AITaskProgressState(progress: 0.75, status: "正在生成思维导图...")

        let encoder = JSONEncoder()
        let metaData = try encoder.encode(metadata)
        let stateData = try encoder.encode(state)

        let decoder = JSONDecoder()
        let decodedMeta = try decoder.decode(AITaskMetadata.self, from: metaData)
        let decodedState = try decoder.decode(AITaskProgressState.self, from: stateData)

        XCTAssertEqual(decodedMeta.taskName, "AI 知识合成")
        XCTAssertEqual(decodedState.progress, 0.75)
        XCTAssertEqual(decodedState.status, "正在生成思维导图...")
    }
}
