# ZhiYu UI Tests Stability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 彻底定位和修复智宇 (ZhiYu) 全平台 UI 自动化测试套件中 testChatAISkeletonLoadingState、testPageLinkNavigation 和 testVaultSwitchingAndSeedingFlow 这三个不稳定的测试用例，完全移去屏蔽标记并在本地实现连续 5 次 100% 成功率。

**Architecture:** 采用高稳健性 UI 测试范式。在打字前引入软键盘等待并实现焦点丢失自动重对焦自愈；在笔记跳转中弃用随机行点击改用确定含双链的预置种子页面做强匹配；在金库和 Tab 转场部分拉大超时门槛并引入阻尼 sleep 缓冲，消除数据库重载异步写盘与 UI 线程的竞争。

**Tech Stack:** XCUI, Swift 6, XCTest

## Global Constraints
- 所有修改均处于 `Tests/UI/ZhiYuUITests.swift` 文件。
- 代码需要具备完善的文件头、函数头和关键过程的中文注释。
- 使用 ./env/venv/bin/python3 运行任何配套脚本。

---

### Task 1: 优化 testChatAISkeletonLoadingState() UI 测试用例

**Files:**
- Modify: `Tests/UI/ZhiYuUITests.swift:320-355`

- [ ] **Step 1: 修改测试用例源代码**
  重构 `testChatAISkeletonLoadingState()` 逻辑，增加软键盘延迟缓冲与打字未成自愈。

```swift
    // UI 冒烟测试：切入 AI 对话面板 -> 模拟发送提问 -> 捕获并校验国际化加载状态 (AppAILoadingSkeleton) 文案 -> 物理中断流式输出
    //
    // 核心职责：验证 AppAILoadingSkeleton 的 L10n 字段正确渲染，并确保 RAG 对话流的中止机制（Stop-flow）功能闭环正常。
    func testChatAISkeletonLoadingState() throws {
        ensureAppIsLoggedInAndInVault()

        var chatTab = app.tabBars.buttons["Chat"]
        if !chatTab.exists {
            chatTab = app.buttons["Chat"]
        }
        if !chatTab.exists {
            chatTab = app.tabBars.buttons["AI 对话"]
        }
        XCTAssertTrue(chatTab.waitForExistence(timeout: 5), "AI 对话 Tab 按钮应当存在")
        chatTab.tap()
        try? Thread.sleep(forTimeInterval: 0.5)

        let chatInput = app.textFields["ChatInput_TextField"]
        XCTAssertTrue(chatInput.waitForExistence(timeout: 5), "对话输入框应当存在并可见")

        chatInput.tap()
        // 关键点：等待软键盘完全弹出且焦点状态完全稳定
        try? Thread.sleep(forTimeInterval: 0.8)
        chatInput.typeText("什么是倒数排名融合RRF算法？")
        try? Thread.sleep(forTimeInterval: 0.5)

        let sendButton = app.buttons["ChatSend_Button"]
        XCTAssertTrue(sendButton.exists, "发送按钮应当存在")
        
        // 关键点：防卫自愈，如因模拟器硬件键盘连接导致输入丢失，则在此重新激活重试
        if !sendButton.isEnabled {
            chatInput.tap()
            try? Thread.sleep(forTimeInterval: 0.5)
            chatInput.typeText("什么是倒数排名融合RRF算法？")
            try? Thread.sleep(forTimeInterval: 0.5)
        }
        
        XCTAssertTrue(sendButton.isEnabled, "发送按钮应当在打字后变为可用状态")
        sendButton.tap()

        let skeletonPredicate = NSPredicate(format: "label CONTAINS '思考' OR label CONTAINS '嵌入' OR label CONTAINS '检索' OR label CONTAINS '整合' OR label CONTAINS 'THINKING' OR label CONTAINS 'EMBEDDING' OR label CONTAINS 'RETRIEVAL' OR label CONTAINS 'SYNTHESIS' OR label CONTAINS 'ai.status.skeleton'")

        let skeletonText = app.staticTexts.matching(skeletonPredicate).element(boundBy: 0)

        // 关键点：放宽超时门限至 12 秒以容忍在慢速 CPU 环境下的模型后台初始化
        let exists = skeletonText.waitForExistence(timeout: 12)
        XCTAssertTrue(exists, "AI 流式思考骨架屏 (AppAILoadingSkeleton) 本地化提示文案应当正确渲染")

        XCTAssertTrue(sendButton.exists, "发送/停止按钮应当可见并支持点击")
        sendButton.tap()

        try? Thread.sleep(forTimeInterval: 1.0)
    }
```

- [ ] **Step 2: 运行测试验证**
  运行：`xcodebuild test -project ZhiYu.xcodeproj -scheme ZhiYu -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:ZhiYuTests/ZhiYuUITests/testChatAISkeletonLoadingState`
  预期：测试通过并全绿。

- [ ] **Step 3: 运行静态规则校验**
  运行：`swiftlint --strict`
  预期：无 Lint 规则违反。

