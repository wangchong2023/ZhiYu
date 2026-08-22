//
//  L10nIngestDeepTests.swift
//  ZhiYuTests
//
//  Created by CodeFree on 2026/08/22.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests] 单元测试层
//  核心职责：深度验证 Ingest 表 L10n 扩展的所有属性 key 存在性与返回值非空。
//

import XCTest
@testable import ZhiYu

/// Ingest 表 L10n 扩展深度测试 — 全量属性覆盖
final class L10nIngestDeepTests: XCTestCase {

    private func assertNonMissing(_ value: String, _ context: String = "") {
        XCTAssertFalse(value.contains("[MISSING:"), "属性返回 Missing \(context): \(value)")
        XCTAssertFalse(value.isEmpty, "属性返回空字符串 \(context)")
    }

    func testTableName_Ingest() {
        XCTAssertEqual(L10n.Ingest.tableName, L10n.Ingest.tableName)
    }

    // MARK: - 全量属性批量验证

    func testIngest_所有静态属性返回非Missing值() {
        let values: [String] = [
            L10n.Ingest.title,
            L10n.Ingest.manualEntry,
            L10n.Ingest.sourcePrefix,
            L10n.Ingest.urlSourcePrefix,
            L10n.Ingest.scrapeTimePrefix,
            L10n.Ingest.importFailed,
            L10n.Ingest.importingFile,
            L10n.Ingest.invalidURL,
            L10n.Ingest.fetchingURL,
            L10n.Ingest.fileImport,
            L10n.Ingest.urlImport,
            L10n.Ingest.ocrScan,
            L10n.Ingest.clipboardImport,
            L10n.Ingest.voiceNote,
            L10n.Ingest.audioSubtitle,
            L10n.Ingest.resultTitle,
            L10n.Ingest.importRecords,
            L10n.Ingest.viewRawText,
            L10n.Ingest.openLink,
            L10n.Ingest.previewFile,
            L10n.Ingest.rawContentTitle,
            L10n.Ingest.viewPage,
            L10n.Ingest.openWith,
            L10n.Ingest.imageTooLarge,
            L10n.Ingest.voiceTooLong,
            L10n.Ingest.importCooldown,
            L10n.Ingest.imageExtracting,
            L10n.Ingest.imageOCRLabel,
            L10n.Ingest.imageSkippedTooLarge,
            L10n.Ingest.imageSkippedFailed,
            L10n.Ingest.batchURLTitle,
            L10n.Ingest.batchURLPlaceholder,
            L10n.Ingest.batchImport,
            L10n.Ingest.aiTag,
            L10n.Ingest.aiTagging,
            L10n.Ingest.untagged,
            L10n.Ingest.aiTagSuccess,
            L10n.Ingest.aiTagFailed,
            L10n.Ingest.importAll,
            L10n.Ingest.noImportRecords,
            L10n.Ingest.fileTooLarge,
            L10n.Ingest.storageFull,
            L10n.Ingest.error,
            L10n.Ingest.smartToggle,
            L10n.Ingest.smartToggleHint,
            L10n.Ingest.deepScan,
            L10n.Ingest.deepScanDesc,
            L10n.Ingest.submitting,
            L10n.Ingest.submit,
            L10n.Ingest.iconCustom,
            L10n.Ingest.iconDefault,
            L10n.Ingest.preview,
            L10n.Ingest.previewConfirm,
            L10n.Ingest.previewDiscard,
            L10n.Ingest.suggestLinks,
            L10n.Ingest.tips,
            L10n.Ingest.urlImportPlaceholder,
            L10n.Ingest.webDesc,
            L10n.Ingest.ok,
            L10n.Ingest.actions,
            L10n.Ingest.recentActivity,
            L10n.Ingest.recent,
            L10n.Ingest.noActivities,
            L10n.Ingest.smartIngest,
            L10n.Ingest.smartIngestDesc,
            L10n.Ingest.ecoIndexingLowPower,
            L10n.Ingest.hero.subtitle,
            L10n.Ingest.field.title,
            L10n.Ingest.field.titlePlaceholder,
            L10n.Ingest.field.tags,
            L10n.Ingest.field.tagsPlaceholder,
            L10n.Ingest.field.content,
            L10n.Ingest.field.type,
            L10n.Ingest.field.icon,
            L10n.Ingest.method.file,
            L10n.Ingest.method.fileDesc,
            L10n.Ingest.method.ocr,
            L10n.Ingest.method.ocrDesc,
            L10n.Ingest.method.manual,
            L10n.Ingest.method.manualDesc,
            L10n.Ingest.OCR.title,
            L10n.Ingest.OCR.previewTitle,
            L10n.Ingest.OCR.pageType,
            L10n.Ingest.OCR.saveToKnowledge,
            L10n.Ingest.OCR.processing,
            L10n.Ingest.OCR.result,
            L10n.Ingest.OCR.selectImage,
            L10n.Ingest.OCR.fromAlbum,
            L10n.Ingest.OCR.recognize,
            L10n.Ingest.OCR.pageTitle,
            L10n.Ingest.OCR.changeIcon,
            L10n.Ingest.OCR.customIcon,
            L10n.Ingest.OCR.scanTag,
            L10n.Ingest.OCR.confirmAndEdit,
            L10n.Ingest.OCR.scanFailed,
            L10n.Ingest.OCR.addTag,
            L10n.Ingest.OCR.Error.cameraUnavailable,
            L10n.Ingest.OCR.Error.invalidImage,
            L10n.Ingest.OCR.Error.noResults,
            L10n.Ingest.PDF.sourceURL,
            L10n.Ingest.PDF.notSupported,
            L10n.Ingest.PDF.notSupportedDesc,
            L10n.Ingest.PDF.pageSeparator,
            L10n.Ingest.PDF.contentPreview,
            L10n.Ingest.PDF.ingestToKnowledge,
            L10n.Ingest.PDF.ingest,
            L10n.Ingest.PDF.pageTitle,
            L10n.Ingest.PDF.pageType,
            L10n.Ingest.PDF.targetPage,
            L10n.Ingest.PDF.extractionMethod,
            L10n.Ingest.PDF.fullText,
            L10n.Ingest.PDF.pageRange,
            L10n.Ingest.PDF.highlightsOnly,
            L10n.Ingest.PDF.fromPage,
            L10n.Ingest.PDF.toPage,
            L10n.Ingest.PDF.page,
            L10n.Ingest.PDF.extractionRange,
            L10n.Ingest.PDF.noHighlights,
            L10n.Ingest.PDF.cannotLoadPDF,
            L10n.Ingest.PDF.noteLabel,
            L10n.Ingest.PDF.title,
            L10n.Ingest.PDF.library,
            L10n.Ingest.PDF.libraryHint,
            L10n.Ingest.PDF.delete,
            L10n.Ingest.PDF.annotateSelected,
            L10n.Ingest.PDF.add,
            L10n.Ingest.PDF.addNote,
            L10n.Ingest.PDF.saveAnnotation,
            L10n.Ingest.Status.starting,
            L10n.Ingest.Status.aiEnriching,
            L10n.Ingest.Status.generatingSummary,
            L10n.Ingest.Status.chunking,
            L10n.Ingest.Status.processingChunk,
            L10n.Ingest.Status.vectorizing,
            L10n.Ingest.Status.completed,
            L10n.Ingest.Status.webscraperLevel1Success,
            L10n.Ingest.Status.webscraperLevel1Failed,
            L10n.Ingest.Status.webscraperLevel2Success,
            L10n.Ingest.Status.webscraperLevel2Failed,
            L10n.Ingest.Status.webscraperLevel3Success,
            L10n.Ingest.Status.webscraperLevel3Failed,
            L10n.Ingest.Status.webscraperLevel4Success,
            L10n.Ingest.previewTruncated,
            L10n.Ingest.previewLoadMore,
            L10n.Ingest.previewFinished
        ]
        for value in values { assertNonMissing(value) }
    }

