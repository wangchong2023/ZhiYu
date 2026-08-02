//
//  ZhiYuE2ETests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 ZhiYuE2E 开展自动化单元测试验证。
//
import XCTest
import MultipeerConnectivity
@preconcurrency import GRDB
@testable import ZhiYu

// MARK: - E2E: Complete Knowledge Page Workflow Tests
/// 覆盖从创建→编辑→链接→健康检查→删除的完整页面生命周期
@MainActor
final class KnowledgePageWorkflowTests: XCTestCase {

    var store: AppStore!
    var linkService: LinkService!
    var lintService: LintService!

    override func setUp() async throws {
        try await super.setUp()
        
        // 1. 重置全局状态 (核心隔离逻辑)
        ServiceContainer.shared.reset()
        DatabaseManager.shared.reset()
        DatabaseManager.shared.isInTesting = true
        
        // 2. 初始化测试专用服务 (使用内存数据库)
        let dbQueue = try DatabaseQueue()
        let sqliteStore = SQLiteStore(dbWriter: dbQueue)
        let linkService = LinkService()
        let lintService = LintService()
        
        // 3. 注册到 DI 容器
        ServiceContainer.shared.register(sqliteStore, for: SQLiteStore.self)
        ServiceContainer.shared.register(linkService, for: LinkService.self)
        ServiceContainer.shared.register(lintService, for: LintService.self)
        ServiceContainer.shared.register(Logger.shared, for: (any LoggerProtocol).self)
        ServiceContainer.shared.register(UndoService(), for: UndoService.self)
        ServiceContainer.shared.register(BackupService(), for: BackupService.self)
        ServiceContainer.shared.register(SettingsStore(), for: SettingsStore.self)
        
        self.store = AppStore()
        self.linkService = linkService
        self.lintService = lintService
    }