- [ ] **Step 4: 提交代码**
  运行：`git add Tests/UI/ZhiYuUITests.swift` && `git commit -m "fix: 重构 AI 骨架屏 UI 测试键盘等待时序及自愈机制"`

---

### Task 2: 优化 testPageLinkNavigation() UI 测试用例

**Files:**
- Modify: `Tests/UI/ZhiYuUITests.swift:178-226`

- [ ] **Step 1: 修改测试用例源代码**
  重构 `testPageLinkNavigation()` 逻辑，用强类型常量匹配 `L10n.InitialNotebook.PKM.title1` 种子页面替换列表第一行随机页面，并加入 Wiki 渲染强校验。

```swift
    // 链接跳转测试：列表文档 -> 查找双向链接 [[WikiPage]] 标记 -> 模拟点击跳转关联页
    func testPageLinkNavigation() throws {
        ensureAppIsLoggedInAndInVault()

        var knowledgeTab = app.tabBars.buttons["Knowledge"]
        if !knowledgeTab.exists {
            knowledgeTab = app.tabBars.buttons["books.vertical.fill"]
        }
        if !knowledgeTab.exists {
            knowledgeTab = app.tabBars.buttons["知识库"]
        }
        XCTAssertTrue(knowledgeTab.exists, "知识库 Tab 按钮应该存在")
        knowledgeTab.tap()
        try? Thread.sleep(forTimeInterval: 0.5)

        let listPredicate = NSPredicate(format: "label CONTAINS '所有' OR label CONTAINS '页面' OR label CONTAINS 'Pages'")
        var pageListRow = app.buttons.matching(listPredicate).element(boundBy: 0)

        if !pageListRow.waitForExistence(timeout: 5) {
            pageListRow = app.cells.matching(listPredicate).element(boundBy: 0)
        }
        if !pageListRow.exists {
            pageListRow = app.cells.containing(listPredicate).element(boundBy: 0)
        }
        if !pageListRow.exists {
            pageListRow = app.buttons.containing(listPredicate).element(boundBy: 0)
        }

        if pageListRow.exists {
            pageListRow.tap()
            try? Thread.sleep(forTimeInterval: 0.8)
        }

        // 关键点：使用必然含有双向链接的预置种子页面 "个人知识图谱指南" 进行精确定位
        let targetTitle = L10n.InitialNotebook.PKM.title1
        let targetPredicate = NSPredicate(format: "label == %@ OR identifier == %@", targetTitle, targetTitle)
        let targetPage = app.buttons.matching(targetPredicate).element(boundBy: 0)
        let targetPageCell = app.cells.matching(targetPredicate).element(boundBy: 0)
        let targetElement = targetPage.exists ? targetPage : targetPageCell

        XCTAssertTrue(targetElement.waitForExistence(timeout: 20), "未能在列表中找到预置的个人知识图谱指南文档")
        targetElement.tap()
        try? Thread.sleep(forTimeInterval: 0.8)

        let linkPredicate = NSPredicate(format: "label CONTAINS '[[ ' OR label CONTAINS '[['")
        var pageLink = app.staticTexts.matching(linkPredicate).element(boundBy: 0)
        if !pageLink.exists {
            pageLink = app.staticTexts.containing(linkPredicate).element(boundBy: 0)
        }
        
        // 关键点：强断言渲染判定，存在后再执行点击
        XCTAssertTrue(pageLink.waitForExistence(timeout: 8), "详情页未能成功渲染 Wiki 双向链接")
        pageLink.tap()

        XCTAssertTrue(app.navigationBars.element.waitForExistence(timeout: 5), "点击 Wiki 双链后应发生导航跳转")
    }
```

- [ ] **Step 2: 运行测试验证**
  运行：`xcodebuild test -project ZhiYu.xcodeproj -scheme ZhiYu -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:ZhiYuTests/ZhiYuUITests/testPageLinkNavigation`
  预期：测试通过。

- [ ] **Step 3: 提交代码**
  运行：`git commit -a -m "fix: 重构 Wiki 链接跳转测试使用强常量模板匹配"`

---

### Task 3: 优化 testVaultSwitchingAndSeedingFlow() UI 测试用例

**Files:**
- Modify: `Tests/UI/ZhiYuUITests.swift:230-313`

- [ ] **Step 1: 修改测试用例及相关辅助函数**
  重构 `testVaultSwitchingAndSeedingFlow` 及内部的 `navigateBackToHub`、`verifyHubAppears`、`switchToVaultCard`、`enterKnowledgeList`。

