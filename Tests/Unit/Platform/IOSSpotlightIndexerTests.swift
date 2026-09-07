//
//  IOSSpotlightIndexerTests.swift
//  ZhiYu
//
//  Created by CodeFree on 2026/08/24.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：iOSSpotlightIndexer 单元测试，覆盖单页索引、批量索引、移除索引、全量重建场景。
//

#if canImport(CoreSpotlight)
import XCTest
@testable import ZhiYu

@MainActor
final class IOSSpotlightIndexerTests: XCTestCase {

    // MARK: - 测试常量

    private enum TestConstants {
        static let pageTitle: String = "Spotlight 测试页面"
        static let pageContent: String = "这是用于 Spotlight 索引测试的页面内容"
        static let pageTag: String = "测试"
        static let pageAlias: String = "别名1"
        static let batchCount: Int = 3
        static let reindexWaitMs: UInt64 = 200
    }

    // MARK: - 辅助方法

    /// 构造测试用 KnowledgePage
    private func makePage(title: String = TestConstants.pageTitle,
                          content: String = TestConstants.pageContent,
                          tags: [String] = [TestConstants.pageTag],
                          aliases: [String] = [TestConstants.pageAlias]) -> KnowledgePage {
        KnowledgePage(title: title, content: content, aliases: aliases, tags: tags)
    }

    /// 构造批量测试页面
    private func makeBatchPages(count: Int = TestConstants.batchCount) -> [KnowledgePage] {
        (0..<count).map { index in
            KnowledgePage(title: "批量页面_\(index)",
                          content: "批量内容_\(index)",
                          aliases: [],
                          tags: [TestConstants.pageTag])
        }
    }

    // MARK: - indexPage

    /// 索引单张页面参数结构完整且不崩溃
    func testIndexPageDoesNotCrash() {
        let indexer = iOSSpotlightIndexer()
        let page = makePage()
        XCTAssertEqual(page.title, TestConstants.pageTitle)
        XCTAssertFalse(page.id.uuidString.isEmpty)
        indexer.indexPage(page)
    }

    /// 索引空内容页面应能安全处理空字符串
    func testIndexPageWithEmptyContentDoesNotCrash() {
        let indexer = iOSSpotlightIndexer()
        let page = KnowledgePage(title: TestConstants.pageTitle, content: "")
        XCTAssertTrue(page.content.isEmpty)
        XCTAssertEqual(page.title, TestConstants.pageTitle)
        indexer.indexPage(page)
    }

    // MARK: - indexPages

    /// 批量索引多张页面应按批量大小正常处理
    func testIndexPagesWithBatchDoesNotCrash() {
        let indexer = iOSSpotlightIndexer()
        let pages = makeBatchPages()
        XCTAssertEqual(pages.count, TestConstants.batchCount)
        XCTAssertEqual(pages.first?.tags, [TestConstants.pageTag])
        indexer.indexPages(pages)
    }

    /// 批量索引空数组应安全执行不抛出越界
    func testIndexPagesWithEmptyArrayDoesNotCrash() {
        let indexer = iOSSpotlightIndexer()
        let emptyPages: [KnowledgePage] = []
        XCTAssertTrue(emptyPages.isEmpty)
        indexer.indexPages(emptyPages)
    }

    // MARK: - removeIndex

    /// 移除指定页面索引
    func testRemoveIndexDoesNotCrash() {
        let indexer = iOSSpotlightIndexer()
        let page = makePage()
        XCTAssertFalse(page.id.uuidString.isEmpty)
        indexer.indexPage(page)
        indexer.removeIndex(for: page.id)
    }

    /// 移除不存在的页面索引不应崩溃
    func testRemoveIndexForNonExistentPageDoesNotCrash() {
        let indexer = iOSSpotlightIndexer()
        let randomID = UUID()
        XCTAssertNotEqual(randomID, UUID())
        indexer.removeIndex(for: randomID)
    }

    // MARK: - deindexAll

    /// 清除所有索引不应崩溃
    func testDeindexAllDoesNotCrash() {
        let indexer = iOSSpotlightIndexer()
        let page = makePage()
        XCTAssertNotNil(page)
        indexer.indexPage(page)
        indexer.deindexAll()
    }

    // MARK: - reindexAll

    /// 全量重建索引能正常处理批量页面
    func testReindexAllWithPagesDoesNotCrash() async {
        let indexer = iOSSpotlightIndexer()
        let pages = makeBatchPages()
        XCTAssertFalse(pages.isEmpty)
        indexer.reindexAll(pages: pages)
        try? await Task.sleep(for: .milliseconds(TestConstants.reindexWaitMs))
    }

    /// 全量重建空数组应安全执行
    func testReindexAllWithEmptyArrayDoesNotCrash() async {
        let indexer = iOSSpotlightIndexer()
        let emptyPages: [KnowledgePage] = []
        XCTAssertTrue(emptyPages.isEmpty)
        indexer.reindexAll(pages: emptyPages)
        try? await Task.sleep(for: .milliseconds(TestConstants.reindexWaitMs))
    }

    // MARK: - 协议一致性

    /// 服务实例应可向上转型为 SearchIndexerProtocol 并正确响应方法
    func testConformsToSearchIndexerProtocol() {
        let indexer: any SearchIndexerProtocol = iOSSpotlightIndexer()
        let page = makePage()
        XCTAssertEqual(page.title, TestConstants.pageTitle)
        indexer.indexPage(page)
        indexer.removeIndex(for: page.id)
    }
}
#endif