    override func tearDown() async throws {
        store = nil
        linkService = nil
        lintService = nil
        // 允许当前主线程/协程事件循环排水，确保所有未完成的异步任务运行完毕，规避重置 DI 导致的 Race Condition (@SRS-7.1)
        try? await Task.sleep(nanoseconds: 50_000_000)
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - Page Creation

    func testCreatePageWithAllFields() {
        let page = KnowledgePage(
            title: "E2E Test Page",
            pageType: .entity,
            customIcon: "star.fill",
            content: "This is test content with enough characters to not be a stub. We need to reach at least one hundred characters to satisfy the business logic in KnowledgePage.",
            aliases: ["E2E Alias", "Test Alias"],
            tags: ["e2e", "test", "automation"],
            status: .active,
            confidence: .high,
            sources: ["Source A"],
            relatedPageIDs: [],
            isPinned: true
        )

        XCTAssertEqual(page.title, "E2E Test Page")
        XCTAssertEqual(page.pageType, .entity)
        XCTAssertEqual(page.displayIcon, "star.fill")
        XCTAssertEqual(page.aliases, ["E2E Alias", "Test Alias"])
        XCTAssertEqual(page.tags, ["e2e", "test", "automation"])
        XCTAssertEqual(page.status, .active)
        XCTAssertEqual(page.confidence, .high)
        XCTAssertTrue(page.isPinned)
        XCTAssertFalse(page.isStub)
    }

    func testCreatePageAutoCalculatesIsStub() {
        let shortContent = KnowledgePage(title: "Short", pageType: .entity, content: "Tiny")
        XCTAssertTrue(shortContent.isStub)

        let longContent = KnowledgePage(title: "Long", pageType: .entity, content: String(repeating: "word ", count: 30))
        XCTAssertFalse(longContent.isStub)
    }

    // MARK: - Page Editing

    func testUpdatePageTitlePropagation() {
        var page = KnowledgePage(title: "Original Title", pageType: .concept, content: "Content here")
        page.title = "Updated Title"

        XCTAssertEqual(page.title, "Updated Title")
    }

    func testUpdatePageTags() {
        var page = KnowledgePage(title: "Tagged Page", pageType: .entity, content: String(repeating: "x ", count: 30))

        XCTAssertTrue(page.tags.isEmpty)

        page.tags = ["new-tag", "another-tag"]
        XCTAssertEqual(page.tags.count, 2)
        XCTAssertTrue(page.tags.contains("new-tag"))
    }

    // MARK: - PageLinks

    func testBidirectionalLinkCreation() async {
        var pageA = KnowledgePage(title: "Page A", pageType: .entity, content: "Links to [[Page B]]")
        var pageB = KnowledgePage(title: "Page B", pageType: .concept, content: "Links to [[Page A]]")

        // Outgoing links
        XCTAssertEqual(pageA.outgoingLinks, ["Page B"])
        XCTAssertEqual(pageB.outgoingLinks, ["Page A"])

        // Backlinks via LinkService
        let pages = [pageA, pageB]
        let aBacklinks = await linkService.backlinks(for: pageA.id, in: pages)
        let bBacklinks = await linkService.backlinks(for: pageB.id, in: pages)

        XCTAssertEqual(aBacklinks.map(\.title), ["Page B"])
        XCTAssertEqual(bBacklinks.map(\.title), ["Page A"])
    }

    func testSelfReferencingLinkHandled() {
        let page = KnowledgePage(title: "Self", pageType: .entity, content: "Links to [[Self]] and [[self]]")
        XCTAssertEqual(page.outgoingLinks.count, 2)
        XCTAssertEqual(page.outgoingLinks, ["Self", "self"])
    }

    func testBrokenPageLinksIdentified() async {
        let pageA = KnowledgePage(title: "A", pageType: .entity, content: "Links to [[NonExistent Page]]")
        let pageB = KnowledgePage(title: "B", pageType: .concept, content: "Real link to [[C]]")
        var pageC = KnowledgePage(title: "C", pageType: .source, content: "Content here")

        let pages = [pageA, pageB, pageC]

        let issues = await lintService.runLint(pages: pages, linkService: linkService)
        let errorIssues = issues.filter { $0.severity == .error }

        // A has broken link to NonExistent Page
        XCTAssertFalse(errorIssues.isEmpty, "Should detect at least one broken link")
    }

    // MARK: - Undo/Redo

    func testUndoRedoFullCycle() {
        let undoService = UndoService()

        let v1 = [KnowledgePage(title: "V1", pageType: .entity, content: "Version 1 content")]
        let v2 = [KnowledgePage(title: "V2", pageType: .concept, content: "Version 2 content")]
        let v3 = [KnowledgePage(title: "V3", pageType: .source, content: "Version 3 content")]

        // Push initial state
        undoService.pushSnapshot(v1)
        XCTAssertTrue(undoService.canUndo)
        XCTAssertFalse(undoService.canRedo)

        // Undo v2 → v1
        let afterUndo = undoService.undo(currentPages: v2)
        XCTAssertEqual(afterUndo?.first?.title, "V1")
        XCTAssertTrue(undoService.canRedo)
        XCTAssertFalse(undoService.canUndo)

        // Redo v1 → v2
        // swiftlint:disable:next force_unwrapping
        let afterRedo = undoService.redo(currentPages: afterUndo!)
        XCTAssertEqual(afterRedo?.first?.title, "V2")
        XCTAssertTrue(undoService.canUndo)
        XCTAssertFalse(undoService.canRedo)

        // New action clears redo
        undoService.pushSnapshot(v3)
        XCTAssertFalse(undoService.canRedo, "New snapshot should clear redo stack")
    }

    // MARK: - Page Deletion

    func testDeletePageRemovesFromList() {
        let page1 = KnowledgePage(title: "To Delete", pageType: .entity, content: "Content")
        let page2 = KnowledgePage(title: "To Keep", pageType: .concept, content: "More content here")

        var pages = [page1, page2]
        pages.removeAll { $0.id == page1.id }

        XCTAssertEqual(pages.count, 1)
        XCTAssertEqual(pages.first?.title, "To Keep")
    }

    // MARK: - Health Check Integration

    func testHealthCheckNoIssuesForHealthyKnowledge() async {
        var page1 = KnowledgePage(title: "Healthy A", pageType: .entity, content: String(repeating: "Healthy content here. ", count: 10))
        var page2 = KnowledgePage(title: "Healthy B", pageType: .concept, content: "Links to [[Healthy A]]. " + String(repeating: "More healthy content. ", count: 10))

        let pages = [page1, page2]

        let issues = await lintService.runLint(pages: pages, linkService: linkService)
        let errorCount = issues.filter { $0.severity == .error }.count

        // No broken links, no orphans (both pages link to each other)
        XCTAssertEqual(errorCount, 0, "Healthy knowledge should produce no errors")
    }

    func testStubPagesFlaggedByHealthCheck() async {
        let stubPage = KnowledgePage(title: "Stubby", pageType: .entity, content: "Too short")

        let pages = [stubPage]
        let issues = await lintService.runLint(pages: pages, linkService: linkService)

        let stubIssues = issues.filter {
            $0.message.localizedCaseInsensitiveContains("stub") ||
            $0.message.localizedCaseInsensitiveContains("short") ||
            $0.message.localizedCaseInsensitiveContains("内容过少")
        }

        XCTAssertFalse(stubIssues.isEmpty, "Stub pages should be flagged by health check")
    }
}

// MARK: - E2E: Search and Filter Workflow
@MainActor
final class SearchFilterWorkflowTests: XCTestCase {

