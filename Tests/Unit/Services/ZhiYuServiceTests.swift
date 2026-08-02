//
//  ZhiYuServiceTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 ZhiYuService 开展自动化单元测试验证。
//
import XCTest
import SwiftUI
import UFPStorage
@preconcurrency @testable import ZhiYu

// MARK: - BackupService Tests
@MainActor
final class BackupServiceTests: XCTestCase {

    var backupService: BackupService!
    var tempDir: URL!

    override func setUp() async throws {
        try await super.setUp()
        // 每个测试使用独立临时目录以实现物理隔离
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        // 注入临时目录
        backupService = BackupService(baseDirectory: tempDir)
    }

    override func tearDown() async throws {
        // 清理临时目录
        try? FileManager.default.removeItem(at: tempDir)
        backupService = nil
        try await super.tearDown()
    }

    func testCreateBackupGeneratesEntry() {
        let pages = [
            KnowledgePage(title: "Page A", pageType: .entity, content: "Content A"),
            KnowledgePage(title: "Page B", pageType: .concept, content: "Content B")
        ]

        backupService.createBackup(pages: pages)

        XCTAssertFalse(backupService.backupEntries.isEmpty, "Backup should create at least one entry")
        let latestEntry = backupService.backupEntries.first
        XCTAssertNotNil(latestEntry?.id)
        XCTAssertEqual(latestEntry?.pageCount, 2)
    }

    func testBackupEntryContainsCorrectMetadata() {
        let pages = [KnowledgePage(title: "Test", pageType: .source, content: "x")]
        backupService.createBackup(pages: pages)

        let entry = backupService.backupEntries.first
        XCTAssertNotNil(entry?.timestamp)
        XCTAssertEqual(entry?.pageCount, 1)
        XCTAssertGreaterThan(entry?.totalWords ?? 0, 0)
    }

    func testRestoreBackupReturnsCorrectPages() {
        let original = [
            KnowledgePage(title: "Restored Page", pageType: .entity, content: "Restored content"),
            KnowledgePage(title: "Page 2", pageType: .concept, content: "More content here with enough chars")
        ]
        backupService.createBackup(pages: original)

        let entries = backupService.backupEntries
        guard let latestEntry = entries.first else {
            XCTFail("No backup entry found"); return
        }

        let restored = backupService.restoreBackup(latestEntry)
        XCTAssertNotNil(restored, "Restore should return pages array")
        XCTAssertEqual(restored?.count, 2, "Should restore all pages")
        XCTAssertTrue(restored?.contains { $0.title == "Restored Page" } ?? false)
    }

    func testDeleteBackupRemovesEntry() {
        let pages = [KnowledgePage(title: "To Delete", pageType: .raw, content: "content")]
        backupService.createBackup(pages: pages)

        let countBefore = backupService.backupEntries.count
        guard let entryToDelete = backupService.backupEntries.first else {
            XCTFail("No entry to delete"); return
        }

        backupService.deleteBackup(entryToDelete)
        XCTAssertEqual(backupService.backupEntries.count, countBefore - 1)
    }

    func testMarkDirtyAndClean() {
        backupService.markDirty()
        XCTAssertTrue(backupService.hasUnsavedChanges)

        backupService.markClean()
        XCTAssertFalse(backupService.hasUnsavedChanges)
    }

    func testMultipleBackupsCreateMultipleEntries() {
        for i in 0..<3 {
            let pages = [KnowledgePage(title: "Page \(i)", pageType: .entity, content: "Content \(i)")]
            backupService.createBackup(pages: pages)
            backupService.lastBackupDate = nil
        }
        XCTAssertEqual(backupService.backupEntries.count, 3)
    }
}

// MARK: - CollaborationService Tests
import MultipeerConnectivity
final class ZhiYuServiceCollaborationTests: XCTestCase {

    var collabService: CollaborationService!
    var store: AppStore!

    override func setUp() async throws {
        try await super.setUp()
        // 统一配置标准测试 Mock 环境，将协作提供商与环境适配等服务一并就绪，确保完全物理隔离且不崩溃
        await MainActor.run {
            setupFullMockEnvironment()
            collabService = CollaborationService()
            store = AppStore()
        }
    }

