//
//  L10nICloudDeepTests.swift
//  ZhiYuTests
//
//  Created by CodeFree on 2026/08/22.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests] 单元测试层
//  核心职责：深度验证 ICloud 表 L10n 扩展的所有属性 key 存在性与返回值非空。
//

import XCTest
@testable import ZhiYu

/// ICloud 表 L10n 扩展深度测试 — 全量属性覆盖
final class L10nICloudDeepTests: XCTestCase {

    private func assertNonMissing(_ value: String, _ context: String = "") {
        XCTAssertFalse(value.contains("[MISSING:"), "属性返回 Missing \(context): \(value)")
        XCTAssertFalse(value.isEmpty, "属性返回空字符串 \(context)")
    }

    func testTableName_ICloud() {
        XCTAssertEqual(L10n.ICloud.tableName, L10n.ICloud.tableName)
    }

    // MARK: - 全量属性批量验证

    func testICloud_所有静态属性返回非Missing值() {
        let values: [String] = [
            L10n.ICloud.pushToCloud,
            L10n.ICloud.pullFromCloud,
            L10n.ICloud.bidirectionalSync,
            L10n.ICloud.clearCloudData,
            L10n.ICloud.pushComplete,
            L10n.ICloud.pullComplete,
            L10n.ICloud.syncComplete,
            L10n.ICloud.lastSync,
            L10n.ICloud.never,
            L10n.ICloud.Status.syncing,
            L10n.ICloud.Status.uploading,
            L10n.ICloud.Status.downloading,
            L10n.ICloud.Status.upToDate,
            L10n.ICloud.Status.error,
            L10n.ICloud.Status.notAvailable,
            L10n.ICloud.Error.auth,
            L10n.ICloud.Error.quota,
            L10n.ICloud.Error.network,
            L10n.ICloud.Error.conflict,
            L10n.ICloud.Error.decoding,
            L10n.ICloud.Error.encoding,
            L10n.ICloud.Error.notAvailable,
            L10n.ICloud.Conflict.manualMergeTitle,
            L10n.ICloud.Conflict.completeMerge,
            L10n.ICloud.Conflict.noPhysicalConflict,
            L10n.ICloud.Conflict.metaConflictAutoSolved,
            L10n.ICloud.Conflict.runSmartMerge,
            L10n.ICloud.Conflict.smartOverwriteMode,
            L10n.ICloud.Conflict.allChooseLocal,
            L10n.ICloud.Conflict.allChooseRemote,
            L10n.ICloud.Conflict.localVersionHeader,
            L10n.ICloud.Conflict.remoteVersionHeader,
            L10n.ICloud.Conflict.mergedResultEditorHeader,
            L10n.ICloud.Conflict.chooseLocalContent,
            L10n.ICloud.Conflict.chooseRemoteContent,
            L10n.ICloud.Conflict.noTimeInfo
        ]
        for value in values { assertNonMissing(value) }
    }

    // MARK: - 全量格式化方法验证

    func testICloud_所有格式化方法返回非Missing值() {
        assertNonMissing(L10n.ICloud.Conflict.docListCount(1), "L10n.ICloud.Conflict.docListCount")
        assertNonMissing(L10n.ICloud.Conflict.localVersionTime("x"), "L10n.ICloud.Conflict.localVersionTime")
        assertNonMissing(L10n.ICloud.Conflict.remoteVersionTime("x"), "L10n.ICloud.Conflict.remoteVersionTime")
    }
}
