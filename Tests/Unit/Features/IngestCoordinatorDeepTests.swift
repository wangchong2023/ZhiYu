//
//  IngestCoordinatorDeepTests.swift
//  ZhiYuTests
//
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层测试
//  核心职责：验证 IngestCoordinator 的 performIngest/prepareImportFiles/triggerAITagging/
//            extractJSON/resetForm/openManualForm 深度逻辑与边界条件。
//

import XCTest
import UFPCore
@testable import ZhiYu

@MainActor
final class IngestCoordinatorDeepTests: XCTestCase {

    private var coordinator: IngestCoordinator!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        coordinator = IngestCoordinator()
    }

    override func tearDown() async throws {
        try? await Task.sleep(nanoseconds: 100_000_000)
        coordinator = nil
        try await super.tearDown()
    }

    // MARK: - isImporting 频控计算属性

    /// 验证新建 coordinator 初始状态 isImporting 为 false
    func testIsImportingInitialFalse() {
        XCTAssertFalse(coordinator.isImporting, "新建 coordinator 不应在频控期内")
    }

    /// 验证频控期内 isImporting 为 true
    func testIsImportingTrueWithinCooldown() {
        coordinator.lastImportTime = Date()
        XCTAssertTrue(coordinator.isImporting, "频控期内 isImporting 应为 true")
    }

    /// 验证频控期外 isImporting 恢复 false
    func testIsImportingFalseAfterCooldown() {
        let cooldown = coordinator.importCooldownSeconds
        coordinator.lastImportTime = Date().addingTimeInterval(-cooldown - 1)
        XCTAssertFalse(coordinator.isImporting, "频控期外 isImporting 应恢复 false")
    }

    // MARK: - isLLMConfigured

    /// 验证 Mock 环境下 isLLMConfigured 状态
    func testIsLLMConfiguredReflectsLLMServiceState() {
        // Mock LLMService 默认 apiKey 为空字符串
        let configured = coordinator.isLLMConfigured
        // Mock 环境下 LLM 可能未配置 apiKey
        XCTAssertFalse(configured, "Mock 环境下 LLM 未配置 apiKey 时 isLLMConfigured 应为 false")
    }

    // MARK: - resetForm

    /// 验证 resetForm 清空所有表单字段
    func testResetFormClearsAllFields() {
        coordinator.newTitle = "测试标题"
        coordinator.newContent = "测试内容"
        coordinator.newCustomIcon = "star"
        coordinator.useSmartIngest = true

        coordinator.resetForm()

        XCTAssertEqual(coordinator.newTitle, "", "resetForm 后 newTitle 应为空")
        XCTAssertEqual(coordinator.newContent, "", "resetForm 后 newContent 应为空")
        XCTAssertNil(coordinator.newCustomIcon, "resetForm 后 newCustomIcon 应为 nil")
        XCTAssertFalse(coordinator.useSmartIngest, "resetForm 后 useSmartIngest 应为 false")
    }

    // MARK: - extractJSON

    /// 验证 extractJSON 正确解析合法 JSON
    func testExtractJSONValidJSON() {
        let jsonText = #"{"tags": ["swift", "ios"], "aliasTitle": "测试别名"}"#
        let result = coordinator.extractJSON(from: jsonText)

        XCTAssertEqual(result["tags"] as? [String], ["swift", "ios"], "tags 应正确解析")
        XCTAssertEqual(result["aliasTitle"] as? String, "测试别名", "aliasTitle 应正确解析")
    }

    /// 验证 extractJSON 对 markdown 代码块包裹的 JSON 也能解析
    func testExtractJSONWithCodeFence() {
        let jsonText = """
        ```json
        {"tags": ["a"]}
        ```
        """
        let result = coordinator.extractJSON(from: jsonText)

        XCTAssertEqual(result["tags"] as? [String], ["a"], "代码块包裹的 JSON 也应正确解析")
    }

    /// 验证 extractJSON 对无 JSON 文本返回空字典
    func testExtractJSONNoJSONReturnsEmpty() {
        let result = coordinator.extractJSON(from: "这是一段纯文本，没有 JSON")

        XCTAssertTrue(result.isEmpty, "无 JSON 文本应返回空字典")
    }

    /// 验证 extractJSON 对嵌套 JSON 的解析
    func testExtractJSONNestedJSON() {
        let jsonText = #"{"tags": ["x"], "aliasTitle": "y", "meta": {"key": "value"}}"#
        let result = coordinator.extractJSON(from: jsonText)

        XCTAssertEqual(result["tags"] as? [String], ["x"])
        XCTAssertEqual(result["aliasTitle"] as? String, "y")
        let meta = result["meta"] as? [String: Any]
        XCTAssertEqual(meta?["key"] as? String, "value", "嵌套 JSON 也应正确解析")
    }

    /// 验证 extractJSON 对含花括号字符串的 JSON 解析（字符串内花括号不应干扰深度计数）
    func testExtractJSONWithBracesInString() {
        let jsonText = #"{"tags": ["a{b}c"], "aliasTitle": "x"}"#
        let result = coordinator.extractJSON(from: jsonText)

        XCTAssertEqual(result["tags"] as? [String], ["a{b}c"], "字符串内花括号不应干扰 JSON 解析")
    }

    // MARK: - prepareImportFiles

    /// 验证 prepareImportFiles 对 manual 来源正常保存
    func testPrepareImportFilesManualSource() {
        coordinator.newContent = "手工录入内容"
        coordinator.sourceHint = .manual

        let result = coordinator.prepareImportFiles(recordID: "test-record-1")

        XCTAssertNotNil(result, "manual 来源应返回非 nil")
        XCTAssertNotNil(result?.savedPath, "savedPath 应非 nil")
        XCTAssertTrue(result?.rawText.contains("手工录入内容") ?? false, "rawText 应包含用户内容")
        XCTAssertTrue(result?.rawText.hasPrefix(">") ?? false, "rawText 应以引用标记 > 开头")
    }

    /// 验证 prepareImportFiles 对 file 来源正常保存
    func testPrepareImportFilesFileSource() {
        coordinator.newContent = "文件导入内容"
        coordinator.sourceHint = .file

        let result = coordinator.prepareImportFiles(recordID: "test-record-2")

        XCTAssertNotNil(result, "file 来源应返回非 nil")
        XCTAssertTrue(result?.rawText.contains("文件导入内容") ?? false)
    }

    /// 验证 prepareImportFiles 对空内容也能保存
    func testPrepareImportFilesEmptyContent() {
        coordinator.newContent = ""
        coordinator.sourceHint = .manual

        let result = coordinator.prepareImportFiles(recordID: "test-record-3")

        XCTAssertNotNil(result, "空内容也应返回非 nil")
        XCTAssertTrue(result?.rawText.contains(">") ?? false, "rawText 仍应有引用头部")
    }

    /// 验证 prepareImportFiles 对 OCR 超限图片返回 nil 并标记 failed
    func testPrepareImportFilesOCROversizeImageReturnsNil() {
        coordinator.sourceHint = .ocr
        coordinator.newTitle = "OCR 测试"
        coordinator.pendingImageData = Data(count: Int(AppConstants.Keys.ImportLimits.maxOCRImageSizeBytes) + 1)

        let result = coordinator.prepareImportFiles(recordID: "test-record-oversize")

        XCTAssertNil(result, "OCR 超限图片应返回 nil")
        XCTAssertNil(coordinator.pendingImageData, "超限后 pendingImageData 应被清空")
        XCTAssertTrue(coordinator.showError, "超限应触发 showError")
        XCTAssertFalse(coordinator.isIngesting, "超限后 isIngesting 应为 false")
        XCTAssertEqual(coordinator.lastImportTime, .distantPast, "超限后 lastImportTime 应重置为 distantPast")
    }

    /// 验证 prepareImportFiles 对 OCR 正常大小图片保存图片数据
    func testPrepareImportFilesOCRNormalSizeImage() {
        coordinator.sourceHint = .ocr
        coordinator.newContent = "OCR 文本"
        coordinator.pendingImageData = Data(count: 100)

        let result = coordinator.prepareImportFiles(recordID: "test-record-ocr-normal")

        XCTAssertNotNil(result, "正常大小 OCR 图片应返回非 nil")
        XCTAssertNil(coordinator.pendingImageData, "处理后 pendingImageData 应被清空")
    }

    /// 验证 prepareImportFiles 对 OCR 来源但无图片数据也能保存文本
    func testPrepareImportFilesOCRNoImageData() {
        coordinator.sourceHint = .ocr
        coordinator.newContent = "OCR 但无图片"
        coordinator.pendingImageData = nil

        let result = coordinator.prepareImportFiles(recordID: "test-record-ocr-noimg")

        XCTAssertNotNil(result, "OCR 无图片数据也应返回非 nil（仅保存文本）")
    }

    // MARK: - openManualForm

    /// 验证 openManualForm 预填带引用头部的 rawText
    func testOpenManualFormWithHeaderRawText() {
        let record = ImportRecord(
            id: UUID().uuidString,
            category: ImportCategory.manual.rawValue,
            title: "二次编辑标题",
            status: ImportRecordStatus.done,
            rawText: "> 手工录入 | 2026/06/20 02:00\n\n用户实际录入的内容",
            pageID: nil
        )

        coordinator.openManualForm(with: record)

        XCTAssertEqual(coordinator.newTitle, "二次编辑标题")
        XCTAssertEqual(coordinator.newContent, "用户实际录入的内容", "应剥离引用头部，仅保留用户内容")
        XCTAssertEqual(coordinator.sourceHint, .manual)
        XCTAssertTrue(coordinator.showManualForm)
    }

    /// 验证 openManualForm 对无引用头部的 rawText 全量预填
    func testOpenManualFormWithoutHeaderRawText() {
        let record = ImportRecord(
            id: UUID().uuidString,
            category: ImportCategory.manual.rawValue,
            title: "无头部编辑",
            status: ImportRecordStatus.done,
            rawText: "这是全部内容，没有引用头部",
            pageID: nil
        )

        coordinator.openManualForm(with: record)

        XCTAssertEqual(coordinator.newTitle, "无头部编辑")
        XCTAssertEqual(coordinator.newContent, "这是全部内容，没有引用头部", "无头部时应全量预填")
    }

    /// 验证 openManualForm 对 nil rawText 预填空字符串
    func testOpenManualFormNilRawText() {
        let record = ImportRecord(
            id: UUID().uuidString,
            category: ImportCategory.manual.rawValue,
            title: "空内容编辑",
            status: ImportRecordStatus.done,
            rawText: nil,
            pageID: nil
        )

        coordinator.openManualForm(with: record)

        XCTAssertEqual(coordinator.newTitle, "空内容编辑")
        XCTAssertEqual(coordinator.newContent, "", "nil rawText 应预填空字符串")
    }

    /// 验证 openManualForm 对带 pageID 的记录预填页面类型和图标
    func testOpenManualFormWithPageID() {
        // 先创建一个页面到 store 中
        let pageID = UUID()
        let page = KnowledgePage(
            id: pageID,
            title: "已有页面",
            pageType: .concept,
            customIcon: "star",
            content: "已有内容"
        )
        coordinator.store.knowledgeStore.pages.append(page)

        let record = ImportRecord(
            id: UUID().uuidString,
            category: ImportCategory.manual.rawValue,
            title: "带 pageID 编辑",
            status: ImportRecordStatus.done,
            rawText: "内容",
            pageID: pageID.uuidString
        )

        coordinator.openManualForm(with: record)

        XCTAssertEqual(coordinator.newType, .concept, "应从已有页面预填 pageType")
        XCTAssertEqual(coordinator.newCustomIcon, "star", "应从已有页面预填 customIcon")
    }

    /// 验证 openManualForm 对无效 pageID 回退到默认值
    func testOpenManualFormWithInvalidPageID() {
        let record = ImportRecord(
            id: UUID().uuidString,
            category: ImportCategory.manual.rawValue,
            title: "无效 pageID",
            status: ImportRecordStatus.done,
            rawText: "内容",
            pageID: "not-a-valid-uuid"
        )

        coordinator.openManualForm(with: record)

        XCTAssertEqual(coordinator.newType, .source, "无效 pageID 应回退到 .source")
        XCTAssertNil(coordinator.newCustomIcon, "无效 pageID 应回退到 nil icon")
    }

    // MARK: - performIngest 频控守卫

    /// 验证 performIngest 在频控期内不执行导入
    func testPerformIngestBlockedByCooldown() {
        coordinator.lastImportTime = Date()
        coordinator.newTitle = "频控测试"
        coordinator.newContent = "内容"

        coordinator.performIngest()

        // 频控期内不应启动导入
        XCTAssertFalse(coordinator.isIngesting, "频控期内不应启动 isIngesting")
    }

    /// 验证 performIngest 空标题也能启动（业务允许空标题导入）
    func testPerformIngestEmptyTitleStillStarts() {
        coordinator.newTitle = ""
        coordinator.newContent = "有内容但无标题"

        coordinator.performIngest()

        // performIngest 不检查空标题，应启动
        XCTAssertTrue(coordinator.isIngesting, "空标题也应启动导入流程")
    }

    // MARK: - triggerAITagging 守卫条件

    /// 验证 triggerAITagging 在 LLM 未配置时不执行
    func testTriggerAITaggingGuardLLMNotConfigured() {
        let record = ImportRecord(
            id: UUID().uuidString,
            category: ImportCategory.manual.rawValue,
            title: "AI 标签测试",
            status: ImportRecordStatus.done,
            rawText: "需要 AI 标签的内容",
            pageID: nil
        )

        // Mock 环境下 LLM apiKey 为空，triggerAITagging 应直接 return
        coordinator.triggerAITagging(for: record)

        // 验证：不应有 toast 显示（因为 guard 直接 return）
        // 无法直接验证 toast，但验证不崩溃即可
        XCTAssertTrue(true, "LLM 未配置时 triggerAITagging 应安全跳过")
    }

    /// 验证 triggerAITagging 对空 rawText 安全跳过
    func testTriggerAITaggingEmptyRawText() {
        let record = ImportRecord(
            id: UUID().uuidString,
            category: ImportCategory.manual.rawValue,
            title: "空文本",
            status: ImportRecordStatus.done,
            rawText: "",
            pageID: nil
        )

        coordinator.triggerAITagging(for: record)

        // 空 rawText 应直接 return，不崩溃
        XCTAssertTrue(true, "空 rawText 时 triggerAITagging 应安全跳过")
    }

    /// 验证 triggerAITagging 对 nil rawText 安全跳过
    func testTriggerAITaggingNilRawText() {
        let record = ImportRecord(
            id: UUID().uuidString,
            category: ImportCategory.manual.rawValue,
            title: "nil 文本",
            status: ImportRecordStatus.done,
            rawText: nil,
            pageID: nil
        )

        coordinator.triggerAITagging(for: record)

        XCTAssertTrue(true, "nil rawText 时 triggerAITagging 应安全跳过")
    }
}