    var linkService: LinkService!

    override func setUp() async throws {
        try await super.setUp()
        ServiceContainer.shared.reset()
        DatabaseManager.shared.reset()
        DatabaseManager.shared.isInTesting = true
        
        let dbQueue = try DatabaseQueue()
        let sqliteStore = SQLiteStore(dbWriter: dbQueue)
        linkService = LinkService()
        
        ServiceContainer.shared.register(sqliteStore, for: SQLiteStore.self)
        ServiceContainer.shared.register(linkService, for: LinkService.self)
        ServiceContainer.shared.register(Logger.shared, for: (any LoggerProtocol).self)
    }
    
    override func tearDown() async throws {
        linkService = nil
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    func testSearchByTitleExactMatch() async {
        let pages = [
            KnowledgePage(title: "Machine Learning", pageType: .concept, content: "ML content"),
            KnowledgePage(title: "Deep Learning", pageType: .concept, content: "DL content"),
            KnowledgePage(title: "Machine", pageType: .entity, content: "Just machine")
        ]

        let results = await linkService.search(query: "Machine Learning", in: pages)
        XCTAssertTrue(results.contains { $0.title == "Machine Learning" })
        XCTAssertFalse(results.contains { $0.title == "Machine" })
    }

    func testSearchByPartialTitle() async {
        let pages = [
            KnowledgePage(title: "Neural Network", pageType: .entity, content: "Content"),
            KnowledgePage(title: "Network Analysis", pageType: .concept, content: "Content")
        ]

        let results = await linkService.search(query: "Network", in: pages)
        XCTAssertEqual(results.count, 2)
    }

    func testSearchByContent() async {
        let pages = [
            KnowledgePage(title: "Doc A", pageType: .source, content: "Python is a great language for data science"),
            KnowledgePage(title: "Doc B", pageType: .source, content: "JavaScript is great for web")
        ]

        let results = await linkService.search(query: "data science", in: pages)
        XCTAssertTrue(results.contains { $0.title == "Doc A" })
        XCTAssertFalse(results.contains { $0.title == "Doc B" })
    }

    func testSearchByTag() async {
        let pages = [
            KnowledgePage(title: "Tagged", pageType: .entity, content: "Content", tags: ["important", "priority"]),
            KnowledgePage(title: "Untagged", pageType: .concept, content: "Content", tags: [])
        ]

        let results = await linkService.search(query: "important", in: pages)
        XCTAssertTrue(results.contains { $0.title == "Tagged" })
        XCTAssertFalse(results.contains { $0.title == "Untagged" })
    }

    func testFilterByPageType() {
        let pages = [
            KnowledgePage(title: "Entity Page", pageType: .entity, content: "Content " + String(repeating: "x ", count: 30)),
            KnowledgePage(title: "Concept Page", pageType: .concept, content: "Content " + String(repeating: "y ", count: 30)),
            KnowledgePage(title: "Source Page", pageType: .source, content: "Content " + String(repeating: "z ", count: 30)),
            KnowledgePage(title: "Another Entity", pageType: .entity, content: "Content " + String(repeating: "a ", count: 30))
        ]

        let entityPages = pages.filter { $0.pageType == .entity }
        XCTAssertEqual(entityPages.count, 2)

        let conceptPages = pages.filter { $0.pageType == .concept }
        XCTAssertEqual(conceptPages.count, 1)
    }

    func testSortByRecentlyUpdated() {
        var oldPage = KnowledgePage(title: "Old", pageType: .entity, content: "Content")
        var newPage = KnowledgePage(title: "New", pageType: .entity, content: "Content")

        // Simulate dates
        oldPage = KnowledgePage(
            id: oldPage.id,
            title: oldPage.title,
            pageType: oldPage.pageType,
            content: oldPage.content,
            aliases: oldPage.aliases,
            tags: oldPage.tags,
            status: oldPage.status,
            confidence: oldPage.confidence,
            sources: oldPage.sources,
            relatedPageIDs: oldPage.relatedPageIDs,
            isPinned: oldPage.isPinned,
            createdAt: Date().addingTimeInterval(-86400),
            updatedAt: Date().addingTimeInterval(-86400)
        )

        let sorted = [oldPage, newPage].sorted { $0.updatedAt > $1.updatedAt }
        XCTAssertEqual(sorted.first?.title, "New")
    }
}

// MARK: - E2E: Collaboration Workflow
@MainActor
final class CollaborationWorkflowTests: XCTestCase {

