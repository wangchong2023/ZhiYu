//
//  SynthesisStrategiesMutationTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/02.
//  Copyright © 2026 WangChong. All rights reserved.
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class SynthesisStrategiesMutationTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. 8 种合成策略生成与变异

    func testSynthesisStrategiesGenerationAndValidation() async throws {
        let store = SynthesisStore()
        let sourceID = UUID()

        for type in SynthesisStore.SynthesisType.allCases {
            // 1. 测试成功生成
            let validMarkdown = """
            # Comprehensive Guide to \(type.title)
            
            This is a detailed analysis containing key takeaways and core concepts for \(type.title).
            
            - Point 1: System architecture
            - Point 2: Performance optimization
            - Point 3: Fault tolerance
            """
            let doc = store.saveSynthesisResult(type: type, content: validMarkdown, sourcePageIDs: [sourceID])
            XCTAssertNotNil(doc)
            XCTAssertEqual(doc?.type, type)
            XCTAssertEqual(store.synthesisStates[type], .completed)

            // 2. 测试无效内容被防御性拦截
            let invalidDoc = store.saveSynthesisResult(type: type, content: "Short")
            XCTAssertNil(invalidDoc)

            // 3. 测试纯 Mermaid 骨架防御拦截
            let mermaidDoc = store.saveSynthesisResult(type: type, content: ProcessorConstants.MermaidSyntax.mindmap)
            XCTAssertNil(mermaidDoc)
        }

        XCTAssertEqual(store.allSortedDocuments.count, SynthesisStore.SynthesisType.allCases.count)
    }

    // MARK: - 2. 文档管理：重命名、删除、批量删除与清空

    func testSynthesisDocManagementOperations() async throws {
        let store = SynthesisStore()
        let doc1 = store.saveSynthesisResult(type: SynthesisStore.SynthesisType.mindmap, content: "# Mindmap 1\n\nDetailed content for testing mindmap generation.")
        let doc2 = store.saveSynthesisResult(type: SynthesisStore.SynthesisType.mindmap, content: "# Mindmap 2\n\nAnother detailed content for mindmap.")
        XCTAssertNotNil(doc1)
        XCTAssertNotNil(doc2)

        guard let id1 = doc1?.id, let id2 = doc2?.id else {
            XCTFail("Documents should be created")
            return
        }

        // 1. 重命名
        store.renameSynthesisDoc(type: SynthesisStore.SynthesisType.mindmap, docID: id1, newName: "Renamed Mindmap")
        let renamed = store.synthesisResults[SynthesisStore.SynthesisType.mindmap]?.first(where: { $0.id == id1 })
        XCTAssertEqual(renamed?.name, "Renamed Mindmap")

        // 2. 单个删除
        store.deleteSynthesisDoc(type: SynthesisStore.SynthesisType.mindmap, docID: id1)
        XCTAssertNil(store.synthesisResults[SynthesisStore.SynthesisType.mindmap]?.first(where: { $0.id == id1 }))

        // 3. 批量删除
        store.batchDeleteSynthesisDocs(ids: [id2])
        XCTAssertTrue(store.synthesisResults[SynthesisStore.SynthesisType.mindmap]?.isEmpty ?? true)
        XCTAssertEqual(store.synthesisStates[SynthesisStore.SynthesisType.mindmap], .idle)

        // 4. 清空全部
        _ = store.saveSynthesisResult(type: SynthesisStore.SynthesisType.slides, content: "# Slides\n\nContent for slides presentation.")
        store.clearAll()
        XCTAssertTrue(store.allSortedDocuments.isEmpty)
    }

    // MARK: - 3. SynthesisControlOptions 与调控指令

    func testSynthesisControlOptionsInstructions() {
        var options = SynthesisControlOptions(
            depth: .detailed,
            audience: .executive,
            tone: .academic,
            customPrompt: "Focus on business value."
        )

        let instruction = options.promptInstruction
        XCTAssertFalse(instruction.isEmpty)
        XCTAssertTrue(instruction.contains("Focus on business value."))

        // 切换篇幅深度
        options.depth = .concise
        XCTAssertFalse(options.promptInstruction.isEmpty)

        options.depth = .standard
        XCTAssertFalse(options.promptInstruction.isEmpty)
    }
}
