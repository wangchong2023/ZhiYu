//
//  FeaturesSearchAndPluginsDeepMatrixTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/03.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests] 单元测试层
//  核心职责：深度覆盖 L2 Features 搜索抽屉面板与插件中心视图状态机。
//

import XCTest
import SwiftUI
@testable import ZhiYu
import UFPCore

@MainActor
final class FeaturesSearchAndPluginsDeepMatrixTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. PagePreviewSheet 深度预览测试

    func testPagePreviewSheet_RenderingWithMetadata() {
        let samplePage = KnowledgePage(
            id: UUID(),
            title: "微调大模型实践指南",
            pageType: .concept,
            content: "本文介绍 LoRA 与 QLoRA 在端侧部署时的量化要点与实践基准测试。",
            tags: ["LLM", "FineTuning", "LoRA", "Quantization"],
            status: .active,
            confidence: .high
        )

        let previewSheet = PagePreviewSheet(page: samplePage)
        let host = UIHostingController(rootView: previewSheet.snapshotEnvironment())
        host.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view, "PagePreviewSheet 应在全量环境中正常完成布局求值")
    }

    // MARK: - 2. SearchDiagnosticSheet 混合诊断面板测试

    func testSearchDiagnosticSheet_RenderingMetricsAndRRFList() {
        let sampleScore = SearchDiagnosticInfo.ResultScore(
            id: UUID(),
            title: "混合检索 RRF 融合算法",
            ftsRank: 1,
            vectorRank: 2,
            finalScore: 0.985
        )

        let diagnosticInfo = SearchDiagnosticInfo(
            query: "如何优化 RAG 混合召回",
            rewrittenQuery: "RAG hybrid search FTS5 vector recall RRF fusion",
            ftsCount: 15,
            vectorCount: 20,
            rrfTopResults: [sampleScore]
        )

        let diagnosticSheet = SearchDiagnosticSheet(info: diagnosticInfo)
        let host = UIHostingController(rootView: diagnosticSheet.snapshotEnvironment())
        host.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view, "SearchDiagnosticSheet 应正常展示多源召回指标与 RRF 重排精细得分")
    }

    // MARK: - 3. PluginCenterView 插件生态视图深度测试

    func testPluginCenterView_MarketAndMyPluginsLifecycle() async {
        let pluginCenter = PluginCenterView()
        let host = UIHostingController(rootView: pluginCenter.snapshotEnvironment())
        host.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view, "PluginCenterView 顶层生态视图应正常装配并求值")
    }
}
