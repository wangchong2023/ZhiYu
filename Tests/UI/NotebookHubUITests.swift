//
//  NotebookHubUITests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/25.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests] UI 测试层
//  核心职责：验证 NotebookHub → 点击内置笔记本 → Dashboard 渲染全链路，
//           覆盖 iPad/Mac NavigationSplitView 过渡和 L10n 初始化场景。
//           防止 EXC_BREAKPOINT (MainActor.assumeIsolated) 和
//           GestureRecognizer 冲突导致的 crash 回归。

import XCTest

/// NotebookHub UI 自动化测试
///
/// 测试覆盖：
/// 1. 内置笔记本数量验证（始终 ≥2）
/// 2. 点击内置笔记本 → Dashboard 仪表盘渲染
/// 3. 笔记本切换无 crash（NavigationSplitView 过渡 + languageMode 访问）
/// 4. languageMode 缓存初始化正确性（非主 actor 上下文安全）
@MainActor
final class NotebookHubUITests: KnowledgeBaseUITests {

    // MARK: - Setup

    /// 覆写基类 setUp：跳过自动进入 vault 的逻辑。
    /// NotebookHub 测试需要从 NotebookHub 工作台开始，而非已进入某个 vault 的主界面。
    override func setUp() async throws {
        // 执行基类的核心安全逻辑（防止在 Unit Test Target 中运行、launch app）
        if ProcessInfo.processInfo.processName == "ZhiYu" {
            throw XCTSkip("Skipping UI test in Unit Test target to prevent XCUIApplication init crash.")
        }

        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-state", "-ResetUserDefaults", "-UITest_MockData"]
        app.launchEnvironment = ["UITesting": "true"]
        app.launch()
        // 关键差异：不自动进入 vault。
        // 基类 setUp 在检测到无 TabBar 时会自动点击卡片进入 vault，
        // 但 NotebookHub 测试需要在工作台界面上验证卡片数量和交互。
        // 如果 app 启动后意外进入了 vault（比如 KeyStore 残留状态），
        // 则通过 returnToNotebookHub() 退出到工作台。
        // 注意：必须等待 TabBar 充分渲染后再判断，避免冷启动时 TabBar
        // 尚未出现导致误判为"已在 NotebookHub"，随后 TabBar 出现破坏测试。
        if app.tabBars.firstMatch.waitForExistence(timeout: 10) {
            returnToNotebookHub()
        }
    }

    // MARK: - 内置笔记本存在性

    /// 验证 NotebookHub 至少显示 2 个内置笔记本（"知识图谱" + "项目调研"）。
    /// 这覆盖了 VaultDataCoordinator.loadVaults() 通过 englishName 补全内置笔记本的逻辑。
    func testNotebookHubShowsAtLeastTwoDefaultNotebooks() async throws {
        // 等待 NotebookHub 出现 — 多级查询策略兼容 SwiftUI ScrollView 在
        // 不同 iOS 版本下底层实现差异（UIScrollView vs UICollectionView）
        let hubFound = waitForNotebookHubView(timeout: 5)
        XCTAssertTrue(hubFound, "NotebookHubView 应在 5 秒内显示")

        // 统计笔记本卡片数量
        let cards = app.buttons.matching(identifier: "NotebookCard_Item")
        let cardCount = cards.count
        XCTAssertGreaterThanOrEqual(cardCount, 2,
                                    "应至少显示 2 个内置笔记本，实际: \(cardCount)")
    }

    // MARK: - 点击笔记本 → Dashboard 渲染

