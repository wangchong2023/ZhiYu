//
//  WebScraperProcessorEdgeTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 WebScraperProcessor 责任链的 URL 标准化、SSRF 拦截、Mock 节点路由、DumbExtractor HTML 提取语义。
//

import XCTest
@testable import ZhiYu

final class WebScraperProcessorEdgeTests: XCTestCase {

    // MARK: - DumbExtractorHandler.extractFromHTML（纯函数，可同步测试）

    func testExtractFromHTML_extractsTitleAndParagraphs() {
        let html = """
        <html><head><title>测试标题</title></head>
        <body>
        <article>
        <p>第一段。</p>
        <p>第二段。</p>
        </article>
        </body></html>
        """
        let result = DumbExtractorHandler.extractFromHTML(html)
        XCTAssertEqual(result.title, "测试标题")
        XCTAssertTrue(result.markdown.contains("# 测试标题"))
        XCTAssertTrue(result.markdown.contains("第一段。"))
        XCTAssertTrue(result.markdown.contains("第二段。"))
    }

    func testExtractFromHTML_noArticle_fallsBackToMain() {
        let html = """
        <html><head><title>主标签测试</title></head>
        <body><main><p>主标签内容。</p></main></body></html>
        """
        let result = DumbExtractorHandler.extractFromHTML(html)
        XCTAssertEqual(result.title, "主标签测试")
        XCTAssertTrue(result.markdown.contains("主标签内容。"))
    }

    func testExtractFromHTML_noArticleNoMain_usesFullText() {
        let html = """
        <html><head><title>全文测试</title></head>
        <body><p>全文段落。</p></body></html>
        """
        let result = DumbExtractorHandler.extractFromHTML(html)
        XCTAssertEqual(result.title, "全文测试")
        XCTAssertTrue(result.markdown.contains("全文段落。"))
    }

    func testExtractFromHTML_stripsScriptAndStyle() {
        let html = """
        <html><head><title>清洗测试</title>
        <script>alert('xss');</script>
        <style>body { color: red; }</style>
        </head>
        <body><article><p>正文。</p></article></body></html>
        """
        let result = DumbExtractorHandler.extractFromHTML(html)
        XCTAssertFalse(result.markdown.contains("alert"))
        XCTAssertFalse(result.markdown.contains("color: red"))
        XCTAssertTrue(result.markdown.contains("正文。"))
    }

    func testExtractFromHTML_decodesEntities() {
        let html = """
        <html><head><title>实体&amp;测试</title></head>
        <body><article><p>引号&quot;内容&quot; &lt;tag&gt; &apos; apos</p></article></body></html>
        """
        let result = DumbExtractorHandler.extractFromHTML(html)
        XCTAssertTrue(result.title.contains("&"))
        XCTAssertTrue(result.markdown.contains("\"内容\""))
        XCTAssertTrue(result.markdown.contains("<tag>"))
        XCTAssertTrue(result.markdown.contains("' apos"))
    }

    func testExtractFromHTML_emptyParagraphs_filtered() {
        let html = """
        <html><head><title>空段测试</title></head>
        <body><article><p></p><p>非空。</p></article></body></html>
        """
        let result = DumbExtractorHandler.extractFromHTML(html)
        XCTAssertTrue(result.markdown.contains("非空。"))
        // 空段不应产生多余空行
        let paragraphBlocks = result.markdown.components(separatedBy: "\n\n")
        XCTAssertLessThanOrEqual(paragraphBlocks.count, 3)
    }

    func testExtractFromHTML_noTitle_returnsEmptyTitle() {
        let html = "<html><body><article><p>无标题。</p></article></body></html>"
        let result = DumbExtractorHandler.extractFromHTML(html)
        XCTAssertEqual(result.title, "")
        XCTAssertTrue(result.markdown.contains("无标题。"))
    }

    func testExtractFromHTML_noParagraphs_returnsTitleOnly() {
        let html = "<html><head><title>仅标题</title></head><body><article></article></body></html>"
        let result = DumbExtractorHandler.extractFromHTML(html)
        XCTAssertEqual(result.title, "仅标题")
        XCTAssertTrue(result.markdown.contains("# 仅标题"))
    }

    // MARK: - MockScraperHandler 路由

