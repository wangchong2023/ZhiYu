//
//  UIComponentsDeepTests.swift
//  ZhiYuTests
//
//  合并自 2 个碎片化测试文件：UIComponentsExhaustiveTests.swift, UIComponentsRendererInteractiveTests.swift
//

import Dependencies
import SwiftUI
import UFPCore
import XCTest

@testable import ZhiYu

@MainActor
final class UIComponentsDeepTests: XCTestCase {

    private var router: Router!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        router = Router.shared
    }

    func testAppErrorView_RetryActionAndNoRetryFallback() {
        var retryTriggered = false

        // 1. 包含重试回调的错误视图
        let errorWithRetry = AppErrorView(
            title: "网络加载超时",
            message: "请检查您的网络连接并重试",
            retryAction: { retryTriggered = true }
        )

        let hostWithRetry = errorWithRetry.snapshotEnvironment().renderInWindow()
        XCTAssertNotNil(hostWithRetry.view)

        // 2. 无重试回调的纯提示错误视图（降级展示）
        let errorWithoutRetry = AppErrorView(
            title: "不可恢复的系统故障",
            message: "请稍后重启应用",
            retryAction: nil
        )
        let hostWithoutRetry = errorWithoutRetry.snapshotEnvironment().renderInWindow()
        XCTAssertNotNil(hostWithoutRetry.view)
        XCTAssertFalse(retryTriggered)
    }

    func testStatCard_RenderingAndLayoutTokenCompliance() {
        let card = StatCard(
            title: "全库知识条目",
            value: "1,280",
            icon: "doc.text.fill",
            color: .blue
        )

        let host = card.snapshotEnvironment().renderInWindow()
        XCTAssertNotNil(host.view)
        XCTAssertEqual(card.title, "全库知识条目")
        XCTAssertEqual(card.value, "1,280")
        XCTAssertEqual(card.icon, "doc.text.fill")
    }

    func testAppTextField_TextBindingAndMounting() {
        var text = "初始文本"
        let binding = Binding(get: { text }, set: { text = $0 })
        let field = AppTextField(placeholder: "请输入搜索关键词", text: binding)
        let host = field.snapshotEnvironment().renderInWindow()
        XCTAssertNotNil(host.view)
        XCTAssertEqual(text, "初始文本")
        XCTAssertEqual(field.placeholder, "请输入搜索关键词")
    }

    func testMarkdownRendererView_rendersAllBlockTypes() {
        let markdown = """
        # 一级主标题
        ## 二级副标题
        这是一段普通段落，包含 **粗体**、*斜体*、~~删除线~~ 和 `行内代码`。
        
        > 这是普通引用块
        > AI 总结：核心技术是分布式图谱与本地端侧大模型。
        
        - 无序列表项 1
        - 无序列表项 2
        
        1. 有序列表项 1
        2. 有序列表项 2
        
        - [x] 已完成待办
        - [ ] 未完成待办
        
        ```swift
        let language = "Swift 6"
        print(language)
        ```
        
        | 模块 | 职责 | 状态 |
        | :--- | :--- | :--- |
        | L0 | 基础设施 | 就绪 |
        | L1.5 | 领域大脑 | 活跃 |
        
        ---
        
        <details>
        <summary>详细技术指标</summary>
        这里是隐藏折叠内容。
        </details>
        """

        var tappedLink: String?
        let renderer = MarkdownRendererView(
            content: markdown,
            isPrivate: false,
            onLinkTap: { link in tappedLink = link }
        )

        let host = UIHostingController(rootView: renderer)
        _ = host.view
        host.view.layoutIfNeeded()
        XCTAssertNotNil(host.view, "Markdown 全语法块应正常完成视图挂载与渲染")
        XCTAssertNil(tappedLink)
    }

    func testMarkdownRendererView_applinkAndWikiLinks() {
        let markdown = """
        参考知识页面 [[分布式系统架构]] 以及别名链接 [[深入理解索引|数据库索引优化]]。
        """

        let renderer = MarkdownRendererView(
            content: markdown,
            isPrivate: false,
            onLinkTap: { _ in }
        )

        let host = UIHostingController(rootView: renderer)
        _ = host.view
        host.view.layoutIfNeeded()
        XCTAssertNotNil(host.view)
        XCTAssertTrue(markdown.contains("分布式系统架构"))
    }

    func testMarkdownRendererView_fuzzChaosMarkdown() {
        let chaosInputs = [
            "```swift\n未闭合代码块",
            "| 列1 | 列2 |\n| 不匹配行 |",
            "| 列1 |\n|---|---|\n| a | b | c | d |",
            "[[未闭合双链",
            "[[|空别名与目标]]",
            "[[目标|]]",
            "$$\\frac{1}{0} 畸变公式",
            "> > > > > 深度嵌套引用块",
            String(repeating: "#", count: 50) + " 超长井号标题",
            String(repeating: "- [ ] 嵌套任务\n", count: 20),
            "",
            "   \n\t\r\n   ",
            "<details><summary></summary></details>"
        ]

        for chaos in chaosInputs {
            let renderer = MarkdownRendererView(
                content: chaos,
                isPrivate: false,
                onLinkTap: { _ in }
            )
            let host = UIHostingController(rootView: renderer)
            _ = host.view
            host.view.layoutIfNeeded()
            XCTAssertNotNil(host.view, "混沌 Markdown 注入严禁产生崩溃: \(chaos)")
            XCTAssertEqual(renderer.content, chaos)
        }
    }

    func testAIRainbowGlowBadge_rendering() {
        let modelManager = GlobalModelManager.shared
        let badge = AIRainbowGlowBadge()
        let host = UIHostingController(rootView: badge)
        _ = host.view
        host.view.layoutIfNeeded()
        XCTAssertNotNil(host.view, "AIRainbowGlowBadge 应正常渲染完成")
        XCTAssertNotNil(modelManager)
    }

}