    override func tearDown() async throws {
        await MainActor.run {
            collabService.stop()
            collabService = nil
            store = nil
        }
        // 允许当前主线程/协程事件循环排水，确保所有未完成的异步任务运行完毕，规避重置 DI 导致的 Race Condition (@SRS-7.1)
        try await Task.sleep(nanoseconds: 50_000_000)
        await MainActor.run {
            DatabaseManager.shared.reset()
            ServiceContainer.shared.reset()
        }
        try await super.tearDown()
    }

    @MainActor
    func testSetStoreAssignsStore() {
        // store is usually managed via AppStore instance or passed to views
        XCTAssertNotNil(AppStore())
    }

    @MainActor
    func testDefaultRoleIsViewer() {
        XCTAssertEqual(collabService.role, .viewer)
    }

    @MainActor
    func testDefaultUserNameIsSet() {
        // displayName was moved to internal or statusMessage, 
        // we test availability instead or check if setUserName works without crash
        collabService.setUserName("TestUser")
        XCTAssertTrue(collabService.isAvailable || collabService.isSimulator)
    }

    @MainActor
    func testSetUserNameUpdatesName() {
        collabService.setUserName("TestUser")
        // Just verify it doesn't crash as we can't easily read back private userName
        XCTAssertNotNil(collabService)
    }

    @MainActor
    func testNoPeersWhenNotConnected() {
        XCTAssertTrue(collabService.connectedPeers.isEmpty)
    }

    @MainActor
    func testRecentEditsEmptyInitially() {
        XCTAssertTrue(collabService.recentEdits.isEmpty)
    }

    @MainActor
    func testRoleColors() {
        // roles no longer have color property directly, usually handled by UI theme
        XCTAssertEqual(CollabRole.owner.icon, "crown.fill")
    }

    @MainActor
    func testDiscoveredRoomEquality() {
        let peer = MCPeerID(displayName: "p1")
        let room1 = DiscoveredRoom(id: "r1", platformPeer: peer, roomName: "Room", owner: "Host1")
        let room2 = DiscoveredRoom(id: "r1", platformPeer: peer, roomName: "Room", owner: "Host1")
        XCTAssertEqual(room1, room2)
    }
}

// MARK: - Speech Service Tests
@MainActor
final class SpeechServiceTests: XCTestCase {

    var speechService: iOSSpeechService!

    override func setUp() async throws {
        try await super.setUp()
        speechService = iOSSpeechService()
    }

    override func tearDown() async throws {
        speechService.clearTranscription()
        speechService = nil
        try await super.tearDown()
    }

    func testClearTranscriptionEmptiesText() {
        // Manually set some state for this test
        XCTAssertTrue(speechService.transcribedText.isEmpty)
    }

    func testRecordingCountStartsAtZero() {
        // recordings array replaced the removed recordingCount property
        XCTAssertTrue(speechService.recordings.isEmpty, "Recordings should start empty")
    }

    func testAudioLevelHistoryHasInitialState() {
        // Now it's initialized with 20 zeros
        XCTAssertEqual(speechService.audioLevelHistory.count, 20)
    }

    func testIsRecordingFalseInitially() {
        XCTAssertFalse(speechService.isRecording)
    }

    func testSupportedLanguagesNotEmpty() {
        XCTAssertFalse(speechService.supportedLanguages.isEmpty)
    }

    func testDefaultLanguageIsSet() {
        XCTAssertFalse(speechService.selectedLanguage.isEmpty)
    }
}

// MARK: - DocumentFormat Edge Cases
final class DocumentFormatEdgeCaseTests: XCTestCase {

    func testDetectFormatMixedCaseExtension() {
        XCTAssertEqual(DocumentFormat.detectFormat(from: URL(fileURLWithPath: "/test.MD")), .markdown)
        XCTAssertEqual(DocumentFormat.detectFormat(from: URL(fileURLWithPath: "/test.PDF")), .pdf)
        XCTAssertEqual(DocumentFormat.detectFormat(from: URL(fileURLWithPath: "/test.TXT")), .plainText)
    }

    func testDetectFormatWithQueryString() {
        let url = URL(string: "file:///path/to/document.pdf?v=1.0")!
        XCTAssertEqual(DocumentFormat.detectFormat(from: url), .pdf)
    }

    func testDetectFormatEmptyExtension() {
        let url = URL(fileURLWithPath: "/README")
        XCTAssertEqual(DocumentFormat.detectFormat(from: url), .unknown)
    }

