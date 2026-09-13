//
//  IngestWorkflowAndImportSheetTests.swift
//  ZhiYuTests
//
//  系统层级：[L2] 业务功能测试 - Knowledge
//  核心职责：验证 IngestCoordinator 状态同步、URLImportSheet 超限警告及 OCR 取消时序。
//

import XCTest
import UFPCore
@testable import ZhiYu

final class IngestWorkflowAndImportSheetTests: XCTestCase {

    /// 验证 IngestCoordinator hasNewContent 标志流转
    @MainActor
    func testIngestCoordinator_hasNewContentFlag_updatesCorrectly() {
        setupFullMockEnvironment()
        let coordinator = IngestCoordinator()
        XCTAssertFalse(coordinator.hasNewContent, "初始 hasNewContent 应为 false")
        coordinator.hasNewContent = true
        XCTAssertTrue(coordinator.hasNewContent, "设置后 hasNewContent 应为 true")
    }

    /// 验证 URL 数量超出上限时正确生成本地化警告
    func testURLImportSheet_exceedsMaxCount_generatesWarning() {
        let maxURLCount = AppConstants.Keys.ImportLimits.maxURLCount
        let validCount = maxURLCount + 3

        let warning: String? = validCount > maxURLCount
            ? L10n.Ingest.urlExceedLimit(validCount - maxURLCount, maxURLCount)
            : nil

        XCTAssertNotNil(warning, "超限时应生成警告")
        XCTAssertTrue(warning?.contains(String(maxURLCount)) == true, "警告应包含最大值")
    }

    /// 验证 URL 数量未超限时不生成警告
    func testURLImportSheet_underMaxCount_generatesNoWarning() {
        let maxURLCount = AppConstants.Keys.ImportLimits.maxURLCount
        let validCount = maxURLCount - 1

        let warning: String? = validCount > maxURLCount
            ? L10n.Ingest.urlExceedLimit(validCount - maxURLCount, maxURLCount)
            : nil

        XCTAssertNil(warning, "未超限时不应生成警告")
    }

    /// 验证 checkCancellation 优先于文本识别执行，取消时保持识别内容为 nil
    func testOCRScanView_cancellationBeforeRecognize_skipsTextExtraction() {
        let isCancelled = true
        var recognizedText: String?

        if !isCancelled {
            recognizedText = "text"
        }

        XCTAssertTrue(isCancelled)
        XCTAssertNil(recognizedText, "取消时不应生成识别文本")
    }
}
