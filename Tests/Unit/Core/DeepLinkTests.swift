//
//  DeepLinkTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 DeepLink 开展自动化单元测试验证。
//
import XCTest
@testable import ZhiYu

// MARK: - 深度链接与快捷路由单元测试
@MainActor
final class DeepLinkTests: XCTestCase {
    
    private var service: DeepLinkService!
    
    override func setUp() async throws {
        try await super.setUp()
        service = DeepLinkService()
        IntentRateLimiter.shared.reset()
    }
    
    override func tearDown() async throws {
        service = nil
        try await super.tearDown()
    }
    
    // MARK: - 1. URL Scheme 基础解析测试
    /// 验证各类合法的 zhiyu:// 协议深度链接能被成功捕获并解析为正确的路由状态
    func testHandleURL_ValidSchemes() throws {
        // 测试案例 1: 物理页面 ID 快速跳转 (zhiyu://page?id=UUID)
        let testUUID = UUID()
        let pageIdURL = try XCTUnwrap(URL(string: "zhiyu://page?id=\(testUUID.uuidString)"))
        XCTAssertTrue(service.handleURL(pageIdURL))
        
        let link1 = service.consumeDeepLink()
        guard case .openPage(let parsedID) = link1 else {
            XCTFail("无法解析 zhiyu://page?id 深度链接"); return
        }
        XCTAssertEqual(parsedID, testUUID)
        
        // 测试案例 2: 页面标题跳转 (zhiyu://page?title=SwiftUI)
        let pageTitleURL = try XCTUnwrap(URL(string: "zhiyu://page?title=SwiftUI%20Guide"))
        XCTAssertTrue(service.handleURL(pageTitleURL))
        
        let link2 = service.consumeDeepLink()
        guard case .openPageByTitle(let parsedTitle) = link2 else {
            XCTFail("无法解析 zhiyu://page?title 深度链接"); return
        }
        XCTAssertEqual(parsedTitle, "SwiftUI Guide")
        
        // 测试案例 3: 全局搜索关键字拉起 (zhiyu://search?q=AI)
        let searchURL = try XCTUnwrap(URL(string: "zhiyu://search?q=%E6%99%BA%E8%83%BD%E5%88%86%E5%9D%97"))
        XCTAssertTrue(service.handleURL(searchURL))
        
        let link3 = service.consumeDeepLink()
        guard case .search(let parsedQuery) = link3 else {
            XCTFail("无法解析 zhiyu://search 深度链接"); return
        }
        XCTAssertEqual(parsedQuery, "智能分块")
    }
    
    // MARK: - 2. 主页面 Tab 栏快速切换测试
    /// 验证快速拉起 Ingest、Graph、Chat 等不同核心功能模块的 DeepLink 跳转
    func testHandleURL_TabShortcuts() throws {
        // 摄入 Ingest 面板
        let ingestURL = try XCTUnwrap(URL(string: "zhiyu://ingest"))
        XCTAssertTrue(service.handleURL(ingestURL))
        guard case .ingest = service.consumeDeepLink() else {
            XCTFail("无法解析 zhiyu://ingest 深度链接"); return
        }
        
        // 关系图谱 Graph 面板
        let graphURL = try XCTUnwrap(URL(string: "zhiyu://graph"))
        XCTAssertTrue(service.handleURL(graphURL))
        guard case .graph = service.consumeDeepLink() else {
            XCTFail("无法解析 zhiyu://graph 深度链接"); return
        }
        
        // AI 对话 Chat 面板
        let chatURL = try XCTUnwrap(URL(string: "zhiyu://chat"))
        XCTAssertTrue(service.handleURL(chatURL))
        guard case .chat = service.consumeDeepLink() else {
            XCTFail("无法解析 zhiyu://chat 深度链接"); return
        }
    }
    
    // MARK: - 3. 非法及降级防护测试
    /// 验证当面对非法 Scheme (如 http, wikilink 等) 或缺失关键参数时，看门狗协议拦截是否能安全降级并丢弃
    func testHandleURL_InvalidAndFallback() throws {
        // 拦截非 zhiyu 专属协议 (即使包含了相同的主机或参数)
        let badSchemeURL = try XCTUnwrap(URL(string: "wikilink://page?title=Test"))
        XCTAssertFalse(service.handleURL(badSchemeURL))
        XCTAssertNil(service.consumeDeepLink())
        
        // 拦截缺失关键参数的链接
        let missingParamsURL = try XCTUnwrap(URL(string: "zhiyu://page"))
        XCTAssertFalse(service.handleURL(missingParamsURL))
        
        // 拦截完全未定义的未知主机入口
        let unknownHostURL = try XCTUnwrap(URL(string: "zhiyu://unknown_path"))
        XCTAssertFalse(service.handleURL(unknownHostURL))
    }
    