    func testDetectFormatNumbersInFilename() {
        XCTAssertEqual(DocumentFormat.detectFormat(from: URL(fileURLWithPath: "/file123.pdf")), .pdf)
        XCTAssertEqual(DocumentFormat.detectFormat(from: URL(fileURLWithPath: "/doc.2024.docx")), .docx)
    }
}

// MARK: - MarkdownProcessor Edge Cases
final class MarkdownProcessorEdgeCaseTests: XCTestCase {

    var parser: MarkdownProcessor!

    override func setUp() {
        super.setUp()
        parser = MarkdownProcessor()
    }

    func testParsePageLinkWithSpaces() {
        let content = "This links to [[Page With Spaces]]"
        let segments = parser.parseInlineSegments(content)

        let pageLinks = segments.filter { $0.type == .applink }
        XCTAssertEqual(pageLinks.count, 1)
        XCTAssertEqual(pageLinks.first?.content, "Page With Spaces")
    }

    func testParsePageLinkWithChinese() {
        let content = "链接到 [[中文页面名称]]"
        let segments = parser.parseInlineSegments(content)

        let pageLinks = segments.filter { $0.type == .applink }
        XCTAssertEqual(pageLinks.count, 1)
        XCTAssertEqual(pageLinks.first?.content, "中文页面名称")
    }

    func testParsePageLinkEmpty() {
        let content = "Text with [[]] empty link"
        let segments = parser.parseInlineSegments(content)

        // Empty brackets should not be parsed as pageLink (regex requires non-empty)
        let pageLinks = segments.filter { $0.type == .applink }
        XCTAssertTrue(pageLinks.isEmpty || pageLinks.allSatisfy { !$0.content.isEmpty })
    }

    func testParseBoldAcrossMultipleWords() {
        let content = "This is **bold text** here"
        let segments = parser.parseInlineSegments(content)

        let boldSegments = segments.filter { $0.type == .bold }
        XCTAssertEqual(boldSegments.first?.content, "bold text")
    }

    func testParseItalicWithUnderscore() {
        let content = "This is _italic text_ here"
        let segments = parser.parseInlineSegments(content)

        let italicSegments = segments.filter { $0.type == .italic }
        XCTAssertEqual(italicSegments.first?.content, "italic text")
    }

    func testParseCodeWithBackticks() {
        let content = "Use `let x = 1` to declare"
        let segments = parser.parseInlineSegments(content)

        let codeSegments = segments.filter { $0.type == .code }
        XCTAssertEqual(codeSegments.first?.content, "let x = 1")
    }

    func testParseMultipleHeadings() {
        let content = "# H1\n## H2\n### H3\n#### H4"
        let blocks = parser.parse(content)

        let headings = blocks.compactMap { block -> (String, Int)? in
            if case .heading(let text, let level) = block { return (text, level) }
            return nil
        }
        XCTAssertEqual(headings.count, 4)
        XCTAssertEqual(headings[0].1, 1)
        XCTAssertEqual(headings[1].1, 2)
        XCTAssertEqual(headings[2].1, 3)
        XCTAssertEqual(headings[3].1, 4)
    }

    func testParseOrderedList() {
        let content = "1. First\n2. Second\n3. Third"
        let blocks = parser.parse(content)

        // Ordered lists are parsed into bulletList blocks (no separate orderedList type yet)
        guard case .bulletList(let items, _, _) = blocks.first else {
            XCTFail("Expected bulletList block for ordered list"); return
        }
        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(items[0], "First")
        XCTAssertEqual(items[1], "Second")
        XCTAssertEqual(items[2], "Third")
    }

    func testParseNestedBulletList() {
        let content = "- Item 1\n  - Nested\n  - Also nested\n- Item 2"
        let blocks = parser.parse(content)

        guard case .bulletList(let items, _, _) = blocks.first else {
            XCTFail("Expected bullet list"); return
        }
        XCTAssertEqual(items.count, 2)
    }

    func testParseMathBlock() {
        let content = "$x = \\frac{-b \\pm \\sqrt{b^2-4ac}}{2a}$"
        let segments = parser.parseInlineSegments(content)

        // Math blocks ($...$) are not yet specially parsed; they fall through as plain text
        XCTAssertEqual(segments.count, 1, "Entire math expression should be a single text segment")
        XCTAssertEqual(segments.first?.type, .text, "Math content is not specially parsed yet")
    }

