//
//  iOSReminderService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 平台适配层
//  核心职责：实现 iOSReminder 模块的核心业务逻辑服务。
//
//  D-32 修复：引入闭包注入模式，使 EventKit 调用可被测试替换，
//  避免模拟器触发真实权限弹窗阻塞单元测试。
//

#if !os(watchOS)
import Foundation
import EventKit

/// iOS/macOS 提醒事项服务实现
final class iOSReminderService: ReminderServiceProtocol, @unchecked Sendable {
    private let eventStore: EKEventStore

    // MARK: - 可注入的 EventKit 调用闭包（测试替换点）

    /// 请求提醒事项访问权限的闭包（默认调用真实 EventKit）
    private let requestAccessHandler: @Sendable () async throws -> Bool

    /// 获取默认提醒日历的闭包（默认调用真实 EventKit）
    private let defaultCalendarHandler: @Sendable () -> EKCalendar?

    /// 获取所有提醒日历的闭包（默认调用真实 EventKit）
    private let calendarsHandler: @Sendable (EKEntityType) -> [EKCalendar]

    /// 保存提醒事项的闭包（默认调用真实 EventKit）
    private let saveHandler: @Sendable (EKReminder, Bool) throws -> Void

    // MARK: - 初始化

    /// 生产环境初始化（使用真实 EKEventStore）
    init() {
        let store = EKEventStore()
        self.eventStore = store
        self.requestAccessHandler = {
            if #available(iOS 17.0, macOS 14.0, *) {
                return try await store.requestFullAccessToReminders()
            } else {
                return try await store.requestAccess(to: .reminder)
            }
        }
        self.defaultCalendarHandler = { store.defaultCalendarForNewReminders() }
        self.calendarsHandler = { store.calendars(for: $0) }
        self.saveHandler = { reminder, commit in
            try store.save(reminder, commit: commit)
        }
    }

    /// 测试环境初始化（注入自定义闭包，避免触发真实 EventKit 权限弹窗）
    init(
        requestAccess: @escaping @Sendable () async throws -> Bool,
        defaultCalendar: @escaping @Sendable () -> EKCalendar?,
        calendars: @escaping @Sendable (EKEntityType) -> [EKCalendar],
        save: @escaping @Sendable (EKReminder, Bool) throws -> Void
    ) {
        self.eventStore = EKEventStore()
        self.requestAccessHandler = requestAccess
        self.defaultCalendarHandler = defaultCalendar
        self.calendarsHandler = calendars
        self.saveHandler = save
    }

    // MARK: - ReminderServiceProtocol 实现

    /// 请求Access
    /// - Returns: 是否成功
    func requestAccess() async -> Bool {
        do {
            return try await requestAccessHandler()
        } catch {
            return false
        }
    }

    /// 创建Reminder
    /// - Parameter title: title
    /// - Parameter notes: notes
    func createReminder(title: String, notes: String) async throws {
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = title
        reminder.notes = notes
        // 优先使用默认日历，若不存在则尝试获取第一个可用的提醒事项日历
        if let calendar = defaultCalendarHandler() {
            reminder.calendar = calendar
        } else {
            let calendars = calendarsHandler(.reminder)
            guard let firstCalendar = calendars.first else {
                // 将硬编码中文字符串替换为强类型多语言引用，防止 L10n 静态扫描泄露并保障 watchOS/iOS 的多语言统一
                throw NSError(domain: "ZhiYu.ReminderService", code: 404, userInfo: [NSLocalizedDescriptionKey: L10n.Reminder.noListAvailableMessage])
            }
            reminder.calendar = firstCalendar
        }

        try saveHandler(reminder, true)
    }
}
#endif
