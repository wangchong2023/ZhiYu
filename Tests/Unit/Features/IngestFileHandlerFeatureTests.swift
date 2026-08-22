//
//  IngestFileHandlerTests.swift
//  ZhiYuTests
//
//  系统层级：[L3] 表现层测试
//  核心职责：补充验证 IngestFileHandler 文件导入的扩展名分派、大文件拦截、
//            去重逻辑与 LabChatMessage 数据模型契约，提升分支覆盖率。
//
//  说明：Tests/Unit/Knowledge/IngestFileHandlerTests.swift 已覆盖频控、failure、
//        空列表与未知/md/txt 扩展名基础场景。本文件聚焦未覆盖的边界条件。
//

import XCTest
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class IngestFileHandlerFeatureTests: XCTestCase {

    // MARK: - LabChatMessage 数据模型契约

    /// 验证默认 id 自动生成且非空
    func testLabChatMessageDefaultIDNotNil() {
        let message = LabChatMessage(isUser: true, text: "你好")
        XCTAssertNotNil(message.id, "默认 id 应自动生成非空 UUID")
    }

    /// 验证显式传入 id 被保留
    func testLabChatMessageExplicitIDPreserved() {
        let id = UUID(uuidString: "00000000-0000-0000-0000-000000000001")
        let message = LabChatMessage(id: id ?? UUID(), isUser: false, text: "AI 回复")
        XCTAssertEqual(message.id, id, "显式传入的 id 应被保留")
    }

    /// 验证 isUser 与 text 属性正确赋值
    func testLabChatMessagePropertiesAssigned() {
        let userMsg = LabChatMessage(isUser: true, text: "用户提问")
        XCTAssertTrue(userMsg.isUser, "isUser=true 应正确赋值")
        XCTAssertEqual(userMsg.text, "用户提问", "text 应正确赋值")

        let aiMsg = LabChatMessage(isUser: false, text: "AI 回答")
        XCTAssertFalse(aiMsg.isUser, "isUser=false 应正确赋值")
        XCTAssertEqual(aiMsg.text, "AI 回答", "text 应正确赋值")
    }

    /// 验证空文本构造不崩溃
    func testLabChatMessageEmptyText() {
        let message = LabChatMessage(isUser: true, text: "")
        XCTAssertEqual(message.text, "", "空文本应被接受")
    }

    /// 验证两次构造生成不同 id（默认 UUID 唯一性）
    func testLabChatMessageUniqueDefaultIDs() {
        let msg1 = LabChatMessage(isUser: true, text: "a")
        let msg2 = LabChatMessage(isUser: true, text: "a")
        XCTAssertNotEqual(msg1.id, msg2.id, "两次默认构造应生成不同 id")
    }

    /// 验证 Equatable — 相同 id+属性判等
    func testLabChatMessageEquatableEqual() {
        let id = UUID()
        let msg1 = LabChatMessage(id: id, isUser: true, text: "相同")
        let msg2 = LabChatMessage(id: id, isUser: true, text: "相同")
        XCTAssertEqual(msg1, msg2, "id 与属性全等时应判等")
    }

    /// 验证 Equatable — id 不同判不等
    func testLabChatMessageEquatableDifferentID() {
        let msg1 = LabChatMessage(isUser: true, text: "相同")
        let msg2 = LabChatMessage(isUser: true, text: "相同")
        XCTAssertNotEqual(msg1, msg2, "id 不同时应判不等")
    }

    /// 验证 Equatable — isUser 不同判不等
    func testLabChatMessageEquatableDifferentIsUser() {
        let id = UUID()
        let msg1 = LabChatMessage(id: id, isUser: true, text: "相同")
        let msg2 = LabChatMessage(id: id, isUser: false, text: "相同")
        XCTAssertNotEqual(msg1, msg2, "isUser 不同时应判不等")
    }

    /// 验证 Equatable — text 不同判不等
    func testLabChatMessageEquatableDifferentText() {
        let id = UUID()
        let msg1 = LabChatMessage(id: id, isUser: true, text: "甲")
        let msg2 = LabChatMessage(id: id, isUser: true, text: "乙")
        XCTAssertNotEqual(msg1, msg2, "text 不同时应判不等")
    }

    /// 验证 Identifiable.id 即模型 id 属性
    func testLabChatMessageIdentifiableIDMatches() {
        let id = UUID()
        let message = LabChatMessage(id: id, isUser: true, text: "x")
        XCTAssertEqual(message.id, id, "Identifiable.id 应与模型 id 一致")
    }

    /// 验证 Sendable — 跨 actor 传递不触发编译错误（运行时无断言）
    func testLabChatMessageSendableCrossActor() async {
        let message = LabChatMessage(isUser: true, text: "跨 actor")
        await Task.detached { @Sendable in
            // 仅验证可被跨 actor 捕获读取，无运行时断言即通过
            _ = message.text
        }.value
    }

    /// 验证 LabChatMessage 可作为数组元素并按 id 去重
    func testLabChatMessageArrayDedupByID() {
        let id = UUID()
        let msg = LabChatMessage(id: id, isUser: true, text: "dup")
        let array = [msg, LabChatMessage(isUser: false, text: "other")]
        let unique = Dictionary(grouping: array, by: { $0.id })
        XCTAssertEqual(unique[id]?.count, 1, "按 id 分组应仅 1 条")
        XCTAssertEqual(unique.count, 2, "应含 2 个不同 id")
    }

    // MARK: - extractImagesFromFile 扩展名分派（PDF/Office 补盲）

    /// 验证 pdf 扩展名触发 PDF 提取路径（NoOp OCR 返回空，不崩溃）
    func testExtractImagesFromFilePDFReturnsEmptyWithNoOpOCR() async {
        let coordinator = makeCoordinator()
        let url = URL(fileURLWithPath: "/tmp/test.pdf")
        let result = await coordinator.extractImagesFromFile(url: url)
        XCTAssertTrue(result.isEmpty, "NoOp OCR 下 pdf 应返回空字符串")
    }

    /// 验证大写 PDF 扩展名同样触发提取路径（lowercased 归一化）
    func testExtractImagesFromFileUppercasePDFReturnsEmpty() async {
        let coordinator = makeCoordinator()
        let url = URL(fileURLWithPath: "/tmp/test.PDF")
        let result = await coordinator.extractImagesFromFile(url: url)
        XCTAssertTrue(result.isEmpty, "大写 PDF 扩展名经 lowercased 后应触发提取路径")
    }

    /// 验证 docx 扩展名触发 Office 提取路径（无 ZIP 归档返回空，不崩溃）
    func testExtractImagesFromFileDocxReturnsEmptyForNonZip() async {
        let coordinator = makeCoordinator()
        let url = URL(fileURLWithPath: "/tmp/test.docx")
        let result = await coordinator.extractImagesFromFile(url: url)
        XCTAssertTrue(result.isEmpty, "非 ZIP 的 docx 应返回空字符串")
    }

    /// 验证 xlsx 扩展名触发 Office 提取路径
    func testExtractImagesFromFileXlsxReturnsEmptyForNonZip() async {
        let coordinator = makeCoordinator()
        let url = URL(fileURLWithPath: "/tmp/test.xlsx")
        let result = await coordinator.extractImagesFromFile(url: url)
        XCTAssertTrue(result.isEmpty, "非 ZIP 的 xlsx 应返回空字符串")
    }

    /// 验证 pptx 扩展名触发 Office 提取路径
    func testExtractImagesFromFilePptxReturnsEmptyForNonZip() async {
        let coordinator = makeCoordinator()
        let url = URL(fileURLWithPath: "/tmp/test.pptx")
        let result = await coordinator.extractImagesFromFile(url: url)
        XCTAssertTrue(result.isEmpty, "非 ZIP 的 pptx 应返回空字符串")
    }

    /// 验证无扩展名文件返回空（default 分支）
    func testExtractImagesFromFileNoExtensionReturnsEmpty() async {
        let coordinator = makeCoordinator()
        let url = URL(fileURLWithPath: "/tmp/noextension")
        let result = await coordinator.extractImagesFromFile(url: url)
        XCTAssertTrue(result.isEmpty, "无扩展名应返回空字符串")
    }

    /// 验证 rtf 扩展名不触发 OCR（不在 pdf/office 集合，走 default）
    func testExtractImagesFromFileRTFReturnsEmpty() async {
        let coordinator = makeCoordinator()
        let url = URL(fileURLWithPath: "/tmp/test.rtf")
        let result = await coordinator.extractImagesFromFile(url: url)
        XCTAssertTrue(result.isEmpty, "rtf 不在 OCR 提取范围，应返回空")
    }

    /// 验证 officeExtensions 集合与 pdfExtension 互不包含
    func testOfficeExtensionsExcludesPDF() {
        let office = AppConstants.Keys.ImportLimits.officeExtensions
        let pdf = AppConstants.Keys.ImportLimits.pdfExtension
        XCTAssertFalse(office.contains(pdf), "officeExtensions 不应包含 pdf 扩展名")
    }

    /// 验证 officeExtensions 恰好含 docx/xlsx/pptx
    func testOfficeExtensionsContainsExpectedMembers() {
        let office = AppConstants.Keys.ImportLimits.officeExtensions
        XCTAssertEqual(office.count, 3, "officeExtensions 应含 3 个成员")
        XCTAssertTrue(office.contains("docx"), "应含 docx")
        XCTAssertTrue(office.contains("xlsx"), "应含 xlsx")
        XCTAssertTrue(office.contains("pptx"), "应含 pptx")
    }

    // MARK: - handleFileImport 成功路径状态变更

    /// 验证成功导入单个文件后 lastImportTime 被更新（进入冷却期）
    func testHandleFileImportSuccessUpdatesLastImportTime() {
        let coordinator = makeCoordinator()
        coordinator.lastImportTime = .distantPast
        let url = URL(fileURLWithPath: "/tmp/test.md")
        coordinator.handleFileImport(.success([url]))
        XCTAssertTrue(coordinator.isImporting, "成功导入后 lastImportTime 应更新至当前，进入冷却期")
    }

    /// 验证成功导入多个文件后仍处于冷却期
    func testHandleFileImportSuccessMultipleURLsEntersCooldown() {
        let coordinator = makeCoordinator()
        coordinator.lastImportTime = .distantPast
        let urls = [
            URL(fileURLWithPath: "/tmp/a.md"),
            URL(fileURLWithPath: "/tmp/b.txt")
        ]
        coordinator.handleFileImport(.success(urls))
        XCTAssertTrue(coordinator.isImporting, "批量导入后应进入冷却期")
    }

    /// 验证 failure 结果不更新 lastImportTime（不进入冷却期）
    func testHandleFileImportFailureDoesNotEnterCooldown() {
        let coordinator = makeCoordinator()
        coordinator.lastImportTime = .distantPast
        struct TestError: Error {}
        coordinator.handleFileImport(.failure(TestError()))
        XCTAssertFalse(coordinator.isImporting, "failure 不应进入冷却期")
        XCTAssertTrue(coordinator.showError, "failure 应设置 showError")
    }

    /// 验证 failure 结果 errorMessage 非空
    func testHandleFileImportFailureSetsNonEmptyErrorMessage() {
        let coordinator = makeCoordinator()
        coordinator.lastImportTime = .distantPast
        struct TestError: Error, LocalizedError {
            var errorDescription: String? { "边界错误" }
        }
        coordinator.handleFileImport(.failure(TestError()))
        XCTAssertNotNil(coordinator.errorMessage, "failure 应设置 errorMessage")
        XCTAssertFalse(coordinator.errorMessage?.isEmpty ?? true, "errorMessage 不应为空")
    }

    /// 验证冷却期内 success 不更新 lastImportTime（保持原冷却时间）
    func testHandleFileImportCooldownPreservesLastImportTime() {
        let coordinator = makeCoordinator()
        let originalTime = Date().addingTimeInterval(-0.5)
        coordinator.lastImportTime = originalTime
        let url = URL(fileURLWithPath: "/tmp/test.md")
        coordinator.handleFileImport(.success([url]))
        // 冷却期内应跳过导入，lastImportTime 不应被刷新到当前
        XCTAssertEqual(coordinator.lastImportTime, originalTime, "冷却期内 lastImportTime 不应被刷新")
    }

    /// 验证冷却期内 failure 错误被 guard 吞掉（已知缺陷：冷却 guard 在 switch 之前，
    /// failure 路径无法触达 errorMessage 赋值，用户得不到错误反馈，仅看到冷却 toast）
    /// 相关源码：IngestFileHandler.swift:21-24 的 guard !isImporting 直接 return
    func testHandleFileImportCooldownSwallowsFailureError() {
        let coordinator = makeCoordinator()
        coordinator.lastImportTime = Date()
        struct TestError: Error, LocalizedError {
            var errorDescription: String? { "冷却期错误" }
        }
        coordinator.handleFileImport(.failure(TestError()))
        // 缺陷记录：冷却期内 failure 的 errorMessage 未被设置
        XCTAssertNil(coordinator.errorMessage, "已知缺陷：冷却 guard 吞掉 failure，errorMessage 未设置")
        XCTAssertFalse(coordinator.showError, "已知缺陷：冷却 guard 吞掉 failure，showError 未触发")
    }

    // MARK: - 去重逻辑边界

    /// 验证 dedupFetchLimit 为正值（去重查询不会拉取空集）
    func testDedupFetchLimitPositive() {
        XCTAssertGreaterThan(AppConstants.Keys.ImportLimits.dedupFetchLimit, 0, "去重拉取数量应为正值")
    }

    /// 验证 maxFileSizeBytes 为正值（大文件拦截阈值有效）
    func testMaxFileSizeBytesPositive() {
        XCTAssertGreaterThan(AppConstants.Keys.ImportLimits.maxFileSizeBytes, 0, "文件大小限制应为正值")
    }

    /// 验证 importCooldownSeconds 为正值（冷却期有效）
    func testImportCooldownSecondsPositive() {
        XCTAssertGreaterThan(AppConstants.Keys.ImportLimits.importCooldownSeconds, 0, "冷却间隔应为正值")
    }

    /// 验证 ImportRecordStatus.done 与去重判断字符串一致
    func testImportRecordStatusDoneConstant() {
        XCTAssertEqual(ImportRecordStatus.done, "done", "done 状态常量应为 'done'")
    }

    /// 验证 ImportCategory.file.rawValue 与去重查询 category 一致
    func testImportCategoryFileRawValue() {
        XCTAssertEqual(ImportCategory.file.rawValue, "file", "file 分类 rawValue 应为 'file'")
    }

    // MARK: - 辅助

    /// 构造带完整 Mock 环境的 IngestCoordinator
    private func makeCoordinator() -> IngestCoordinator {
        setupFullMockEnvironment()
        _ = AppStore()
        return IngestCoordinator()
    }
}
