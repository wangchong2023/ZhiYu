//
//  L10nKnowledgeTableTests.swift
//  ZhiYuTests
//
//  Created by CodeFree on 2026/08/06.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 Knowledge 表 L10n 扩展的 key 存在性与返回值非空。
//

import XCTest
@testable import ZhiYu

/// Knowledge 表 L10n 扩展测试（Creation/Tag）
final class L10nKnowledgeTableTests: XCTestCase {

    // MARK: - tableName 正确性

    func testTableName_Creation_为Knowledge() {
        XCTAssertEqual(L10n.Creation.tableName, "Knowledge")
    }

    func testTableName_Tag_为Knowledge() {
        XCTAssertEqual(L10n.Tag.tableName, "Knowledge")
    }

    // MARK: - Creation 属性 key 存在性

    func testCreation_基础属性返回非Missing值() {
        let values = [
            L10n.Creation.entityTemplate,
            L10n.Creation.conceptTemplate,
            L10n.Creation.comparisonTemplate,
            L10n.Creation.customIcon,
            L10n.Creation.newPage,
            L10n.Creation.basicInfo,
            L10n.Creation.pageTitle,
            L10n.Creation.pageType,
            L10n.Creation.title,
            L10n.Creation.tagsPlaceholder,
            L10n.Creation.create,
            L10n.Creation.content,
            L10n.Creation.quickTemplates,
            L10n.Creation.relatedLinks,
            L10n.Creation.compareItemA,
            L10n.Creation.compareItemB
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Creation 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Creation 属性返回空字符串")
        }
    }

    func testCreation_template_entity_所有属性返回非Missing值() {
        let values = [
            L10n.Creation.template.entity.desc,
            L10n.Creation.template.entity.overview,
            L10n.Creation.template.entity.overviewPlaceholder,
            L10n.Creation.template.entity.contributions,
            L10n.Creation.template.entity.contributionsPlaceholder,
            L10n.Creation.template.entity.related,
            L10n.Creation.template.entity.relatedPlaceholder,
            L10n.Creation.template.entity.overviewHint
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Creation.template.entity 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Creation.template.entity 属性返回空字符串")
        }
    }

    func testCreation_template_concept_所有属性返回非Missing值() {
        let values = [
            L10n.Creation.template.concept.desc,
            L10n.Creation.template.concept.definition,
            L10n.Creation.template.concept.definitionPlaceholder,
            L10n.Creation.template.concept.analysis,
            L10n.Creation.template.concept.analysisPlaceholder,
            L10n.Creation.template.concept.links,
            L10n.Creation.template.concept.linksPlaceholder,
            L10n.Creation.template.concept.analysisHint
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Creation.template.concept 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Creation.template.concept 属性返回空字符串")
        }
    }

    func testCreation_template_comparison_所有属性返回非Missing值() {
        let values = [
            L10n.Creation.template.comparison.desc,
            L10n.Creation.template.comparison.suffix,
            L10n.Creation.template.comparison.dimensions,
            L10n.Creation.template.comparison.dimensionsPlaceholder,
            L10n.Creation.template.comparison.conclusion,
            L10n.Creation.template.comparison.conclusionPlaceholder,
            L10n.Creation.template.comparison.table,
            L10n.Creation.template.comparison.conclusionHint
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Creation.template.comparison 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Creation.template.comparison 属性返回空字符串")
        }
    }

    // MARK: - Tag 属性 key 存在性

    func testTag_基础属性返回非Missing值() {
        let values = [
            L10n.Tag.title,
            L10n.Tag.allTags,
            L10n.Tag.relatedPagesTitle,
            L10n.Tag.layoutList,
            L10n.Tag.layoutBubble,
            L10n.Tag.expandAll,
            L10n.Tag.collapse
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Tag 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Tag 属性返回空字符串")
        }
    }

    func testTag_Action_所有属性返回非Missing值() {
        let values = [
            L10n.Tag.Action.rename,
            L10n.Tag.Action.delete,
            L10n.Tag.Action.renameTag,
            L10n.Tag.Action.newName,
            L10n.Tag.Action.deleteTag,
            L10n.Tag.Action.noTags,
            L10n.Tag.Action.noTagsHint
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Tag.Action 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Tag.Action 属性返回空字符串")
        }
    }

    func testTag_Management_所有属性返回非Missing值() {
        let values = [
            L10n.Tag.Management.addNew,
            L10n.Tag.Management.inputName,
            L10n.Tag.Management.manageTitle,
            L10n.Tag.Management.createHint,
            L10n.Tag.Management.selectToManage
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Tag.Management 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Tag.Management 属性返回空字符串")
        }
    }

    func testTag_Cloud_所有属性返回非Missing值() {
        let value = L10n.Tag.Cloud.selectTag
        XCTAssertFalse(value.contains("[MISSING:"),
                       "Tag.Cloud 属性返回 Missing: \(value)")
        XCTAssertFalse(value.isEmpty, "Tag.Cloud 属性返回空字符串")
    }

    // MARK: - Tag trf 参数化方法

    func testTag_tagCount_返回非Missing() {
        let result = L10n.Tag.tagCount(5)
        XCTAssertFalse(result.contains("[MISSING:"),
                       "tagCount 返回 Missing: \(result)")
        XCTAssertFalse(result.isEmpty)
    }

    func testTag_Action_renameMessage_返回非Missing() {
        let result = L10n.Tag.Action.renameMessage("测试标签")
        XCTAssertFalse(result.contains("[MISSING:"),
                       "renameMessage 返回 Missing: \(result)")
        XCTAssertFalse(result.isEmpty)
    }

    func testTag_Action_deleteMessage_返回非Missing() {
        let result = L10n.Tag.Action.deleteMessage("测试标签")
        XCTAssertFalse(result.contains("[MISSING:"),
                       "deleteMessage 返回 Missing: \(result)")
        XCTAssertFalse(result.isEmpty)
    }

    func testTag_Action_tagPages_返回非Missing() {
        let result = L10n.Tag.Action.tagPages(3)
        XCTAssertFalse(result.contains("[MISSING:"),
                       "tagPages 返回 Missing: \(result)")
        XCTAssertFalse(result.isEmpty)
    }

    func testTag_Management_bulkDeleteWarning_返回非Missing() {
        let result = L10n.Tag.Management.bulkDeleteWarning(10)
        XCTAssertFalse(result.contains("[MISSING:"),
                       "bulkDeleteWarning 返回 Missing: \(result)")
        XCTAssertFalse(result.isEmpty)
    }

    func testTag_Management_selectedCount_返回非Missing() {
        let result = L10n.Tag.Management.selectedCount(2)
        XCTAssertFalse(result.contains("[MISSING:"),
                       "selectedCount 返回 Missing: \(result)")
        XCTAssertFalse(result.isEmpty)
    }
}
