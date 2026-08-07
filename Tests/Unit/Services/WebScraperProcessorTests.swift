//
//  WebScraperProcessorTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/03.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：验证网页内容级联抓取算法、付费墙检测重定向绕过与兜底恢复机制。
//

import XCTest
@testable import ZhiYu

@MainActor
final class WebScraperProcessorTests: XCTestCase {
    
    private var scraper: WebScraperProcessor!
    
    override func setUp() async throws {
        try await super.setUp()
        scraper = WebScraperProcessor()
    }
    
    override func tearDown() async throws {
        scraper = nil
        try await super.tearDown()
    }
    
    /// 验证测试付费墙网址（http://paywall-test.com）的直接拦截与绕过机制 (TC-ING-03)
    func testPaywallDirectBypass() async throws {
        let testURL = "http://paywall-test.com"
        
        let (markdown, title) = try await scraper.fetchMarkdown(from: testURL)
        
        // 验证标题和正文正确提取自 Level 4 的模拟付费墙数据
        XCTAssertEqual(title, "Paywall Test Article")
        XCTAssertTrue(markdown.contains("This is mock premium content bypass success."))
        XCTAssertTrue(markdown.contains("Second paragraph of the premium article."))
        XCTAssertTrue(markdown.contains("# Paywall Test Article"))
    }
    
    /// 验证当 Jina API 与直连抓取都失败（模拟 Jina 挂掉）时，级联自愈落入 Level 4 兜底备份模板 (TC-ING-03)
    func testCascadeGrabDisasterRecovery() async throws {
        // 使用一个由于域名无法解析必然失败的无效地址
        let failedURL = "http://\(ProcessorConstants.WebScraper.invalidHostTestDomain)"

        let (markdown, title) = try await scraper.fetchMarkdown(from: failedURL)
        
        // 验证系统没有抛出异常，而是自愈性落入 Level 4 的灾备恢复模板
        XCTAssertEqual(title, "Recovered Article Title")
        XCTAssertTrue(markdown.contains("This is recovered content. The website blocked automated scraping"))
        XCTAssertTrue(markdown.contains("# Recovered Article Title"))
    }
}
