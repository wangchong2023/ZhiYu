import XCTest
@testable import ZhiYu

/// KnowledgePage processor 协议测试（不依赖 DI）
final class KnowledgePageProcessorTests: XCTestCase {

    func testMockProcessor_returnsSamePage() async throws {
        let processor = MockProcessor(id: "test", name: "Test")
        let page = KnowledgePage(title: "测试页面", pageType: .concept, content: "# 测试")

        let result = try await processor.process(page: page)

        XCTAssertEqual(result.title, page.title)
        XCTAssertEqual(result.content, page.content)
    }

    func testMockProcessor_withModifiedContent() async throws {
        let processor = MockProcessor(id: "modifier", name: "Modifier")
        let page = KnowledgePage(title: "原始标题", pageType: .concept, content: "原始内容")

        let result = try await processor.process(page: page)

        XCTAssertEqual(result.title, "原始标题")
    }

    func testMockProcessor_concurrentCalls() async throws {
        let processor = MockProcessor(id: "concurrent", name: "Concurrent")
        let page = KnowledgePage(title: "并发测试", pageType: .entity, content: "内容")

        async let r1 = processor.process(page: page)
        async let r2 = processor.process(page: page)
        async let r3 = processor.process(page: page)

        let results = try await [r1, r2, r3]
        for result in results {
            XCTAssertEqual(result.title, "并发测试")
        }
    }

    func testProcessorIdentity() {
        let p1 = MockProcessor(id: "a", name: "Alpha")
        let p2 = MockProcessor(id: "b", name: "Beta")

        XCTAssertEqual(p1.id, "a")
        XCTAssertEqual(p1.name, "Alpha")
        XCTAssertEqual(p2.id, "b")
        XCTAssertEqual(p2.name, "Beta")
        XCTAssertNotEqual(p1.id, p2.id)
    }
}

// MARK: - 测试用 Processor

private final class MockProcessor: KnowledgePageProcessor {
    let id: String
    let name: String
    nonisolated(unsafe) var processedCount = 0

    init(id: String, name: String) {
        self.id = id
        self.name = name
    }

    func process(page: KnowledgePage) async throws -> KnowledgePage {
        processedCount += 1
        return page
    }
}
