//
//  ImportRecordPreviewTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/06/28.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests] 单元测试层
//  核心职责：对 Ingest 导入记录的几种不同类型在点击和预览时的分发动作与逻辑（ImportPreviewHandler）进行完备的单元测试校验。
//

import XCTest
@testable import ZhiYu

final class ImportRecordPreviewTests: XCTestCase {

    private var mockURLOpener: MockURLOpener!
    private var mockShareSheet: MockShareSheet!
    private var router: Router!
    private var handler: ImportPreviewHandler!

    @MainActor
    override func setUp() {
        super.setUp()
        mockURLOpener = MockURLOpener()
        mockShareSheet = MockShareSheet()
        router = Router()
        handler = ImportPreviewHandler(
            urlOpener: mockURLOpener,
            shareSheet: mockShareSheet,
            router: router
        )
    }

    override func tearDown() {
        mockURLOpener = nil
        mockShareSheet = nil
        router = nil
        handler = nil
        super.tearDown()
    }

    // MARK: - 1. 手工记录跳转编辑测试（最高优先级）

    /// 手工记录优先分派编辑事件，拉起输入编辑表单
    func testManualEdit() {
        let record = ImportRecord(
            id: UUID().uuidString,
            category: ImportCategory.manual.rawValue,
            title: "手工导入记录"
        )

        let action = handler.resolveAction(for: record)
        XCTAssertEqual(action, .manualEdit)
    }

    /// forceRaw 模式下手工记录不走编辑，降级到后续分支
    func testManualEditForceRawFallsThrough() {
        let record = ImportRecord(
            id: UUID().uuidString,
            category: ImportCategory.manual.rawValue,
            title: "强制原始文本的手工记录",
            rawText: "手工录入的文本内容"
        )

        let action = handler.resolveAction(for: record, forceRaw: true)
        XCTAssertEqual(action, .rawTextPreview(text: "手工录入的文本内容"))
    }

    // MARK: - 2. 本地文本文件预览测试

    /// 磁盘上真实存在的文本文件应走文本预览分支
    func testLocalTextFile() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("zhiyu_test_notes.md")
        try "# 测试 Markdown".write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        let record = ImportRecord(
            id: UUID().uuidString,
            category: ImportCategory.file.rawValue,
            title: "本地文本记录",
            filePath: tempFile.path
        )

        let action = handler.resolveAction(for: record)
        XCTAssertEqual(action, .localTextFile(path: tempFile.path))
    }

    // MARK: - 3. 本地二进制文件 QL 预览测试

    /// 磁盘上真实存在的二进制文件应走 QL 预览分支
    func testLocalBinaryFile() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("zhiyu_test_doc.pdf")
        try Data([0x25, 0x50, 0x44, 0x46]).write(to: tempFile)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        let record = ImportRecord(
            id: UUID().uuidString,
            category: ImportCategory.file.rawValue,
            title: "本地PDF记录",
            filePath: tempFile.path
        )

        let action = handler.resolveAction(for: record)
        XCTAssertEqual(action, .localBinaryFile(url: tempFile))
    }

    /// filePath 指向不存在的文件时，应跳过文件分支降级处理
    func testNonExistentFileFallsThrough() {
        let record = ImportRecord(
            id: UUID().uuidString,
            category: ImportCategory.file.rawValue,
            title: "文件已丢失的记录",
            rawText: "降级文本预览",
            filePath: "/path/to/nonexistent_file.md"
        )

        let action = handler.resolveAction(for: record)
        XCTAssertEqual(action, .rawTextPreview(text: "降级文本预览"))
    }

    // MARK: - 4. 提取出的纯文本弹窗预览测试

    /// OCR/语音/网页抓取的原始文本应走文本弹窗预览
    func testRawTextPreview() {
        let record = ImportRecord(
            id: UUID().uuidString,
            category: ImportCategory.ocr.rawValue,
            title: "无文件的OCR文本记录",
            rawText: "这是扫描提取出来的文字"
        )

        let action = handler.resolveAction(for: record)
        XCTAssertEqual(action, .rawTextPreview(text: "这是扫描提取出来的文字"))
    }

    // MARK: - 5. 网页链接跳转浏览器测试

    /// 有 sourceURL 但无 rawText、无本地文件的链接记录应打开浏览器
    func testOpenURL() {
        let record = ImportRecord(
            id: UUID().uuidString,
            category: ImportCategory.link.rawValue,
            title: "链接记录",
            sourceURL: "https://example.com/source"
        )

        let action = handler.resolveAction(for: record)
        let expectedURL = URL(string: "https://example.com/source")!
        XCTAssertEqual(action, .openURL(url: expectedURL))
    }

    // MARK: - 6. 关联页面跳转测试（降级优先级）

    /// 有 pageID 但无 rawText、无 sourceURL、无本地文件的记录应跳转页面详情
    func testNavigateToPage() {
        let pageUUID = UUID()
        let record = ImportRecord(
            id: UUID().uuidString,
            category: ImportCategory.link.rawValue,
            title: "已完成并关联页面的链接",
            status: ImportRecordStatus.done,
            pageID: pageUUID.uuidString
        )

        let action = handler.resolveAction(for: record)
        XCTAssertEqual(action, .navigateToPage(id: pageUUID))
    }

    /// 有 rawText 时优先走文本预览，不跳转页面
    func testRawTextTakesPrecedenceOverPageNavigation() {
        let pageUUID = UUID()
        let record = ImportRecord(
            id: UUID().uuidString,
            category: ImportCategory.link.rawValue,
            title: "有文本的关联页面记录",
            status: ImportRecordStatus.done,
            rawText: "优先展示的文本",
            pageID: pageUUID.uuidString
        )

        let action = handler.resolveAction(for: record)
        XCTAssertEqual(action, .rawTextPreview(text: "优先展示的文本"))
    }

    // MARK: - 7. 兜底回退测试

    /// 无任何可预览内容的记录应返回 none
    func testNoneFallback() {
        let record = ImportRecord(
            id: UUID().uuidString,
            category: ImportCategory.file.rawValue,
            title: "什么都没有的记录"
        )

        let action = handler.resolveAction(for: record)
        XCTAssertEqual(action, .none)
    }
}

// MARK: - Mocks

final class MockURLOpener: URLOpenerProtocol, @unchecked Sendable {
    var openedURL: URL?
    func open(_ url: URL) async {
        openedURL = url
    }
}

final class MockShareSheet: ShareSheetProtocol, @unchecked Sendable {
    var sharedItems: [Any]?
    func presentShareSheet(items: [Any]) async {
        sharedItems = items
    }
}
