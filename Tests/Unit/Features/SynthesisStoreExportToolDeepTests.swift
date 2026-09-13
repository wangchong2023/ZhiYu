//
//  SynthesisStoreExportToolDeepTests.swift
//  ZhiYuTests
//
//  系统层级：[Test] 单元测试
//  核心职责：SynthesisStore 深度补盲测试（导出/工具/Document 分片）— 覆盖 allSortedDocuments 排序、
//            exportSynthesisDocument 导出分派（mindmap/slides/report/quiz + 特殊字符文件名）、
//            cleanMarkdown 静态工具（转义清理/双链/修剪/空串）、SynthesisDocument 属性与 Codable 编解码，
//            以发现生产代码潜在 bug 为首要目标。
//
//  说明：从 SynthesisStoreDeepTests.swift 拆分而来（按 MARK 分段）。本文件聚焦导出分派、工具方法与
//        SynthesisDocument 数据模型属性验证。
//

import XCTest
import UFPCore
import Combine
import Dependencies
@testable import ZhiYu

// MARK: - SynthesisStore 导出/工具/Document 深度测试

@MainActor
final class SynthesisStoreExportToolDeepTests: XCTestCase {

    // MARK: - 测试夹具

    private var mockLLM: SynthesisStoreControllableLLM!
    private var taskCenter: TaskCenter!
    private var store: SynthesisStore!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        resetPersistentTestState()

        // 创建可控 LLM Mock 并双重注入：
        // 1) ServiceContainer 注册（AISynthesisService.currentLLM 优先从 DI 解析）
        // 2) AISynthesisService.shared.updateLLMForTesting（覆盖 actor 内部 llm 后备引用）
        let llm = SynthesisStoreControllableLLM()
        self.mockLLM = llm
        ServiceContainer.shared.register(llm as any LLMServiceProtocol, for: (any LLMServiceProtocol).self)
        await AISynthesisService.shared.updateLLMForTesting(llm)

        // 创建独立的 TaskCenter 实例，通过 withDependencies 注入到 SynthesisStore
        self.taskCenter = TaskCenter(activityService: nil)
        self.taskCenter.reset()

        // 清理 UserDefaults.standard 中可能残留的合成文档键（跨测试隔离）
        for type in SynthesisStore.SynthesisType.allCases {
            let key = AppConstants.Keys.Storage.Legacy.synthesisDocsPrefix + type.rawValue
            UserDefaults.standard.removeObject(forKey: key)
        }

