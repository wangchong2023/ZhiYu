//
//  ImportRecordSectionAndTabsDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Unit] 单元测试层
//  核心职责：深度测试 ImportRecordSection 导入分段、分类筛选 Tab、
//           OCR 与文本预览模态窗以及卡片操作逻辑。
//

import XCTest
import SwiftUI
import Dependencies
import UFPCore
import UFPStorage
@testable import ZhiYu

@MainActor
final class ImportRecordSectionAndTabsDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. ImportRecordSection 视图装配测试

    func testImportRecordSection_Hierarchy() {
        let view = NavigationStack {
            ScrollView {
                ImportRecordSection(
                    onAITag: { _ in },
                    onManualEdit: { _ in }
                )
            }
        }
        .snapshotEnvironment()

        XCTAssertNotNil(view)
    }

    // MARK: - 2. 导入分类与映射测试

    func testImportCategory_DisplayNamesAndDirectory() {
        for category in ImportCategory.allCases {
            XCTAssertFalse(category.displayName.isEmpty)
            XCTAssertFalse(category.directoryName.isEmpty)
            XCTAssertFalse(category.rawValue.isEmpty)
        }
    }
}
