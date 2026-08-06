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

    // MARK: - 已知限制记录（P1 finding #5）

    /// 已知限制：iOS 模拟器下 isJailbroken() 误报 true（finding #5）
    ///
    /// 原因：checkCommonJailbreakFiles() 检测 /bin/bash、/usr/sbin/sshd、/usr/bin/ssh，
    /// 这些路径在 macOS 自带存在，而 iOS 模拟器运行在 macOS 上，导致误报。
    /// 真实 iOS 设备上这些路径不存在，检测正常。
    ///
    /// 此测试文档化此限制，不断言 false（因模拟器下实际返回 true）。
    /// 待修复后改为 XCTAssertFalse。
    func testKnownLimitation_模拟器误报越狱() {
        let detector = JailbreakDetector.shared
        let result = detector.isJailbroken()
        #if targetEnvironment(simulator)
        // 模拟器下因 finding #5 误报 true，记录此已知行为
        XCTAssertTrue(result, "模拟器下因 P1 finding #5 误报 true（macOS 自带路径）")
        #else
        // 真机非越狱环境应返回 false
        XCTAssertFalse(result, "真机非越狱环境应返回 false")
        #endif
    }
}