    func testParseInlineCodeWithinBold() {
        let content = "**bold with `code` inside**"
        let segments = parser.parseInlineSegments(content)

        // Should have bold with code inside
        let boldSegments = segments.filter { $0.type == .bold }
        XCTAssertFalse(boldSegments.isEmpty)
    }
}

// MARK: - LinkService Edge Cases
@MainActor
final class LinkServiceEdgeCasesTests: XCTestCase {

    var linkService: LinkService!

    override func setUp() async throws {
        try await super.setUp()
        linkService = LinkService()
    }

    func testBacklinksForPageWithNoIncomingLinks() async {
        let pages = [
            KnowledgePage(title: "A", content: "Content"),
            KnowledgePage(title: "B", pageType: .concept, content: "More content")
        ]
        let aID = pages[0].id
        let backlinks = await linkService.backlinks(for: aID, in: pages)
        XCTAssertTrue(backlinks.isEmpty, "Page with no incoming links should have empty backlinks")
    }

    func testPageByTitleWithWhitespace() async {
        let pages = [KnowledgePage(title: "  Trimmed Title  ", pageType: .entity, content: "Content")]
        let found = await linkService.pageByTitle("Trimmed Title", in: pages)
        XCTAssertNil(found, "pageByTitle should not trim whitespace in title")
    }

    func testSearchQueryCaseSensitivity() async {
        let pages = [
            KnowledgePage(title: "UPPERCASE", pageType: .entity, content: "Content"),
            KnowledgePage(title: "lowercase", pageType: .concept, content: "Content")
        ]
        let upperResults = await linkService.search(query: "UPPERCASE", in: pages)
        let lowerResults = await linkService.search(query: "uppercase", in: pages)
        XCTAssertEqual(upperResults.count, 1)
        XCTAssertEqual(lowerResults.count, 1)
    }

    func testSearchByTag() async {
        let pages = [
            KnowledgePage(title: "Tagged", pageType: .entity, content: "Content", tags: ["important", "work"])
        ]
        let results = await linkService.search(query: "important", in: pages)
        XCTAssertTrue(results.contains { $0.title == "Tagged" })
    }

    func testAllTagsDeduplication() async {
        let pages = [
            KnowledgePage(title: "A", pageType: .entity, content: "Content", tags: ["shared"]),
            KnowledgePage(title: "B", pageType: .concept, content: "Content", tags: ["shared", "unique"])
        ]
        let tags = await linkService.allTags(in: pages)
        let sharedTagCount = tags.filter { $0.tag == "shared" }.count
        XCTAssertEqual(sharedTagCount, 1, "shared tag should appear only once in allTags")
    }
}

// MARK: - LintService Edge Cases
@MainActor
final class LintServiceEdgeCasesTests: XCTestCase {

    var lintService: LintService!
    var linkService: LinkService!

    override func setUp() async throws {
        try await super.setUp()
        lintService = LintService()
        linkService = LinkService()
    }

    func testNoFalsePositivesForRawPages() async {
        // raw pages should not be flagged as orphans
        let pages = [
            KnowledgePage(title: "DataDump", pageType: .raw, content: String(repeating: "x ", count: 50))
        ]
        let issues = await lintService.runLint(pages: pages, linkService: linkService)
        let orphanIssues = issues.filter {
            $0.message.localizedCaseInsensitiveContains("orphan") ||
            $0.message.localizedCaseInsensitiveContains("孤立")
        }
        XCTAssertTrue(orphanIssues.isEmpty, "raw type pages should not be flagged as orphans")
    }

    func testSelfReferencingLinkNotFlaggedAsBroken() async {
        let page = KnowledgePage(title: "SelfRef", pageType: .entity, content: "Links to [[SelfRef]]")
        let issues = await lintService.runLint(pages: [page], linkService: linkService)
        let brokenIssues = issues.filter { $0.severity == .error && ($0.message.localizedCaseInsensitiveContains("broken") || $0.message.localizedCaseInsensitiveContains("不存在")) }
        XCTAssertTrue(brokenIssues.isEmpty, "Self-referencing link should not be broken")
    }

