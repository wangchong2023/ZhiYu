//
//  IngestCoordinatorImportTests.swift
//  ZhiYuTests
//
//  系统层级：[L2] 业务功能测试 - Knowledge
//  核心职责：验证 IngestCoordinator 在超限图片导入失败或提前返回时 isIngesting 状态的安全重置。
//

import XCTest
import UFPCore
@testable import ZhiYu

#if !os(watchOS)
@MainActor
final class IngestCoordinatorImportTests: XCTestCase {

    /// 验证 OCR 图片超限时 prepareImportFiles 返回 nil 并确保 isIngesting 重置为 false
    func testPrepareImportFiles_oversizedOCRImage_resetsIsIngesting() {
        let coordinator = IngestCoordinator()
        coordinator.isIngesting = true
        coordinator.sourceHint = .ocr
        coordinator.newTitle = "ImportTest"
        coordinator.newContent = "TestContent"

        let maxBytes = Int(AppConstants.Keys.ImportLimits.maxOCRImageSizeBytes)
        let oversized = Data(repeating: 0xFF, count: maxBytes + 1)
        coordinator.pendingImageData = oversized

        let result = coordinator.prepareImportFiles(recordID: "oversized-test")

        XCTAssertNil(result, "OCR 超限应返回 nil")
        XCTAssertFalse(coordinator.isIngesting, "prepareImportFiles 返回 nil 后 isIngesting 应重置为 false")
    }
}
#endif