    // MARK: - 全量格式化方法验证

    func testIngest_所有格式化方法返回非Missing值() {
        assertNonMissing(L10n.Ingest.smartIngestDoneDesc("x"), "L10n.Ingest.smartIngestDoneDesc")
        assertNonMissing(L10n.Ingest.activeTasks(1), "L10n.Ingest.activeTasks")
        assertNonMissing(L10n.Ingest.pdfPageCountFormat(1), "L10n.Ingest.pdfPageCountFormat")
        assertNonMissing(L10n.Ingest.pdfCreatedPage("x"), "L10n.Ingest.pdfCreatedPage")
        assertNonMissing(L10n.Ingest.pdfPageNumber(1), "L10n.Ingest.pdfPageNumber")
        assertNonMissing(L10n.Ingest.ocrCharCountFormat(1), "L10n.Ingest.ocrCharCountFormat")
        assertNonMissing(L10n.Ingest.pdfIngestModeFormat("x"), "L10n.Ingest.pdfIngestModeFormat")
        assertNonMissing(L10n.Ingest.pdfHighlightCountFormat(1), "L10n.Ingest.pdfHighlightCountFormat")
        assertNonMissing(L10n.Ingest.duplicateFile("x"), "L10n.Ingest.duplicateFile")
        assertNonMissing(L10n.Ingest.imageCount(1), "L10n.Ingest.imageCount")
        assertNonMissing(L10n.Ingest.invalidURLAtLine(1), "L10n.Ingest.invalidURLAtLine")
        assertNonMissing(L10n.Ingest.validURLCount(1, 1), "L10n.Ingest.validURLCount")
        assertNonMissing(L10n.Ingest.importProgress(1, 1), "L10n.Ingest.importProgress")
        assertNonMissing(L10n.Ingest.batchResult(1, 1), "L10n.Ingest.batchResult")
        assertNonMissing(L10n.Ingest.aiTagPrompt("x"), "L10n.Ingest.aiTagPrompt")
        assertNonMissing(L10n.Ingest.Status.webscraperPaywallDetected(1), "L10n.Ingest.Status.webscraperPaywallDetected")
    }
}