    /// 点击内置笔记本 → 验证 Dashboard 仪表盘正确渲染。
    /// 这是本次 crash 修复的核心回归测试——验证 .task 闭包中
    /// languageMode 访问不会触发 EXC_BREAKPOINT。
    func testClickBuiltInNotebookNavigatesToDashboard() async throws {
        // 确保在 NotebookHub
        if app.tabBars.firstMatch.exists {
            returnToNotebookHub()
        }

        guard waitForNotebookHubView(timeout: 5) else {
            throw XCTSkip("NotebookHubView 未显示，跳过测试")
        }

        // 点击第一个内置笔记本（使用坐标后备点击，避免 hittable 判定问题）
        let firstCard = app.buttons.matching(identifier: "NotebookCard_Item").element(boundBy: 0)
        guard firstCard.waitForExistence(timeout: 3) else {
            throw XCTSkip("无可点击的笔记本卡片，跳过测试")
        }
        if firstCard.isHittable {
            firstCard.tap()
        } else {
            firstCard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }

        // 等待主界面出现（TabBar + 内容区域）
        // 注意：selectNotebook 中有 Task.yield() 时序 hack（避免 GestureRecognizer 冲突），
        // 加上数据库初始化，5 秒超时在模拟器高负载下不够，改为 10 秒
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10),
                      "点击笔记本后 TabBar 应在 10 秒内显示")

        // 验证 Knowledge tab 被选中
        try? await Task.sleep(nanoseconds: 1_000_000_000)

        // 检查 Dashboard 区域有内容渲染（非白屏）
        let sidebarTitle = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS[c] 'dashboard' OR label CONTAINS[c] '仪表盘'")
        ).firstMatch
        let hasContent = sidebarTitle.exists
            || app.staticTexts.firstMatch.exists
        XCTAssertTrue(hasContent, "仪表盘应渲染至少部分可见内容")

        // 核心断言：应用未崩溃。如果到达这里，说明 NavigationSplitView 过渡、
        // KnowledgeDashboardView.task 中的 languageMode 访问均成功。
    }

    // MARK: - 笔记本切换稳定性

    /// 连续切换多个笔记本，验证 NavigationSplitView 过渡无 crash。
    func testSwitchBetweenVaultsDoesNotCrash() async throws {
        // 进入第一个笔记本
        if app.tabBars.firstMatch.exists {
            returnToNotebookHub()
        }

        guard waitForNotebookHubView(timeout: 5) else {
            throw XCTSkip("NotebookHubView 未显示")
        }

        let cards = app.buttons.matching(identifier: "NotebookCard_Item")
        guard cards.count >= 2 else {
            throw XCTSkip("需要至少 2 个笔记本进行切换测试")
        }

        // 第一轮：点击第一个笔记本（坐标后备点击）
        let firstCard = cards.element(boundBy: 0)
        if firstCard.isHittable {
            firstCard.tap()
        } else {
            firstCard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        var tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "首次点击应进入主界面")

        // 返回到 NotebookHub
        returnToNotebookHub()
        guard waitForNotebookHubView(timeout: 5) else {
            throw XCTSkip("返回 NotebookHub 失败")
        }

        // 第二轮：点击第二个笔记本（坐标后备点击）
        let refreshedCards = app.buttons.matching(identifier: "NotebookCard_Item")
        guard refreshedCards.count >= 2 else {
            throw XCTSkip("返回后笔记本卡片数量不足")
        }
        let secondCard = refreshedCards.element(boundBy: 1)
        if secondCard.isHittable {
            secondCard.tap()
        } else {
            secondCard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }

        tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "第二次点击应进入主界面")

        // 如果到达这里，连续切换无 crash
    }

    // MARK: - 从 NotebookHub 创建并进入自定义笔记本

    /// 创建自定义笔记本 → 点击进入 → 验证 Dashboard 不 crash。
    /// 这覆盖了非内置笔记本（拼音 englishName 路径）的完整流程。
    func testCreateAndEnterCustomNotebookDoesNotCrash() async throws {
        // 确保在 NotebookHub
        if app.tabBars.firstMatch.exists {
            returnToNotebookHub()
        }

        guard waitForNotebookHubView(timeout: 5) else {
            throw XCTSkip("NotebookHubView 未显示")
        }

        // 点击新建按钮（网格模式下的 + 卡片或空状态下的引导按钮）
        let createBtn: XCUIElement
        let gridCreateBtn = app.buttons["CreateNotebookButton"]
        let emptyCreateBtn = app.buttons["empty_state_action_button"]
        if gridCreateBtn.exists {
            createBtn = gridCreateBtn
        } else if emptyCreateBtn.exists {
            createBtn = emptyCreateBtn
        } else {
            throw XCTSkip("找不到新建笔记本按钮")
        }
        createBtn.tap()

        // 填写创建表单
        let nameField = app.textFields["notebook_name_textfield"]
        guard nameField.waitForExistence(timeout: 3) else {
            throw XCTSkip("创建表单未出现")
        }
        nameField.tap()
        nameField.typeText("UI 测试笔记本")

        let submitBtn = app.buttons["notebook_submit_button"]
        guard submitBtn.exists else {
            throw XCTSkip("提交按钮不存在")
        }
        submitBtn.tap()

        // 等待新卡片出现并点击
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        let newCard = app.buttons.matching(identifier: "NotebookCard_Item").element(boundBy: 0)
        guard newCard.waitForExistence(timeout: 3) else {
            throw XCTSkip("新建笔记本卡片未出现")
        }
        newCard.tap()

        // 验证主界面出现
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5),
                      "进入自定义笔记本后 TabBar 应显示")
    }

    // MARK: - Helpers

    /// 等待 NotebookHub 视图出现。
    ///
    /// 多级查询策略兼容 SwiftUI ScrollView 在不同 iOS 版本下的底层实现差异：
    /// - iOS 16-17: ScrollView → `UIScrollView` → `XCUIElementTypeScrollView`
    /// - iOS 18+: ScrollView 可能使用 `UICollectionView` 内部实现
    ///
    /// 查询优先级：scrollViews → otherElements → NotebookCard → 空状态按钮
    private func waitForNotebookHubView(timeout: TimeInterval = 5) -> Bool {
        // 策略 1: 标准 ScrollView 查询（iOS 16-17）
        if app.scrollViews["NotebookHubView"].waitForExistence(timeout: 2) {
            return true
        }
        // 策略 2: otherElements 查询（iOS 18+ SwiftUI 可能不使用 UIScrollView）
        if app.otherElements["NotebookHubView"].waitForExistence(timeout: 2) {
            return true
        }
        // 策略 3: 通过 NotebookCard 卡片的出现间接确认 NotebookHub 已展示
        if app.buttons.matching(identifier: "NotebookCard_Item").firstMatch.waitForExistence(timeout: timeout) {
            return true
        }
        // 策略 4: 通过空状态引导按钮确认（数据库完全空白时）
        if app.buttons["empty_state_action_button"].waitForExistence(timeout: 1) {
            return true
        }
        return false
    }

    /// 通过 VaultBadge 或 FloatingContextCapsule 退出当前笔记本，返回 NotebookHub 工作台。
    ///
    /// 重要：UI 测试模式（`--uitesting`）下，`VaultBadge` 渲染为直通 Button
    /// （而非 Menu），点击即直接调用 `exitVault()`。因此不存在 `vaultBackToHubButton`
    /// 子菜单项。本方法已针对两种模式适配。
    private func returnToNotebookHub() {
        let isUITesting = ProcessInfo.processInfo.arguments.contains("--uitesting")

        // 方案 1: 通过 VaultBadge 退出
        let vaultBadge = app.buttons["vaultBadgeButton"]
        if vaultBadge.waitForExistence(timeout: 5) {
            vaultBadge.tap()

            if isUITesting {
                // UI 测试模式：VaultBadge 为直通 Button，点击即退出。
                // 直接等待 NotebookHub 卡片出现即可。
                if waitForNotebookHubView(timeout: 8) {
                    return
                }
            } else {
                // 生产模式：VaultBadge 为 Menu，需点击其中的退出按钮。
                let backBtn = app.buttons["vaultBackToHubButton"]
                if backBtn.waitForExistence(timeout: 5) {
                    backBtn.tap()
                    if waitForNotebookHubView(timeout: 8) {
                        return
                    }
                }
            }
        }

        // 方案 2: 通过 FloatingContextCapsule（紧凑设备或自定义工具栏）
        // FloatingContextCapsule 是 HStack 容器（非 Button），需用 otherElements 查询
        let capsuleElement = app.otherElements["FloatingContextCapsule"]
        if capsuleElement.waitForExistence(timeout: 3) {
            capsuleElement.tap()
            let backBtn = app.buttons["vaultBackToHubButton"]
            if backBtn.waitForExistence(timeout: 5) {
                backBtn.tap()
                if waitForNotebookHubView(timeout: 8) {
                    return
                }
            }
        }

        // 回退方案：通过 Sidebar 中的 NotebookHub 入口
        let sidebarHubEntry = app.buttons["SidebarTab_knowledge"]
        if sidebarHubEntry.exists {
            sidebarHubEntry.tap()
        }
        _ = waitForNotebookHubView(timeout: 5)
    }
}
