//
//  ExtractorAndChatHistoryPureLogicTests.swift
//  ZhiYu
//
//  Created by CodeFree on 2026/08/07.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 HTML 提取器、图片 URL 提取器与聊天记录持久化的正确性。
//

import XCTest
import Foundation
import UFPCore
@testable import ZhiYu

// MARK: - DumbExtractorHandler HTML 提取器

final class DumbExtractorHandlerPureLogicTests: XCTestCase {

    // MARK: - extractFromHTML

    func testExtractTitle() {
        let html = "<html><head><title>Test Page</title></head><body><p>Content</p></body></html>"
        let (markdown, title) = DumbExtractorHandler.extractFromHTML(html)
        XCTAssertEqual(title, "Test Page")
        XCTAssertTrue(markdown.contains("# Test Page"))
    }

    func testExtractArticleParagraphs() {
        let html = """
        <html><head><title>Article Page</title></head>
        <body>
        <article>
        <p>First paragraph</p>
        <p>Second paragraph</p>
        </article>
        </body></html>
        """
        let (markdown, title) = DumbExtractorHandler.extractFromHTML(html)
        XCTAssertEqual(title, "Article Page")
        XCTAssertTrue(markdown.contains("First paragraph"))
        XCTAssertTrue(markdown.contains("Second paragraph"))
    }

    func testExtractMainFallback() {
        let html = """
        <html><head><title>Main Page</title></head>
        <body>
        <main>
        <p>Main content</p>
        </main>
        </body></html>
        """
        let (markdown, _) = DumbExtractorHandler.extractFromHTML(html)
        XCTAssertTrue(markdown.contains("Main content"))
    }

    func testExtractFullTextFallback() {
        let html = """
        <html><head><title>Full Text</title></head>
        <body>
        <p>Body paragraph</p>
        </body></html>
        """
        let (markdown, _) = DumbExtractorHandler.extractFromHTML(html)
        XCTAssertTrue(markdown.contains("Body paragraph"))
    }

    func testScriptStyleRemoved() {
        let html = """
        <html><head><title>Test</title>
        <script>alert('xss')</script>
        <style>body { color: red; }</style>
        </head>
        <body>
        <p>Visible content</p>
        </body></html>
        """
        let (markdown, _) = DumbExtractorHandler.extractFromHTML(html)
        XCTAssertFalse(markdown.contains("alert('xss')"))
        XCTAssertFalse(markdown.contains("color: red"))
        XCTAssertTrue(markdown.contains("Visible content"))
    }

    func testEmptyParagraphsFiltered() {
        let html = """
        <html><head><title>Test</title></head>
        <body>
        <p></p>
        <p>Real content</p>
        <p>   </p>
        </body></html>
        """
        let (markdown, _) = DumbExtractorHandler.extractFromHTML(html)
        XCTAssertTrue(markdown.contains("Real content"))
    }

    func testNoTitleEmpty() {
        let html = "<html><body><p>Content only</p></body></html>"
        let (markdown, title) = DumbExtractorHandler.extractFromHTML(html)
        XCTAssertEqual(title, "")
        XCTAssertTrue(markdown.contains("Content only"))
    }

    func testNoParagraphsOnlyTitle() {
        let html = "<html><head><title>Empty</title></head><body></body></html>"
        let (markdown, title) = DumbExtractorHandler.extractFromHTML(html)
        XCTAssertEqual(title, "Empty")
        XCTAssertEqual(markdown, "# Empty\n\n")
    }

    func testEmptyHTML() {
        let (markdown, title) = DumbExtractorHandler.extractFromHTML("")
        XCTAssertEqual(title, "")
        XCTAssertTrue(markdown.contains("# "))
    }

    // MARK: - cleanHTMLTags

    func testCleanTagsRemovesAll() {
        let result = DumbExtractorHandler.cleanHTMLTags("<p>Hello <b>World</b></p>")
        XCTAssertEqual(result, "Hello World")
    }

    func testCleanTagsDecodesEntities() {
        let result = DumbExtractorHandler.cleanHTMLTags("&quot;quote&quot; &amp; &lt;tag&gt;")
        XCTAssertEqual(result, "\"quote\" & <tag>")
    }

    func testCleanTagsEmpty() {
        let result = DumbExtractorHandler.cleanHTMLTags("")
        XCTAssertEqual(result, "")
    }

    func testCleanTagsPlainText() {
        let result = DumbExtractorHandler.cleanHTMLTags("plain text")
        XCTAssertEqual(result, "plain text")
    }

    func testCleanTagsTrimsWhitespace() {
        let result = DumbExtractorHandler.cleanHTMLTags("  <p>  text  </p>  ")
        XCTAssertEqual(result, "text")
    }
}

// MARK: - ImageExtractor 图片 URL 提取

