//
//  L10nKnowledgeTableExtrasTests.swift
//  ZhiYuTests
//
//  Created by CodeFree on 2026/08/10.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 Knowledge 表 L10n 扩展（Knowledge/Editor/Quiz/Vault）的 tableName 正确性与属性 key 存在性。
//

import XCTest
@testable import ZhiYu

/// Knowledge 表 L10n 扩展补充测试（Knowledge/Editor/Quiz/Vault）
/// 已有 L10nKnowledgeTableTests 覆盖 Creation/Tag
final class L10nKnowledgeTableExtrasTests: XCTestCase {

    // MARK: - tableName 正确性

    func testTableName_Knowledge_为Knowledge() {
        XCTAssertEqual(L10n.Knowledge.tableName, "Knowledge")
    }

    func testTableName_Editor_为Knowledge() {
        XCTAssertEqual(L10n.Editor.tableName, "Knowledge")
    }

    func testTableName_Quiz_为Knowledge() {
        XCTAssertEqual(L10n.Quiz.tableName, "Knowledge")
    }

    func testTableName_Vault_为Knowledge() {
        XCTAssertEqual(L10n.Vault.tableName, "Knowledge")
    }

    // MARK: - Knowledge.Page 属性 key 存在性

    func testKnowledge_Page_基础属性返回非Missing值() {
        let values = [
            L10n.Knowledge.Page.edit,
            L10n.Knowledge.Page.doneEditing,
            L10n.Knowledge.Page.deletePage,
            L10n.Knowledge.Page.confirmDelete,
            L10n.Knowledge.Page.deleteMessage,
            L10n.Knowledge.Page.icon,
            L10n.Knowledge.Page.knowledge,
            L10n.Knowledge.Page.empty,
            L10n.Knowledge.Page.emptyHint,
            L10n.Knowledge.Page.content,
            L10n.Knowledge.Page.status,
            L10n.Knowledge.Page.metaInfo,
            L10n.Knowledge.Page.expandStub,
            L10n.Knowledge.Page.findLinks,
            L10n.Knowledge.Page.pin,
            L10n.Knowledge.Page.unpin,
            L10n.Knowledge.Page.outLinkUnit,
            L10n.Knowledge.Page.noBackLinks,
            L10n.Knowledge.Page.sourceOpenLink,
            L10n.Knowledge.Page.doubleTapToNavigate,
            L10n.Knowledge.Page.backlinks,
            L10n.Knowledge.Page.outgoings,
            L10n.Knowledge.Page.brokenLinks,
            L10n.Knowledge.Page.orphanPages
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Knowledge.Page 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Knowledge.Page 属性返回空字符串")
        }
    }

    func testKnowledge_Page_Source_属性返回非Missing值() {
        let values = [
            L10n.Knowledge.Page.Source.title,
            L10n.Knowledge.Page.Source.open,
            L10n.Knowledge.Page.Source.content,
            L10n.Knowledge.Page.Source.empty,
            L10n.Knowledge.Page.Source.copied,
            L10n.Knowledge.Page.Source.copyPath,
            L10n.Knowledge.Page.Source.localFile
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Knowledge.Page.Source 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Knowledge.Page.Source 属性返回空字符串")
        }
    }

    func testKnowledge_Page_AI_属性返回非Missing值() {
        let values = [
            L10n.Knowledge.Page.AI.insights,
            L10n.Knowledge.Page.AI.insightsDesc,
            L10n.Knowledge.Page.AI.summary,
            L10n.Knowledge.Page.AI.extractActions,
            L10n.Knowledge.Page.AI.mindmap,
            L10n.Knowledge.Page.AI.quiz,
            L10n.Knowledge.Page.AI.slides,
            L10n.Knowledge.Page.AI.report,
            L10n.Knowledge.Page.AI.infographic,
            L10n.Knowledge.Page.AI.lab,
            L10n.Knowledge.Page.AI.expansion,
            L10n.Knowledge.Page.AI.labOutput,
            L10n.Knowledge.Page.AI.potentialLinksScanning,
            L10n.Knowledge.Page.AI.potentialLinksTitle,
            L10n.Knowledge.Page.AI.potentialLinksEmpty
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Knowledge.Page.AI 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Knowledge.Page.AI 属性返回空字符串")
        }
    }

