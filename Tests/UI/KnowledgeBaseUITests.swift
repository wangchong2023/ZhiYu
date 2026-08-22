//
//  KnowledgeBaseUITests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 KnowledgeBaseUI 开展自动化单元测试验证。
//
import XCTest

// MARK: - UI Test Base Class
/// KnowledgeBase UI 自动化测试公共基础类
///
/// 提供以下核心能力：
///  1. `setUp` — 以 UI Test Runner 身份安全启动 App（防止在 Unit Test Target 中误触崩溃）
///  2. `tearDown` — 每个测试用例结束后干净地终止 App 进程
///  3. `tapTab(named:)` — 跨 iOS 版本、多语言、多平台（Compact/Regular）的自适应 Tab 导航
///  4. `safeTap` / `assertTap` — 软断言与强断言点击的统一入口
///  5. `navigateToKnowledgeTab` / `navigateToSettingsTab` — 常用导航快捷方法
@MainActor
class KnowledgeBaseUITests: XCTestCase {

    /// 被测应用实例
    var app: XCUIApplication!

    /// 子类可 override 此属性，追加 UI 测试专用 launch argument（如路由注入）
    /// 基类 launch 时会合并这些参数，避免子类重复 launch
    var extraLaunchArguments: [String] { [] }

    /// 子类可 override 为 true，跳过基类的 vault 自愈逻辑
    /// 用于通过路由注入直接打开 sheet 的测试（如 --open-ai-settings）
    var skipVaultAutoSelect: Bool { false }

    // MARK: - Setup & Teardown

    /// 每个测试用例启动前初始化 XCUIApplication
    /// 注意：本基础类检查进程名，防止在 Unit Test Target 中触发 XCUIApplication 崩溃
    override func setUp() async throws {
        try await super.setUp()

        // 防止在单元测试 Target 中运行 UI 测试导致崩溃
        // UI 测试必须在独立的 UI Test Runner 中运行，进程名不应为 "ZhiYu"
        if ProcessInfo.processInfo.processName == "ZhiYu" {
            throw XCTSkip("Skipping UI test in Unit Test target to prevent XCUIApplication init crash.")
        }

        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-state", "-ResetUserDefaults", "-UITest_MockData"] + extraLaunchArguments
        app.launchEnvironment = ["UITesting": "true"]
        app.launch()

        // [自适应金库工作台跳转保护] 如果启动后处于冷启动 NotebookHub 笔记本工作台界面（不存在 TabBar）
        // 必须先自动进入第一个可用金库，以展现出应用主界面及底座 TabBar，防止 UI 单测乱点或找不到元素崩溃
        // 注意：先等待 15 秒让 App 充分加载，防止长时间测试后模拟器启动缓慢导致即时判断误判
        // 跳过条件：子类通过路由注入直接打开 sheet（如 --open-ai-settings），无需进入 vault
        guard !skipVaultAutoSelect else { return }
        _ = app.tabBars.firstMatch.waitForExistence(timeout: 15)
        // 结合 userProfileMenuButton 状态共同判定，防止 XCTest 假阳性缓存误判导致自愈逻辑被跳过
        if !app.tabBars.firstMatch.exists || !app.buttons["userProfileMenuButton"].exists {
            let firstVaultCard = app.buttons.containing(NSPredicate(format: "label CONTAINS '的笔记本' OR label CONTAINS 'Vault' OR label CONTAINS 'Notebook' OR label CONTAINS 'Research'")).element(boundBy: 0)
            let anyCard = app.buttons.matching(identifier: "NotebookCard_Item").element(boundBy: 0)
            
            if firstVaultCard.waitForExistence(timeout: 2.0) && firstVaultCard.exists {
                firstVaultCard.tap()
                try? await Task.sleep(nanoseconds: 1 * 1_000_000_000)
            } else if anyCard.exists {
                anyCard.tap()
                try? await Task.sleep(nanoseconds: 1 * 1_000_000_000)
            } else {
                // MARK: - [自愈逻辑] 冷启动且数据库为空时，通过引导按钮自动创建并进入测试笔记本
                let createBtn = app.buttons["empty_state_action_button"]
                if createBtn.waitForExistence(timeout: 3.0) && createBtn.exists {
                    createBtn.tap()
                    
                    let nameField = app.textFields["notebook_name_textfield"]
                    if nameField.waitForExistence(timeout: 3.0) {
                        nameField.tap()
                        // 智能探测当前界面中英文状态以决定输入的金库名称，确保 L10n 数据种子播种一致性
                        let isEnglish = app.staticTexts["Create Notebook"].exists || app.staticTexts["Create Vault"].exists || app.staticTexts["Notebook Name"].exists
                        let vaultName = isEnglish ? "Research" : "项目调研"
                        nameField.typeText(vaultName)
                        
                        let submitBtn = app.buttons["notebook_submit_button"]
                        if submitBtn.exists {
                            submitBtn.tap()
                            
                            // 提交后稍作等待，再点击生成的卡片进入主页
                            try? await Task.sleep(nanoseconds: 1 * 1_000_000_000)
                            let newCard = app.buttons.matching(identifier: "NotebookCard_Item").element(boundBy: 0)
                            if newCard.waitForExistence(timeout: 3.0) {
                                newCard.tap()
                                try? await Task.sleep(nanoseconds: 1 * 1_000_000_000)
                            }
                        }
                    }
                }
            }
        }
    }

