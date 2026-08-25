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

    /// 索引单张页面不应抛出异常或崩溃
    func testIndexPageDoesNotCrash() {
        let indexer = iOSSpotlightIndexer()
        let page = makePage()
        indexer.indexPage(page)
        XCTAssertTrue(true, "indexPage 应正常执行无崩溃")
    }

    /// 索引空内容页面不应崩溃
    func testIndexPageWithEmptyContentDoesNotCrash() {
        let indexer = iOSSpotlightIndexer()
        let page = KnowledgePage(title: TestConstants.pageTitle, content: "")
        indexer.indexPage(page)
        XCTAssertTrue(true, "空内容页面索引应正常执行")
    }

    // MARK: - indexPages

    /// 批量索引多张页面不应崩溃
    func testIndexPagesWithBatchDoesNotCrash() {
        let indexer = iOSSpotlightIndexer()
        let pages = makeBatchPages()
        indexer.indexPages(pages)
        XCTAssertTrue(true, "批量索引应正常执行无崩溃")
    }

    /// 批量索引空数组不应崩溃
    func testIndexPagesWithEmptyArrayDoesNotCrash() {
        let indexer = iOSSpotlightIndexer()
        indexer.indexPages([])
        XCTAssertTrue(true, "空数组批量索引应正常执行")
    }

    // MARK: - removeIndex

    /// 移除指定页面索引不应崩溃
    func testRemoveIndexDoesNotCrash() {
        let indexer = iOSSpotlightIndexer()
        let page = makePage()
        indexer.indexPage(page)
        indexer.removeIndex(for: page.id)
        XCTAssertTrue(true, "removeIndex 应正常执行无崩溃")
    }

    /// 移除不存在的页面索引不应崩溃
    func testRemoveIndexForNonExistentPageDoesNotCrash() {
        let indexer = iOSSpotlightIndexer()
        indexer.removeIndex(for: UUID())
        XCTAssertTrue(true, "移除不存在的索引应正常执行")
    }

    // MARK: - deindexAll

    /// 清除所有索引不应崩溃
    func testDeindexAllDoesNotCrash() {
        let indexer = iOSSpotlightIndexer()
        let page = makePage()
        indexer.indexPage(page)
        indexer.deindexAll()
        XCTAssertTrue(true, "deindexAll 应正常执行无崩溃")
    }

    // MARK: - reindexAll

    /// 全量重建索引不应崩溃
    func testReindexAllWithPagesDoesNotCrash() async {
        let indexer = iOSSpotlightIndexer()
        let pages = makeBatchPages()
        indexer.reindexAll(pages: pages)
        try? await Task.sleep(for: .milliseconds(TestConstants.reindexWaitMs))
        XCTAssertTrue(true, "reindexAll 应正常执行无崩溃")
    }

    /// 全量重建空数组不应崩溃
    func testReindexAllWithEmptyArrayDoesNotCrash() async {
        let indexer = iOSSpotlightIndexer()
        indexer.reindexAll(pages: [])
        try? await Task.sleep(for: .milliseconds(TestConstants.reindexWaitMs))
        XCTAssertTrue(true, "空数组全量重建应正常执行")
    }

    // MARK: - 协议一致性

    /// 服务实例应可向上转型为 SearchIndexerProtocol
    func testConformsToSearchIndexerProtocol() {
        let indexer: any SearchIndexerProtocol = iOSSpotlightIndexer()
        let page = makePage()
        indexer.indexPage(page)
        indexer.removeIndex(for: page.id)
        XCTAssertTrue(true, "协议转型与调用应成功")
    }
}
#endif
