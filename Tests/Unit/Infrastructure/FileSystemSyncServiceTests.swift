//
//  FileSystemSyncServiceTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证文件系统同步服务的 Markdown 导出、子目录分类、文件名安全化与 YAML front matter 生成语义。
//

import XCTest
@testable import ZhiYu

final class FileSystemSyncServiceTests: XCTestCase {

    private var tempRoot: URL!

    override func setUp() {
        super.setUp()
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileSystemSyncTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempRoot)
        tempRoot = nil
        super.tearDown()
    }

    // MARK: - 基础导出

    func testExportToMarkdown_singlePage_createsFileWithYamlFrontMatter() throws {
        let page = KnowledgePage(
            title: "测试页面",
            pageType: .concept,
            content: "这是正文内容",
            tags: ["标签A", "标签B"]
        )
        let service = FileSystemSyncService()

        try service.exportToMarkdown(pages: [page], destinationURL: tempRoot)

        let expectedFile = tempRoot
            .appendingPathComponent("concepts")
            .appendingPathComponent("测试页面.md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: expectedFile.path), "应在 concepts 子目录创建 .md 文件")

        let content = try String(contentsOf: expectedFile, encoding: .utf8)
        XCTAssertTrue(content.hasPrefix("---"), "文件应以 YAML front matter 开头")
        XCTAssertTrue(content.contains("title: 测试页面"), "YAML 应包含标题")
        XCTAssertTrue(content.contains("type: concept"), "YAML 应包含页面类型")
        XCTAssertTrue(content.contains("tags: 标签A, 标签B"), "YAML 应包含标签")
        XCTAssertTrue(content.contains("这是正文内容"), "文件应包含正文")
    }

    // MARK: - 子目录分类

    func testExportToMarkdown_differentPageTypes_sortedIntoSubfolders() throws {
        let pages = [
            KnowledgePage(title: "概念页", pageType: .concept, content: "c"),
            KnowledgePage(title: "实体页", pageType: .entity, content: "e"),
            KnowledgePage(title: "来源页", pageType: .source, content: "s"),
            KnowledgePage(title: "比较页", pageType: .comparison, content: "cmp"),
            KnowledgePage(title: "原始页", pageType: .raw, content: "r")
        ]
        let service = FileSystemSyncService()

        try service.exportToMarkdown(pages: pages, destinationURL: tempRoot)

        XCTAssertTrue(FileManager.default.fileExists(atPath: tempRoot.appendingPathComponent("concepts/概念页.md").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempRoot.appendingPathComponent("entities/实体页.md").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempRoot.appendingPathComponent("sources/来源页.md").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempRoot.appendingPathComponent("comparisons/比较页.md").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempRoot.appendingPathComponent("raw/原始页.md").path))
    }

    // MARK: - 文件名安全化

    func testExportToMarkdown_titleWithSlash_replacedWithDash() throws {
        let page = KnowledgePage(title: "A/B", pageType: .concept, content: "x")
        let service = FileSystemSyncService()

        try service.exportToMarkdown(pages: [page], destinationURL: tempRoot)

        let safeFile = tempRoot.appendingPathComponent("concepts/A-B.md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: safeFile.path), "标题中的 / 应替换为 -")
    }

    func testExportToMarkdown_titleWithColon_replacedWithDash() throws {
        let page = KnowledgePage(title: "A:B", pageType: .concept, content: "x")
        let service = FileSystemSyncService()

        try service.exportToMarkdown(pages: [page], destinationURL: tempRoot)

        let safeFile = tempRoot.appendingPathComponent("concepts/A-B.md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: safeFile.path), "标题中的 : 应替换为 -")
    }

    // MARK: - 空页面列表

    func testExportToMarkdown_emptyPages_createsOnlyRootDirectory() throws {
        let service = FileSystemSyncService()

        try service.exportToMarkdown(pages: [], destinationURL: tempRoot)

        let contents = try FileManager.default.contentsOfDirectory(atPath: tempRoot.path)
        XCTAssertTrue(contents.isEmpty, "空页面列表不应创建任何子目录或文件")
    }

    // MARK: - 目标目录不存在时自动创建

    func testExportToMarkdown_nonExistentDestination_createsDirectory() throws {
        let nonExistent = tempRoot.appendingPathComponent("newdir")
        let page = KnowledgePage(title: "测试", pageType: .concept, content: "x")
        let service = FileSystemSyncService()

        try service.exportToMarkdown(pages: [page], destinationURL: nonExistent)

        XCTAssertTrue(FileManager.default.fileExists(atPath: nonExistent.appendingPathComponent("concepts/测试.md").path))
    }

    // MARK: - 多页面导出

    func testExportToMarkdown_multiplePages_allFilesCreated() throws {
        let pages = [
            KnowledgePage(title: "页面1", pageType: .concept, content: "内容1"),
            KnowledgePage(title: "页面2", pageType: .concept, content: "内容2"),
            KnowledgePage(title: "页面3", pageType: .entity, content: "内容3")
        ]
        let service = FileSystemSyncService()

        try service.exportToMarkdown(pages: pages, destinationURL: tempRoot)

        XCTAssertTrue(FileManager.default.fileExists(atPath: tempRoot.appendingPathComponent("concepts/页面1.md").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempRoot.appendingPathComponent("concepts/页面2.md").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempRoot.appendingPathComponent("entities/页面3.md").path))
    }

    // MARK: - YAML front matter 格式

    func testExportToMarkdown_yamlContainsAllRequiredFields() throws {
        let page = KnowledgePage(
            title: "完整页面",
            pageType: .entity,
            content: "正文",
            tags: ["t1", "t2"]
        )
        let service = FileSystemSyncService()

        try service.exportToMarkdown(pages: [page], destinationURL: tempRoot)

        let file = tempRoot.appendingPathComponent("entities/完整页面.md")
        let content = try String(contentsOf: file, encoding: .utf8)

        let lines = content.components(separatedBy: .newlines)
        XCTAssertEqual(lines[0], "---", "第一行应为 YAML 开始标记")
        XCTAssertTrue(content.contains("---\n\ntitle: 完整页面") || content.contains("title: 完整页面"), "应包含 title 字段")
        XCTAssertTrue(content.contains("type: entity"), "应包含 type 字段")
        XCTAssertTrue(content.contains("tags: t1, t2"), "应包含 tags 字段")
        XCTAssertTrue(content.contains("updated:"), "应包含 updated 字段")
    }
}
