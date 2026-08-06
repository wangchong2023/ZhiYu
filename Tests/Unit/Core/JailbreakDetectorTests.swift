//
//  JailbreakDetectorTests.swift
//  ZhiYu
//
//  系统层级：[L0] 测试层
//  核心职责：验证 JailbreakDetector 单例一致性、多次调用稳定性，并文档化模拟器误报限制。
//

import XCTest
@testable import ZhiYu

@MainActor
final class JailbreakDetectorTests: XCTestCase {

    // MARK: - 单例一致性

    /// shared 应返回同一实例
    func testShared_多次访问_同一实例() {
        let a = JailbreakDetector.shared
        let b = JailbreakDetector.shared
        XCTAssertTrue(a === b)
    }

    /// 独立实例应与 shared 不同（init 已改为 internal，见 finding #4）
    func testInit_独立实例_与shared不同() {
        let independent = JailbreakDetector()
        let shared = JailbreakDetector.shared
        XCTAssertFalse(independent === shared)
    }

    // MARK: - 多次调用稳定性

    /// 多次调用 isJailbroken() 应返回一致结果
    func testIsJailbroken_多次调用_结果一致() {
        let detector = JailbreakDetector.shared
        let first = detector.isJailbroken()
        for _ in 0..<10 {
            XCTAssertEqual(detector.isJailbroken(), first, "多次调用应返回一致结果")
        }
    }

    // MARK: - 非越狱环境（finding #5 已修复：移除 macOS 自带路径）

    /// 测试环境（模拟器/CI）应检测为非越狱（finding #5 修复后）
    func testIsJailbroken_非越狱环境_返回false() {
        let detector = JailbreakDetector.shared
        XCTAssertFalse(
            detector.isJailbroken(),
            "测试环境（模拟器）应检测为非越狱（finding #5 已修复）"
        )
    }

    /// 独立实例也应检测为非越狱
    func testIsJailbroken_独立实例_返回false() {
        let detector = JailbreakDetector()
        XCTAssertFalse(detector.isJailbroken())
    }
}