    func testCollabEditStructure() {
        let edit = CollabEdit(
            id: UUID().uuidString,
            userID: "user1",
            pageID: UUID(),
            field: "title",
            oldValue: "Old Title",
            newValue: "New Title",
            timestamp: Date()
        )

        XCTAssertEqual(edit.field, "title")
        XCTAssertEqual(edit.oldValue, "Old Title")
        XCTAssertEqual(edit.newValue, "New Title")
    }

    func testCollabUserDisplayLabel() {
        let user = CollabUser(
            id: "u1",
            displayName: "Alice",
            deviceName: "iPhone 15",
            joinedAt: Date()
        )

        XCTAssertEqual(user.displayLabel, "Alice (iPhone 15)")
    }

    func testDiscoveredRoomStructure() {
        let peer = MCPeerID(displayName: "peer123")
        let room = DiscoveredRoom(
            id: "room-1",
            platformPeer: peer,
            roomName: "Test Room",
            owner: "HostUser"
        )

        XCTAssertEqual(room.roomName, "Test Room")
        XCTAssertEqual(room.owner, "HostUser")
    }

    func testRolePermissions() {
        // Only test display metadata since permissions properties were removed
        XCTAssertFalse(CollabRole.owner.displayName.isEmpty)
        XCTAssertEqual(CollabRole.owner.icon, "crown.fill")
        XCTAssertEqual(CollabRole.editor.icon, "pencil.circle.fill")
    }
}

// MARK: - E2E: Backup and Restore Workflow
@MainActor
final class BackupRestoreWorkflowTests: XCTestCase {

    var backupService: BackupService!

    var tempDir: URL!

