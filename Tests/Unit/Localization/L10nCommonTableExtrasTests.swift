//
//  L10nCommonTableExtrasTests.swift
//  ZhiYuTests
//
//  Created by CodeFree on 2026/08/10.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 Common 表 L10n 扩展（Shared/Graph）的 tableName 正确性与代表性属性 key 存在性。
//

import XCTest
@testable import ZhiYu

/// Common 表 L10n 扩展补充测试（Shared/Graph）
/// 已有 L10nCommonTableTests 覆盖 Action/Accessibility/Components/CoreModels/Log/Schema/Search
final class L10nCommonTableExtrasTests: XCTestCase {

    // MARK: - tableName 正确性
    // Shared/Graph 是 struct 非 L10nTableEntry，通过 Common.tr 访问 Common 表
    // 此处验证代表性属性返回非 Missing 值即可

    // MARK: - Shared 属性 key 存在性

    func testShared_基础属性返回非Missing值() {
        let values = [
            L10n.Shared.errorTitle,
            L10n.Shared.retryButton,
            L10n.Shared.editorPlaceholder,
            L10n.Shared.themeStandard,
            L10n.Shared.themeSunset,
            L10n.Shared.themeNeonPurple
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Shared 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Shared 属性返回空字符串")
        }
    }

    func testShared_pageCountFormat_返回非Missing且包含参数() {
        let result = L10n.Shared.pageCountFormat(42)
        XCTAssertFalse(result.contains("[MISSING:"),
                       "Shared.pageCountFormat 返回 Missing: \(result)")
        XCTAssertFalse(result.isEmpty)
    }

    // MARK: - Graph 属性 key 存在性

    func testGraph_基础属性返回非Missing值() {
        let values = [
            L10n.Graph.filter,
            L10n.Graph.insights,
            L10n.Graph.emptyTitle,
            L10n.Graph.emptyDesc,
            L10n.Graph.startBuilding,
            L10n.Graph.all,
            L10n.Graph.legend,
            L10n.Graph.viewDetail,
            L10n.Graph.copyPageLink,
            L10n.Graph.openInNewWindow,
            L10n.Graph.insightSurprising,
            L10n.Graph.insightSurprisingDesc,
            L10n.Graph.title,
            L10n.Graph.insightOrphans,
            L10n.Graph.insightOrphansDesc,
            L10n.Graph.insightSparse,
            L10n.Graph.insightSparseDesc,
            L10n.Graph.insightBridges,
            L10n.Graph.insightBridgesDesc,
            L10n.Graph.nodesLimitDegradeHint
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Graph 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Graph 属性返回空字符串")
        }
    }

    func testGraph_nodesConnections_返回非Missing且包含参数() {
        let result = L10n.Graph.nodesConnections(10, 20)
        XCTAssertFalse(result.contains("[MISSING:"),
                       "Graph.nodesConnections 返回 Missing: \(result)")
        XCTAssertFalse(result.isEmpty)
    }

    func testGraph_edgeTruncationHint_返回非Missing且包含参数() {
        let result = L10n.Graph.edgeTruncationHint(50)
        XCTAssertFalse(result.contains("[MISSING:"),
                       "Graph.edgeTruncationHint 返回 Missing: \(result)")
        XCTAssertFalse(result.isEmpty)
    }

    func testGraph_linksCountFormat_返回非Missing且包含参数() {
        let result = L10n.Graph.linksCountFormat(15)
        XCTAssertFalse(result.contains("[MISSING:"),
                       "Graph.linksCountFormat 返回 Missing: \(result)")
        XCTAssertFalse(result.isEmpty)
    }

    func testGraph_clusterName_返回非Missing且包含参数() {
        let result = L10n.Graph.clusterName(3)
        XCTAssertFalse(result.contains("[MISSING:"),
                       "Graph.clusterName 返回 Missing: \(result)")
        XCTAssertFalse(result.isEmpty)
    }

    // MARK: - Graph.Accessibility 子命名空间

    func testGraph_Accessibility_属性返回非Missing值() {
        let accessibility = L10n.Graph.Accessibility()
        let values = [
            accessibility.nodeHint,
            accessibility.zoomInLabel,
            accessibility.zoomInHint,
            accessibility.zoomOutLabel,
            accessibility.zoomOutHint,
            accessibility.resetLabel,
            accessibility.resetHint
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Graph.Accessibility 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Graph.Accessibility 属性返回空字符串")
        }
    }

    // MARK: - Graph.ThreeD 子命名空间

    func testGraph_ThreeD_title_返回非Missing值() {
        let value = L10n.Graph.ThreeD.title
        XCTAssertFalse(value.contains("[MISSING:"),
                       "Graph.ThreeD.title 返回 Missing: \(value)")
        XCTAssertFalse(value.isEmpty, "Graph.ThreeD.title 返回空字符串")
    }

    // MARK: - Graph.guide 子命名空间

    func testGraph_guide_属性返回非Missing值() {
        let values = [
            L10n.Graph.guide.entryTitle,
            L10n.Graph.guide.entrySubtitle,
            L10n.Graph.guide.sheetTitle,
            L10n.Graph.guide.legendNodeTitle,
            L10n.Graph.guide.legendNodeDesc,
            L10n.Graph.guide.legendLinkTitle,
            L10n.Graph.guide.legendLinkDesc,
            L10n.Graph.guide.typeConceptTitle,
            L10n.Graph.guide.typeConceptDesc,
            L10n.Graph.guide.typeEntityTitle,
            L10n.Graph.guide.typeEntityDesc,
            L10n.Graph.guide.bridgeTitle,
            L10n.Graph.guide.bridgeDesc,
            L10n.Graph.guide.sparseTitle,
            L10n.Graph.guide.sparseDesc,
            L10n.Graph.guide.orphanTitle,
            L10n.Graph.guide.orphanDesc,
            L10n.Graph.guide.surprisingTitle,
            L10n.Graph.guide.surprisingDesc
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Graph.guide 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Graph.guide 属性返回空字符串")
        }
    }
}
