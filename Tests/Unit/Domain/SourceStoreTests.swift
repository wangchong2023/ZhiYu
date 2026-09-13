import XCTest
@testable import ZhiYu

@MainActor
final class SourceStoreTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        SourceStore.shared.clear()
    }

    func testInitialState_empty() {
        XCTAssertTrue(SourceStore.shared.activeSources.isEmpty)
    }

    func testUpdateSources_replacesAndSortsByScore() {
        let s1 = KnowledgeSource(pageID: UUID(), title: "B", snippet: "s1", score: 0.5)
        let s2 = KnowledgeSource(pageID: UUID(), title: "A", snippet: "s2", score: 0.9)
        let s3 = KnowledgeSource(pageID: UUID(), title: "C", snippet: "s3", score: 0.3)

        SourceStore.shared.updateSources([s1, s2, s3])

        XCTAssertEqual(SourceStore.shared.activeSources.count, 3)
        // 按 score 降序排列
        XCTAssertEqual(SourceStore.shared.activeSources[0].title, "A")
        XCTAssertEqual(SourceStore.shared.activeSources[1].title, "B")
        XCTAssertEqual(SourceStore.shared.activeSources[2].title, "C")
    }

    func testClear_emptiesSources() {
        let s = KnowledgeSource(pageID: UUID(), title: "T", snippet: "s", score: 1.0)
        SourceStore.shared.updateSources([s])
        XCTAssertEqual(SourceStore.shared.activeSources.count, 1)

        SourceStore.shared.clear()
        XCTAssertTrue(SourceStore.shared.activeSources.isEmpty)
    }

    func testUpdateSources_replacesPreviousContent() {
        let first = KnowledgeSource(pageID: UUID(), title: "First", snippet: "f", score: 0.8)
        SourceStore.shared.updateSources([first])
        XCTAssertEqual(SourceStore.shared.activeSources.count, 1)

        let second = KnowledgeSource(pageID: UUID(), title: "Second", snippet: "s", score: 0.6)
        SourceStore.shared.updateSources([second])
        XCTAssertEqual(SourceStore.shared.activeSources.count, 1)
        XCTAssertEqual(SourceStore.shared.activeSources[0].title, "Second")
    }

    func testUpdateSources_withEqualScores_maintainsRelativeOrder() {
        let s1 = KnowledgeSource(pageID: UUID(), title: "A", snippet: "s1", score: 0.5)
        let s2 = KnowledgeSource(pageID: UUID(), title: "B", snippet: "s2", score: 0.5)
        let s3 = KnowledgeSource(pageID: UUID(), title: "C", snippet: "s3", score: 0.5)

        SourceStore.shared.updateSources([s1, s2, s3])

        // score 相同时保持原顺序（稳定排序：score > 不是 >=）
        XCTAssertEqual(SourceStore.shared.activeSources[0].title, "A")
        XCTAssertEqual(SourceStore.shared.activeSources[1].title, "B")
        XCTAssertEqual(SourceStore.shared.activeSources[2].title, "C")
    }
}