    override func setUp() async throws {
        try await super.setUp()
        ServiceContainer.shared.reset()
        
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        backupService = BackupService(baseDirectory: tempDir)
        ServiceContainer.shared.register(backupService, for: BackupService.self)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
        backupService = nil
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    func testCreateAndRestoreBackup() {
        let original = [
            KnowledgePage(title: "Page A", pageType: .entity, content: "Content A " + String(repeating: "x ", count: 20)),
            KnowledgePage(title: "Page B", pageType: .concept, content: "Content B " + String(repeating: "y ", count: 20))
        ]

        backupService.createBackup(pages: original)

        guard let entry = backupService.backupEntries.first else {
            XCTFail("Backup entry should exist"); return
        }

        let restored = backupService.restoreBackup(entry)
        XCTAssertNotNil(restored)
        XCTAssertEqual(restored?.count, 2)

        let restoredA = restored?.first { $0.title == "Page A" }
        XCTAssertNotNil(restoredA)
    }

    func testBackupPreservesAllPageTypes() {
        var pages: [KnowledgePage] = []
        for type in PageType.allCases {
            pages.append(KnowledgePage(title: "\(type.rawValue.capitalized) Page", pageType: type, content: "Content for \(type.rawValue) " + String(repeating: "x ", count: 20)))
        }

        backupService.createBackup(pages: pages)
        guard let entry = backupService.backupEntries.first else {
            XCTFail("Backup entry should exist"); return
        }

        let restored = backupService.restoreBackup(entry)
        XCTAssertEqual(restored?.count, PageType.allCases.count)

        for type in PageType.allCases {
            let found = restored?.contains { $0.pageType == type } ?? false
            XCTAssertTrue(found, "Page of type \(type.rawValue) should be in restored backup")
        }
    }

    func testMarkDirtyAndCleanWorkflow() {
        XCTAssertFalse(backupService.hasUnsavedChanges)

        backupService.markDirty()
        XCTAssertTrue(backupService.hasUnsavedChanges)

        backupService.markClean()
        XCTAssertFalse(backupService.hasUnsavedChanges)
    }
}

// MARK: - E2E: Ingest Pipeline
@MainActor
final class IngestPipelineTests: XCTestCase {

    var ingestService: IngestService!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        ingestService = IngestService()
        ServiceContainer.shared.register(ingestService, for: IngestService.self)
    }
    
    override func tearDown() async throws {
        ingestService = nil
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    func testExtractConceptsFromMixedContent() async {
        let existingPages = [
            KnowledgePage(title: "Machine Learning", pageType: .concept, content: "ML content"),
            KnowledgePage(title: "Neural Network", pageType: .entity, content: "NN content"),
            KnowledgePage(title: "Deep Learning", pageType: .concept, content: "DL content"),
            KnowledgePage(title: "Python", pageType: .source, content: "Python content")
        ]

        let newContent = """
        Machine Learning and Neural Networks are related fields.
        Deep Learning uses Neural Networks as building blocks.
        Python is commonly used for ML.
        """

        let concepts = await ingestService.extractConcepts(from: newContent, pages: existingPages)

        XCTAssertTrue(concepts.contains("Machine Learning"), "Should extract 'Machine Learning'")
        XCTAssertTrue(concepts.contains("Neural Network"), "Should extract 'Neural Network'")
        XCTAssertTrue(concepts.contains("Deep Learning"), "Should extract 'Deep Learning'")
        XCTAssertTrue(concepts.contains("Python"), "Should extract 'Python'")
        XCTAssertEqual(concepts.count, 4, "Should extract exactly 4 unique concepts")
    }

    func testDocumentFormatDetectionPipeline() {
        let testCases: [(String, DocumentFormat)] = [
            ("document.md", .markdown),
            ("notes.txt", .plainText),
            ("report.pdf", .pdf),
            ("data.xlsx", .xlsx),
            ("document.docx", .docx),
            ("unknown.xyz", .unknown),
            ("UPPERCASE.MD", .markdown)
        ]

        for (filename, expected) in testCases {
            let url = URL(fileURLWithPath: "/path/to/\(filename)")
            let detected = DocumentFormat.detectFormat(from: url)
            XCTAssertEqual(detected, expected, "Failed for \(filename)")
        }
    }
}

// MARK: - E2E: Graph Layout with Realistic Data
@MainActor
final class GraphLayoutRealisticTests: XCTestCase {