    // MARK: - 4. Spotlight 全局搜索集成测试
    /// 验证从 iOS 系统 Spotlight 聚焦搜索中点击卡片拉起 App 时，能正确解析出 userActivity 对应的页面 ID 并执行无缝转场
    func testHandleSpotlightActivity() {
        let testUUID = UUID()
        let activity = NSUserActivity(activityType: "com.zhiyu.app.openPage")
        activity.userInfo = ["pageID": testUUID.uuidString]
        
        // 触发 Spotlight 动作解析
        XCTAssertTrue(service.handleSpotlightActivity(activity))
        
        // 验证消费挂起的 DeepLink 是否与 Spotlight 的 ID 完全对齐
        let link = service.consumeDeepLink()
        guard case .openPage(let parsedID) = link else {
            XCTFail("Spotlight 路由无法被正确识别 and 提取"); return
        }
        XCTAssertEqual(parsedID, testUUID)
        
        // 验证单次消费后挂起链接被清空，防止多次误触发
        XCTAssertNil(service.consumeDeepLink())
    }
    
    // MARK: - 5. 桌面静态小组件专属跳转解析测试
    /// TC-DEE-05: 验证从小组件高频入口点击时派生的专属协议（新建卡片、空搜索）解析安全性
    func testHandleURL_WidgetSpecificDeepLinks() throws {
        // 测试案例 1: 桌面“New Card”快捷小按钮跳转 (zhiyu://create)
        let createURL = try XCTUnwrap(URL(string: "zhiyu://create"))
        XCTAssertTrue(service.handleURL(createURL), "新建卡片深度链接应解析成功")
        
        let link1 = service.consumeDeepLink()
        guard case .create = link1 else {
            XCTFail("无法安全解析小组件 zhiyu://create 快捷新建动作"); return
        }
        
        // 测试案例 2: 桌面“Search”按钮未携带关键字跳转 (zhiyu://search)
        let emptySearchURL = try XCTUnwrap(URL(string: "zhiyu://search"))
        XCTAssertTrue(service.handleURL(emptySearchURL), "无参数搜索深度链接应解析成功并自动降级防灾")
        
        let link2 = service.consumeDeepLink()
        guard case .search(let query) = link2 else {
            XCTFail("无法安全解析小组件 zhiyu://search 宽限空搜索动作"); return
        }
        XCTAssertTrue(query.isEmpty, "宽限降级后的搜索词应安全设置为空字符串")
    }
    
    // MARK: - 6. 意图总线高并发限流熔断测试 (TC-DEE-06)
    /// 验证 10Hz 滑动窗口限流器对于外部高频调用/恶意高并发写入的熔断保护机制
    func testHandleURL_RateLimiterBypassAndBlock() async throws {
        // 重置限流器状态
        IntentRateLimiter.shared.reset()
        
        let testURL = try XCTUnwrap(URL(string: "zhiyu://chat"))
        
        // 1. 连续触发 10 次 handleURL（应当全部允许）
        for i in 1...10 {
            XCTAssertTrue(service.handleURL(testURL), "第 \(i) 次调用不应被限流")
            _ = service.consumeDeepLink()
        }
        
        // 2. 第 11 次调用，应当触发限流直接熔断拒绝
        XCTAssertFalse(service.handleURL(testURL), "第 11 次调用应当被限流熔断")
        XCTAssertNil(service.consumeDeepLink())
        
        // 3. 高并发测试：启动并发 Task 并发请求，验证限流器的绝对可靠性 (TC-DEE-06)
        IntentRateLimiter.shared.reset()
        
        let concurrencyCount = 20
        var results: [Bool] = []
        
        await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<concurrencyCount {
                group.addTask {
                    return IntentRateLimiter.shared.request()
                }
            }
            for await res in group {
                results.append(res)
            }
        }
        
        // 验证允许的次数恰好等于 10，其余 10 次均被拒绝
        let allowedCount = results.filter { $0 == true }.count
        let blockedCount = results.filter { $0 == false }.count
        
        XCTAssertEqual(allowedCount, 10, "并发环境下应当仅允许 10 次请求")
        XCTAssertEqual(blockedCount, 10, "并发环境下应当拦截并拒绝 10 次请求")
    }
}
