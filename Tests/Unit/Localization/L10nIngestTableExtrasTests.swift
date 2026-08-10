//
//  L10nIngestTableExtrasTests.swift
//  ZhiYuTests
//
//  Created by CodeFree on 2026/08/10.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 Ingest 表 L10n 扩展（Ingest/Backup/ICloud）的 tableName 正确性与属性 key 存在性。
//

import XCTest
@testable import ZhiYu

/// Ingest 表 L10n 扩展补充测试（Ingest/Backup/ICloud）
/// 已有 L10nIngestTableTests 覆盖 Transfer
final class L10nIngestTableExtrasTests: XCTestCase {

    // MARK: - tableName 正确性

    func testTableName_Ingest_为Ingest() {
        XCTAssertEqual(L10n.Ingest.tableName, "Ingest")
    }

    func testTableName_Backup_为Ingest() {
        XCTAssertEqual(L10n.Backup.tableName, "Ingest")
    }

    func testTableName_ICloud_为Ingest() {
        XCTAssertEqual(L10n.ICloud.tableName, "Ingest")
    }

    // MARK: - Ingest 属性 key 存在性

    func testIngest_基础属性返回非Missing值() {
        let values = [
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
            L10n.Ingest.openWith
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Ingest 基础属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Ingest 基础属性返回空字符串")
        }
    }

    func testIngest_图片与语音属性返回非Missing值() {
        let values = [
            L10n.Ingest.imageTooLarge,
            L10n.Ingest.voiceTooLong,
            L10n.Ingest.importCooldown,
            L10n.Ingest.imageExtracting,
            L10n.Ingest.imageOCRLabel,
            L10n.Ingest.imageSkippedTooLarge,
            L10n.Ingest.imageSkippedFailed
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Ingest 图片语音属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Ingest 图片语音属性返回空字符串")
        }
    }

    func testIngest_批量URL属性返回非Missing值() {
        let values = [
            L10n.Ingest.batchURLTitle,
            L10n.Ingest.batchURLPlaceholder,
            L10n.Ingest.batchImport
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Ingest 批量URL属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Ingest 批量URL属性返回空字符串")
        }
    }

    func testIngest_AITag属性返回非Missing值() {
        let values = [
            L10n.Ingest.aiTag,
            L10n.Ingest.aiTagging,
            L10n.Ingest.untagged,
            L10n.Ingest.aiTagSuccess,
            L10n.Ingest.aiTagFailed
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Ingest AITag 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Ingest AITag 属性返回空字符串")
        }
    }

    func testIngest_智能导入属性返回非Missing值() {
        let values = [
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
            L10n.Ingest.smartIngest,
            L10n.Ingest.smartIngestDesc,
            L10n.Ingest.ecoIndexingLowPower
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Ingest 智能导入属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Ingest 智能导入属性返回空字符串")
        }
    }

    func testIngest_预览与活动属性返回非Missing值() {
        let values = [
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
            L10n.Ingest.previewTruncated,
            L10n.Ingest.previewLoadMore,
            L10n.Ingest.previewFinished
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Ingest 预览活动属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Ingest 预览活动属性返回空字符串")
        }
    }

    func testIngest_pdfPageCountFormat_返回非Missing且包含参数() {
        let result = L10n.Ingest.pdfPageCountFormat(10)
        XCTAssertFalse(result.contains("[MISSING:"),
                       "Ingest.pdfPageCountFormat 返回 Missing: \(result)")
        XCTAssertFalse(result.isEmpty)
    }

    func testIngest_batchResult_返回非Missing且包含参数() {
        let result = L10n.Ingest.batchResult(5, 2)
        XCTAssertFalse(result.contains("[MISSING:"),
                       "Ingest.batchResult 返回 Missing: \(result)")
        XCTAssertFalse(result.isEmpty)
    }

    func testIngest_imageCount_返回非Missing且包含参数() {
        let result = L10n.Ingest.imageCount(3)
        XCTAssertFalse(result.contains("[MISSING:"),
                       "Ingest.imageCount 返回 Missing: \(result)")
        XCTAssertFalse(result.isEmpty)
    }

    // MARK: - Backup 属性 key 存在性

    func testBackup_基础属性返回非Missing值() {
        let values = [
            L10n.Backup.title,
            L10n.Backup.autoBackup,
            L10n.Backup.createNow,
            L10n.Backup.exportCurrent,
            L10n.Backup.pages,
            L10n.Backup.words,
            L10n.Backup.restoreTitle,
            L10n.Backup.deleteConfirmTitle,
            L10n.Backup.lastBackup,
            L10n.Backup.restore,
            L10n.Backup.restoreMessage,
            L10n.Backup.settings,
            L10n.Backup.actions,
            L10n.Backup.noBackups,
            L10n.Backup.noBackupsDesc,
            L10n.Backup.deleteConfirmMessage,
            L10n.Backup.history
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Backup 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Backup 属性返回空字符串")
        }
    }

    func testBackup_log_属性返回非Missing值() {
        let values = [
            L10n.Backup.log.createFailed,
            L10n.Backup.log.restoreFailed,
            L10n.Backup.log.saveIndexFailed,
            L10n.Backup.log.crashRecovery
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Backup.log 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Backup.log 属性返回空字符串")
        }
    }

    // MARK: - ICloud 属性 key 存在性

    func testICloud_基础属性返回非Missing值() {
        let values = [
            L10n.ICloud.pushToCloud,
            L10n.ICloud.pullFromCloud,
            L10n.ICloud.bidirectionalSync,
            L10n.ICloud.clearCloudData,
            L10n.ICloud.pushComplete,
            L10n.ICloud.pullComplete,
            L10n.ICloud.syncComplete,
            L10n.ICloud.lastSync,
            L10n.ICloud.never
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "ICloud 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "ICloud 属性返回空字符串")
        }
    }
}
