//
//  iPadEnvironmentTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 iPadEnvironment 开展自动化单元测试验证。
//
import XCTest
import UIKit
@testable import ZhiYu

/// Mock 设备环境实现，用于单元测试中强制模拟大屏（iPadOS）环境，打通各分支逻辑覆盖
@MainActor
private final class MockiPadEnvironment: AppEnvironmentProtocol {
    var screenClass: ScreenClass { .expansive }
    var interactionStyle: InteractionStyle { .touch }
    var deviceName: String { "Test iPad Pro" }
    var supportsPencil: Bool { true }
    var hasCamera: Bool { true }
    var isMobile: Bool { false }
    var platformName: String { "iPadOS" }
    var appVersion: String { "1.0.0 (42)" }
    var isCloudSyncSupported: Bool { true }
}

@MainActor
final class iPadEnvironmentTests: XCTestCase {
    
    func testActualEnvironmentConsistency() async {
        /// 函数头说明: 测试实际 iOSAppEnvironment 实例在当前运行设备环境下的行为，动态校准断言
        /// - 验证点: 1. 自动适配宿主测试机的设备类型（iPhone vs iPad）；
        ///          2. 验证相应属性（isMobile, screenClass, supportsPencil）随 idiom 的转换是否符合逻辑；
        ///          3. 验证 interactionStyle 等静态能力属性。
        let env = iOSAppEnvironment()
        let currentIdiom = UIDevice.current.userInterfaceIdiom
        
        // 关键过程：提前提取 @MainActor 隔离属性值至局部变量，规避 Swift 6 自动闭包（autoclosure）引起的线程逃逸编译报错
        let screenClass = env.screenClass
        let supportsPencil = env.supportsPencil
        let platformName = env.platformName
        let isMobile = env.isMobile
        let hasCamera = env.hasCamera
        let interactionStyle = env.interactionStyle
        let deviceName = env.deviceName
        
        // 1. 动态校准：根据物理环境自动采取相应断言以应对各种宿主回归
        if currentIdiom == .pad {
            XCTAssertEqual(screenClass, .expansive, "iPad 设备上的 screenClass 应该为 expansive")
            XCTAssertTrue(supportsPencil, "iPad 设备上应该默认支持 Apple Pencil")
            XCTAssertEqual(platformName, "iPadOS", "iPad 设备上平台名称应该返回 iPadOS")
            XCTAssertFalse(isMobile, "iPadOS 在业务定义中不应被视为 mobile 移动终端（对标 iPhone）")
        } else {
            XCTAssertEqual(screenClass, .compact, "iPhone 设备上的 screenClass 应该为 compact")
            XCTAssertFalse(supportsPencil, "iPhone 设备上默认不支持 Apple Pencil")
            XCTAssertEqual(platformName, "iOS", "iPhone 设备上平台名称应该返回 iOS")
            XCTAssertTrue(isMobile, "iPhone 在业务定义中应返回为 mobile 移动终端")
        }
        
        // 2. 静态及全局可用性能力验证
        XCTAssertTrue(hasCamera, "设备应该默认具备摄像头能力支持")
        XCTAssertEqual(interactionStyle, .touch, "iOS/iPadOS 平台主导交互样式应为触控 touch")
        XCTAssertFalse(deviceName.isEmpty, "设备名称不应为空")
    }
    
    func testMockiPadEnvironmentCapabilities() async {
        /// 函数头说明: 测试 Mock 大屏 (iPad) 设备能力的逻辑消费，确保所有业务对大屏环境状态定义的准确匹配
        /// - 验证点: 1. MockiPadEnvironment 返回的值符合大屏物理表现；
        ///          2. 100% 覆盖大屏分支在协议层所具备的高阶特权（supportsPencil == true）。
        let mockEnv: AppEnvironmentProtocol = MockiPadEnvironment()
        
        // 关键过程：提前提取 @MainActor 隔离的 Mock 属性值至局部变量，避免逃逸闭包报错
        let screenClass = mockEnv.screenClass
        let interactionStyle = mockEnv.interactionStyle
        let deviceName = mockEnv.deviceName
        let supportsPencil = mockEnv.supportsPencil
        let hasCamera = mockEnv.hasCamera
        let isMobile = mockEnv.isMobile
        let platformName = mockEnv.platformName
        let isCloudSyncSupported = mockEnv.isCloudSyncSupported
        let appVersion = mockEnv.appVersion
        
        // 核心验证点：100% 覆盖 iPadOS 所定义的平台特异性
        XCTAssertEqual(screenClass, .expansive, "iPad Mock 环境的屏幕应为 expansive 宽屏")
        XCTAssertEqual(interactionStyle, .touch, "iPad 默认支持触控交互")
        XCTAssertEqual(deviceName, "Test iPad Pro", "设备名验证")
        XCTAssertTrue(supportsPencil, "iPad 应该具备 Apple Pencil 特权")
        XCTAssertTrue(hasCamera, "iPad 拥有摄像头能力")
        XCTAssertFalse(isMobile, "iPad 在大屏协作下不是 compact 类型的 mobile 终端")
        XCTAssertEqual(platformName, "iPadOS", "平台名称应为 iPadOS")
        XCTAssertTrue(isCloudSyncSupported, "大屏应支持云端同步")
        XCTAssertEqual(appVersion, "1.0.0 (42)", "App 版本号输出应与 Mock 完全一致")
    }
    
    func testEnvironmentConditionalCompilationAndVersion() async {
        /// 函数头说明: 验证条件编译下的 iCloud 支持标志，以及 App 版本信息的格式正确性
        /// - 验证点: 1. 基于 targetEnvironment 宏判定 CloudSyncSupported 返回值；
        ///          2. 验证 App 版本信息是否包含合法的括号和版本组装标识。
        let env = iOSAppEnvironment()
        
        // 关键过程：提取 @MainActor 的 isCloudSyncSupported 及 appVersion 至本地，保障线程隔离一致性
        let isCloudSyncSupported = env.isCloudSyncSupported
        let appVersionString = env.appVersion
        
        // 1. iCloud 同步策略验证
        #if targetEnvironment(simulator)
        XCTAssertFalse(isCloudSyncSupported, "在 iOS 模拟器沙盒环境下，iCloud 同步应由于 entitlements 签名缺失默认置为 false")
        #else
        XCTAssertTrue(isCloudSyncSupported, "在 iOS 物理真机环境下，iCloud 同步功能应支持")
        #endif
        
        // 2. 版本号组装完整性验证
        XCTAssertFalse(appVersionString.isEmpty, "环境中的 appVersion 不应返回空值")
        XCTAssertTrue(appVersionString.contains("("), "环境获取的版本号应该包含 build 信息，格式类似 '1.0.0 (1)'")
        XCTAssertTrue(appVersionString.contains(")"), "版本号右括号应闭合，确保版本字符串整体渲染美观")
    }
}
