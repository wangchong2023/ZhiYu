//
//  IOSReminderServiceTests.swift
//  ZhiYu
//
//  Created by CodeFree on 2026/08/24.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：iOSReminderService 单元测试，覆盖权限请求、提醒创建与异常路径场景。
//
//  D-32 修复：使用闭包注入模式，避免模拟器触发真实 EventKit 权限弹窗。
//

#if !os(watchOS)
import XCTest
import EventKit
@testable import ZhiYu

@MainActor
final class IOSReminderServiceTests: XCTestCase {

    // MARK: - 测试常量

    private enum TestConstants {
        static let reminderTitle: String = "智宇测试提醒"
        static let reminderNotes: String = "单元测试自动创建的提醒事项"
        static let emptyTitle: String = ""
        static let errorDomain: String = "ZhiYu.ReminderService"
        static let noCalendarErrorCode: Int = 404
    }

    // MARK: - 测试工厂方法

    /// 构造使用 Mock 闭包的 iOSReminderService，避免触发真实 EventKit 权限弹窗
    private func makeService(
        accessGranted: Bool = true,
        defaultCalendar: EKCalendar? = nil,
        calendars: [EKCalendar] = [],
        saveThrows: Bool = false
    ) -> iOSReminderService {
        iOSReminderService(
            requestAccess: { accessGranted },
            defaultCalendar: { defaultCalendar },
            calendars: { _ in calendars },
            save: { _, _ in
                if saveThrows {
                    throw NSError(
                        domain: TestConstants.errorDomain,
                        code: 500,
                        userInfo: [NSLocalizedDescriptionKey: "Mock save error"]
                    )
                }
            }
        )
    }

    // MARK: - requestAccess

    /// requestAccess 授权成功时应返回 true
    func testRequestAccessGrantedReturnsTrue() async {
        let service = makeService(accessGranted: true)
        let granted = await service.requestAccess()
        XCTAssertTrue(granted, "授权成功时 requestAccess 应返回 true")
    }

    /// requestAccess 授权拒绝时应返回 false
    func testRequestAccessDeniedReturnsFalse() async {
        let service = makeService(accessGranted: false)
        let granted = await service.requestAccess()
        XCTAssertFalse(granted, "授权拒绝时 requestAccess 应返回 false")
    }

    /// requestAccess 闭包抛错时应返回 false（不崩溃）
    func testRequestAccessThrowsReturnsFalse() async {
        let service = iOSReminderService(
            requestAccess: { throw NSError(
                domain: TestConstants.errorDomain,
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Mock access error"]
            )},
            defaultCalendar: { nil },
            calendars: { _ in [] },
            save: { _, _ in }
        )
        let granted = await service.requestAccess()
        XCTAssertFalse(granted, "闭包抛错时 requestAccess 应返回 false 而非崩溃")
    }

    // MARK: - createReminder（有默认日历）

    /// 有默认日历时 createReminder 应成功且不抛错
    func testCreateReminderWithDefaultCalendarSucceeds() async throws {
        let calendar = EKCalendar(for: .reminder, eventStore: EKEventStore())
        let service = makeService(
            accessGranted: true,
            defaultCalendar: calendar,
            saveThrows: false
        )
        // requestAccess 先通过，再创建
        let granted = await service.requestAccess()
        XCTAssertTrue(granted, "前置条件：授权应成功")

        try await service.createReminder(
            title: TestConstants.reminderTitle,
            notes: TestConstants.reminderNotes
        )
        // 无抛错即成功
    }

    // MARK: - createReminder（无默认日历，回退到 calendars 列表）

    /// 无默认日历但 calendars 列表非空时，应使用第一个日历创建成功
    func testCreateReminderFallbackToCalendarsListSucceeds() async throws {
        let fallbackCalendar = EKCalendar(for: .reminder, eventStore: EKEventStore())
        let service = makeService(
            accessGranted: true,
            defaultCalendar: nil,
            calendars: [fallbackCalendar],
            saveThrows: false
        )
        try await service.createReminder(
            title: TestConstants.reminderTitle,
            notes: TestConstants.reminderNotes
        )
        // 无抛错即成功
    }

    /// 无默认日历且 calendars 列表为空时，应抛出 NSError(404)
    func testCreateReminderNoCalendarThrows404() async {
        let service = makeService(
            accessGranted: true,
            defaultCalendar: nil,
            calendars: [],
            saveThrows: false
        )
        do {
            try await service.createReminder(
                title: TestConstants.reminderTitle,
                notes: TestConstants.reminderNotes
            )
            XCTFail("无可用日历时应抛出 NSError(404)")
        } catch let error as NSError {
            XCTAssertEqual(error.domain, TestConstants.errorDomain, "错误 domain 应为 ZhiYu.ReminderService")
            XCTAssertEqual(error.code, TestConstants.noCalendarErrorCode, "错误 code 应为 404")
        } catch {
            XCTFail("应抛出 NSError 类型，实际：\(type(of: error))")
        }
    }

    // MARK: - createReminder（save 抛错）

    /// save 闭包抛错时 createReminder 应向上传播错误
    func testCreateReminderSaveThrowsPropagatesError() async {
        let calendar = EKCalendar(for: .reminder, eventStore: EKEventStore())
        let service = makeService(
            accessGranted: true,
            defaultCalendar: calendar,
            saveThrows: true
        )
        do {
            try await service.createReminder(
                title: TestConstants.reminderTitle,
                notes: TestConstants.reminderNotes
            )
            XCTFail("save 抛错时 createReminder 应向上传播错误")
        } catch let error as NSError {
            XCTAssertEqual(error.code, 500, "应传播 save 闭包的 NSError(500)")
        } catch {
            XCTFail("应抛出 NSError 类型，实际：\(type(of: error))")
        }
    }

    // MARK: - createReminder（空标题）

    /// 空标题创建提醒不应导致服务崩溃
    func testCreateReminderWithEmptyTitleDoesNotCrash() async throws {
        let calendar = EKCalendar(for: .reminder, eventStore: EKEventStore())
        let service = makeService(
            accessGranted: true,
            defaultCalendar: calendar,
            saveThrows: false
        )
        try await service.createReminder(
            title: TestConstants.emptyTitle,
            notes: TestConstants.reminderNotes
        )
        // 无抛错即成功（空标题由调用方校验，服务层不拦截）
    }

    // MARK: - 协议一致性

    /// 服务实例应可向上转型为 ReminderServiceProtocol
    func testConformsToReminderServiceProtocol() async {
        let service: any ReminderServiceProtocol = makeService(accessGranted: true)
        let granted = await service.requestAccess()
        XCTAssertTrue(granted, "协议转型与调用应成功")
    }

    /// 生产环境 init() 应可正常实例化（不触发权限弹窗，仅构造 EKEventStore）
    func testProductionInitDoesNotCrash() {
        // 仅验证 init() 不崩溃，不调用 requestAccess（避免触发权限弹窗）
        _ = iOSReminderService()
    }
}
#endif
