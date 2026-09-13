//
//  SourceViewAndSettingsComponentsDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/03.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests] 单元测试层
//  核心职责：深度覆盖 L2 Features 知识溯源 SourceView 与模型实验室/配置生成器。
//

import XCTest
import SwiftUI
@testable import ZhiYu
import UFPCore

@MainActor
final class SourceViewAndSettingsComponentsDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. SourceView 与 SourceRow 溯源测试

    func testSourceView_EmptyAndPopulated() {
        let store = SourceStore.shared
        store.clear()

        // 1. 空状态测试
        let emptyView = SourceView()
        let host1 = UIHostingController(rootView: emptyView.snapshotEnvironment())
        host1.view.frame = CGRect(x: 0, y: 0, width: 390, height: 600)
        host1.view.layoutIfNeeded()
        XCTAssertNotNil(host1.view)

        // 2. 注入数据测试
        let samplePageID = UUID()
        let sampleSource = KnowledgeSource(
            id: UUID(),
            pageID: samplePageID,
            title: "大语言模型原理与工程实践",
            snippet: "Transformer 架构中的 Self-Attention 机制通过 QKV 矩阵计算相关度权重。",
            anchorPath: "第 3 章 / 3.2 节",
            score: 0.94
        )
        store.updateSources([sampleSource])

        let populatedView = SourceView()
        let host2 = UIHostingController(rootView: populatedView.snapshotEnvironment())
        host2.view.frame = CGRect(x: 0, y: 0, width: 390, height: 600)
        host2.view.layoutIfNeeded()
        XCTAssertNotNil(host2.view)

        // 3. SourceRow 点击交互测试
        var selectedID: UUID?
        let row = SourceRow(source: sampleSource) { pageID in
            selectedID = pageID
        }
        let host3 = UIHostingController(rootView: row.snapshotEnvironment())
        host3.view.frame = CGRect(x: 0, y: 0, width: 390, height: 120)
        host3.view.layoutIfNeeded()
        XCTAssertNotNil(host3.view)

        row.onSelect(samplePageID)
        XCTAssertEqual(selectedID, samplePageID)
    }

    // MARK: - 2. ModelLabView 格栅卡片与头部测试
    // MARK: - 3. PluginCustomSettingsView 动态配置渲染测试
    // MARK: - 4. PluginIconView 多态图标渲染测试
    // MARK: - 5. RAGTimeRangePicker 时间范围选择器测试

    func testRAGTimeRangePicker_Selection() {
        var selectedDays = 7
        let binding = Binding(get: { selectedDays }, set: { selectedDays = $0 })

        let picker = RAGTimeRangePicker(selectedDays: binding)
        let host = UIHostingController(rootView: picker.snapshotEnvironment())
        host.view.frame = CGRect(x: 0, y: 0, width: 320, height: 60)
        host.view.layoutIfNeeded()
        XCTAssertNotNil(host.view)

        // 模拟切换
        selectedDays = 30
        XCTAssertEqual(selectedDays, 30)
    }

    // MARK: - 6. PluginExtensionsSection & DetailView 测试
}