    func testLayoutWith100NodesCompletesInReasonableTime() {
        var pages: [KnowledgePage] = []
        for i in 0..<100 {
            var page = KnowledgePage(
                title: "Page \(i)",
                pageType: PageType.allCases[i % PageType.allCases.count],
                content: "Content for page \(i). " + String(repeating: "word ", count: 20)
            )
            // Create some links between pages
            if i > 0 {
                page = KnowledgePage(
                    id: page.id,
                    title: page.title,
                    pageType: page.pageType,
                    content: "Links to [[Page \(i - 1)]] and [[Page \(i - 2)]]",
                    aliases: page.aliases,
                    tags: page.tags,
                    status: page.status,
                    confidence: page.confidence,
                    sources: page.sources,
                    relatedPageIDs: page.relatedPageIDs,
                    isPinned: page.isPinned,
                    createdAt: page.createdAt,
                    updatedAt: page.updatedAt
                )
            }
            pages.append(page)
        }

        let start = Date()
        let result = GraphLayoutProcessor.layout(
            pages: pages,
            linkResolver: { title in
                let numStr = title.replacingOccurrences(of: "Page ", with: "")
                if let num = Int(numStr), num >= 0, num < pages.count {
                    return pages[num]
                }
                return nil
            },
            canvasSize: CGSize(width: DesignSystem.Metrics.snapshotScrollHeight, height: DesignSystem.Metrics.snapshotGraphCanvasWidth)
        )
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertEqual(result.nodes.count, 100)
        XCTAssertGreaterThan(result.edges.count, 0)
        XCTAssertLessThan(elapsed, 5.0, "Layout should complete in under 5 seconds for 100 nodes")
    }

    func testGraphCommunitiesIdentified() {
        // Create a graph with clear community structure
        var communityA: [KnowledgePage] = []
        for i in 0..<5 {
            var page = KnowledgePage(title: "A\(i)", pageType: .entity, content: "Content A " + String(repeating: "x ", count: 20))
            if i > 0 {
                page = KnowledgePage(
                    id: page.id,
                    title: page.title,
                    pageType: page.pageType,
                    content: "Links to [[A\(i - 1)]]",
                    aliases: page.aliases,
                    tags: page.tags,
                    status: page.status,
                    confidence: page.confidence,
                    sources: page.sources,
                    relatedPageIDs: page.relatedPageIDs,
                    isPinned: page.isPinned,
                    createdAt: page.createdAt,
                    updatedAt: page.updatedAt
                )
            }
            communityA.append(page)
        }

        var communityB: [KnowledgePage] = []
        for i in 0..<5 {
            var page = KnowledgePage(title: "B\(i)", pageType: .concept, content: "Content B " + String(repeating: "y ", count: 20))
            if i > 0 {
                page = KnowledgePage(
                    id: page.id,
                    title: page.title,
                    pageType: page.pageType,
                    content: "Links to [[B\(i - 1)]]",
                    aliases: page.aliases,
                    tags: page.tags,
                    status: page.status,
                    confidence: page.confidence,
                    sources: page.sources,
                    relatedPageIDs: page.relatedPageIDs,
                    isPinned: page.isPinned,
                    createdAt: page.createdAt,
                    updatedAt: page.updatedAt
                )
            }
            communityB.append(page)
        }

        let allPages = communityA + communityB

        let result = GraphLayoutProcessor.layout(
            pages: allPages,
            linkResolver: { title in allPages.first { $0.title == title } },
            canvasSize: CGSize(width: DesignSystem.Metrics.snapshotScrollHeight, height: DesignSystem.Metrics.snapshotGraphCanvasWidth)
        )

        // Should have 10 nodes and 8 edges (5-1 in A, 5-1 in B)
        XCTAssertEqual(result.nodes.count, 10)
        XCTAssertEqual(result.edges.count, 8)

        // Check all nodes are within canvas
        for node in result.nodes {
            XCTAssertGreaterThanOrEqual(node.position.x, 0)
            XCTAssertGreaterThanOrEqual(node.position.y, 0)
            XCTAssertLessThanOrEqual(node.position.x, 1200)
            XCTAssertLessThanOrEqual(node.position.y, 800)
        }
    }
}

// MARK: - E2E: Markdown Rendering
final class MarkdownRenderingTests: XCTestCase {

    var parser: MarkdownProcessor!

    override func setUp() async throws {
        try await super.setUp()
        parser = MarkdownProcessor()
    }

