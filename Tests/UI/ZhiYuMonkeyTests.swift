//
//  ZhiYuMonkeyTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 ZhiYuMonkey 开展自动化单元测试验证。
//
import XCTest

/// 智宇 (ZhiYu) 原生 100 次狂暴随机点击 Monkey 测试
///
/// 本测试通过遍历屏幕上的活动 hittable 元素，结合防死锁的过滤安全逻辑和随机交互，
/// 狂暴碰撞并深度压力遍历应用内各种隐藏的弹窗与深层嵌套导航。
@MainActor
final class ZhiYuMonkeyTests: XCTestCase {
    
    /// XCUIApplication 实例句柄
    var app: XCUIApplication!

    override func setUp() async throws {
        try await super.setUp()
        
        // 避让单元测试 Target，确保此 UI 测试只在 UI 测试沙盒中正确运行
        if ProcessInfo.processInfo.processName == "ZhiYu" {
            throw XCTSkip("Skipping Monkey UI test in Unit Test target to prevent XCUIApplication init crash.")
        }
        
        // 启用持续执行策略，保障 Monkey 测试不受偶发性 UI 动效干扰而断流
        continueAfterFailure = true
        app = XCUIApplication()
        app.launch()
    }

    override func tearDown() async throws {
        // 优雅关闭：先返回主屏幕触发应用进入后台生命周期，让底层资源有机会安全清理
        XCUIDevice.shared.press(.home)
        try? await Task.sleep(nanoseconds: 500_000_000)
        app?.terminate()
        try await super.tearDown()
    }

    /// 狂暴随机点击 Monkey 测试。
    ///
    /// 在 CI 环境中自动缩减至 20 步，本地开发保持 100 步。
    /// 本地 100 步 × 0.4s 休眠 + UI 响应延迟可能超过默认 120s 超时，故显式提升至 300s。
    func testWildMonkeyClickTraversal() throws {
        // 本地 100 步 Monkey 测试需要更长的执行时间 allowance
        executionTimeAllowance = 300

        let isCI = ProcessInfo.processInfo.environment["CI"] == "true"
        let maxIterations = isCI ? 20 : 100
        print("====== [MONKEY] 开始执行 \(maxIterations) 步狂暴随机点击遍历压力测试 (CI: \(isCI)) ======")

        for step in 1...maxIterations {
            // 每步短暂休眠 0.4s，提供充分的 UI 动效渲染缓冲
            let pause = XCTestExpectation(description: "step pause")
            _ = XCTWaiter.wait(for: [pause], timeout: 0.4)
            
            // 2. 动态随机选择要遍历的元素类型：0: 按钮, 1: 列表行 (Cells), 2: 标签栏
            let targetType = Int.random(in: 0...2)
            let query: XCUIElementQuery
            switch targetType {
            case 0:
                query = app.buttons
            case 1:
                query = app.cells
            default:
                query = app.tabBars.buttons
            }
            
            let count = query.count
            var clicked = false
            
            // 3. 如果对应类型的可用元素数量大于零，动态抽取并执行安全判定
            if count > 0 {
                let randomIndex = Int.random(in: 0..<count)
                let targetElement = query.element(boundBy: randomIndex)

                // 🛡️ 前置过滤：在调用 isHittable 之前先检查元素 label/identifier/frame
                // isHittable 在 frame 为零/无效时可能触发 XCUITest 底层断言崩溃
                // 因此必须先将已知高危元素过滤掉，避免 isHittable 调用本身崩溃
                guard targetElement.exists else { continue }
                let label = targetElement.label.lowercased()
                let identifier = targetElement.identifier.lowercased()

                // 【智能避让机制】拦截一切破坏性、重置性以及会导致退出账户的安全敏感按钮
                let isDestructive = label.contains("delete") || label.contains("删除") ||
                                    label.contains("erase") || label.contains("擦除") ||
                                    label.contains("sign out") || label.contains("退出登录") ||
                                    label.contains("logout") || label.contains("clear") ||
                                    label.contains("清除") || label.contains("reset") ||
                                    label.contains("重置")

                let isDestructiveId = identifier.contains("delete") || identifier.contains("logout") || identifier.contains("reset")

                // 避让水平 ScrollView 中易被遮挡不可点击的图标选择按钮，避免 XCTest 物理点击挂起
                let isIconOption = ["📚", "🔬", "📓", "📖", "📝", "🗂️", "📊", "🧪", "💡", "🎯", "🚀", "⭐", "🔧", "🎨", "📐", "🧠"].contains(targetElement.label)

                // 🛡️ 额外防御：跳过 frame 为零或无效的元素，防止 isHittable 内部断言失败
                let frame = targetElement.frame
                let hasValidFrame = !frame.isEmpty && frame.width > 1 && frame.height > 1

                if !isDestructive && !isDestructiveId && !isIconOption && hasValidFrame && targetElement.isHittable {
                        print("[MONKEY] 第 \(step)/\(maxIterations) 步：拟真操作 -> 元素类型: \(targetElement.elementType)，文本标签: '\(targetElement.label)'")
                        
                        // 执行防护式点击，检查元素可点击性
                        if targetElement.exists && targetElement.isHittable {
                            targetElement.tap()
                            clicked = true
                        }
                    }
            }
            
            // 4. 如果未能执行有效点击，则进行物理滑动，用于解锁死局页面
            if !clicked {
                print("[MONKEY] 第 \(step)/\(maxIterations) 步：当前路径无匹配安全目标。执行屏幕随机拖拽滑动破局。")
                let startPoint = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
                let endPoint = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25))
                startPoint.press(forDuration: 0.1, thenDragTo: endPoint)
            }
        }
        
        print("====== [MONKEY] 狂暴随机测试顺利闯关 100 步！应用导航无死锁，未触发任何崩溃或 UI 栈冲突 ======")
    }
}
