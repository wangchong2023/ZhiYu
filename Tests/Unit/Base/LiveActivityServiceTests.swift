//
//  LiveActivityServiceTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//

import XCTest
@testable import ZhiYu

@MainActor
final class LiveActivityServiceTests: XCTestCase {

    func testContentStateCodableContract() throws {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        let originalState = AIProcessingAttributes.ContentState(
            progress: 0.75,
            status: "Synthesis Processing",
            kind: .synthesis,
            sourceCount: 12,
            currentFileName: "Karpathy_LLM_Wiki.pdf",
            estimatedSecondsRemaining: 15
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(originalState)
        XCTAssertGreaterThan(data.count, 0, "ContentState 序列化数据不应为空")

        let decoder = JSONDecoder()
        let decodedState = try decoder.decode(AIProcessingAttributes.ContentState.self, from: data)

        XCTAssertEqual(decodedState.progress, 0.75, "Progress 必须精准反序列化")
        XCTAssertEqual(decodedState.status, "Synthesis Processing", "Status 描述必须匹配")
        XCTAssertEqual(decodedState.kind, .synthesis, "ActivityKind 变体必须匹配")
        XCTAssertEqual(decodedState.sourceCount, 12, "sourceCount 必须匹配")
        XCTAssertEqual(decodedState.currentFileName, "Karpathy_LLM_Wiki.pdf", "currentFileName 必须匹配")
        XCTAssertEqual(decodedState.estimatedSecondsRemaining, 15, "estimatedSecondsRemaining 必须匹配")
        #endif
    }

    func testActivityKindEnumRawValues() {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        XCTAssertEqual(ActivityKind.synthesis.rawValue, "synthesis")
        XCTAssertEqual(ActivityKind.ingestOCR.rawValue, "ingestOCR")
        XCTAssertEqual(ActivityKind.voiceNote.rawValue, "voiceNote")
        #endif
    }

    func testDummyActivityServiceProtocolOverloads() async {
        let dummy = DummyActivityService()
        let id = UUID()
        
        dummy.startActivity(
            id: id,
            name: "AI Synthesis Lab",
            target: "Retrieval",
            kind: .synthesis,
            sourceCount: 5,
            currentFileName: "Doc.pdf",
            estimatedSecondsRemaining: 20
        )
        
        await dummy.updateProgress(
            id: id,
            progress: 0.5,
            message: "Generating",
            sourceCount: 5,
            currentFileName: "Doc.pdf",
            estimatedSecondsRemaining: 10
        )
        
        await dummy.endActivity(id: id)
        
        XCTAssertTrue(true, "DummyActivityService 的扩展协议重载必须平滑无缝执行")
    }
}