final class ImageExtractorPureLogicTests: XCTestCase {

    let extractor = ImageExtractor()

    // MARK: - parseImageURLs

    func testParseSingleImage() {
        let html = #"<img src="https://example.com/image.jpg">"#
        let urls = extractor.parseImageURLs(from: html, baseURL: nil)
        XCTAssertEqual(urls.count, 1)
        XCTAssertEqual(urls[0].absoluteString, "https://example.com/image.jpg")
    }
    func testParseSingleQuoteSrc() {
        let html = #"<img src='https://example.com/single.jpg'>"#
        let urls = extractor.parseImageURLs(from: html, baseURL: nil)
        XCTAssertEqual(urls.count, 1)
        XCTAssertEqual(urls[0].absoluteString, "https://example.com/single.jpg")
    }

    func testParseRelativeURL() {
        let html = #"<img src="/images/photo.jpg">"#
        let baseURL = URL(string: "https://example.com")
        let urls = extractor.parseImageURLs(from: html, baseURL: baseURL)
        XCTAssertEqual(urls.count, 1)
        XCTAssertEqual(urls[0].absoluteString, "https://example.com/images/photo.jpg")
    }

    func testParseSVGFilted() {
        let html = #"<img src="https://example.com/icon.svg">"#
        let urls = extractor.parseImageURLs(from: html, baseURL: nil)
        XCTAssertTrue(urls.isEmpty)
    }

    func testParseInternalIPBlocked() {
        let html = #"<img src="http://10.0.0.1/secret.jpg">"#
        let urls = extractor.parseImageURLs(from: html, baseURL: nil)
        XCTAssertTrue(urls.isEmpty)
    }

    func testParseNoImages() {
        let html = "<p>No images here</p>"
        let urls = extractor.parseImageURLs(from: html, baseURL: nil)
        XCTAssertTrue(urls.isEmpty)
    }

    func testParseEmptyHTML() {
        let urls = extractor.parseImageURLs(from: "", baseURL: nil)
        XCTAssertTrue(urls.isEmpty)
    }

    func testParseImgWithoutSrc() {
        let html = #"<img alt="no src">"#
        let urls = extractor.parseImageURLs(from: html, baseURL: nil)
        XCTAssertTrue(urls.isEmpty)
    }
}

// MARK: - ChatHistoryStore 聊天记录持久化（补充测试）

final class ChatHistoryStoreSupplementLogicTests: XCTestCase {

    @MainActor
    func testAppendSingleMessage() {
        let store = ChatHistoryStore()
        store.clear()
        let message = ChatMessageDTO(role: .user, content: "test message")
        store.append(message)
        XCTAssertEqual(store.messages.count, 1)
        XCTAssertEqual(store.messages.last?.content, "test message")
        store.clear()
    }

    @MainActor
    func testAppendBatchMessages() {
        let store = ChatHistoryStore()
        store.clear()
        let messages = [
            ChatMessageDTO(role: .user, content: "msg1"),
            ChatMessageDTO(role: .assistant, content: "msg2"),
            ChatMessageDTO(role: .user, content: "msg3")
        ]
        store.appendBatch(messages)
        XCTAssertEqual(store.messages.count, 3)
        store.clear()
    }

    @MainActor
    func testRecentMessages() {
        let store = ChatHistoryStore()
        store.clear()
        for i in 1...5 {
            store.append(ChatMessageDTO(role: .user, content: "msg\(i)"))
        }
        let recent = store.recent(3)
        XCTAssertEqual(recent.count, 3)
        let recentArray = Array(recent)
        XCTAssertEqual(recentArray[0].content, "msg3")
        XCTAssertEqual(recentArray[1].content, "msg4")
        XCTAssertEqual(recentArray[2].content, "msg5")
        store.clear()
    }

    @MainActor
    func testRecentMoreThanTotal() {
        let store = ChatHistoryStore()
        store.clear()
        store.append(ChatMessageDTO(role: .user, content: "only one"))
        let recent = store.recent(10)
        XCTAssertEqual(recent.count, 1)
        store.clear()
    }

    @MainActor
    func testPersistAndReload() {
        let store = ChatHistoryStore()
        store.clear()
        store.append(ChatMessageDTO(role: .user, content: "persist test"))
        store.persistToDisk()

        let newStore = ChatHistoryStore()
        XCTAssertTrue(newStore.messages.contains { $0.content == "persist test" })
        newStore.clear()
    }

    @MainActor
    func testClearPersistsToDisk() {
        let store = ChatHistoryStore()
        store.append(ChatMessageDTO(role: .user, content: "temp"))
        store.clear()
        store.persistToDisk()

        let newStore = ChatHistoryStore()
        XCTAssertFalse(newStore.messages.contains { $0.content == "temp" })
    }
}
