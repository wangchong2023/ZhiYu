//
//  LogActionTests.swift
//  ZhiYu
//
//  系统层级：[L0] 测试层
//  核心职责：验证 LogAction 枚举 rawValue 契约一致性（前缀模式/唯一性/可逆性）。
//

import XCTest
@testable import ZhiYu

final class LogActionTests: XCTestCase {

    // MARK: - rawValue 前缀契约

    /// 标准 case 的 rawValue 应以 "logAction." 前缀开头（契约一致性）
    func testRawValue_标准case_logAction前缀() {
        let standardCases: [LogAction] = [
            .create, .update, .delete,
            .ingest, .smartIngest,
            .importPDF, .importPDFFailed, .deletePDF, .highlight,
            .lint, .healthCheck, .systemInit, .sync
        ]
        for action in standardCases {
            XCTAssertTrue(
                action.rawValue.hasPrefix("logAction."),
                "case \(action) 的 rawValue '\(action.rawValue)' 应以 'logAction.' 前缀开头"
            )
        }
    }

    /// aiscanFailed/aiscanSkipped 前缀已统一为 "logAction.aiscan."（finding #1 已修复）
    func testRawValue_aiscan前缀_已统一() {
        XCTAssertTrue(LogAction.aiscanFailed.rawValue.hasPrefix("logAction.aiscan."))
        XCTAssertTrue(LogAction.aiscanSkipped.rawValue.hasPrefix("logAction.aiscan."))
    }

    /// export 前缀已统一为 "logAction.export"（finding #1 已修复）
    func testRawValue_export前缀_已统一() {
        XCTAssertEqual(LogAction.export.rawValue, "logAction.export")
    }

    /// error/unknown 已统一为 logAction.* 前缀（finding #1 已修复）
    func testRawValue_error和unknown_已统一前缀() {
        XCTAssertEqual(LogAction.error.rawValue, "logAction.error")
        XCTAssertEqual(LogAction.unknown.rawValue, "logAction.unknown")
    }

    // MARK: - rawValue 唯一性

    /// 所有 case 的 rawValue 应唯一（无重复）
    func testRawValue_唯一性_无重复() {
        let allCases = LogAction.allCases
        let rawValues = allCases.map(\.rawValue)
        let uniqueRawValues = Set(rawValues)
        XCTAssertEqual(rawValues.count, uniqueRawValues.count, "所有 rawValue 应唯一")
        XCTAssertEqual(allCases.count, 18, "应有 18 个 case（CaseIterable）")
    }

    // MARK: - 可逆性（rawValue → LogAction）

    /// rawValue 应能反向构造 LogAction（RawRepresentable 契约）
    func testRawValue_可逆性_rawValue转LogAction() {
        for action in LogAction.allCases {
            let reconstructed = LogAction(rawValue: action.rawValue)
            XCTAssertEqual(reconstructed, action, "rawValue '\(action.rawValue)' 应能反向构造 \(action)")
        }
    }

    // MARK: - 未知 rawValue

    /// 未知 rawValue 应返回 nil
    func testRawValue_未知rawValue_返回nil() {
        XCTAssertNil(LogAction(rawValue: "unknown.action"))
        XCTAssertNil(LogAction(rawValue: ""))
    }

    // MARK: - rawValue 非空

    /// 所有 case 的 rawValue 应非空
    func testRawValue_非空() {
        for action in LogAction.allCases {
            XCTAssertFalse(action.rawValue.isEmpty, "case \(action) 的 rawValue 不应为空")
        }
    }

    // MARK: - localizedName 非空

    /// localizedName 应返回非空字符串
    func testLocalizedName_非空() {
        for action in LogAction.allCases {
            XCTAssertFalse(action.localizedName.isEmpty, "case \(action) 的 localizedName 不应为空")
        }
    }

    // MARK: - colorName 非空

    /// colorName 应返回非空字符串
    func testColorName_非空() {
        for action in LogAction.allCases {
            XCTAssertFalse(action.colorName.isEmpty, "case \(action) 的 colorName 不应为空")
        }
    }

    // MARK: - icon 非空

    /// icon 应返回非空字符串
    func testIcon_非空() {
        for action in LogAction.allCases {
            XCTAssertFalse(action.icon.isEmpty, "case \(action) 的 icon 不应为空")
        }
    }

    // MARK: - CaseIterable 一致性

    /// CaseIterable 应包含所有 case
    func testAllCases_包含所有case() {
        let allCases = LogAction.allCases
        XCTAssertEqual(allCases.count, 18)
        XCTAssertTrue(allCases.contains(.create))
        XCTAssertTrue(allCases.contains(.aiscanFailed))
        XCTAssertTrue(allCases.contains(.error))
        XCTAssertTrue(allCases.contains(.unknown))
    }
}
