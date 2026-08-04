//
//  DesignSystemBundleTests.swift
//  UFPDesignSystemTests
//
//  系统层级：[UFPDesignSystemTests]
//  核心职责：验证 Bundle.module 资源包的完整性与可访问性。
//

import XCTest
@testable import UFPDesignSystem

final class DesignSystemBundleTests: XCTestCase {

    /// Bundle.module 必须非 nil（SPM 资源处理正确）
    func testBundleModuleExists() {
        XCTAssertNotNil(Bundle.module, "Bundle.module 必须成功装载资源包")
    }

    /// Bundle.module 必须有有效的 bundlePath
    func testBundleModuleHasPath() {
        XCTAssertFalse(Bundle.module.bundlePath.isEmpty,
                       "Bundle.module 必须有有效的 bundlePath")
    }

    /// Bundle.module 路径必须存在
    func testBundleModulePathExists() {
        let path = Bundle.module.bundlePath
        XCTAssertTrue(FileManager.default.fileExists(atPath: path),
                      "Bundle.module 路径必须实际存在")
    }
}