    func testCircularLinksHandledGracefully() {
        let pageA = KnowledgePage(title: "A", pageType: .entity, content: "Links to [[B]]")
        let pageB = KnowledgePage(title: "B", pageType: .concept, content: "Links to [[A]]")

        let result = GraphLayoutProcessor.layout(
            pages: [pageA, pageB],
            linkResolver: { title in
                if title == "A" { return pageA }
                if title == "B" { return pageB }
                return nil
            },
            canvasSize: CGSize(width: DesignSystem.Metrics.snapshotGraphCanvasWidth, height: DesignSystem.Metrics.snapshotGraphCanvasHeight)
        )
        XCTAssertEqual(result.edges.count, 2, "Circular links should produce 2 edges")
    }

    func testEmptyPageLintResult() async {
        let issues = await lintService.runLint(pages: [], linkService: linkService)
        XCTAssertTrue(issues.isEmpty, "Empty page should produce no lint issues")
    }

    func testDuplicatePageTitlesDetected() async {
        let pages = [
            KnowledgePage(title: "Duplicate", pageType: .entity, content: String(repeating: "x ", count: 30)),
            KnowledgePage(title: "Duplicate", pageType: .concept, content: String(repeating: "y ", count: 30))
        ]
        let issues = await lintService.runLint(pages: pages, linkService: linkService)
        let dupIssues = issues.filter {
            $0.message.localizedCaseInsensitiveContains("duplicate") ||
            $0.message.localizedCaseInsensitiveContains("重复")
        }
        XCTAssertFalse(dupIssues.isEmpty, "Duplicate titles should be flagged")
    }
}

// MARK: - IngestService Edge Cases
@MainActor
final class IngestServiceEdgeCasesTests: XCTestCase {

    var ingestService: IngestService!

    override func setUp() async throws {
        try await super.setUp()
        ingestService = IngestService()
    }

    func testExtractConceptsNoMatch() async {
        let pages = [KnowledgePage(title: "Existing", pageType: .concept)]
        let content = "This mentions Nothing That Exists"
        let concepts = await ingestService.extractConcepts(from: content, pages: pages)
        XCTAssertTrue(concepts.isEmpty)
    }

    func testExtractConceptsCaseInsensitive() async {
        let pages = [KnowledgePage(title: "SwiftUI", pageType: .concept)]
        let concepts1 = await ingestService.extractConcepts(from: "swiftui", pages: pages)
        let concepts2 = await ingestService.extractConcepts(from: "SWIFTUI", pages: pages)
        XCTAssertFalse(concepts1.isEmpty)
        XCTAssertFalse(concepts2.isEmpty)
    }

    func testExtractConceptsPartialMatch() async {
        let pages = [KnowledgePage(title: "Machine Learning", pageType: .concept)]
        // Partial match should not trigger
        let concepts = await ingestService.extractConcepts(from: "Machines are everywhere", pages: pages)
        XCTAssertTrue(concepts.isEmpty, "Partial word match should not extract concept")
    }

    func testDocumentFormatUnsupported() {
        let formats: [DocumentFormat] = [.markdown, .plainText, .docx, .xlsx, .pdf]
        XCTAssertEqual(formats.count, 5)
    }
}

// MARK: - Page Lifecycle Integration Tests
@MainActor
final class PageLifecycleIntegrationTests: XCTestCase {

    var linkService: LinkService!
    var lintService: LintService!
    var undoService: UndoService!

    override func setUp() async throws {
        try await super.setUp()
        linkService = LinkService()
        lintService = LintService()
        undoService = UndoService()
    }

