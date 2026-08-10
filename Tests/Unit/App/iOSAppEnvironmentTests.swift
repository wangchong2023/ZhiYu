//
//  iOSAppEnvironmentTests.swift
//  ZhiYu
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 iOSAppEnvironment 平台适配实现开展自动化单元测试验证。
//

#if os(iOS)
import XCTest
@testable import ZhiYu

@MainActor
final class iOSAppEnvironmentTests: XCTestCase {

    private var env: iOSAppEnvironment!

    override func setUp() async throws {
        try await super.setUp()
        env = iOSAppEnvironment()
    }

    override func tearDown() async throws {
        env = nil
        try await super.tearDown()
    }

    /// 验证 screenClass 在 iPad 上返回 .expansive，其他设备返回 .compact
    func testScreenClass_ReturnsCorrectClass() {
        let screenClass = env.screenClass
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCTAssertEqual(screenClass, .expansive, "iPad 设备应返回 .expansive")
        } else {
            XCTAssertEqual(screenClass, .compact, "非 iPad 设备应返回 .compact")
        }
    }

    /// 验证 interactionStyle 始终返回 .touch
    func testInteractionStyle_AlwaysTouch() {
        XCTAssertEqual(env.interactionStyle, .touch, "iOS 平台主导交互方式应为 .touch")
    }

    /// 验证 deviceName 返回非空字符串
    func testDeviceName_ReturnsNonEmptyString() {
        let name = env.deviceName
        XCTAssertFalse(name.isEmpty, "设备名称不应为空")
    }

    /// 验证 supportsPencil 在 iPad 上返回 true，其他设备返回 false
    func testSupportsPencil_ReflectsDeviceIdiom() {
        let supports = env.supportsPencil
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCTAssertTrue(supports, "iPad 应支持 Apple Pencil")
        } else {
            XCTAssertFalse(supports, "非 iPad 设备不应支持 Apple Pencil")
        }
    }

    /// 验证 hasCamera 始终返回 true
    func testHasCamera_AlwaysTrue() {
        XCTAssertTrue(env.hasCamera, "iOS 设备默认应具备摄像头能力")
    }

    /// 验证 isMobile 在 iPhone 上返回 true，其他设备返回 false
    func testIsMobile_ReflectsDeviceIdiom() {
        let isMobile = env.isMobile
        if UIDevice.current.userInterfaceIdiom == .phone {
            XCTAssertTrue(isMobile, "iPhone 应为移动设备")
        } else {
            XCTAssertFalse(isMobile, "非 iPhone 设备不应为移动设备")
        }
    }

    /// 验证 platformName 在 iPad 上返回 "iPadOS"，其他设备返回 "iOS"
    func testPlatformName_ReturnsCorrectName() {
        let name = env.platformName
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCTAssertEqual(name, "iPadOS", "iPad 设备平台名应为 iPadOS")
        } else {
            XCTAssertEqual(name, "iOS", "非 iPad 设备平台名应为 iOS")
        }
    }

    /// 验证 appVersion 返回非空字符串且包含版本号格式
    func testAppVersion_ReturnsNonEmptyString() {
        let version = env.appVersion
        XCTAssertFalse(version.isEmpty, "应用版本号不应为空")
        XCTAssertTrue(version.contains("("), "版本号应包含构建号括号格式")
        XCTAssertTrue(version.contains(")"), "版本号应包含构建号闭合括号")
    }

    /// 验证 isCloudSyncSupported 在模拟器返回 false
    func testIsCloudSyncSupported_SimulatorReturnsFalse() {
        let supported = env.isCloudSyncSupported
        #if targetEnvironment(simulator)
        XCTAssertFalse(supported, "模拟器环境不应支持 iCloud 同步")
        #else
        XCTAssertTrue(supported, "真机环境应支持 iCloud 同步")
        #endif
    }
}
#endif
