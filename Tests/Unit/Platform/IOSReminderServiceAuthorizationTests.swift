//
//  IOSReminderServiceAuthorizationTests.swift
//  ZhiYuTests
//
//  系统层级：[Platforms] 平台测试
//  核心职责：验证 iOSReminderService 权限校验、无可用日历时抛错及正常保存分支。
//

import XCTest
import Foundation
@testable import ZhiYu

#if !os(watchOS)
import EventKit

@MainActor
final class IOSReminderServiceAuthorizationTests: XCTestCase {

    /// 验证权限未被授予时创建提醒抛出错误
    func testCreateReminder_unauthorizedAccess_throwsError() async throws {
        let service = iOSReminderService(
            requestAccess: { false },
            defaultCalendar: { nil },
            calendars: { _ in [] },
            save: { _, _ in }
        )

        do {
            try await service.createReminder(title: "Test", notes: "Notes")
            XCTFail("未授权时应抛错")
        } catch {
            let nsError = error as NSError
            XCTAssertEqual(nsError.code, PlatformConstants.Reminder.notFoundErrorCode, "未授权应抛错误")
        }
    }

    /// 验证无日历可用时抛错且包含正确 domain
    func testCreateReminder_noCalendarAvailable_throwsError() async {
        let service = iOSReminderService(
            requestAccess: { true },
            defaultCalendar: { nil },
            calendars: { _ in [] },
            save: { _, _ in }
        )

        do {
            try await service.createReminder(title: "Test", notes: "Notes")
            XCTFail("应抛出无日历可用错误")
        } catch {
            let nsError = error as NSError
            XCTAssertEqual(nsError.code, PlatformConstants.Reminder.notFoundErrorCode)
            XCTAssertEqual(nsError.domain, "ZhiYu.ReminderService")
        }
    }

    /// 验证存在默认日历时保存闭包被调用
    func testCreateReminder_withDefaultCalendar_invokesSave() async throws {
        var saveCalled = false
        let service = iOSReminderService(
            requestAccess: { true },
            defaultCalendar: { EKCalendar(for: .reminder, eventStore: EKEventStore()) },
            calendars: { _ in [] },
            save: { _, _ in saveCalled = true }
        )

        try await service.createReminder(title: "Test", notes: "Notes")
        XCTAssertTrue(saveCalled, "save 应被调用")
    }
}
#endif
