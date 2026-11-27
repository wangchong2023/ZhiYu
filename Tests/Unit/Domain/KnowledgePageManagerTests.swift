import XCTest
import UFPCore
@testable import ZhiYuUnitTestHost

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

// MARK: - deletePage 备份脏位标记 (缺陷 #84)

final class KnowledgePageDeleteMarkDirtyTests: XCTestCase {

    /// 删除页面是数据变更，应与 create/update/rename 一致标记备份脏位 (缺陷 #84)。
    @MainActor
    func testDeletePage_marksBackupDirty() async throws {
        setupFullMockEnvironment()

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ZhiYuTest-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        ServiceContainer.shared.register(BackupService(baseDirectory: tempDir), for: BackupService.self)

        let manager = KnowledgePageManager()
        let page = KnowledgePage(title: "缺陷84测试", pageType: .concept, content: "内容")

        try await manager.deletePage(page, currentPages: [])

        let dirtyFlag = tempDir.appendingPathComponent(".knowledge-management_dirty")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: dirtyFlag.path),
            "删除页面是数据变更，应与 create/update/rename 一致标记备份脏位 (缺陷 #84)"
        )
    }

    // MARK: - 缺陷 #240 回归：UTF-16 Emoji 偏移安全、已有双链保护与空白重命名早退

    @MainActor
    func testWrapPlainOccurrences_withLeadingEmoji_doesNotCrashOrCorruptIndices() {
        let content = "🚀👨‍👩‍👧‍👦🇨🇳 深入理解 Swift 并发模型，再谈 swift 内存安全。"
        let wrapped = KnowledgePageManager.wrapPlainOccurrences(
            in: content,
            target: "Swift",
            open: "[[",
            close: "]]"
        )

        XCTAssertEqual(wrapped, "🚀👨‍👩‍👧‍👦🇨🇳 深入理解 [[Swift]] 并发模型，再谈 [[swift]] 内存安全。")
    }

    @MainActor
    func testWrapPlainOccurrences_skipsExistingWikiLinksWithAliasOrAnchor() {
        let content = "已有 [[Swift|语言]]、[[Swift#并发]] 和 [[Other|Swift]]，但纯文本 Swift 需要包裹。"
        let wrapped = KnowledgePageManager.wrapPlainOccurrences(
            in: content,
            target: "Swift",
            open: "[[",
            close: "]]"
        )

        XCTAssertEqual(
            wrapped,
            "已有 [[Swift|语言]]、[[Swift#并发]] 和 [[Other|Swift]]，但纯文本 [[Swift]] 需要包裹。"
        )
    }

    @MainActor
    func testRenamePage_blankTitle_skipsWriteAndBackupDirty() async throws {
        setupFullMockEnvironment()
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ZhiYuRenameTest-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        ServiceContainer.shared.register(BackupService(baseDirectory: tempDir), for: BackupService.self)
        let manager = KnowledgePageManager()
        let page = KnowledgePage(title: "原标题", pageType: .concept, content: "正文")

        try await manager.renamePage(page, to: "   \n ", currentPages: [page])

        let dirtyFlag = tempDir.appendingPathComponent(".knowledge-management_dirty")
        XCTAssertFalse(FileManager.default.fileExists(atPath: dirtyFlag.path), "空白重命名应早退，不应标记备份脏位")
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