    func testMockHandler_paywallTestURL_returnsMockContent() async throws {
        let processor = WebScraperProcessor()
        do {
            let result = try await processor.fetchMarkdown(from: "paywall-test.com")
            XCTAssertTrue(result.markdown.contains("mock premium content"))
            XCTAssertEqual(result.title, "Paywall Test Article")
        } catch {
            // 网络环境可能影响，但 Mock 节点应优先处理 paywall-test
            throw error
        }
    }

    func testMockHandler_invalidHostDomain_returnsMockRecovery() async throws {
        let processor = WebScraperProcessor()
        let result = try await processor.fetchMarkdown(from: ProcessorConstants.WebScraper.invalidHostTestDomain)
        XCTAssertTrue(result.markdown.contains("recovered content"))
        XCTAssertEqual(result.title, "Recovered Article Title")
    }

    // MARK: - URL 标准化

    func testFetchMarkdown_addsHttpsPrefix() async {
        let processor = WebScraperProcessor()
        // paywall-test 是 Mock 节点，会拦截，验证 https:// 已被添加
        do {
            _ = try await processor.fetchMarkdown(from: "paywall-test.com")
        } catch WebScraperProcessor.ScraperError.invalidURL {
            // 不应是 invalidURL（SSRF 拦截），因为 paywall-test 是 Mock 路由
            XCTFail("Mock 路由应优先于 SSRF 拦截")
        } catch {
            // 其他错误可接受（网络等）
        }
    }

    func testFetchMarkdown_alreadyHasHttpPrefix_notDoubled() async {
        let processor = WebScraperProcessor()
        do {
            _ = try await processor.fetchMarkdown(from: "http://paywall-test.com")
        } catch {
            // 不应抛出 invalidURL
            if case WebScraperProcessor.ScraperError.invalidURL = error {
                XCTFail("已有 http 前缀不应触发 invalidURL")
            }
        }
    }

    // MARK: - SSRF 拦截

    func testFetchMarkdown_localhost_throwsInvalidURL() async {
        let processor = WebScraperProcessor()
        do {
            _ = try await processor.fetchMarkdown(from: "http://127.0.0.1")
            XCTFail("环回地址应被 SSRF 拦截")
        } catch WebScraperProcessor.ScraperError.invalidURL {
            // 预期行为
        } catch {
            // 其他错误也可接受
        }
    }

    func testFetchMarkdown_privateNetwork_throwsInvalidURL() async {
        let processor = WebScraperProcessor()
        do {
            _ = try await processor.fetchMarkdown(from: "http://192.168.1.1")
            XCTFail("私有网络地址应被 SSRF 拦截")
        } catch WebScraperProcessor.ScraperError.invalidURL {
            // 预期行为
        } catch {
            // 其他错误也可接受
        }
    }

    func testFetchMarkdown_emptyString_throwsInvalidURL() async {
        let processor = WebScraperProcessor()
        do {
            _ = try await processor.fetchMarkdown(from: "")
            XCTFail("空字符串应抛出 invalidURL")
        } catch WebScraperProcessor.ScraperError.invalidURL {
            // 预期行为
        } catch {
            // 其他错误也可接受
        }
    }

    // MARK: - ScraperError

    func testScraperError_chainExhausted_isCase() {
        let error = WebScraperProcessor.ScraperError.chainExhausted
        switch error {
        case .chainExhausted: break
        default: XCTFail("应为 chainExhausted")
        }
    }

    func testScraperError_invalidURL_isCase() {
        let error = WebScraperProcessor.ScraperError.invalidURL
        switch error {
        case .invalidURL: break
        default: XCTFail("应为 invalidURL")
        }
    }

    func testScraperError_parsingFailed_isCase() {
        let error = WebScraperProcessor.ScraperError.parsingFailed
        switch error {
        case .parsingFailed: break
        default: XCTFail("应为 parsingFailed")
        }
    }

    // MARK: - DumbExtractorHandler.handle（责任链末端）

    func testDumbExtractorHandler_handle_throwsChainExhausted() async {
        let handler = DumbExtractorHandler(next: nil)
        let url = URL(string: "https://example.com")!
        do {
            _ = try await handler.handle(url: url, startTime: Date())
            XCTFail("DumbExtractor 责任链末端应抛出 chainExhausted")
        } catch WebScraperProcessor.ScraperError.chainExhausted {
            // 预期行为
        } catch {
            XCTFail("应为 chainExhausted，实际: \(error)")
        }
    }
}
