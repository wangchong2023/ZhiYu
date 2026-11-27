//
//  FileSystemSyncServiceTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证文件系统同步服务的 Markdown 导出、子目录分类、文件名安全化与 YAML front matter 生成语义。
//

import XCTest
@testable import ZhiYuUnitTestHost

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

    // MARK: - 缺陷 #114 回归：路径穿越与 YAML 换行注入防护

    func testExportToMarkdown_traversalAndMultilineTitleSanitizedSafely() throws {
        XCTAssertEqual(FileSystemSyncService.sanitizeFilename(".."), "untitled")
        XCTAssertEqual(FileSystemSyncService.sanitizeFilename("///..."), "untitled")
        XCTAssertFalse(FileSystemSyncService.sanitizeFilename("../../secret\\file").contains(".."))
        XCTAssertFalse(FileSystemSyncService.sanitizeFilename("../../secret\\file").contains("\\"))
        XCTAssertFalse(FileSystemSyncService.sanitizeYAMLTitle("Line1\n---\nInjected").contains("\n"))

        let page = KnowledgePage(title: "../evil\n---", pageType: .concept, content: "safe body")
        let service = FileSystemSyncService()
        try service.exportToMarkdown(pages: [page], destinationURL: tempRoot)

        let conceptsDir = tempRoot.appendingPathComponent("concepts")
        let files = try FileManager.default.contentsOfDirectory(atPath: conceptsDir.path)
        XCTAssertEqual(files.count, 1, "文件必须严格写入 concepts 目录内不得穿越")
    }

    // MARK: - 缺陷 #192 回归：同名/清洗后冲突页面自动去重不互相覆盖 & 标签换行清洗

    func testExportToMarkdown_collidingTitles_disambiguatedWithoutOverwrite() throws {
        let pages = [
            KnowledgePage(title: "A/B", pageType: .concept, content: "第一篇内容", tags: ["正常", "折行\n注入"]),
            KnowledgePage(title: "A:B", pageType: .concept, content: "第二篇内容"),
            KnowledgePage(title: "a-b", pageType: .concept, content: "第三篇大小写冲突内容")
        ]
        let service = FileSystemSyncService()
        try service.exportToMarkdown(pages: pages, destinationURL: tempRoot)

        let conceptsDir = tempRoot.appendingPathComponent("concepts")
        let files = try FileManager.default.contentsOfDirectory(atPath: conceptsDir.path).sorted()
        XCTAssertEqual(files.count, 3, "同名、清洗冲突及大小写冲突页面必须全部保留，不得互相覆盖")

        let allContents = try files.map { fileName in
            try String(contentsOf: conceptsDir.appendingPathComponent(fileName), encoding: .utf8)
        }
        XCTAssertTrue(allContents.contains { $0.contains("第一篇内容") })
        XCTAssertTrue(allContents.contains { $0.contains("第二篇内容") })
        XCTAssertTrue(allContents.contains { $0.contains("第三篇大小写冲突内容") })
        XCTAssertTrue(allContents.contains { $0.contains("tags: 正常, 折行 注入") }, "标签中的换行符应被清洗为空格")
    }

    // MARK: - 缺陷 #244 回归：空字节/跨平台保留字符清洗、YAML 特殊标题引号转义与 ISO-8601 时间戳

    func testSanitizeFilename_stripsNullByteControlAndReservedChars() {
        let cleaned = FileSystemSyncService.sanitizeFilename("doc\0name*?\"<>|end")
        XCTAssertFalse(cleaned.contains("\0"))
        XCTAssertFalse(cleaned.contains("*"))
        XCTAssertFalse(cleaned.contains("?"))
        XCTAssertFalse(cleaned.contains("<"))
        XCTAssertFalse(cleaned.contains(">"))
        XCTAssertFalse(cleaned.contains("|"))
        XCTAssertFalse(cleaned.contains("\""))
    }

    func testExportToMarkdown_yamlSpecialTitleQuotedAndISO8601UpdatedDate() throws {
        let page = KnowledgePage(
            title: "Swift 6: 并发 #1",
            pageType: .concept,
            content: "正文"
        )
        let service = FileSystemSyncService()
        try service.exportToMarkdown(pages: [page], destinationURL: tempRoot)

        let conceptsDir = tempRoot.appendingPathComponent("concepts")
        let files = try FileManager.default.contentsOfDirectory(atPath: conceptsDir.path)
        let file = conceptsDir.appendingPathComponent(try XCTUnwrap(files.first))
        let content = try String(contentsOf: file, encoding: .utf8)

        XCTAssertTrue(content.contains("title: \"Swift 6: 并发 #1\""), "含冒号或井号的标题应自动双引号转义包裹，got: \(content)")
        let updatedLine = try XCTUnwrap(content.components(separatedBy: .newlines).first { $0.hasPrefix("updated: ") })
        let isoString = String(updatedLine.dropFirst("updated: ".count))
        XCTAssertNotNil(ISO8601DateFormatter().date(from: isoString), "updated 字段应输出标准确定性 ISO-8601 格式，got: \(isoString)")
    }
}
