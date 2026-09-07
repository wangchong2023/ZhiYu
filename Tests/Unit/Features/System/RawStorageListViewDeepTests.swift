//
//  RawStorageListViewDeepTests.swift
//  ZhiYuTests
//
//  合并自 3 个碎片化测试文件：RawStorageListViewDeepTests.swift, RawStorageListViewFullCoverageTests.swift, RawStorageListViewInteractiveTests.swift
//

import Dependencies
import SwiftUI
import UFPCore
import XCTest

@testable import ZhiYu

@MainActor
final class RawStorageListViewDeepTests: XCTestCase {

    private var appStore: AppStore!
    private var router: Router!
    private var themeManager: ThemeManager!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        appStore = AppStore()
        router = Router.shared
        themeManager = ThemeManager()
    }

    func testRawCategoryTypeProperties() {
        for category in RawCategoryType.allCases {
            XCTAssertEqual(category.id, category.rawValue)
            XCTAssertFalse(category.systemIconName.isEmpty)
            XCTAssertNotNil(category.defaultColor)
            XCTAssertFalse(category.displayName.isEmpty)
        }
    }

    func testHighlightedTextAndRawPageRow() {
        let highlighted = HighlightedText(text: "Karpathy LLM Wiki Architecture", highlight: "LLM")
        let hostHighlight = UIHostingController(rootView: highlighted)
        XCTAssertEqual(highlighted.text, "Karpathy LLM Wiki Architecture")
        XCTAssertEqual(highlighted.highlight, "LLM")
        XCTAssertNotNil(hostHighlight.view)

        let emptyHighlight = HighlightedText(text: "Plain Text Note", highlight: "")
        let hostEmpty = UIHostingController(rootView: emptyHighlight)
        XCTAssertEqual(emptyHighlight.text, "Plain Text Note")
        XCTAssertNotNil(hostEmpty.view)

        let rawPage = KnowledgePage(
            title: "Recorded Lecture.m4a",
            pageType: .source,
            content: "Audio transcript content...",
            sourceURL: "file:///vault/audio/lecture.m4a",
            fileSize: 1024 * 1024 * 5,
            sourceType: "m4a"
        )

        let row = RawPageRow(page: rawPage, searchText: "Lecture")
        let hostRow = UIHostingController(rootView: row)
        XCTAssertEqual(row.page.title, "Recorded Lecture.m4a")
        XCTAssertEqual(row.searchText, "Lecture")
        XCTAssertNotNil(hostRow.view)
    }

    func testRawStorageListViewEmptyAndPopulated() throws {
        let store = ServiceContainer.shared.resolveOptional(KnowledgeStore.self) ?? KnowledgeStore()

        // 1. 空状态测试
        store.pages = []
        let emptyView = RawStorageListView()
            .snapshotEnvironment()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let hostEmpty = UIHostingController(rootView: emptyView)
        window.rootViewController = hostEmpty
        window.makeKeyAndVisible()
        hostEmpty.view.layoutIfNeeded()
        XCTAssertTrue(store.pages.isEmpty)
        XCTAssertNotNil(hostEmpty.view)

        // 2. 填充 6 大分类原始页面
        let docPage = KnowledgePage(
            title: "Requirements.pdf",
            pageType: .source,
            content: "System requirements",
            sourceURL: "file:///doc.pdf",
            sourceType: "pdf"
        )
        let audioPage = KnowledgePage(
            title: "VoiceMemo.mp3",
            pageType: .source,
            content: "Voice note",
            sourceURL: "file:///memo.mp3",
            sourceType: "mp3"
        )
        let ocrPage = KnowledgePage(
            title: "Whiteboard.png",
            pageType: .source,
            content: "OCR extracted text",
            sourceURL: "file:///board.png",
            sourceType: "png"
        )
        let webPage = KnowledgePage(
            title: "Karpathy Article",
            pageType: .source,
            content: "Web article text",
            sourceURL: "https://karpathy.ai",
            sourceType: "web"
        )
        let clipPage = KnowledgePage(
            title: "Clipboard Snippet",
            pageType: .source,
            content: "Copied code snippet",
            sourceURL: "clipboard://snippet",
            sourceType: "clipboard"
        )
        let manualPage = KnowledgePage(
            title: "Manual Page",
            pageType: .source,
            content: "Manual entry without extension",
            sourceURL: "manual://page",
            sourceType: "custom_ext"
        )

        store.pages = [docPage, audioPage, ocrPage, webPage, clipPage, manualPage]

        let populatedView = RawStorageListView()
            .snapshotEnvironment()
        let hostPopulated = UIHostingController(rootView: populatedView)
        window.rootViewController = hostPopulated
        hostPopulated.view.layoutIfNeeded()
        XCTAssertNotNil(hostPopulated.view)
    }

    func testHighlightedTextVariations() {
        // 空高亮关键字
        let viewEmpty = HighlightedText(text: "智宇知识库系统", highlight: "")
        XCTAssertEqual(viewEmpty.text, "智宇知识库系统")
        XCTAssertEqual(viewEmpty.highlight, "")
        let hostEmpty = UIHostingController(rootView: viewEmpty)
        XCTAssertNotNil(hostEmpty.view)

        // 匹配单次
        let viewSingle = HighlightedText(text: "智宇知识库系统", highlight: "知识库")
        XCTAssertEqual(viewSingle.highlight, "知识库")
        let hostSingle = UIHostingController(rootView: viewSingle)
        XCTAssertNotNil(hostSingle.view)

        // 大小写不敏感与多次匹配
        let viewMulti = HighlightedText(text: "Swift is awesome, swift rocks", highlight: "swift")
        XCTAssertEqual(viewMulti.highlight, "swift")
        let hostMulti = UIHostingController(rootView: viewMulti)
        XCTAssertNotNil(hostMulti.view)

        // 不匹配项
        let viewNoMatch = HighlightedText(text: "Hello World", highlight: "NotFoundKeyword")
        XCTAssertEqual(viewNoMatch.highlight, "NotFoundKeyword")
        let hostNoMatch = UIHostingController(rootView: viewNoMatch)
        XCTAssertNotNil(hostNoMatch.view)
    }

    func testRawPageRowRendering() {
        var page = KnowledgePage(
            title: "测试原始文档.pdf",
            content: "这是从 PDF 提取的原始文档文本内容",
            sourceURL: "file:///documents/test.pdf"
        )
        page.sourceType = "pdf"
        page.fileSize = 1024 * 256

        XCTAssertEqual(page.title, "测试原始文档.pdf")
        XCTAssertEqual(page.sourceType, "pdf")

        let row = RawPageRow(page: page, searchText: "测试")
            .snapshotEnvironment()
        let hosting = UIHostingController(rootView: row)
        XCTAssertNotNil(hosting.view)
        hosting.view.layoutIfNeeded()
    }

    func testRawPageDetailView() {
        var page = KnowledgePage(
            title: "深度 RAG 评测方案.pdf",
            content: "这是一份关于 RAG 检索评测指标 (Faithfulness, Answer Relevance) 的完整技术文档规范。",
            sourceURL: "https://zhiyu.app/docs/rag-evaluation.pdf"
        )
        page.sourceType = "pdf"
        page.fileSize = 1024 * 512

        XCTAssertEqual(page.title, "深度 RAG 评测方案.pdf")
        XCTAssertEqual(page.fileSize, 1024 * 512)

        let detailView = RawPageDetailView(page: page)
            .snapshotEnvironment()
        let hosting = UIHostingController(rootView: detailView)
        XCTAssertNotNil(hosting.view)
        hosting.view.layoutIfNeeded()
    }

    func testRawCategoryTypeContractAndIcons() {
        for category in RawCategoryType.allCases {
            XCTAssertFalse(category.id.isEmpty)
            XCTAssertFalse(category.systemIconName.isEmpty, "\(category.rawValue) 必须具备有效的系统图标")
            XCTAssertFalse(category.displayName.isEmpty, "\(category.rawValue) 必须具备有效的本地化名称")
            XCTAssertNotNil(category.defaultColor)
        }

        // 验证特定核心映射
        XCTAssertEqual(RawCategoryType.document.systemIconName, "doc.text.fill")
        XCTAssertEqual(RawCategoryType.audio.systemIconName, "music.note")
        XCTAssertEqual(RawCategoryType.ocr.systemIconName, "photo.fill")
        XCTAssertEqual(RawCategoryType.web.systemIconName, "globe")
        XCTAssertEqual(RawCategoryType.clipboard.systemIconName, "doc.on.clipboard.fill")
        XCTAssertEqual(RawCategoryType.manual.systemIconName, "square.and.pencil")
    }

    func testGetCategoryFromKnowledgePageSourceType() {
        // Document 后缀
        let docExtensions = ["pdf", "markdown", "md", "txt", "doc", "docx", "file"]
        for ext in docExtensions {
            let page = KnowledgePage(title: "测试文档", sourceType: ext)
            XCTAssertEqual(RawStorageListView.getCategory(for: page), .document, "\(ext) 应被识别为 document")
        }

        // Audio 后缀
        let audioExtensions = ["voice", "audio", "mp3", "m4a", "wav"]
        for ext in audioExtensions {
            let page = KnowledgePage(title: "测试音频", sourceType: ext)
            XCTAssertEqual(RawStorageListView.getCategory(for: page), .audio, "\(ext) 应被识别为 audio")
        }

        // OCR 后缀
        let ocrExtensions = ["ocr", "png", "jpg", "jpeg"]
        for ext in ocrExtensions {
            let page = KnowledgePage(title: "测试图像", sourceType: ext)
            XCTAssertEqual(RawStorageListView.getCategory(for: page), .ocr, "\(ext) 应被识别为 ocr")
        }

        // Web 后缀
        let webExtensions = ["link", "web", "url"]
        for ext in webExtensions {
            let page = KnowledgePage(title: "测试网页", sourceType: ext)
            XCTAssertEqual(RawStorageListView.getCategory(for: page), .web, "\(ext) 应被识别为 web")
        }

        // Clipboard 后缀
        let clipboardPage = KnowledgePage(title: "测试剪贴板", sourceType: "clipboard")
        XCTAssertEqual(RawStorageListView.getCategory(for: clipboardPage), .clipboard)

        // 未知或空后缀 -> .manual
        let unknownPage = KnowledgePage(title: "未知类型", sourceType: "xyz123")
        XCTAssertEqual(RawStorageListView.getCategory(for: unknownPage), .manual)

        let nilPage = KnowledgePage(title: "无后缀", sourceType: nil)
        XCTAssertEqual(RawStorageListView.getCategory(for: nilPage), .manual)
    }

    func testHighlightedTextRender() {
        let emptyHighlight = HighlightedText(text: "全文检索高亮测试", highlight: "")
        XCTAssertEqual(emptyHighlight.text, "全文检索高亮测试")
        XCTAssertEqual(emptyHighlight.highlight, "")
        let host1 = UIHostingController(rootView: emptyHighlight)
        XCTAssertNotNil(host1.view)

        let matchedHighlight = HighlightedText(text: "全文检索高亮测试", highlight: "高亮")
        XCTAssertEqual(matchedHighlight.highlight, "高亮")
        let host2 = UIHostingController(rootView: matchedHighlight)
        XCTAssertNotNil(host2.view)

        let caseInsensitiveHighlight = HighlightedText(text: "ZhiYu Knowledge Base", highlight: "zhiyu")
        XCTAssertEqual(caseInsensitiveHighlight.highlight, "zhiyu")
        let host3 = UIHostingController(rootView: caseInsensitiveHighlight)
        XCTAssertNotNil(host3.view)
    }

    func testRawStorageListViewMount() {
        let view = RawStorageListView()
            .environment(appStore)
            .environment(router)
            .environment(themeManager)

        let host = UIHostingController(rootView: view)
        XCTAssertNotNil(host.view)
        XCTAssertNotNil(appStore)
        XCTAssertNotNil(router)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
    }

}
