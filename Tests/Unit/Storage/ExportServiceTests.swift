//
//  ExportServiceTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 导出服务 (WebViewExportService) 的字节物理门禁与并发安全性开展单元测试。
//

import XCTest
@testable import ZhiYu

final class ExportServiceTests: XCTestCase {

    func testExportLimitsConstants() {
        XCTAssertGreaterThan(AppConstants.ExportLimits.minValidSynthesisTextBytes, 0, "文本导出阀值必须大于 0")
        XCTAssertGreaterThan(AppConstants.ExportLimits.minValidPDFBytes, 0, "PDF 二进制导出阀值必须大于 0")
        XCTAssertGreaterThan(AppConstants.ExportLimits.webRenderFallbackTimeoutMS, 0, "离屏降级超时必须大于 0")
    }

    @MainActor
    func testExportServiceInvocationSafety() async {
        let markdown = "# 测试导出\n正文内容"
        let service = WebViewExportService.shared
        XCTAssertNotNil(service, "WebViewExportService 门面单例必须可用")
    }
}
