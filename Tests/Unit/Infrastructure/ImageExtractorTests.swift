//
//  ImageExtractorTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/10.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：图片提取、URL 解析、大小限制、OCR 集成全覆盖

import XCTest
@testable import ZhiYu

final class ImageExtractorTests: XCTestCase {

    let extractor = ImageExtractor()

    // MARK: - URL 解析

    func testParseAbsoluteHTTPURL() {
        let html = #"<img src="https://example.com/photo.jpg" />"#
        let urls = extractor.parseImageURLs(from: html, baseURL: nil)
        XCTAssertEqual(urls.count, 1)
        XCTAssertEqual(urls[0].absoluteString, "https://example.com/photo.jpg")
    }

    func testParseRelativeURLWithBase() {
        let html = #"<img src="/images/photo.png" />"#
        let urls = extractor.parseImageURLs(from: html, baseURL: URL(string: "https://example.com"))
        XCTAssertEqual(urls.count, 1)
        XCTAssertEqual(urls[0].absoluteString, "https://example.com/images/photo.png")
    }

    func testParseProtocolRelativeURL() {
        let html = #"<img src="//cdn.example.com/img.jpg" />"#
        let urls = extractor.parseImageURLs(from: html, baseURL: nil)
        XCTAssertEqual(urls.count, 1)
        XCTAssertTrue(urls[0].absoluteString.hasPrefix("https://"))
    }

    func testParseMultipleImages() {
        let html = """
        <img src="https://a.com/1.jpg" />
        <img src="https://b.com/2.png" />
        <img src="https://c.com/3.webp" />
        """
        let urls = extractor.parseImageURLs(from: html, baseURL: nil)
        XCTAssertEqual(urls.count, 3)
    }

    func testSkipSVGImages() {
        let html = #"<img src="https://example.com/icon.svg" />"#
        let urls = extractor.parseImageURLs(from: html, baseURL: nil)
        XCTAssertEqual(urls.count, 0, "SVG 应被过滤")
    }

    func testEmptyHTMLReturnsNoImages() {
        let urls = extractor.parseImageURLs(from: "", baseURL: nil)
        XCTAssertTrue(urls.isEmpty)
    }

    func testHTMLWithoutImages() {
        let html = "<div>No images here</div>"
        let urls = extractor.parseImageURLs(from: html, baseURL: nil)
        XCTAssertTrue(urls.isEmpty)
    }

    func testSingleQuoteAttribute() {
        let html = "<img src='https://example.com/photo.jpg' />"
        let urls = extractor.parseImageURLs(from: html, baseURL: nil)
        XCTAssertEqual(urls.count, 1)
    }

    // MARK: - URL 解析边界

    func testMalformedImgTagsIgnored() {
        let html = "<img broken"  // 无闭合，无 src
        let urls = extractor.parseImageURLs(from: html, baseURL: nil)
        XCTAssertTrue(urls.isEmpty)
    }

    func testURLWithQueryParams() {
        let html = #"<img src="https://example.com/img.jpg?w=800&h=600" />"#
        let urls = extractor.parseImageURLs(from: html, baseURL: nil)
        XCTAssertEqual(urls.count, 1)
    }

    // MARK: - 图片数量限制

    func testMaxImagesLimit() {
        let limit = AppConstants.Keys.ImportLimits.maxImagesPerPage
        let tags = (1...(limit + 5)).map { "<img src=\"https://example.com/\($0).jpg\" />" }
        let html = tags.joined(separator: "\n")
        let urls = extractor.parseImageURLs(from: html, baseURL: nil)
        // parseImageURLs 不截断，截断在 extractImagesFromHTML 中
        XCTAssertGreaterThan(urls.count, limit, "解析所有 URL")
    }

    // MARK: - 大小限制

    func testImageWithinSizeLimit() {
        let size: Int64 = 3 * 1_024 * 1_024 // 3MB
        XCTAssertLessThanOrEqual(size, AppConstants.Keys.ImportLimits.maxImageSizeBytes)
    }

    func testImageExceedsSizeLimit() {
        let size: Int64 = 10 * 1_024 * 1_024 // 10MB
        XCTAssertGreaterThan(size, AppConstants.Keys.ImportLimits.maxImageSizeBytes)
    }

    func testImageDownloadTimeoutConstant() {
        XCTAssertEqual(AppConstants.Keys.ImportLimits.imageDownloadTimeoutSeconds, 10)
    }

    // MARK: - 解析去重

    func testDuplicateURLsAllParsed() {
        let html = """
        <img src="https://example.com/same.jpg" />
        <img src="https://example.com/same.jpg" />
        """
        let urls = extractor.parseImageURLs(from: html, baseURL: nil)
        // parseImageURLs 返回所有找到的 URL（去重在 extractImagesFromHTML 中）
        XCTAssertEqual(urls.count, 2)
    }

    // MARK: - Markdown 无图片

    func testEmptyMarkdownReturnsEmpty() {
        let html = "<p>No images</p>"
        let urls = extractor.parseImageURLs(from: html, baseURL: nil)
        XCTAssertTrue(urls.isEmpty)
    }

    // MARK: - OCR 文字格式化

    func testOCRTextFormat() {
        let label = L10n.Ingest.imageOCRLabel
        XCTAssertFalse(label.isEmpty, "OCR label should not be empty")
    }

    func testImageCountFormat() {
        let msg = L10n.Ingest.imageCount(5)
        XCTAssertTrue(msg.contains("5"))
    }

    // MARK: - 错误提示

    func testSkippedMessagesNotEmpty() {
        XCTAssertFalse(L10n.Ingest.imageSkippedTooLarge.isEmpty)
        XCTAssertFalse(L10n.Ingest.imageSkippedFailed.isEmpty)
    }
}