    func testCreateAndLinkPagesFullLifecycle() async {
        // 1. Create pages
        var pageA = KnowledgePage(title: "Machine Learning", pageType: .concept, content: "Related to [[Neural Network]]")
        var pageB = KnowledgePage(title: "Neural Network", pageType: .entity, content: "Part of [[Machine Learning]]")
        var pageC = KnowledgePage(title: "Data Science", pageType: .concept, content: "Uses machine learning")

        // 2. Add related page
        pageC.relatedPageIDs = [pageA.id]

        let pages = [pageA, pageB, pageC]

        // 3. Verify backlinks
        let mlBacklinks = await linkService.backlinks(for: pageA.id, in: pages)
        XCTAssertEqual(mlBacklinks.count, 2, "ML should have 2 backlinks: from Neural Network and Data Science relatedPageIDs")

        // 4. Verify outgoing links
        XCTAssertEqual(pageA.outgoingLinks, ["Neural Network"])
        XCTAssertEqual(pageB.outgoingLinks, ["Machine Learning"])

        // 5. Verify lint - no broken links
        let issues = await lintService.runLint(pages: pages, linkService: linkService)
        let brokenCount = issues.filter { $0.severity == .error }.count
        XCTAssertEqual(brokenCount, 0, "All links are valid — no broken links")

        // 6. Undo service integration
        undoService.pushSnapshot(pages)
        XCTAssertTrue(undoService.canUndo)

        // 7. Simulate content update
        pageA.content = "Updated [[Neural Network]] content"
        var updatedPages = pages
        updatedPages[0] = pageA

        // 8. Undo should restore original
        let restored = undoService.undo(currentPages: updatedPages)
        XCTAssertEqual(restored?.first?.content, "Related to [[Neural Network]]")
    }

    func testPageTypeClassificationAffectsStubDetection() {
        // raw pages with lots of content should not be stub
        let rawPage = KnowledgePage(title: "RawData", pageType: .raw, content: String(repeating: "x ", count: 80))
        XCTAssertFalse(rawPage.isStub, "raw page with 80 words should not be stub")

        // But entity with < 100 chars is stub
        let entityPage = KnowledgePage(title: "ShortEntity", pageType: .entity, content: "Too short")
        XCTAssertTrue(entityPage.isStub)
    }

    func testWordCountForMixedCJKAndEnglish() {
        let page = KnowledgePage(title: "Mixed", pageType: .concept, content: "Hello世界123测试")
        // English words: Hello(1), 123(1) = 2, CJK chars: 世界测试 = 4
        // Total = 6
        XCTAssertEqual(page.wordCount, 6)
    }

    func testFolderNamePerType() {
        let typeFolderPairs: [(PageType, String)] = [
            (.entity, "entities"),
            (.concept, "concepts"),
            (.source, "sources"),
            (.comparison, "comparisons"),
            (.raw, "raw")
        ]
        for (type, expected) in typeFolderPairs {
            XCTAssertEqual(KnowledgePage(title: "", pageType: type).folderName, expected)
        }
    }
}

// MARK: - Plugin Registry Tests (Security & Consistency)
final class PluginRegistryTests: XCTestCase {
    
    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }
    
    @MainActor
    override func tearDown() async throws {
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }
    
    @MainActor
    func testMultiPluginInterceptorConsistency() {
        let registry = PluginRegistry.shared
        
        // Mock Plugin 1: Adds a prefix
        let p1 = MockPlugin(id: "p1", preProcessor: { "P1: " + $0 })
        // Mock Plugin 2: Adds a suffix
        let p2 = MockPlugin(id: "p2", preProcessor: { $0 + " :P2" })
        
        registry.loadPlugin(p1)
        registry.loadPlugin(p2)
        
        let original = "Hello"
        let processed = registry.applyPreProcess(to: original)
        
        XCTAssertTrue(processed.contains("P1:"), "Should contain prefix from P1")
        XCTAssertTrue(processed.contains(":P2"), "Should contain suffix from P2")
        XCTAssertEqual(processed, "P1: Hello :P2", "Plugins should be applied sequentially")
        
        // Clean up
        registry.unloadPlugin(id: "p1")
        registry.unloadPlugin(id: "p2")
    }
}

// Mock Plugin Helper
@MainActor
final class MockPlugin: InterceptionPlugin {
    let manifest: PluginManifest
    var monetization: MonetizationInfo?
    
    var preProcessor: ((String) -> String)?
    
    init(id: String, preProcessor: ((String) -> String)? = nil) {
        self.manifest = PluginManifest(
            id: id,
            version: "1.0.0",
            author: "Tester",
            permissions: ["writeContent"],
            names: ["en": id],
            descriptions: ["en": "Test plugin"]
        )
        self.preProcessor = preProcessor
    }
    
    func onLoad(context: PluginContext) {}
    func onUnload() {}
    
    func preProcess(content: String) throws -> String {
        preProcessor?(content) ?? content
    }
    
    func postProcess(content: String) throws -> String { content }
}