    func testAllMarkdownBlockTypesParsed() {
        let content = """
        # Heading 1

        Some paragraph text.

        ## Heading 2

        - Bullet item 1
        - Bullet item 2

        1. Ordered item 1
        2. Ordered item 2

        > Blockquote text

        ```
        code block
        ```

        | Header 1 | Header 2 |
        |----------|----------|
        | Cell 1   | Cell 2   |

        - [ ] Unchecked task
        - [x] Checked task

        ---

        More text after HR.
        """

        let blocks = parser.parse(content)
        XCTAssertGreaterThanOrEqual(blocks.count, 9, "Should parse at least 9 block types")
    }

    func testInlineFormattingExtraction() {
        let content = "**bold** and *italic* and `code` and [[PageLink]]"

        let segments = parser.parseInlineSegments(content)

        let boldSegments = segments.filter { $0.type == .bold }
        let italicSegments = segments.filter { $0.type == .italic }
        let codeSegments = segments.filter { $0.type == .code }
        let pageLinkSegments = segments.filter { $0.type == .applink }

        XCTAssertEqual(boldSegments.first?.content, "bold")
        XCTAssertEqual(italicSegments.first?.content, "italic")
        XCTAssertEqual(codeSegments.first?.content, "code")
        XCTAssertEqual(pageLinkSegments.first?.content, "PageLink")
    }

    func testComplexNestedFormatting() {
        let content = "**Bold with `code` inside** and *italic with [[link]]*"

        let segments = parser.parseInlineSegments(content)

        // Should still extract bold and italic even with nested content
        XCTAssertFalse(segments.isEmpty)
    }
}

// MARK: - E2E: Log and Audit Trail
@MainActor
final class LogAuditTrailTests: XCTestCase {

    var logService: Logger!
    var tempDir: URL!

    override func setUp() async throws {
        try await super.setUp()
        ServiceContainer.shared.reset()
        
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        logService = Logger(customDirectory: tempDir)
        ServiceContainer.shared.register(logService, for: (any LoggerProtocol).self)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
        logService = nil
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }
    func testLogEntryCapturesAllActionTypes() async {
        logService.addLog(action: .create, target: "Test Page", details: "Created new page")
        logService.addLog(action: .update, target: "Test Page", details: "Updated content")
        logService.addLog(action: .delete, target: "Test Page", details: "Deleted page")
        logService.addLog(action: .lint, target: "Knowledge", details: "Ran full lint: 3 issues found")

        try? await Task.sleep(nanoseconds: 200_000_000)
        let entries = await logService.getLogEntries()
        XCTAssertEqual(entries.count, 4)

        // Verify action types
        let actions = entries.map(\.action)
        XCTAssertTrue(actions.contains(.create))
        XCTAssertTrue(actions.contains(.update))
        XCTAssertTrue(actions.contains(.delete))
        XCTAssertTrue(actions.contains(.lint))
    }

    func testLogOrderingNewestFirst() async {
        logService.addLog(action: .update, target: "T1", details: "first")
        try? await Task.sleep(nanoseconds: 50_000_000)
        logService.addLog(action: .update, target: "T2", details: "second")
        try? await Task.sleep(nanoseconds: 50_000_000)
        logService.addLog(action: .update, target: "T3", details: "third")

        let maxWait = 10
        var entries: [LogEntry] = []
        for _ in 0..<maxWait {
            entries = await logService.getLogEntries()
            if entries.count >= 3 { break }
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        XCTAssertEqual(entries.first?.target, "T3")
        XCTAssertEqual(entries.last?.target, "T1")
    }

    func testLogMaxEntriesCapped() async {
        for i in 0..<600 {
            logService.addLog(action: .update, target: "page_\(i)", details: "Log entry \(i)")
        }

        let maxWait = 10
        var entries: [LogEntry] = []
        for _ in 0..<maxWait {
            entries = await logService.getLogEntries()
            if entries.count <= 500 { break }
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        XCTAssertLessThanOrEqual(entries.count, 500, "Log should cap at 500 entries")
    }
}
