//
//  PlatformContextTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证平台上下文值类型的初始化、相等性比较与设备家族枚举完整性。
//

import XCTest
@testable import ZhiYu

final class PlatformContextTests: XCTestCase {

    // MARK: - PlatformDeviceFamily 枚举完整性

    func testPlatformDeviceFamily_allCases包含4个case() {
        XCTAssertEqual(PlatformDeviceFamily.allCases.count, 4)
        XCTAssertTrue(PlatformDeviceFamily.allCases.contains(.phone))
        XCTAssertTrue(PlatformDeviceFamily.allCases.contains(.pad))
        XCTAssertTrue(PlatformDeviceFamily.allCases.contains(.mac))
        XCTAssertTrue(PlatformDeviceFamily.allCases.contains(.watch))
    }

    func testPlatformDeviceFamily_rawValue正确() {
        XCTAssertEqual(PlatformDeviceFamily.phone.rawValue, "phone")
        XCTAssertEqual(PlatformDeviceFamily.pad.rawValue, "pad")
        XCTAssertEqual(PlatformDeviceFamily.mac.rawValue, "mac")
        XCTAssertEqual(PlatformDeviceFamily.watch.rawValue, "watch")
    }

    func testPlatformDeviceFamily_Codable往返() throws {
        for family in PlatformDeviceFamily.allCases {
            let encoded = try JSONEncoder().encode(family)
            let decoded = try JSONDecoder().decode(PlatformDeviceFamily.self, from: encoded)
            XCTAssertEqual(decoded, family, "Codable 往返应保持一致")
        }
    }

    func testPlatformDeviceFamily_无效rawValue返回nil() {
        XCTAssertNil(PlatformDeviceFamily(rawValue: "tv"))
        XCTAssertNil(PlatformDeviceFamily(rawValue: ""))
        XCTAssertNil(PlatformDeviceFamily(rawValue: "Phone"))
    }

    // MARK: - PlatformContext 初始化

    func testInit_默认screenClass为Regular() {
        let context = PlatformContext(deviceFamily: .phone, isTouchOptimized: true)
        XCTAssertEqual(context.deviceFamily, .phone)
        XCTAssertTrue(context.isTouchOptimized)
        XCTAssertEqual(context.screenClass, .regular)
    }

    func testInit_显式指定screenClass() {
        let context = PlatformContext(deviceFamily: .mac, isTouchOptimized: false, screenClass: .expansive)
        XCTAssertEqual(context.screenClass, .expansive)
    }

    func testInit_所有设备家族组合() {
        let phone = PlatformContext(deviceFamily: .phone, isTouchOptimized: true, screenClass: .compact)
        let pad = PlatformContext(deviceFamily: .pad, isTouchOptimized: true, screenClass: .regular)
        let mac = PlatformContext(deviceFamily: .mac, isTouchOptimized: false, screenClass: .expansive)
        let watch = PlatformContext(deviceFamily: .watch, isTouchOptimized: true, screenClass: .compact)

        XCTAssertEqual(phone.deviceFamily, .phone)
        XCTAssertEqual(pad.deviceFamily, .pad)
        XCTAssertEqual(mac.deviceFamily, .mac)
        XCTAssertEqual(watch.deviceFamily, .watch)
    }

    // MARK: - Equatable 相等性

    func testEquatable_相同参数相等() {
        let context1 = PlatformContext(deviceFamily: .phone, isTouchOptimized: true, screenClass: .compact)
        let context2 = PlatformContext(deviceFamily: .phone, isTouchOptimized: true, screenClass: .compact)
        XCTAssertEqual(context1, context2)
    }

    func testEquatable_不同deviceFamily不相等() {
        let context1 = PlatformContext(deviceFamily: .phone, isTouchOptimized: true)
        let context2 = PlatformContext(deviceFamily: .pad, isTouchOptimized: true)
        XCTAssertNotEqual(context1, context2)
    }

    func testEquatable_不同isTouchOptimized不相等() {
        let context1 = PlatformContext(deviceFamily: .pad, isTouchOptimized: true)
        let context2 = PlatformContext(deviceFamily: .pad, isTouchOptimized: false)
        XCTAssertNotEqual(context1, context2)
    }

    func testEquatable_不同screenClass不相等() {
        let context1 = PlatformContext(deviceFamily: .pad, isTouchOptimized: true, screenClass: .regular)
        let context2 = PlatformContext(deviceFamily: .pad, isTouchOptimized: true, screenClass: .expansive)
        XCTAssertNotEqual(context1, context2)
    }

    // MARK: - Sendable 合规

    func testSendable_可作为Sendable传递() {
        let context: Sendable = PlatformContext(deviceFamily: .phone, isTouchOptimized: true)
        XCTAssertNotNil(context)
    }

    // MARK: - current 静态属性

    func testCurrent_返回非空上下文() {
        let current = PlatformContext.current
        XCTAssertNotNil(current.deviceFamily)
    }

    func testCurrent_设备家族在allCases中() {
        let current = PlatformContext.current
        XCTAssertTrue(PlatformDeviceFamily.allCases.contains(current.deviceFamily),
                      "current.deviceFamily 应在 allCases 中")
    }
}