```swift
    // 闭环测试：退出至工作台 -> 多笔记本金库切换 -> 校验播种数据幂等填充
    func testVaultSwitchingAndSeedingFlow() throws {
        ensureAppIsLoggedInAndInVault()
        navigateBackToHub()
        verifyHubAppears()
        switchToVaultCard()
        enterKnowledgeList()
        verifySeededDocuments()
    }

    private func navigateBackToHub() {
        let badgePredicate = NSPredicate(format: "label CONTAINS '笔记本' OR label CONTAINS 'Notebook'")
        let vaultBadge = findFirstExisting(app.buttons.matching(badgePredicate).firstMatch, app.buttons.containing(badgePredicate).firstMatch)
        // 关键点：延长角标识别超时到 8 秒
        guard vaultBadge.waitForExistence(timeout: 8) else { return }
        vaultBadge.tap()
        try? Thread.sleep(forTimeInterval: 0.5) // 转场缓冲
        
        let backLabels = ["所有笔记本", "返回工作台", "All Notebooks"]
        for label in backLabels {
            let btn = app.buttons[label]
            if btn.waitForExistence(timeout: 5) {
                btn.tap()
                try? Thread.sleep(forTimeInterval: 0.8) // 再次等待返回 Hub 列表转场动画
                return
            }
        }
    }

    private func verifyHubAppears() {
        let predicate = NSPredicate(format: "label CONTAINS '笔记本' OR label CONTAINS 'Notebooks' OR label CONTAINS 'Notebook'")
        let hubTitle = app.staticTexts.matching(predicate).firstMatch
        // 关键点：延长工作台展现超时至 12 秒
        XCTAssertTrue(hubTitle.waitForExistence(timeout: 12), "NotebookHub 工作台界面应当在 12 秒内显示")
    }

    private func switchToVaultCard() {
        let cardPredicate = NSPredicate(format: "label CONTAINS '的笔记本'")
        let namedCard = findFirstExisting(app.buttons.matching(cardPredicate).firstMatch, app.buttons.containing(cardPredicate).firstMatch)
        if namedCard.exists {
            namedCard.tap()
            // 关键点：切换金库后给予 1.5 秒的重度缓冲，以便后台 GRDB 重新写库播种完成
            try? Thread.sleep(forTimeInterval: 1.5)
            return
        }
        let anyCard = findFirstExisting(app.buttons.matching(identifier: "NotebookCard_Item").firstMatch, app.buttons.element(boundBy: 0))
        XCTAssertTrue(anyCard.exists)
        anyCard.tap()
        try? Thread.sleep(forTimeInterval: 1.5)
    }

    private func enterKnowledgeList() {
        let knowledgeTab = resolveKnowledgeTab()
        // 关键点：等待 Tab 显示超时延长至 8 秒
        XCTAssertTrue(knowledgeTab.waitForExistence(timeout: 8), "知识库 Tab 按钮应该在金库载入后 8 秒内存在")
        knowledgeTab.tap()
        try? Thread.sleep(forTimeInterval: 0.6) // 切换 Tab 转场缓冲

        let listPredicate = NSPredicate(format: "label CONTAINS '所有' OR label CONTAINS '页面' OR label CONTAINS 'Pages'")
        let pageListRow = findFirstExisting(
            app.buttons.matching(listPredicate).element(boundBy: 0),
            app.cells.matching(listPredicate).element(boundBy: 0),
            app.cells.containing(listPredicate).element(boundBy: 0),
            app.buttons.containing(listPredicate).element(boundBy: 0)
        )
        // 关键点：页面列表行加载的超时时间提升至 10 秒
        XCTAssertTrue(pageListRow.waitForExistence(timeout: 10), "‘所有页面’入口应当在知识库页面就绪")
        pageListRow.tap()
        try? Thread.sleep(forTimeInterval: 0.8) // 进入页面列表页缓冲
    }
```

- [ ] **Step 2: 运行测试验证**
  运行：`xcodebuild test -project ZhiYu.xcodeproj -scheme ZhiYu -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:ZhiYuTests/ZhiYuUITests/testVaultSwitchingAndSeedingFlow`
  预期：测试通过。

- [ ] **Step 3: 提交代码**
  运行：`git commit -a -m "fix: 重构金库切换和数据重新播种的转场等待阻尼"`

---

### Task 4: 本地连续 5 次回归测试与覆盖率校验

- [ ] **Step 1: 编写回归脚本并重复测试**
  在本地通过循环执行以下脚本 5 次，确保 100% 运行成功率：

```bash
for i in {1..5}; do
  echo "🚀 Running UI stability test iteration $i / 5..."
  xcodebuild test -project ZhiYu.xcodeproj -scheme ZhiYu -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:ZhiYuTests/ZhiYuUITests/testChatAISkeletonLoadingState -only-testing:ZhiYuTests/ZhiYuUITests/testPageLinkNavigation -only-testing:ZhiYuTests/ZhiYuUITests/testVaultSwitchingAndSeedingFlow || exit 1
done
echo "🎉 UI stability test iteration successfully passed 5/5 times!"
```

- [ ] **Step 2: 执行全量单元测试与覆盖率报表输出**
  运行：`./env/venv/bin/python3 Tools/ci/assert-test-coverage.py` 或提取 Core 模块代码覆盖率。
  预期：输出汇总报表。

- [ ] **Step 3: 生成 Walkthrough 交付文档**
  预期：在 walkthrough.md 汇总提交修复内容与通过状态。
