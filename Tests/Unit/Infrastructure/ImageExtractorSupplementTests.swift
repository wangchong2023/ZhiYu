//
//  ImageExtractorSupplementTests.swift
//  ZhiYu
//
//  Created by CodeFree on 2026/09/07.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Test] 单元测试
//  核心职责：ImageExtractor 补充测试 — HTML 图片提取、SSRF 防护、URL 解析边界条件
//

import XCTest
import Foundation
import Dependencies
import UFPCore
@testable import ZhiYu

// MARK: - A-27 修复：NoOpDocumentExtractionService 已移入生产代码（DocumentExtractionServiceProtocol.swift）

// MARK: - ImageExtractor 补充测试

final class ImageExtractorSupplementTests: XCTestCase {

    private var extractor: ImageExtractor!

    override func setUp() {
        super.setUp()
        extractor = ImageExtractor()
    }

    override func tearDown() {
        extractor = nil
        super.tearDown()
    }

    // MARK: - extractImagesFromHTML 边界条件

    func testExtractImagesFromHTML_emptyHTML_returnsEmpty() async {
        let result = await extractor.extractImagesFromHTML("", baseURL: nil)
        XCTAssertEqual(result, "")
    }

    func testExtractImagesFromHTML_noImgTags_returnsEmpty() async {
        let html = "<html><body><p>No images here</p></body></html>"
        let result = await extractor.extractImagesFromHTML(html, baseURL: nil)
        XCTAssertEqual(result, "")
    }

    func testExtractImagesFromHTML_onlySvgImages_filtered() async {
        let html = #"<img src="https://example.com/diagram.svg" alt="diagram">"#
        let urls = extractor.parseImageURLs(from: html, baseURL: nil)
        XCTAssertTrue(urls.isEmpty, "SVG 图片应被过滤")
    }

    // MARK: - ocrImageBatch 边界条件

    func testOcrImageBatch_emptyList_returnsEmpty() async {
        let result = await extractor.ocrImageBatch([], prefix: ProcessorConstants.FileFormat.pdf)
        XCTAssertEqual(result, "")
    }

    // MARK: - parseImageURLs SSRF 防护

    func testParseImageURLs_localhost_filtered() {
        let html = #"<img src="http://localhost:8080/secret.png">"#
        let urls = extractor.parseImageURLs(from: html, baseURL: nil)
        XCTAssertTrue(urls.isEmpty, "localhost 应被 SSRF 防护过滤")
    }

    func testParseImageURLs_privateIP_filtered() {
        let html = #"<img src="http://192.168.1.1/secret.png">"#
        let urls = extractor.parseImageURLs(from: html, baseURL: nil)
        XCTAssertTrue(urls.isEmpty, "私有 IP 应被 SSRF 防护过滤")
    }

    func testParseImageURLs_linkLocal_filtered() {
        let html = #"<img src="http://169.254.169.254/metadata.png">"#
        let urls = extractor.parseImageURLs(from: html, baseURL: nil)
        XCTAssertTrue(urls.isEmpty, "链路本地地址应被 SSRF 防护过滤")
    }

    // MARK: - resolveURL 间接测试（通过 parseImageURLs）

    func testParseImageURLs_protocolRelativeURL_resolved() {
        let html = #"<img src="//example.com/image.png">"#
        let urls = extractor.parseImageURLs(from: html, baseURL: nil)
        XCTAssertEqual(urls.count, 1)
        XCTAssertEqual(urls.first?.scheme, "https")
    }

    func testParseImageURLs_rootRelativeURL_resolvedWithBaseURL() {
        let html = #"<img src="/images/photo.png">"#
        let baseURL = URL(string: "https://example.com/blog/article")
        let urls = extractor.parseImageURLs(from: html, baseURL: baseURL)
        XCTAssertEqual(urls.count, 1)
        XCTAssertTrue(urls.first?.absoluteString.contains("example.com") == true)
    }

    func testParseImageURLs_relativeURL_resolvedWithBaseURL() {
        let html = #"<img src="photo.png">"#
        let baseURL = URL(string: "https://example.com/blog/")
        let urls = extractor.parseImageURLs(from: html, baseURL: baseURL)
        XCTAssertEqual(urls.count, 1)
        XCTAssertTrue(urls.first?.absoluteString.contains("photo.png") == true)
    }

    func testParseImageURLs_relativeURL_noBaseURL_returnsNil() {
        let html = #"<img src="photo.png">"#
        let urls = extractor.parseImageURLs(from: html, baseURL: nil)
        XCTAssertTrue(urls.isEmpty, "无 baseURL 的相对路径应返回空")
    }

    // MARK: - 多图片截断测试

    func testParseImageURLs_moreThanMaxImages_notTruncatedInParse() {
        var html = ""
        for i in 0..<15 {
            html += #"<img src="https://example.com/image\#(i).png">"#
        }
        let urls = extractor.parseImageURLs(from: html, baseURL: nil)
        XCTAssertEqual(urls.count, 15, "parseImageURLs 不截断，截断在 extractImagesFromHTML 中")
    }
}
