//
//  ImageExtractorParsingTests.swift
//  ZhiYuTests
//
//  系统层级：[L1] 基础设施层测试
//  核心职责：验证 ImageExtractor.parseImageURLs 的 HTML 解析、URL 解析与 SSRF 防护
//

import XCTest
@testable import ZhiYu

final class ImageExtractorParsingTests: XCTestCase {

    private var extractor: ImageExtractor!

    override func setUp() {
        super.setUp()
        extractor = ImageExtractor()
    }

    override func tearDown() {
        extractor = nil
        super.tearDown()
    }

    // MARK: - 基本解析

    func testParseImageURLsReturnsEmptyWhenNoImgTag() {
        let html = "<html><body><p>no images here</p></body></html>"
        let urls = extractor.parseImageURLs(from: html, baseURL: nil)
        XCTAssertTrue(urls.isEmpty)
    }

    func testParseImageURLsExtractsAbsoluteHTTPSURL() {
        let html = #"<img src="https://example.com/photo.jpg">"#
        let urls = extractor.parseImageURLs(from: html, baseURL: nil)
        XCTAssertEqual(urls.count, 1)
        XCTAssertEqual(urls.first?.absoluteString, "https://example.com/photo.jpg")
    }

    func testParseImageURLsExtractsAbsoluteHTTPURL() {
        let html = #"<img src="http://example.com/photo.png">"#
        let urls = extractor.parseImageURLs(from: html, baseURL: nil)
        XCTAssertEqual(urls.count, 1)
        XCTAssertEqual(urls.first?.absoluteString, "http://example.com/photo.png")
    }

    // MARK: - SVG 过滤

    func testParseImageURLsSkipsSVGImages() {
        let html = #"<img src="https://example.com/icon.svg">"#
        let urls = extractor.parseImageURLs(from: html, baseURL: nil)
        XCTAssertTrue(urls.isEmpty, "SVG 图片应被跳过")
    }

    // MARK: - 相对路径解析

    func testParseImageURLsResolvesRelativePathWithBaseURL() {
        let html = #"<img src="/images/photo.jpg">"#
        let baseURL = URL(string: "https://example.com/article/page")
        let urls = extractor.parseImageURLs(from: html, baseURL: baseURL)
        XCTAssertEqual(urls.count, 1)
        XCTAssertTrue(urls.first?.absoluteString.contains("example.com") == true)
        XCTAssertTrue(urls.first?.absoluteString.contains("photo.jpg") == true)
    }

    func testParseImageURLsResolvesProtocolRelativeURL() {
        let html = #"<img src="//cdn.example.com/photo.jpg">"#
        let urls = extractor.parseImageURLs(from: html, baseURL: nil)
        XCTAssertEqual(urls.count, 1)
        XCTAssertEqual(urls.first?.absoluteString, "https://cdn.example.com/photo.jpg")
    }

    func testParseImageURLsResolvesRelativePathWithoutLeadingSlash() {
        let html = #"<img src="photo.jpg">"#
        let baseURL = URL(string: "https://example.com/article/")
        let urls = extractor.parseImageURLs(from: html, baseURL: baseURL)
        XCTAssertEqual(urls.count, 1)
        XCTAssertTrue(urls.first?.absoluteString.contains("photo.jpg") == true)
    }

    func testParseImageURLsReturnsNilForRelativePathWithoutBaseURL() {
        let html = #"<img src="photo.jpg">"#
        let urls = extractor.parseImageURLs(from: html, baseURL: nil)
        XCTAssertTrue(urls.isEmpty, "无 baseURL 时相对路径应返回空")
    }

    // MARK: - SSRF 防护

    func testParseImageURLsFiltersLoopbackAddress() {
        let html = #"<img src="http://127.0.0.1:8080/secret.jpg">"#
        let urls = extractor.parseImageURLs(from: html, baseURL: nil)
        XCTAssertTrue(urls.isEmpty, "环回地址应被 SSRF 防护过滤")
    }

    func testParseImageURLsFiltersPrivateNetworkAddress() {
        let html = #"<img src="http://192.168.1.1/internal.jpg">"#
        let urls = extractor.parseImageURLs(from: html, baseURL: nil)
        XCTAssertTrue(urls.isEmpty, "内网地址应被 SSRF 防护过滤")
    }

    // MARK: - 多图片

    func testParseImageURLsExtractsMultipleImages() {
        let html = #"""
        <img src="https://example.com/a.jpg">
        <img src="https://example.com/b.png">
        <img src="https://example.com/c.gif">
        """#
        let urls = extractor.parseImageURLs(from: html, baseURL: nil)
        XCTAssertEqual(urls.count, 3)
    }

    func testParseImageURLsHandlesSingleQuotes() {
        let html = #"<img src='https://example.com/single.jpg'>"#
        let urls = extractor.parseImageURLs(from: html, baseURL: nil)
        XCTAssertEqual(urls.count, 1)
        XCTAssertEqual(urls.first?.absoluteString, "https://example.com/single.jpg")
    }
}
