//
//  L10nCommonTableTests.swift
//  ZhiYuTests
//
//  Created by CodeFree on 2026/08/06.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 Common 表 L10n 扩展的 key 存在性与返回值非空。
//

import XCTest
@testable import ZhiYu

/// Common 表 L10n 扩展测试（Action/Accessibility/Log/Schema/Components/CoreModels/Search）
final class L10nCommonTableTests: XCTestCase {

    // MARK: - tableName 正确性

    func testTableName_Action_为Common() {
        XCTAssertEqual(L10n.Action.tableName, "Common")
    }

    func testTableName_Accessibility_为Common() {
        XCTAssertEqual(L10n.Accessibility.tableName, "Common")
    }

    func testTableName_Log_为Common() {
        XCTAssertEqual(L10n.Log.tableName, "Common")
    }

    func testTableName_Schema_为Common() {
        XCTAssertEqual(L10n.Schema.tableName, "Common")
    }

    func testTableName_Components_为Common() {
        XCTAssertEqual(L10n.Components.tableName, "Common")
    }

    func testTableName_CoreModels_为Common() {
        XCTAssertEqual(L10n.CoreModels.tableName, "Common")
    }

    func testTableName_Search_为Common() {
        XCTAssertEqual(L10n.Search.tableName, "Common")
    }

    // MARK: - Action 属性 key 存在性

    func testAction_所有属性返回非Missing值() {
        let values = [
            L10n.Action.createPage,
            L10n.Action.createPageSubtitle,
            L10n.Action.ingestKnowledge,
            L10n.Action.ingestKnowledgeSubtitle,
            L10n.Action.cmd.deepExplore,
            L10n.Action.cmd.newKnowledgePage,
            L10n.Action.cmd.quickActions,
            L10n.Action.cmd.recentAccess
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Action 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Action 属性返回空字符串")
        }
    }

    // MARK: - Accessibility 属性 key 存在性

    func testAccessibility_所有属性返回非Missing值() {
        let values = [
            L10n.Accessibility.tags,
            L10n.Accessibility.words,
            L10n.Accessibility.links,
            L10n.Accessibility.tapToOpen,
            L10n.Accessibility.notebookCardLabel,
            L10n.Accessibility.notebookCardHint,
            L10n.Accessibility.notebookListRowHint
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Accessibility 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Accessibility 属性返回空字符串")
        }
    }

    // MARK: - Log 属性 key 存在性

    func testLog_所有属性返回非Missing值() {
        let values = [
            L10n.Log.noLogs,
            L10n.Log.clearConfirmTitle,
            L10n.Log.startTime,
            L10n.Log.endTime,
            L10n.Log.duration,
            L10n.Log.failureReason,
            L10n.Log.statusSuccess,
            L10n.Log.statusFailure,
            L10n.Log.statusProcessing
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Log 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Log 属性返回空字符串")
        }
    }

    // MARK: - Schema 属性 key 存在性

    func testSchema_concept_所有属性返回非Missing值() {
        let values = [
            L10n.Schema.concept.template,
            L10n.Schema.concept.prompt,
            L10n.Schema.concept.field.applications,
            L10n.Schema.concept.field.theory
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Schema.concept 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Schema.concept 属性返回空字符串")
        }
    }

    func testSchema_entity_所有属性返回非Missing值() {
        let values = [
            L10n.Schema.entity.template,
            L10n.Schema.entity.prompt,
            L10n.Schema.entity.field.attributes,
            L10n.Schema.entity.field.definition,
            L10n.Schema.entity.field.relations
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Schema.entity 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Schema.entity 属性返回空字符串")
        }
    }

    // MARK: - Components 属性 key 存在性

    func testComponents_所有属性返回非Missing值() {
        let values = [
            L10n.Components.noOutgoing,
            L10n.Components.noBackLinks,
            L10n.Components.search
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Components 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Components 属性返回空字符串")
        }
    }

    // MARK: - CoreModels 属性 key 存在性

    func testCoreModels_type_所有属性返回非Missing值() {
        let values = [
            L10n.CoreModels.type.entity,
            L10n.CoreModels.type.concept,
            L10n.CoreModels.type.source,
            L10n.CoreModels.type.comparison,
            L10n.CoreModels.type.raw
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "CoreModels.type 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "CoreModels.type 属性返回空字符串")
        }
    }

    func testCoreModels_Status_所有属性返回非Missing值() {
        let values = [
            L10n.CoreModels.Status.active,
            L10n.CoreModels.Status.stub,
            L10n.CoreModels.Status.needsUpdate,
            L10n.CoreModels.Status.deprecated
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "CoreModels.Status 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "CoreModels.Status 属性返回空字符串")
        }
    }

    func testCoreModels_confidence_所有属性返回非Missing值() {
        let values = [
            L10n.CoreModels.confidence.high,
            L10n.CoreModels.confidence.medium,
            L10n.CoreModels.confidence.low
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "CoreModels.confidence 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "CoreModels.confidence 属性返回空字符串")
        }
    }

    // MARK: - Search 属性 key 存在性

    func testSearch_所有属性返回非Missing值() {
        let values = [
            L10n.Search.base,
            L10n.Search.title,
            L10n.Search.all,
            L10n.Search.noResults,
            L10n.Search.noResultsHint,
            L10n.Search.filterTags,
            L10n.Search.diagnostics
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Search 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Search 属性返回空字符串")
        }
    }

    func testSearch_Diag_所有属性返回非Missing值() {
        let values = [
            L10n.Search.Diag.title,
            L10n.Search.Diag.rewrite,
            L10n.Search.Diag.originalQuery,
            L10n.Search.Diag.rewrittenQuery,
            L10n.Search.Diag.rrfDetail,
            L10n.Search.Diag.ftsRank,
            L10n.Search.Diag.vectorRank,
            L10n.Search.Diag.miss,
            L10n.Search.Diag.scoreFormat,
            L10n.Search.Diag.ftsEngine,
            L10n.Search.Diag.vectorEngine
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Search.Diag 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Search.Diag 属性返回空字符串")
        }
    }

    // MARK: - Search trf 参数化方法

    func testSearch_resultsCount_返回非Missing且包含参数() {
        let result = L10n.Search.resultsCount(42)
        XCTAssertFalse(result.contains("[MISSING:"),
                       "resultsCount 返回 Missing: \(result)")
        XCTAssertFalse(result.isEmpty)
    }

    func testSearch_pagesCount_返回非Missing且包含参数() {
        let result = L10n.Search.pagesCount(7)
        XCTAssertFalse(result.contains("[MISSING:"),
                       "pagesCount 返回 Missing: \(result)")
        XCTAssertFalse(result.isEmpty)
    }

    // MARK: - Common 基础属性 key 存在性（跨表引用基础）

    func testCommon_基础属性返回非Missing值() {
        let values = [
            L10n.Common.appName,
            L10n.Common.ok,
            L10n.Common.cancel,
            L10n.Common.done,
            L10n.Common.save,
            L10n.Common.delete,
            L10n.Common.edit,
            L10n.Common.refresh,
            L10n.Common.success,
            L10n.Common.failed,
            L10n.Common.error,
            L10n.Common.settings,
            L10n.Common.rename,
            L10n.Common.create
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Common 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Common 属性返回空字符串")
        }
    }
}
