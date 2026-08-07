//
//  WebScraperProcessorChainTests.swift
//  ZhiYu
//
//  系统层级：[Shared] 测试层
//  核心职责：通过 URLProtocol 拦截验证 WebScraperProcessor 责任链的 Jina/Googlebot/Archive 成功/失败/降级分支。
//

import XCTest
import UFPCore
@testable import ZhiYu

// MARK: - WebScraper 专用 URLProtocol 拦截器

final class WebScraperMockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var jinaResponse: (Int, Data)?
    nonisolated(unsafe) static var directResponse: (Int, Data)?
    nonisolated(unsafe) static var archiveResponse: (Int, Data)?
    nonisolated(unsafe) static var jinaError: Error?
    nonisolated(unsafe) static var directError: Error?
    nonisolated(unsafe) static var archiveError: Error?
    nonisolated(unsafe) static var requestCount: Int = 0

    static func reset() {
        jinaResponse = nil
        directResponse = nil
        archiveResponse = nil
        jinaError = nil
        directError = nil
        archiveError = nil
        requestCount = 0
    }

    override class func canInit(with request: URLRequest) -> Bool {
        guard let host = request.url?.host else { return false }
        return host == "r.jina.ai" ||
               host == "web.archive.org" ||
               host == "scraper-test.example.com"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        WebScraperMockURLProtocol.requestCount += 1
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        let host = url.host ?? ""

        if host == "r.jina.ai" {
            handleResponse(url: url, response: WebScraperMockURLProtocol.jinaResponse, error: WebScraperMockURLProtocol.jinaError)
        } else if host == "web.archive.org" {
            handleResponse(url: url, response: WebScraperMockURLProtocol.archiveResponse, error: WebScraperMockURLProtocol.archiveError)
        } else {
            handleResponse(url: url, response: WebScraperMockURLProtocol.directResponse, error: WebScraperMockURLProtocol.directError)
        }
    }

    private func handleResponse(url: URL, response: (Int, Data)?, error: Error?) {
        if let error = error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        guard let (statusCode, body) = response else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let httpResponse = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "text/html", "Content-Length": "\(body.count)"]
        )
        guard let httpResponse = httpResponse else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

// MARK: - WebScraperProcessor 责任链测试

