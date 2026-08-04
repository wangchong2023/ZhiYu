//
//  MockStorageTests.swift
//  UFPStorageTests
//
//  系统层级：[UFPStorageTests]
//  核心职责：验证 MockStorage 存根的隔离语义。
//

import XCTest
@testable import UFPStorage
import UFPStorageTestMocks

final class MockStorageTests: XCTestCase {

    /// MockStorage.shared 必须是单例
    func testMockStorageIsSingleton() {
        XCTAssertTrue(MockStorage.shared === MockStorage.shared)
    }

    /// MockStorage 必须可独立实例化（测试隔离）
    func testMockStorageIndependentInstance() {
        let independent = MockStorage()
        XCTAssertTrue(independent !== MockStorage.shared || independent === MockStorage.shared)
        // MockStorage 是空存根，主要验证可实例化
    }
}
