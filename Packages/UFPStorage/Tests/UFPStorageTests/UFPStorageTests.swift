//
//  UFPStorageTests.swift
//  UFPStorageTests
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[UFPStorageTests]
//  核心职责：UFPStorage 通用存储包单元测试套件。
//

import XCTest
@testable import UFPStorage

final class UFPStorageTests: XCTestCase {

    func testStorageConstantsIntegrity() {
        XCTAssertEqual(StorageConstants.databaseFileName, "ZhiYu.sqlite")
        XCTAssertEqual(StorageConstants.Tables.pages, "knowledge_pages")
        XCTAssertEqual(StorageConstants.Limits.maxBatchInsertSize, 500)
    }
}
