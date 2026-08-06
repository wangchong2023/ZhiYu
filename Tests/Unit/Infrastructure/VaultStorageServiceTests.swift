//
//  VaultStorageServiceTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 Vault 存储服务的 Markdown 文件扫描、H1 标题提取、文件名回退与空目录处理语义。
//

import XCTest
@testable import ZhiYu

@MainActor
final class VaultStorageServiceTests: XCTestCase {

    private var tempRoot: URL!

    override func setUp() {
        super.setUp()
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("VaultStorageTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempRoot)
        tempRoot = nil
        super.tearDown()
    }

    // MARK: - 辅助方法

    private func createMarkdownFile(named name: String, content: String) throws -> URL {
        let url = tempRoot.appendingPathComponent(name)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - 空目录扫描

    func testScan_emptyDirectory_returnsEmptyArray() {
        let service = VaultStorageService()
        let results = service.scan(directory: tempRoot)
        XCTAssertTrue(results.isEmpty, "空目录扫描应返回空数组")
    }

    // MARK: - 单文件扫描

    func testScan_singleMarkdownFileWithH1_extractsTitleFromH1() throws {
        let content = """
        # 我的标题

        这是正文内容。
        """
        let fileURL = try createMarkdownFile(named: "test.md", content: content)

        let service = VaultStorageService()
        let results = service.scan(directory: tempRoot)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].title, "我的标题", "应从 H1 提取标题")
        XCTAssertEqual(results[0].url, fileURL)
        XCTAssertEqual(results[0].content, content)
    }

    // MARK: - 无 H1 时回退到文件名

    func testScan_markdownWithoutH1_usesFileNameAsTitle() throws {
        let content = "这是没有标题的文档。"
        let fileURL = try createMarkdownFile(named: "无标题文档.md", content: content)

        let service = VaultStorageService()
        let results = service.scan(directory: tempRoot)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].title, "无标题文档", "无 H1 时应用文件名作为标题")
        XCTAssertEqual(results[0].url, fileURL)
    }

    // MARK: - 多文件扫描

    func testScan_multipleMarkdownFiles_allScanned() throws {
        _ = try createMarkdownFile(named: "file1.md", content: "# 文件1")
        _ = try createMarkdownFile(named: "file2.md", content: "# 文件2")
        _ = try createMarkdownFile(named: "file3.md", content: "# 文件3")

        let service = VaultStorageService()
        let results = service.scan(directory: tempRoot)

        XCTAssertEqual(results.count, 3, "应扫描所有 .md 文件")
    }

    // MARK: - 非 Markdown 文件被忽略

    func testScan_nonMarkdownFiles_ignored() throws {
        _ = try createMarkdownFile(named: "valid.md", content: "# 有效")
        let txtURL = tempRoot.appendingPathComponent("invalid.txt")
        try "文本内容".write(to: txtURL, atomically: true, encoding: .utf8)

        let service = VaultStorageService()
        let results = service.scan(directory: tempRoot)

        XCTAssertEqual(results.count, 1, "非 .md 文件应被忽略")
        XCTAssertEqual(results[0].title, "有效")
    }

    // MARK: - 大写扩展名

    func testScan_uppercaseMDExtension_alsoScanned() throws {
        _ = try createMarkdownFile(named: "upper.MD", content: "# 大写扩展")

        let service = VaultStorageService()
        let results = service.scan(directory: tempRoot)

        XCTAssertEqual(results.count, 1, ".MD 大写扩展名也应被扫描")
    }

    // MARK: - 隐藏文件跳过

    func testScan_hiddenFiles_skipped() throws {
        _ = try createMarkdownFile(named: ".hidden.md", content: "# 隐藏")
        _ = try createMarkdownFile(named: "visible.md", content: "# 可见")

        let service = VaultStorageService()
        let results = service.scan(directory: tempRoot)

        XCTAssertEqual(results.count, 1, "隐藏文件应被跳过")
        XCTAssertEqual(results[0].title, "可见")
    }

    // MARK: - 子目录递归

    func testScan_subdirectoryMarkdownFiles_included() throws {
        _ = try createMarkdownFile(named: "root.md", content: "# 根")
        let subdir = tempRoot.appendingPathComponent("subdir")
        try FileManager.default.createDirectory(at: subdir, withIntermediateDirectories: true)
        try "# 子目录".write(to: subdir.appendingPathComponent("sub.md"), atomically: true, encoding: .utf8)

        let service = VaultStorageService()
        let results = service.scan(directory: tempRoot)

        XCTAssertEqual(results.count, 2, "应递归扫描子目录")
    }

    // MARK: - H1 前有空白

    func testScan_h1WithLeadingWhitespace_titleExtracted() throws {
        let content = """
           # 缩进标题

        正文
        """
        _ = try createMarkdownFile(named: "indent.md", content: content)

        let service = VaultStorageService()
        let results = service.scan(directory: tempRoot)

        XCTAssertEqual(results[0].title, "缩进标题", "带前导空白的 H1 也应被提取")
    }

    // MARK: - lastModified 非空

    func testScan_lastModifiedDate_notNil() throws {
        _ = try createMarkdownFile(named: "dated.md", content: "# 日期")

        let service = VaultStorageService()
        let results = service.scan(directory: tempRoot)

        XCTAssertNotNil(results[0].lastModified, "lastModified 不应为 nil")
    }
}
