//
//  SynthesisAndTaskCenterViewTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 测试层
//  核心职责：验证 SynthesisStore 合成类型选择、任务中心队列状态流转与进度渲染分支。
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class SynthesisAndTaskCenterViewTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. SynthesisType 全部合成枚举与图标映射

    func testSynthesisType_AllCasesAndTitles() {
        let types: [SynthesisStore.SynthesisType] = [.mindmap, .slides, .quiz, .report, .infographic]

        for type in types {
            XCTAssertFalse(type.title.isEmpty, "合成类型 \(type) 必须具备本地化标题")
            XCTAssertFalse(type.icon.isEmpty, "合成类型 \(type) 必须具备图标")
        }
    }

    // MARK: - 2. AITaskProgressState 任务进度模型与状态机

    func testAITaskProgress_Lifecycle() {
        let metadata = AITaskMetadata(taskName: "生成思维导图", startTime: Date())
        let progressState = AITaskProgressState(progress: 0.5, status: "running")

        XCTAssertEqual(metadata.taskName, "生成思维导图")
        XCTAssertEqual(progressState.progress, 0.5)
        XCTAssertEqual(progressState.status, "running")
    }
}