    /// 每个测试用例结束后终止 App，确保下一个测试用例从干净状态开始
    override func tearDown() async throws {
        // 优雅关闭：先返回主屏幕触发应用进入后台生命周期，让底层资源（如 WebKit, GRDB）有机会安全清理
        XCUIDevice.shared.press(.home)
        try? await Task.sleep(nanoseconds: 500_000_000)
        app?.terminate()
        try await super.tearDown()
    }

    // MARK: - Helper Methods

    /// 等待元素在指定超时时间内出现
    /// - Parameters:
    ///   - element: 目标 UI 元素
    ///   - timeout: 等待超时，默认 5 秒
    /// - Returns: 元素是否在超时前出现
    func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        return element.waitForExistence(timeout: timeout)
    }

    /// 安全点击元素：元素存在且可点击时执行点击，否则静默跳过（不 XCTFail）
    /// 适用于可选性 UI 元素（某些平台/状态下可能不存在）
    /// - Returns: 是否成功执行了点击
    @discardableResult
    func safeTap(_ element: XCUIElement) -> Bool {
        if element.exists {
            if element.isHittable {
                element.tap()
            } else {
                element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
            return true
        }
        return false
    }

    /// 强制点击元素：元素不存在或不可点击时触发 XCTFail
    /// 适用于必须存在的 UI 元素（官方测试套件关键项）
    func assertTap(_ element: XCUIElement, file: StaticString = #file, line: UInt = #line) {
        XCTAssertTrue(element.exists, "元素不存在: \(element.identifier)", file: file, line: line)
        if element.exists {
            if element.isHittable {
                element.tap()
            } else {
                element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
        }
    }

    // MARK: - Tab Navigation

    /// 跨系统版本与多语言自适应的 Tab 点击辅助方法
    ///
    /// 查找策略（三级降级）：
    ///  1. 精确 Tab 标签名匹配（英文/中文原生 accessibilityIdentifier）
    ///  2. 语言互转后备（中英文映射 switch）
    ///  3. 物理索引后备（严格对齐 AppLayoutComponents.swift 中 TabView 顺序：
    ///     Knowledge=0, Chat=1, Ingest=2, Synthesis=3, Graph=4）
    ///
    /// - Parameter tabName: Tab 标识名（支持英文或中文）
    func tapTab(named tabName: String) {
        // 先等待 TabBar 出现，防止主界面加载动画或 XCTest accessibility 缓存延迟导致误判
        _ = app.tabBars.firstMatch.waitForExistence(timeout: 15)

        ensureAppMainInterfaceVisible()

        // 1. 获取所有可能的别名列表
        let aliases = tabAliases(for: tabName)
        
        // 2. 快速扫描（瞬时检测 exists），避免不必要的等待
        for alias in aliases {
            let tabButton = app.tabBars.buttons[alias]
            if tabButton.exists {
                tabButton.tap()
                return
            }
            let genericButton = app.buttons[alias]
            if genericButton.exists {
                genericButton.tap()
                return
            }
        }
        
        // 3. 如果瞬时检测全部没有找到，使用 2.0 秒的短超时等待任何一个别名出现
        for alias in aliases {
            let tabButton = app.tabBars.buttons[alias]
            if tabButton.waitForExistence(timeout: 2.0) {
                tabButton.tap()
                return
            }
            let genericButton = app.buttons[alias]
            if genericButton.waitForExistence(timeout: 2.0) {
                genericButton.tap()
                return
            }
        }
        
        // 4. 终极兜底：使用物理位置索引
        tapFallbackIndex(for: tabName)
    }

    private func ensureAppMainInterfaceVisible() {
        // [自适应金库工作台跳转保护] 如果当前处于冷启动 NotebookHub 笔记本工作台界面（不存在 TabBar）
        // 必须先自动进入第一个可用金库，以展现出应用主界面及底座 TabBar
        if !app.tabBars.firstMatch.exists || !app.buttons["userProfileMenuButton"].exists {
            let firstVaultCard = app.buttons.containing(NSPredicate(format: "label CONTAINS '的笔记本' OR label CONTAINS 'Vault' OR label CONTAINS 'Notebook' OR label CONTAINS 'Research'")).element(boundBy: 0)
            var targetCard = firstVaultCard
            if !targetCard.exists {
                targetCard = app.buttons.matching(identifier: "NotebookCard_Item").element(boundBy: 0)
            }
            if targetCard.exists {
                if targetCard.isHittable {
                    targetCard.tap()
                } else {
                    targetCard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                }
                _ = app.tabBars.firstMatch.waitForExistence(timeout: 2.0)
            } else {
                handleEmptyStateAutoCreation()
            }
        }
    }

    private func handleEmptyStateAutoCreation() {
        // MARK: - [自愈逻辑] 同步模式下若无 any 卡片，触发流式创建自愈
        let createBtn = app.buttons["empty_state_action_button"]
        if createBtn.waitForExistence(timeout: 3.0) && createBtn.exists {
            createBtn.tap()
            
            let nameField = app.textFields["notebook_name_textfield"]
            if nameField.waitForExistence(timeout: 3.0) {
                nameField.tap()
                // 智能探测当前界面中英文状态以决定输入的金库名称，确保 L10n 数据种子播种一致性
                let isEnglish = app.staticTexts["Create Notebook"].exists || app.staticTexts["Create Vault"].exists || app.staticTexts["Notebook Name"].exists
                let vaultName = isEnglish ? "Research" : "项目调研"
                nameField.typeText(vaultName)
                
                let submitBtn = app.buttons["notebook_submit_button"]
                if submitBtn.exists {
                    submitBtn.tap()
                    _ = XCTWaiter.wait(for: [XCTestExpectation(description: "提交后等待卡片创建")], timeout: 1.0)
                    let newCard = app.buttons.matching(identifier: "NotebookCard_Item").element(boundBy: 0)
                    if newCard.waitForExistence(timeout: 3.0) {
                        if newCard.isHittable {
                            newCard.tap()
                        } else {
                            newCard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                        }
                        _ = app.tabBars.firstMatch.waitForExistence(timeout: 2.0)
                    }
                }
            }
        }
    }

    private func tabAliases(for tabName: String) -> [String] {
        var baseNames = [tabName]
        
        // 映射所有的近义词和本地化物理值
        let mapping: [String: [String]] = [
            "Knowledge": ["Knowledge", "知识", "主页", "NotebookHub"],
            "知识": ["Knowledge", "知识", "主页", "NotebookHub"],
            "主页": ["Knowledge", "知识", "主页", "NotebookHub"],
            
            "Chat": ["Chat", "AI Chat", "对话", "AI 对话", "聊天"],
            "对话": ["Chat", "AI Chat", "对话", "AI 对话", "聊天"],
            "聊天": ["Chat", "AI Chat", "对话", "AI 对话", "聊天"],
            
            "Ingest": ["Ingest", "Sources", "导入", "来源"],
            "导入": ["Ingest", "Sources", "导入", "来源"],
            "来源": ["Ingest", "Sources", "导入", "来源"],
            
            "Synthesis": ["Synthesis", "合成"],
            "合成": ["Synthesis", "合成"],
            
            "Graph": ["Graph", "图谱"],
            "图谱": ["Graph", "图谱"],
            
            "Settings": ["Settings", "设置"],
            "设置": ["Settings", "设置"]
        ]
        
        if let mapped = mapping[tabName] {
            for val in mapped where !baseNames.contains(val) {
                baseNames.append(val)
            }
        }
        return baseNames
    }

    private func tapFallbackIndex(for tabName: String) {
        let indexMapping: [String: Int] = [
            "Knowledge": 0, "知识": 0, "主页": 0,
            "Chat": 1, "对话": 1, "聊天": 1,
            "Ingest": 2, "导入": 2,
            "Synthesis": 3, "合成": 3,
            "Graph": 4, "图谱": 4,
            "Search": 2, "搜索": 2, "检索": 2
        ]

        if tabName == "Settings" || tabName == "设置" {
            let settingsBtn = app.buttons["Settings"]
            if settingsBtn.waitForExistence(timeout: 15) {
                settingsBtn.tap()
                return
            }
            let settingsBtnZh = app.buttons["设置"]
            if settingsBtnZh.waitForExistence(timeout: 15) {
                settingsBtnZh.tap()
                return
            }
        }

        let index = indexMapping[tabName] ?? (tabName == "Settings" || tabName == "设置" ? 4 : 0)

        // 重试机制：冷启动时 TabBar 可能需要更长时间渲染
        let maxRetries = 3
        for attempt in 1...maxRetries {
            // 等待 TabBar 出现（每次重试增加等待时间）
            let waitTimeout = TimeInterval(10 * attempt)
            guard app.tabBars.firstMatch.waitForExistence(timeout: waitTimeout) else {
                // TabBar 未出现，尝试 ensureAppMainInterfaceVisible 后重试
                ensureAppMainInterfaceVisible()
                continue
            }

            // 优先从 TabBar 按索引点击
            if app.tabBars.buttons.count > index {
                let button = app.tabBars.buttons.element(boundBy: index)
                if button.waitForExistence(timeout: 5) && button.isHittable {
                    button.tap()
                    return
                }
            }

            // fallback：从所有按钮中按索引点击
            if app.buttons.count > index {
                let button = app.buttons.element(boundBy: index)
                if button.waitForExistence(timeout: 5) && button.isHittable {
                    button.tap()
                    return
                }
            }

            // 再 fallback：按 accessibility identifier 搜索
            let aliases = tabAliases(for: tabName)
            for alias in aliases {
                let btn = app.buttons[alias]
                if btn.waitForExistence(timeout: 3) && btn.isHittable {
                    btn.tap()
                    return
                }
            }

            // 短暂等待后重试
            if attempt < maxRetries {
                Thread.sleep(forTimeInterval: 2.0)
            }
        }

        // 最终兜底：使用坐标点击 TabBar 底部区域
        let tabBar = app.tabBars.firstMatch
        if tabBar.exists {
            let tabBarFrame = tabBar.frame
            if tabBarFrame.width > 0 {
                let xOffset = CGFloat(index + 1) / CGFloat(max(app.tabBars.buttons.count, index + 2))
                tabBar.coordinate(withNormalizedOffset: CGVector(dx: xOffset, dy: 0.5)).tap()
                return
            }
        }

        XCTFail("重试 \(maxRetries) 次后仍找不到 Tab 按钮: \(tabName)")
    }

    // MARK: - Common Navigation

    /// 导航到 Knowledge（知识）Tab 并等待视图稳定
    func navigateToKnowledgeTab() async {
        tapTab(named: "Knowledge")
        try? await Task.sleep(nanoseconds: 1 * 1_000_000_000)
    }

    /// 导航到设置 Tab（通过 Settings Sheet 或 Tab 按钮）并等待视图稳定
    func navigateToSettingsTab() async {
        tapTab(named: "Settings")
        try? await Task.sleep(nanoseconds: 1 * 1_000_000_000)
    }

    /// 点击源元素并等待目标元素出现，若在短时间内目标未出现，则进行重试点击，彻底根治 CI 环境下的静默点击失败
    /// - Parameters:
    ///   - source: 被点击的源元素
    ///   - target: 期待出现的目标元素
    ///   - timeout: 每次点击后等待目标出现的超时时长
    ///   - maxRetries: 最大点击重试次数，默认 3 次
    /// - Returns: 目标元素最终是否成功出现并可用
    @discardableResult
    func tap(_ source: XCUIElement, waitingFor target: XCUIElement, timeout: TimeInterval = 3.0, maxRetries: Int = 3) -> Bool {
        for i in 0..<maxRetries {
            if target.exists { return true }
            safeTap(source)
            if target.waitForExistence(timeout: timeout) {
                return true
            }
            print("⚠️ [UI Test] 点击 \(source.identifier) 后未检测到 \(target.identifier) 出现，重试第 \(i + 1) 次...")
        }
        return target.exists
    }
}