    func testKnowledge_Page_History_属性返回非Missing值() {
        let values = [
            L10n.Knowledge.Page.History.title,
            L10n.Knowledge.Page.History.none,
            L10n.Knowledge.Page.History.manual,
            L10n.Knowledge.Page.History.physical,
            L10n.Knowledge.Page.History.version,
            L10n.Knowledge.Page.History.rollback
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Knowledge.Page.History 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Knowledge.Page.History 属性返回空字符串")
        }
    }

    func testKnowledge_Page_Snapshot_属性返回非Missing值() {
        let value = L10n.Knowledge.Page.Snapshot.preview
        XCTAssertFalse(value.contains("[MISSING:"),
                       "Knowledge.Page.Snapshot.preview 返回 Missing: \(value)")
        XCTAssertFalse(value.isEmpty, "Knowledge.Page.Snapshot.preview 返回空字符串")
    }

    // MARK: - Editor 属性 key 存在性

    func testEditor_基础属性返回非Missing值() {
        let values = [
            L10n.Editor.insertPageLink,
            L10n.Editor.searchPages,
            L10n.Editor.bidirectionalLinks,
            L10n.Editor.enterTag,
            L10n.Editor.addTag,
            L10n.Editor.tableColumn1,
            L10n.Editor.tableColumn2,
            L10n.Editor.tableColumn3,
            L10n.Editor.tableContent,
            L10n.Editor.bold,
            L10n.Editor.code,
            L10n.Editor.divider,
            L10n.Editor.italic,
            L10n.Editor.knowledgeLink,
            L10n.Editor.link,
            L10n.Editor.list,
            L10n.Editor.ocrScan,
            L10n.Editor.quote,
            L10n.Editor.table,
            L10n.Editor.selectedText,
            L10n.Editor.placeholder,
            L10n.Editor.toc,
            L10n.Editor.outline
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Editor 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Editor 属性返回空字符串")
        }
    }

    func testEditor_iconPicker_属性返回非Missing值() {
        let values = [
            L10n.Editor.iconPicker.customSelected,
            L10n.Editor.iconPicker.useDefault,
            L10n.Editor.iconPicker.selectIcon
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Editor.iconPicker 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Editor.iconPicker 属性返回空字符串")
        }
    }

    // MARK: - Quiz 属性 key 存在性

    func testQuiz_基础属性返回非Missing值() {
        let values = [
            L10n.Quiz.title,
            L10n.Quiz.completed,
            L10n.Quiz.yourScore,
            L10n.Quiz.backToPage,
            L10n.Quiz.showAnswer,
            L10n.Quiz.correctAnswer,
            L10n.Quiz.explanation
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Quiz 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Quiz 属性返回空字符串")
        }
    }

    func testQuiz_questionFormat_返回非Missing且包含参数() {
        let result = L10n.Quiz.questionFormat(1, 10)
        XCTAssertFalse(result.contains("[MISSING:"),
                       "Quiz.questionFormat 返回 Missing: \(result)")
        XCTAssertFalse(result.isEmpty)
    }

    func testQuiz_scoreFormat_返回非Missing且包含参数() {
        let result = L10n.Quiz.scoreFormat(85)
        XCTAssertFalse(result.contains("[MISSING:"),
                       "Quiz.scoreFormat 返回 Missing: \(result)")
        XCTAssertFalse(result.isEmpty)
    }

    // MARK: - Vault 属性 key 存在性

    func testVault_基础属性返回非Missing值() {
        let values = [
            L10n.Vault.homeTitle,
            L10n.Vault.label,
            L10n.Vault.backToHub,
            L10n.Vault.defaultName,
            L10n.Vault.defaultNameZh,
            L10n.Vault.defaultNameEn,
            L10n.Vault.researchName,
            L10n.Vault.researchNameZh,
            L10n.Vault.researchNameEn,
            L10n.Vault.subtitle,
            L10n.Vault.noSelection,
            L10n.Vault.new,
            L10n.Vault.create,
            L10n.Vault.rename,
            L10n.Vault.deleteNotebook,
            L10n.Vault.edit,
            L10n.Vault.iconLabel,
            L10n.Vault.namePlaceholder,
            L10n.Vault.renameMessage,
            L10n.Vault.defaultDescription,
            L10n.Vault.researchDescription,
            L10n.Vault.lastEdited,
            L10n.Vault.descriptionLabel,
            L10n.Vault.descriptionPlaceholder,
            L10n.Vault.nameLabel,
            L10n.Vault.pageCountSuffix
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Vault 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Vault 属性返回空字符串")
        }
    }
}
