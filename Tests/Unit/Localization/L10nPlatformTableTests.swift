//
//  L10nPlatformTableTests.swift
//  ZhiYuTests
//
//  Created by CodeFree on 2026/08/06.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 Platform 表 L10n 扩展的 key 存在性与返回值非空。
//

import XCTest
@testable import ZhiYu

/// Platform 表 L10n 扩展测试（Watch/Widget/Platform）
final class L10nPlatformTableTests: XCTestCase {

    // MARK: - tableName 正确性

    func testTableName_Watch_为Platform() {
        XCTAssertEqual(L10n.Watch.tableName, "Platform")
    }

    func testTableName_Widget_为Platform() {
        XCTAssertEqual(L10n.Widget.tableName, "Platform")
    }

    func testTableName_Platform_为Platform() {
        XCTAssertEqual(L10n.Platform.tableName, "Platform")
    }

    // MARK: - Watch 属性 key 存在性

    func testWatch_基础属性返回非Missing值() {
        let values = [
            L10n.Watch.capture,
            L10n.Watch.recents,
            L10n.Watch.dictateHint,
            L10n.Watch.widgetDisplayName,
            L10n.Watch.widgetDisplayDesc,
            L10n.Watch.briefingSynthesizing,
            L10n.Watch.briefingGetToday,
            L10n.Watch.briefingGenerateNow,
            L10n.Watch.briefingAudioBriefing,
            L10n.Watch.widgetCapture,
            L10n.Watch.widgetDescription,
            L10n.Watch.briefingNoNewContent,
            L10n.Watch.briefingSystemPrompt,
            L10n.Watch.briefingFailed
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Watch 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Watch 属性返回空字符串")
        }
    }

    func testWatch_占位提示属性返回非Missing值() {
        let values = [
            L10n.Watch.taskCenterPlaceholder,
            L10n.Watch.promptWorkshopPlaceholder,
            L10n.Watch.graphCanvasPlaceholder,
            L10n.Watch.graph3DPlaceholder,
            L10n.Watch.ingestPlaceholder,
            L10n.Watch.pdfReaderPlaceholder,
            L10n.Watch.ocrScanPlaceholder
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Watch 占位提示属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Watch 占位提示属性返回空字符串")
        }
    }

    // MARK: - Watch trf 参数化方法

    func testWatch_briefingPromptTemplate_返回非Missing() {
        let result = L10n.Watch.briefingPromptTemplate("测试内容")
        XCTAssertFalse(result.contains("[MISSING:"),
                       "briefingPromptTemplate 返回 Missing: \(result)")
        XCTAssertFalse(result.isEmpty)
    }

    // MARK: - Widget 属性 key 存在性

    func testWidget_所有属性返回非Missing值() {
        let values = [
            L10n.Widget.title,
            L10n.Widget.pages,
            L10n.Widget.words,
            L10n.Widget.active,
            L10n.Widget.characters,
            L10n.Widget.recentUpdates,
            L10n.Widget.stub,
            L10n.Widget.knowledgeCompile,
            L10n.Widget.aiChat,
            L10n.Widget.search,
            L10n.Widget.links,
            L10n.Widget.tags,
            L10n.Widget.vaultName,
            L10n.Widget.ai,
            L10n.Widget.dailyInsight,
            L10n.Widget.knowledgeDistribution,
            L10n.Widget.voice,
            L10n.Widget.qa,
            L10n.Widget.dictating,
            L10n.Widget.voiceFlashCapture,
            L10n.Widget.syncedToiOS,
            L10n.Widget.llmWikiChunking,
            L10n.Widget.llmWikiDescription,
            L10n.Widget.flashThoughtSub,
            L10n.Widget.insightQuote1,
            L10n.Widget.insightQuote2,
            L10n.Widget.insightQuote3,
            L10n.Widget.sampleVoiceNote,
            L10n.Widget.zhiyuAI,
            L10n.Widget.widgetsPreview,
            L10n.Widget.watchVoiceCapture
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Widget 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Widget 属性返回空字符串")
        }
    }

    // MARK: - Widget trf 参数化方法

    func testWidget_pages_返回非Missing() {
        let result = L10n.Widget.pages(10)
        XCTAssertFalse(result.contains("[MISSING:"),
                       "Widget.pages 返回 Missing: \(result)")
        XCTAssertFalse(result.isEmpty)
    }

    // MARK: - Platform 属性 key 存在性

    func testPlatform_Unsupported_所有属性返回非Missing值() {
        let values = [
            L10n.Platform.Unsupported.pdf,
            L10n.Platform.Unsupported.mermaid
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Platform.Unsupported 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Platform.Unsupported 属性返回空字符串")
        }
    }

    func testPlatform_Watch_所有属性返回非Missing值() {
        let values = [
            L10n.Platform.Watch.pages,
            L10n.Platform.Watch.words,
            L10n.Platform.Watch.recentUpdates,
            L10n.Platform.Watch.tenThousand
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Platform.Watch 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Platform.Watch 属性返回空字符串")
        }
    }
}
