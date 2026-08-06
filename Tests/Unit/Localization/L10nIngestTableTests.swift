//
//  L10nIngestTableTests.swift
//  ZhiYuTests
//
//  Created by CodeFree on 2026/08/06.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 Ingest 表 L10n 扩展的 key 存在性与返回值非空。
//

import XCTest
@testable import ZhiYu

/// Ingest 表 L10n 扩展测试（Transfer）
final class L10nIngestTableTests: XCTestCase {

    // MARK: - tableName 正确性

    func testTableName_Transfer_为Ingest() {
        XCTAssertEqual(L10n.Transfer.tableName, "Ingest")
    }

    // MARK: - Transfer.Export 属性 key 存在性

    func testTransfer_Export_基础属性返回非Missing值() {
        let values = [
            L10n.Transfer.Export.errorSystemBusy,
            L10n.Transfer.Export.errorEngineNotReady
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Transfer.Export 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Transfer.Export 属性返回空字符串")
        }
    }

    // MARK: - Transfer.Export trf 参数化方法

    func testTransfer_Export_errorInternal_返回非Missing() {
        let result = L10n.Transfer.Export.errorInternal("测试错误信息")
        XCTAssertFalse(result.contains("[MISSING:"),
                       "errorInternal 返回 Missing: \(result)")
        XCTAssertFalse(result.isEmpty)
    }
}
