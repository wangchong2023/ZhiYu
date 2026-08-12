//
//  WorkflowServiceTests.swift
//  ZhiYu
//
//  系统层级：[L0] 测试层
//  核心职责：验证 WorkflowService Markdown 解析与同步逻辑（通过观察 ToastManager 副作用）。
//

import XCTest
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class WorkflowServiceTests: XCTestCase {

    var mockReminderService: MockReminderService!
    var service: WorkflowService!
    @Dependency(\.toastService) var toastManager

    override func setUp() {
        super.setUp()
        mockReminderService = MockReminderService()
        mockReminderService.requestAccessResult = true
        service = WorkflowService(reminderService: mockReminderService)
        // 注册 HapticFeedbackProtocol mock，避免 HapticFeedback.shared DI 崩溃
        ServiceContainer.shared.register(
            MockHapticFeedback() as any HapticFeedbackProtocol,
            for: (any HapticFeedbackProtocol).self
        )
        // 重置 Toast 状态
        toastManager.currentToast = nil
    }

    override func tearDown() {
        toastManager.currentToast = nil
        service = nil
        mockReminderService = nil
        super.tearDown()
    }

    // MARK: - Markdown 任务标记解析

    /// 含未完成任务标记（- [ ]）的 Markdown 应被识别为任务
    func testSyncToReminders_含未完成任务_调用createReminder() async {
        let markdown = """
        # 测试页面
        - [ ] 待办事项 1
        - [ ] 待办事项 2
        """
        try? await service.syncToReminders(text: markdown, title: "测试页面")

        XCTAssertEqual(
            mockReminderService.createReminderCallCount,
            2,
            "应识别 2 个未完成任务并调用 createReminder 2 次"
        )
    }

    /// 含已完成任务标记（- [x]）的 Markdown 不应被同步（finding #8 已修复）
    func testSyncToReminders_含已完成任务_不同步() async {
        let markdown = """
        # 测试页面
        - [x] 已完成事项
        """
        try? await service.syncToReminders(text: markdown, title: "测试页面")

        XCTAssertEqual(
            mockReminderService.createReminderCallCount,
            0,
            "已完成任务（- [x]）不应被同步（finding #8 已修复）"
        )
    }

    /// 含 `- ` 前缀的无序列表应被识别为任务
    func testSyncToReminders_含无序列表_调用createReminder() async {
        let markdown = """
        - 任务 1
        - 任务 2
        """
        try? await service.syncToReminders(text: markdown, title: "测试")

        XCTAssertEqual(mockReminderService.createReminderCallCount, 2)
    }

    /// 含 `* ` 前缀的无序列表应被识别为任务
    func testSyncToReminders_含星号无序列表_调用createReminder() async {
        let markdown = """
        * 任务 1
        * 任务 2
        """
        try? await service.syncToReminders(text: markdown, title: "测试")

        XCTAssertEqual(mockReminderService.createReminderCallCount, 2)
    }

    /// 含 `1. ` 前缀的有序列表应被识别为任务
    func testSyncToReminders_含有序列表_调用createReminder() async {
        let markdown = """
        1. 任务 1
        2. 任务 2
        """
        try? await service.syncToReminders(text: markdown, title: "测试")

        XCTAssertEqual(mockReminderService.createReminderCallCount, 2)
    }

    /// 无任务标记的 Markdown 不应调用 createReminder
    func testSyncToReminders_无任务标记_不调用() async {
        let markdown = """
        # 普通页面
        这是一段普通文本。
        """
        try? await service.syncToReminders(text: markdown, title: "测试")

        XCTAssertEqual(mockReminderService.createReminderCallCount, 0)
    }

    /// 空字符串不应调用 createReminder
    func testSyncToReminders_空字符串_不调用() async {
        try? await service.syncToReminders(text: "", title: "测试")
        XCTAssertEqual(mockReminderService.createReminderCallCount, 0)
    }

    // MARK: - Markdown 样式标记剔除

    /// 任务文本中的加粗标记应被剔除
    func testSyncToReminders_加粗标记_被剔除() async {
        let markdown = "- **重要任务**"
        try? await service.syncToReminders(text: markdown, title: "测试")

        XCTAssertEqual(mockReminderService.lastCreatedTitle, "重要任务")
    }

    /// 任务文本中的斜体标记应被剔除
    func testSyncToReminders_斜体标记_被剔除() async {
        let markdown = "- _强调任务_"
        try? await service.syncToReminders(text: markdown, title: "测试")

        XCTAssertEqual(mockReminderService.lastCreatedTitle, "强调任务")
    }

    /// 任务文本中的删除线标记应被剔除
    func testSyncToReminders_删除线标记_被剔除() async {
        let markdown = "- ~~废弃任务~~"
        try? await service.syncToReminders(text: markdown, title: "测试")

        XCTAssertEqual(mockReminderService.lastCreatedTitle, "废弃任务")
    }

    /// 任务文本中的行内代码标记应被剔除
    func testSyncToReminders_行内代码标记_被剔除() async {
        let markdown = "- `代码任务`"
        try? await service.syncToReminders(text: markdown, title: "测试")

        XCTAssertEqual(mockReminderService.lastCreatedTitle, "代码任务")
    }

    // MARK: - 副作用：Toast 反馈

    /// 同步成功后应显示成功 Toast
    func testSyncToReminders_成功_显示成功Toast() async {
        let markdown = "- [ ] 测试任务"
        try? await service.syncToReminders(text: markdown, title: "测试")

        XCTAssertNotNil(
            toastManager.currentToast,
            "同步后应显示 Toast"
        )
    }

    /// 权限拒绝时应显示错误 Toast 并抛出 accessDenied
    func testSyncToReminders_权限拒绝_显示错误Toast() async {
        mockReminderService.requestAccessResult = false
        let markdown = "- [ ] 测试任务"

        do {
            try await service.syncToReminders(text: markdown, title: "测试")
            XCTFail("应抛出 accessDenied")
        } catch {
            // 预期抛错
        }

        XCTAssertNotNil(
            toastManager.currentToast,
            "权限拒绝时应显示错误 Toast"
        )
        XCTAssertEqual(
            mockReminderService.createReminderCallCount,
            0,
            "权限拒绝时不应调用 createReminder"
        )
    }

    /// 无任务时应显示 info Toast（noTasksFoundMessage）
    func testSyncToReminders_无任务_显示infoToast() async {
        let markdown = "普通文本，无任务"
        try? await service.syncToReminders(text: markdown, title: "测试")

        XCTAssertNotNil(
            toastManager.currentToast,
            "无任务时应显示 info Toast"
        )
    }

    /// createReminder 抛错时应显示错误 Toast 并重新抛出
    func testSyncToReminders_createReminder失败_显示错误Toast() async {
        mockReminderService.createReminderShouldThrow = true
        let markdown = "- [ ] 测试任务"

        do {
            try await service.syncToReminders(text: markdown, title: "测试")
            XCTFail("应抛出错误")
        } catch {
            // 预期抛错
        }

        XCTAssertNotNil(
            toastManager.currentToast,
            "失败时应显示错误 Toast"
        )
    }

    // MARK: - 单例一致性

    func testShared_多次访问_同一实例() {
        let a = WorkflowService.shared
        let b = WorkflowService.shared
        XCTAssertTrue(a === b)
    }
}
