//
//  AppToastTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 Toast 类型枚举映射、Toast 数据模型与 ToastManager 状态机生命周期。
//

import XCTest
@testable import ZhiYu

final class AppToastTypeTests: XCTestCase {

    // MARK: - AppToastType 枚举映射

    func testIcon_所有case返回非空字符串() {
        for toastType in [AppToastType.success, .error, .info, .processing] {
            XCTAssertFalse(toastType.icon.isEmpty, "icon 不应为空")
        }
    }

    func testIcon_各case返回不同值() {
        let icons = [AppToastType.success, .error, .info, .processing].map { $0.icon }
        XCTAssertEqual(icons.count, Set(icons).count, "各 case 的 icon 应唯一")
    }

    func testColor_各case返回不同Color() {
        // success 和 info/processing 都用 appAccent，但 success=green, error=red
        XCTAssertEqual(AppToastType.success.color, .green)
        XCTAssertEqual(AppToastType.error.color, .red)
        // info 和 processing 都返回 .appAccent，颜色相同
        XCTAssertEqual(AppToastType.info.color, AppToastType.processing.color)
    }

    func testEquatable_相同类型相等() {
        XCTAssertEqual(AppToastType.success, AppToastType.success)
        XCTAssertEqual(AppToastType.error, AppToastType.error)
        XCTAssertNotEqual(AppToastType.success, AppToastType.error)
    }
}

final class AppToastModelTests: XCTestCase {

    // MARK: - AppToast 数据模型

    func testInit_默认duration为3秒() {
        let toast = AppToast(type: .success, message: "测试")
        XCTAssertEqual(toast.duration, 3.0, "默认 duration 应为 3.0 秒")
    }

    func testInit_自定义duration() {
        let toast = AppToast(type: .info, message: "测试", duration: 5.0)
        XCTAssertEqual(toast.duration, 5.0)
    }

    func testInit_duration为零() {
        let toast = AppToast(type: .processing, message: "处理中", duration: 0)
        XCTAssertEqual(toast.duration, 0)
    }

    func testInit_负duration() {
        let toast = AppToast(type: .error, message: "错误", duration: -1)
        XCTAssertEqual(toast.duration, -1, "负 duration 应原样保留（由 show 决定行为）")
    }

    func testId_每次创建唯一() {
        let toast1 = AppToast(type: .success, message: "1")
        let toast2 = AppToast(type: .success, message: "2")
        XCTAssertNotEqual(toast1.id, toast2.id, "每次创建的 Toast id 应唯一")
    }

    func testEquatable_相同id相等() {
        let toast = AppToast(type: .success, message: "测试")
        XCTAssertEqual(toast, toast)
    }

    func testEquatable_不同id不相等() {
        let toast1 = AppToast(type: .success, message: "1")
        let toast2 = AppToast(type: .success, message: "2")
        XCTAssertNotEqual(toast1, toast2)
    }
}

@MainActor
final class ToastManagerTests: XCTestCase {

    private var manager: ToastManager!

    override func setUp() async throws {
        try await super.setUp()
        manager = ToastManager()
    }

    override func tearDown() async throws {
        manager.dismiss()
        manager = nil
        try await super.tearDown()
    }

    // MARK: - 初始状态

    func testInitial_currentToast为nil() {
        XCTAssertNil(manager.currentToast)
    }

    // MARK: - show 状态机

    func testShow_设置currentToast() {
        manager.show(type: .success, message: "成功")
        XCTAssertNotNil(manager.currentToast)
        XCTAssertEqual(manager.currentToast?.type, .success)
        XCTAssertEqual(manager.currentToast?.message, "成功")
    }

    func testShow_覆盖之前的Toast() {
        manager.show(type: .info, message: "第一条")
        manager.show(type: .error, message: "第二条")
        XCTAssertEqual(manager.currentToast?.type, .error)
        XCTAssertEqual(manager.currentToast?.message, "第二条")
    }

    func testShow_自定义duration() {
        manager.show(type: .processing, message: "处理中", duration: 5.0)
        XCTAssertEqual(manager.currentToast?.duration, 5.0)
    }

    func testShow_duration为零不自动消失() {
        manager.show(type: .processing, message: "持续处理", duration: 0)
        XCTAssertNotNil(manager.currentToast, "duration=0 应不设置自动消失计时器")
    }

    // MARK: - dismiss 状态机

    func testDismiss_清空currentToast() {
        manager.show(type: .success, message: "测试")
        XCTAssertNotNil(manager.currentToast)
        manager.dismiss()
        XCTAssertNil(manager.currentToast)
    }

    func testDismiss_无Toast时调用不崩溃() {
        XCTAssertNil(manager.currentToast)
        manager.dismiss()
        XCTAssertNil(manager.currentToast)
    }

    // MARK: - 所有 ToastType 都能 show

    func testShow_success类型() {
        manager.show(type: .success, message: "成功")
        XCTAssertEqual(manager.currentToast?.type, .success)
    }

    func testShow_error类型() {
        manager.show(type: .error, message: "错误")
        XCTAssertEqual(manager.currentToast?.type, .error)
    }

    func testShow_info类型() {
        manager.show(type: .info, message: "信息")
        XCTAssertEqual(manager.currentToast?.type, .info)
    }

    func testShow_processing类型() {
        manager.show(type: .processing, message: "处理中")
        XCTAssertEqual(manager.currentToast?.type, .processing)
    }
}
