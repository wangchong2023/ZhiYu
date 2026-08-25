//
//  IOSDeviceInfoServiceTests.swift
//  ZhiYu
//
//  Created by CodeFree on 2026/08/24.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：iOSDeviceInfoService 单元测试，覆盖设备版本、型号、名称、屏幕高度获取场景。
//

#if os(iOS) && !os(watchOS)
import UIKit
import XCTest
@testable import ZhiYu

@MainActor
final class IOSDeviceInfoServiceTests: XCTestCase {

    // MARK: - 测试常量

    private enum TestConstants {
        static let minSystemVersionLength: Int = 2
        static let minScreenHeight: CGFloat = 100
    }

    // MARK: - systemVersion

    /// systemVersion 应返回非空字符串（如 "17.0"）
    func testSystemVersionReturnsNonEmptyString() {
        let service = iOSDeviceInfoService()
        let version = service.systemVersion
        XCTAssertFalse(version.isEmpty, "系统版本不应为空")
        XCTAssertGreaterThanOrEqual(version.count, TestConstants.minSystemVersionLength,
                                    "系统版本至少包含主.次版本号")
    }

    // MARK: - deviceModel

    /// deviceModel 应返回非空字符串（如 "iPhone"）
    func testDeviceModelReturnsNonEmptyString() {
        let service = iOSDeviceInfoService()
        let model = service.deviceModel
        XCTAssertFalse(model.isEmpty, "设备型号不应为空")
    }

    // MARK: - deviceName

    /// deviceName 应返回字符串（模拟器可能为 "Simulator" 或自定义名）
    func testDeviceNameReturnsStringValue() {
        let service = iOSDeviceInfoService()
        let name = service.deviceName
        XCTAssertFalse(name.isEmpty, "设备名称不应为空")
    }

    // MARK: - screenHeight

    /// screenHeight 应返回大于最小阈值的正值
    func testScreenHeightReturnsPositiveValue() {
        let service = iOSDeviceInfoService()
        let height = service.screenHeight
        XCTAssertGreaterThan(height, TestConstants.minScreenHeight,
                             "屏幕高度应大于最小阈值")
    }

    // MARK: - 协议一致性

    /// 服务实例应可向上转型为 DeviceInfoProtocol
    func testConformsToDeviceInfoProtocol() {
        let service: any DeviceInfoProtocol = iOSDeviceInfoService()
        XCTAssertFalse(service.systemVersion.isEmpty)
        XCTAssertFalse(service.deviceModel.isEmpty)
        XCTAssertGreaterThan(service.screenHeight, 0, "屏幕高度应大于 0")
    }

    /// 多次读取 systemVersion 应返回稳定一致的值
    func testSystemVersionIsStableAcrossReads() {
        let service = iOSDeviceInfoService()
        let first = service.systemVersion
        let second = service.systemVersion
        XCTAssertEqual(first, second, "多次读取系统版本应一致")
    }
}
#endif
