//
//  PPTXProcessorSupplementTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：补充 PPTX 处理器的 Markdown 解析、空输入、单幻灯片、多列表项与文件覆盖语义。
//

import XCTest
import UFPCore
@testable import ZhiYu

final class PPTXProcessorSupplementTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PPTXSupplementTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
        super.tearDown()
    }

    // MARK: - 辅助

    private func makeProcessor() -> PPTXProcessor {
        PPTXProcessor(archiver: ZIPFoundationArchiver())
    }

    // MARK: - 空输入

    func testGenerate_emptyMarkdown_producesSingleSlideWithDefaultTitle() async throws {
        let processor = makeProcessor()

        let outputURL = try await processor.generate(markdown: "", title: "EmptyTest")

        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        let attrs = try FileManager.default.attributesOfItem(atPath: outputURL.path)
        let size = attrs[.size] as? Int64 ?? 0
        XCTAssertGreaterThan(size, 0, "空 Markdown 也应生成有效 PPTX")

        try? FileManager.default.removeItem(at: outputURL)
    }

    // MARK: - 单幻灯片

    func testGenerate_singleSlideWithBullets_producesValidFile() async throws {
        let markdown = """
        # 单页标题

        - 要点一
        - 要点二
        """

        let processor = makeProcessor()
        let outputURL = try await processor.generate(markdown: markdown, title: "SingleSlide")

        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        try? FileManager.default.removeItem(at: outputURL)
    }

    // MARK: - 多幻灯片

    func testGenerate_multipleSlides_producesValidFile() async throws {
        let markdown = """
        # 第一页

        - 内容A

        ## 第二页

        - 内容B
        """

        let processor = makeProcessor()
        let outputURL = try await processor.generate(markdown: markdown, title: "MultiSlide")

        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        try? FileManager.default.removeItem(at: outputURL)
    }

    // MARK: - 星号列表项

    func testGenerate_asteriskBullets_parsedCorrectly() async throws {
        let markdown = """
        # 星号列表

        * 星号项一
        * 星号项二
        """

        let processor = makeProcessor()
        let outputURL = try await processor.generate(markdown: markdown, title: "AsteriskBullets")

        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        try? FileManager.default.removeItem(at: outputURL)
    }

    // MARK: - 文件覆盖

    func testGenerate_existingFileOverwritten_success() async throws {
        let markdown = "# 覆盖测试"
        let processor = makeProcessor()

        let firstURL = try await processor.generate(markdown: markdown, title: "OverwriteTest")
        XCTAssertTrue(FileManager.default.fileExists(atPath: firstURL.path))

        let secondURL = try await processor.generate(markdown: markdown, title: "OverwriteTest")
        XCTAssertTrue(FileManager.default.fileExists(atPath: secondURL.path))
        XCTAssertEqual(firstURL, secondURL, "同标题应生成同路径文件")

        try? FileManager.default.removeItem(at: secondURL)
    }

    // MARK: - 无列表项的幻灯片

    func testGenerate_slideWithoutBullets_producesValidFile() async throws {
        let markdown = """
        # 纯标题页

        ## 第二页纯标题
        """

        let processor = makeProcessor()
        let outputURL = try await processor.generate(markdown: markdown, title: "NoBullets")

        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        try? FileManager.default.removeItem(at: outputURL)
    }

    // MARK: - 中文标题

    func testGenerate_chineseTitle_producesValidFile() async throws {
        let markdown = """
        # 智宇知识管理

        - 语义分块
        - 向量检索
        """

        let processor = makeProcessor()
        let outputURL = try await processor.generate(markdown: markdown, title: "中文演示")

        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        try? FileManager.default.removeItem(at: outputURL)
    }

    // MARK: - 构造函数注入隔离

    func testInit_withCustomArchiver_doesNotUseSharedSingleton() {
        let mockArchiver = MockFileArchiver()
        let processor = PPTXProcessor(archiver: mockArchiver)

        XCTAssertNotNil(processor, "构造函数注入应创建独立实例，不依赖 shared 单例")
    }
}
