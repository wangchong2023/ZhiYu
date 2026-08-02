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
        XCTAssertEqual(StorageConstants.walCheckpointThreshold, 1000)
        XCTAssertEqual(StorageConstants.connectionTimeout, 30)
        XCTAssertEqual(StorageConstants.defaultPageSize, 4096)
        XCTAssertEqual(StorageConstants.defaultBatchInsertLimit, 500)
        XCTAssertEqual(StorageConstants.defaultPageLimit, 20)
    }
}
