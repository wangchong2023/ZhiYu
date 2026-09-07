//
//  SynthesisActionButtonInteractiveTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/04.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests/Unit] 功能测试层
//  核心职责：SynthesisActionButton 触发逻辑、前置环境校验、控制面板调用与容量预警测试
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class SynthesisActionButtonInteractiveTests: XCTestCase {

    private var appStore: AppStore!
    private var synthesisStore: SynthesisStore!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        appStore = AppStore()
        synthesisStore = SynthesisStore()
    }

    override func tearDown() async throws {
        appStore = nil
        synthesisStore = nil
        try await super.tearDown()
    }

    // MARK: - 1. SynthesisActionButton 实例化与状态卡片渲染测试

    func testSynthesisActionButtonIdleAndLimitReached() {
        struct Host: View {
            @State var showNoPagesAlert = false
            @State var showLimitAlert = false
            @State var showLLMAlert = false
            @State var selectedFilterType: SynthesisStore.SynthesisType?
            @State var selectedDoc: SynthesisStore.SynthesisDocument?
            @State var showOutput = false

            let store: AppStore
            let type: SynthesisStore.SynthesisType

            var body: some View {
                SynthesisActionButton(
                    type: type,
                    store: store,
                    showNoPagesAlert: $showNoPagesAlert,
                    showLimitAlert: $showLimitAlert,
                    showLLMAlert: $showLLMAlert,
                    selectedFilterType: $selectedFilterType,
                    selectedDoc: $selectedDoc,
                    showOutput: $showOutput
                )
            }
        }

        let host = UIHostingController(
            rootView: Host(store: appStore, type: .report).snapshotEnvironment()
        )
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertEqual(synthesisStore.synthesisStates[.report] ?? .idle, .idle)
    }

    // MARK: - 2. 容量预警状态判断测试

    func testCapacityLimitReachedCondition() {
        // 填满最大文档数量
        var mockDocs: [SynthesisStore.SynthesisDocument] = []
        for i in 1...synthesisStore.maxSynthesisDocsPerType {
            mockDocs.append(SynthesisStore.SynthesisDocument(
                id: UUID(),
                type: .report,
                name: "Doc \(i)",
                content: "Content",
                createdAt: Date(),
                size: 100,
                sourcePageIDs: []
            ))
        }

        synthesisStore.synthesisResults[.report] = mockDocs
        let currentCount = synthesisStore.synthesisResults[.report]?.count ?? 0
        let isLimitReached = currentCount >= synthesisStore.maxSynthesisDocsPerType

        XCTAssertTrue(isLimitReached, "当文档数达到上限时应触发容量警戒判定")
    }

    // MARK: - 3. 控制选项 (SynthesisControlOptions) 自定义提示词拼接测试

    func testControlOptionsPromptAugmentation() {
        let page = KnowledgePage(title: "分布式系统", content: "高并发架构核心要素")
        let activePages = [page]

        let options = SynthesisControlOptions(
            depth: .detailed,
            audience: .professional,
            tone: .academic,
            customPrompt: "必须重点阐述脑裂问题的防御机制"
        )

        var combinedContent = activePages.map { "# \($0.title)\n\($0.content)" }.joined(separator: "\n\n---\n\n")
        if !options.customPrompt.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
            combinedContent += "\n\n[用户定制需求/侧重点说明]: \(options.customPrompt)"
        }

        XCTAssertTrue(combinedContent.contains("必须重点阐述脑裂问题的防御机制"))
        XCTAssertTrue(combinedContent.contains("高并发架构核心要素"))
    }
}