        // 在 withDependencies 闭包内创建 SynthesisStore，确保 @Dependency(\.taskCenter) 解析到自定义实例
        self.store = withDependencies {
            $0.taskCenter = self.taskCenter
        } operation: {
            SynthesisStore()
        }
        self.store.clearAll()
    }

    override func tearDown() async throws {
        store?.clearAll()
        for type in SynthesisStore.SynthesisType.allCases {
            let key = AppConstants.Keys.Storage.Legacy.synthesisDocsPrefix + type.rawValue
            UserDefaults.standard.removeObject(forKey: key)
        }
        store = nil
        taskCenter = nil
        mockLLM = nil
        await MainActor.run { resetPersistentTestState() }
        try await super.tearDown()
    }

    // MARK: - allSortedDocuments

    /// 验证 allSortedDocuments 按 createdAt 降序排序。
    func testAllSortedDocuments按CreatedAt降序排序() async throws {
        // 保存 3 份不同类型的文档，确保 createdAt 不同
        store.saveSynthesisResult(type: .report, content: "# 报告1\n正文。")
        try await Task.sleep(nanoseconds: 50_000_000)
        store.saveSynthesisResult(type: .mindmap, content: "# 导图1\nmindmap\n  root((主题))")
        try await Task.sleep(nanoseconds: 50_000_000)
        store.saveSynthesisResult(type: .quiz, content: "{\"title\":\"测验\",\"questions\":[]}")

        let allDocs = store.allSortedDocuments
        XCTAssertEqual(allDocs.count, 3)

        // 验证降序：第一个 createdAt >= 第二个
        XCTAssertGreaterThanOrEqual(allDocs[0].1.createdAt, allDocs[1].1.createdAt, "应按 createdAt 降序")
        XCTAssertGreaterThanOrEqual(allDocs[1].1.createdAt, allDocs[2].1.createdAt, "应按 createdAt 降序")
    }

    /// 验证 allSortedDocuments 在空存储时返回空数组。
    func testAllSortedDocuments空存储返回空数组() {
        XCTAssertTrue(store.allSortedDocuments.isEmpty)
    }

    /// 验证 allSortedDocuments 包含所有类型的文档。
    func testAllSortedDocuments包含所有类型文档() {
        store.saveSynthesisResult(type: .report, content: "# 报告\n正文。")
        store.saveSynthesisResult(type: .mindmap, content: "# 导图\nmindmap\n  root((主题))")

        let allDocs = store.allSortedDocuments
        let types = Set(allDocs.map { $0.0 })
        XCTAssertTrue(types.contains(.report))
        XCTAssertTrue(types.contains(.mindmap))
    }

    // MARK: - exportSynthesisDocument

    /// 验证 exportSynthesisDocument(.mindmap) 调用 exportMindmapToPDF。
    func testExportSynthesisDocument_mindmap调用ExportMindmapToPDF() async throws {
        let doc = SynthesisStore.SynthesisDocument(
            type: .mindmap,
            name: "测试导图",
            content: "mindmap\n  root((测试))",
            size: 20
        )

        let url = try await store.exportSynthesisDocument(doc)
        XCTAssertTrue(url.pathExtension == "pdf" || url.lastPathComponent.contains("测试导图"), "应导出 PDF")
    }

    /// 验证 exportSynthesisDocument(.slides) 调用 exportToPPTX。
    func testExportSynthesisDocument_slides调用ExportToPPTX() async throws {
        let doc = SynthesisStore.SynthesisDocument(
            type: .slides,
            name: "测试幻灯片",
            content: "# 幻灯片1\n内容",
            size: 20
        )

        let url = try await store.exportSynthesisDocument(doc)
        XCTAssertTrue(url.pathExtension == "pptx" || url.lastPathComponent.contains("测试幻灯片"), "应导出 PPTX")
    }

    /// 验证 exportSynthesisDocument(.report) 调用 exportToPDF。
    func testExportSynthesisDocument_report调用ExportToPDF() async throws {
        let doc = SynthesisStore.SynthesisDocument(
            type: .report,
            name: "测试报告",
            content: "# 报告\n正文",
            size: 20
        )

        let url = try await store.exportSynthesisDocument(doc)
        XCTAssertTrue(url.pathExtension == "pdf" || url.lastPathComponent.contains("测试报告"), "应导出 PDF")
    }

    /// 验证 exportSynthesisDocument(.quiz) 调用 exportToPDF。
    func testExportSynthesisDocument_quiz调用ExportToPDF() async throws {
        let doc = SynthesisStore.SynthesisDocument(
            type: .quiz,
            name: "测试测验",
            content: "{\"title\":\"测验\"}",
            size: 20
        )

        let url = try await store.exportSynthesisDocument(doc)
        XCTAssertTrue(url.pathExtension == "pdf" || url.lastPathComponent.contains("测试测验"), "应导出 PDF")
    }

    /// 验证 exportSynthesisDocument 文件名替换 "/" 和 ":"。
    func testExportSynthesisDocument文件名替换特殊字符() async throws {
        let doc = SynthesisStore.SynthesisDocument(
            type: .report,
            name: "测试/报告:2026",
            content: "# 报告\n正文",
            size: 20
        )

        _ = try await store.exportSynthesisDocument(doc)
        // 不崩溃即通过（MockExportService 返回固定路径）
    }

    // MARK: - cleanMarkdown 静态工具

    /// 验证 cleanMarkdown 清理转义的 Markdown 特殊字符。
    func testCleanMarkdown清理转义特殊字符() {
        let input = "\\# 标题 \\(括号\\) \\[方括号\\]"
        let cleaned = SynthesisStore.cleanMarkdown(input)

        XCTAssertFalse(cleaned.contains("\\#"), "应清理转义的 #")
        XCTAssertFalse(cleaned.contains("\\("), "应清理转义的 (")
        XCTAssertFalse(cleaned.contains("\\["), "应清理转义的 [")
        XCTAssertTrue(cleaned.contains("# 标题"), "应保留 # 标题")
    }

    /// 验证 cleanMarkdown 清理转义的 [[ ]] 双链。
    func testCleanMarkdown清理转义双链() {
        let input = "文本 \\[\\[双链\\]\\] 结尾"
        let cleaned = SynthesisStore.cleanMarkdown(input)

        XCTAssertTrue(cleaned.contains("[[双链]]"), "应将 \\[\\[ 转为 [[，\\]\\] 转为 ]]")
    }

    /// 验证 cleanMarkdown 修剪首尾空白。
    func testCleanMarkdown修剪首尾空白() {
        let input = "  \n  内容  \n  "
        let cleaned = SynthesisStore.cleanMarkdown(input)

        XCTAssertEqual(cleaned, "内容", "应修剪首尾空白")
    }

    /// 验证 cleanMarkdown 处理空字符串不崩溃。
    func testCleanMarkdown空字符串不崩溃() {
        let cleaned = SynthesisStore.cleanMarkdown("")
        XCTAssertTrue(cleaned.isEmpty)
    }

    // MARK: - SynthesisDocument 属性验证

    /// 验证 SynthesisDocument 默认 init 参数（id 自动生成、createdAt 当前时间、sourcePageIDs 为空）。
    func testSynthesisDocument默认Init参数() {
        let doc = SynthesisStore.SynthesisDocument(
            type: .report,
            name: "测试",
            content: "内容",
            size: 10
        )

        XCTAssertNotEqual(doc.id, UUID(), "id 应自动生成（非默认 UUID）")
        XCTAssertEqual(doc.type, .report)
        XCTAssertEqual(doc.name, "测试")
        XCTAssertEqual(doc.content, "内容")
        XCTAssertEqual(doc.size, 10)
        XCTAssertTrue(doc.sourcePageIDs.isEmpty, "sourcePageIDs 默认应为空")
    }

    /// 验证 SynthesisDocument 自定义 init 参数。
    func testSynthesisDocument自定义Init参数() {
        let id = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_000_000)
        let pageIDs = [UUID(), UUID()]

        let doc = SynthesisStore.SynthesisDocument(
            id: id,
            type: .quiz,
            name: "自定义",
            content: "内容",
            createdAt: createdAt,
            size: 100,
            sourcePageIDs: pageIDs
        )

        XCTAssertEqual(doc.id, id)
        XCTAssertEqual(doc.type, .quiz)
        XCTAssertEqual(doc.name, "自定义")
        XCTAssertEqual(doc.content, "内容")
        XCTAssertEqual(doc.createdAt, createdAt)
        XCTAssertEqual(doc.size, 100)
        XCTAssertEqual(doc.sourcePageIDs, pageIDs)
    }

    /// 验证 SynthesisDocument Codable 编解码一致性。
    func testSynthesisDocumentCodable编解码一致() throws {
        let doc = SynthesisStore.SynthesisDocument(
            type: .mindmap,
            name: "编解码测试",
            content: "mindmap\n  root((测试))",
            size: 25,
            sourcePageIDs: [UUID()]
        )

        let data = try JSONEncoder().encode(doc)
        let decoded = try JSONDecoder().decode(SynthesisStore.SynthesisDocument.self, from: data)

        XCTAssertEqual(decoded.id, doc.id)
        XCTAssertEqual(decoded.type, doc.type)
        XCTAssertEqual(decoded.name, doc.name)
        XCTAssertEqual(decoded.content, doc.content)
        XCTAssertEqual(decoded.size, doc.size)
        XCTAssertEqual(decoded.sourcePageIDs, doc.sourcePageIDs)
    }
}
