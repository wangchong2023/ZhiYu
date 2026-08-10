//
//  AISettingsTabSwitchingUITests.swift
//  ZhiYuUITests
//
//  临时 UI 测试：验证 AISettingsView 顶部 Tab 切换是否正常响应
//  修复前：tab 点击不响应
//  修复后：tab 应能正常切换内容
//

import XCTest

@MainActor
final class AISettingsTabSwitchingUITests: KnowledgeBaseUITests {

    /// 注入 `--open-ai-settings` launch argument，启动时直接跳转 AI 设置页面
    /// 避免在源码中添加 `if isUITesting` 测试耦合分支
    override var extraLaunchArguments: [String] { ["--open-ai-settings"] }

    /// 路由注入直接打开 AI 设置 sheet，跳过基类的 vault 自愈逻辑
    override var skipVaultAutoSelect: Bool { true }

    override func setUp() async throws {
        try await super.setUp()

        continueAfterFailure = false
        // 等待 AI 设置页面通过路由注入呈现
        try? await Task.sleep(nanoseconds: 2_000_000_000)
    }

    func testAISettingsTabsAreSwitchable() async throws {
        // 1. 确认进入 AI 设置页面
        let navTitle = app.navigationBars.firstMatch
        XCTAssertTrue(navTitle.waitForExistence(timeout: 5), "AI 设置页面导航栏应当存在")

        // 2. 通过 segmented control 定位 Picker
        let segmentedControl = app.segmentedControls.firstMatch
        XCTAssertTrue(segmentedControl.waitForExistence(timeout: 5), "AISettingsView 顶部的分段选择器应当存在")
        XCTAssertEqual(segmentedControl.buttons.count, 3, "分段选择器应当有 3 个 tab")

        // 3. 点击 "在线大模型" segment (索引 1)
        let tab2 = segmentedControl.buttons.element(boundBy: 1)
        XCTAssertTrue(tab2.waitForExistence(timeout: 3) && tab2.isHittable, "tab '在线大模型' 应当可点击")
        safeTap(tab2)

        try? await Task.sleep(nanoseconds: 1_000_000_000)

        let apiKeyText = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS '开启 AI 助手' OR label CONTAINS 'Enable AI Assistant' OR label CONTAINS '提供商' OR label CONTAINS 'Provider' OR label CONTAINS 'API'")
        ).firstMatch
        XCTAssertTrue(apiKeyText.waitForExistence(timeout: 3),
                      "点击'在线大模型' tab 后应显示相关配置内容（API Key、提供商等），说明 tab 切换响应成功")

        // 4. 点击 "本地大模型" tab
        let tab3 = segmentedControl.buttons.element(boundBy: 2)
        XCTAssertTrue(tab3.waitForExistence(timeout: 3) && tab3.isHittable, "tab '本地大模型' 应当可点击")
        safeTap(tab3)
        try? await Task.sleep(nanoseconds: 1_000_000_000)

        let localText = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS '本地' OR label CONTAINS '模型市场' OR label CONTAINS '测试' OR label CONTAINS 'Model Store' OR label CONTAINS 'Laboratory' OR label CONTAINS 'Local'")
        ).firstMatch
        XCTAssertTrue(localText.waitForExistence(timeout: 3),
                      "点击'本地大模型' tab 后应显示相关配置内容（模型市场/测试实验室/Model Store/Laboratory/Local）")

        // 5. 点击 "大模型策略" tab 回到第一项
        let tab1 = segmentedControl.buttons.element(boundBy: 0)
        XCTAssertTrue(tab1.waitForExistence(timeout: 3) && tab1.isHittable, "tab '大模型策略' 应当可点击")
        safeTap(tab1)
        try? await Task.sleep(nanoseconds: 1_000_000_000)

        let strategyText = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS '策略' OR label CONTAINS '路由' OR label CONTAINS '本地模型' OR label CONTAINS 'Strategy' OR label CONTAINS 'Policy' OR label CONTAINS 'Routing' OR label CONTAINS 'Collaborative AI'")
        ).firstMatch
        XCTAssertTrue(strategyText.waitForExistence(timeout: 3),
                      "点击'大模型策略' tab 后应显示路由策略相关内容")
    }
}