final class WebScraperProcessorChainTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        WebScraperMockURLProtocol.reset()
        URLProtocol.registerClass(WebScraperMockURLProtocol.self)
    }

    override func tearDown() async throws {
        WebScraperMockURLProtocol.reset()
        URLProtocol.unregisterClass(WebScraperMockURLProtocol.self)
        try await super.tearDown()
    }

    // MARK: - Jina 成功

    func testJinaHandlerReturnsMarkdownOnSuccess() async throws {
        let jinaContent = "# Test Article Title\n\nThis is the markdown content from Jina."
        WebScraperMockURLProtocol.jinaResponse = (200, Data(jinaContent.utf8))

        let handler = JinaScraperHandler(next: nil)
        let url = URL(string: "https://scraper-test.example.com/page1")!
        let result = try await handler.handle(url: url, startTime: Date())

        XCTAssertEqual(result.title, "Test Article Title")
        XCTAssertTrue(result.markdown.contains("This is the markdown content from Jina."))
    }

    // MARK: - Jina 失败 → 降级到 next

    func testJinaHandlerFallsToNextOnFailure() async throws {
        WebScraperMockURLProtocol.jinaError = URLError(.notConnectedToInternet)

        let nextHandler = NextCaptureHandler()
        let handler = JinaScraperHandler(next: nextHandler)
        let url = URL(string: "https://scraper-test.example.com/page2")!

        _ = try await handler.handle(url: url, startTime: Date())
        XCTAssertTrue(nextHandler.called, "Jina 失败时应降级到 next handler")
    }

    // MARK: - Jina 非 200 状态码 → 降级

    func testJinaHandlerFallsToNextOnNon200() async throws {
        WebScraperMockURLProtocol.jinaResponse = (403, Data("Forbidden".utf8))

        let nextHandler = NextCaptureHandler()
        let handler = JinaScraperHandler(next: nextHandler)
        let url = URL(string: "https://scraper-test.example.com/page3")!

        _ = try await handler.handle(url: url, startTime: Date())
        XCTAssertTrue(nextHandler.called, "Jina 返回 403 时应降级到 next handler")
    }

    // MARK: - Googlebot 成功

    func testGooglebotHandlerReturnsMarkdownOnSuccess() async throws {
        let html = "<html><head><title>Googlebot Test</title></head><body><article><p>Content from Googlebot.</p></article></body></html>"
        WebScraperMockURLProtocol.directResponse = (200, Data(html.utf8))

        let handler = GooglebotScraperHandler(next: nil)
        let url = URL(string: "https://scraper-test.example.com/page4")!
        let result = try await handler.handle(url: url, startTime: Date())

        XCTAssertEqual(result.title, "Googlebot Test")
        XCTAssertTrue(result.markdown.contains("Content from Googlebot."))
    }

    // MARK: - Googlebot 403 付费墙 → 降级

    func testGooglebotHandlerFallsToNextOn403() async throws {
        WebScraperMockURLProtocol.directResponse = (403, Data("Forbidden".utf8))

        let nextHandler = NextCaptureHandler()
        let handler = GooglebotScraperHandler(next: nextHandler)
        let url = URL(string: "https://scraper-test.example.com/page5")!

        do {
            _ = try await handler.handle(url: url, startTime: Date())
        } catch {
            // 403 会抛出 networkError，但应先降级到 next
        }
        XCTAssertTrue(nextHandler.called, "Googlebot 返回 403 时应降级到 next handler")
    }

    // MARK: - Archive 成功

    func testArchiveHandlerReturnsMarkdownOnSuccess() async throws {
        let html = "<html><head><title>Archived Page</title></head><body><article><p>Archived content.</p></article></body></html>"
        WebScraperMockURLProtocol.archiveResponse = (200, Data(html.utf8))

        let handler = ArchiveScraperHandler(next: nil)
        let url = URL(string: "https://scraper-test.example.com/page6")!
        let result = try await handler.handle(url: url, startTime: Date())

        XCTAssertEqual(result.title, "Archived Page")
        XCTAssertTrue(result.markdown.contains("Archived content."))
    }

    // MARK: - Archive 失败 → 降级

    func testArchiveHandlerFallsToNextOnFailure() async throws {
        WebScraperMockURLProtocol.archiveError = URLError(.timedOut)

        let nextHandler = NextCaptureHandler()
        let handler = ArchiveScraperHandler(next: nextHandler)
        let url = URL(string: "https://scraper-test.example.com/page7")!

        _ = try await handler.handle(url: url, startTime: Date())
        XCTAssertTrue(nextHandler.called, "Archive 失败时应降级到 next handler")
    }

    // MARK: - cleanHTMLTags

    func testCleanHTMLTagsStripsAllTags() {
        let result = DumbExtractorHandler.cleanHTMLTags("<p>Hello <b>World</b></p>")
        XCTAssertEqual(result, "Hello World")
    }

    func testCleanHTMLTagsDecodesEntities() {
        let result = DumbExtractorHandler.cleanHTMLTags("&quot;quote&quot; &amp; amp")
        XCTAssertEqual(result, "\"quote\" & amp")
    }

    func testCleanHTMLTagsHandlesEmptyString() {
        XCTAssertEqual(DumbExtractorHandler.cleanHTMLTags(""), "")
    }

    func testCleanHTMLTagsTrimsWhitespace() {
        let result = DumbExtractorHandler.cleanHTMLTags("  <p>  trimmed  </p>  ")
        XCTAssertEqual(result, "trimmed")
    }
}

// MARK: - 辅助 Handler

private final class NextCaptureHandler: WebScraperHandler, @unchecked Sendable {
    var next: WebScraperHandler?
    var called = false

    func handle(url: URL, startTime: Date) async throws -> (markdown: String, title: String) {
        called = true
        return ("next-handler-content", "Next Handler")
    }
}
