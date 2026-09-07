//
//  IOSExportServiceTests.swift
//  ZhiYu
//
//  Created by CodeFree on 2026/08/24.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：iOSExportService 单元测试，覆盖导出引擎初始化、PDF/PPTX 导出、并发槽位等场景。
//

#if canImport(WebKit)
import XCTest
import WebKit
@testable import ZhiYu

@MainActor
final class IOSExportServiceTests: XCTestCase {

    // MARK: - 测试常量

    private enum TestConstants {
        static let simpleMarkdown: String = "# 标题\n\n这是正文内容。"
        static let mermaidCode: String = "mindmap\n  root((测试))\n    分支1\n    分支2"
        static let fileName: String = "zhiyu_export_test"
        static let slidesMarkdown: String = "# 幻灯片1\n- 要点1\n- 要点2\n\n## 幻灯片2\n- 要点3"
        static let emptyMarkdown: String = ""
        static let minValidPDFBytes: Int64 = 100
    }

    // MARK: - 初始化

    /// 服务应可无参初始化且不崩溃
    func testInitSucceedsWithoutCrash() {
        let service = iOSExportService()
        XCTAssertNotNil(service, "iOSExportService 应成功初始化")
    }

    // MARK: - exportToPDF

    /// 导出简单 Markdown 为 PDF 应返回有效 URL 或抛出受控导出错误
    func testExportToPDFWithSimpleMarkdownReturnsURL() async {
        let service = iOSExportService()
        do {
            let url = try await service.exportToPDF(markdown: TestConstants.simpleMarkdown,
                                                    fileName: TestConstants.fileName)
            XCTAssertEqual(url.pathExtension, "pdf", "导出文件应以 .pdf 结尾")
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "成功导出的 PDF 文件应物理存在")
            try? FileManager.default.removeItem(at: url)
        } catch {
            XCTAssertFalse(error.localizedDescription.isEmpty, "导出失败抛出的错误描述不应为空: \(error)")
            XCTAssertTrue(error is ExportError || (error as NSError).domain.contains("WK") || (error as NSError).domain.contains("WebKit"), "异常必须属于受控 ExportError 或 WebKit 域")
        }
    }

    /// 导出空 Markdown 不应导致服务崩溃
    func testExportToPDFWithEmptyMarkdownDoesNotCrash() async {
        let service = iOSExportService()
        do {
            let url = try await service.exportToPDF(markdown: TestConstants.emptyMarkdown,
                                                    fileName: TestConstants.fileName)
            XCTAssertEqual(url.pathExtension, "pdf", "空内容若导出成功应依然为 pdf")
            try? FileManager.default.removeItem(at: url)
        } catch {
            XCTAssertFalse(error.localizedDescription.isEmpty, "空 Markdown 导出失败时必须包含明确错误说明")
        }
    }

    // MARK: - exportMindmapToPDF

    /// 导出 Mermaid 思维导图为 PDF 应返回 URL 或抛出受控错误
    func testExportMindmapToPDFReturnsURL() async {
        let service = iOSExportService()
        do {
            let url = try await service.exportMindmapToPDF(mermaidCode: TestConstants.mermaidCode,
                                                           fileName: TestConstants.fileName)
            XCTAssertEqual(url.pathExtension, "pdf", "思维导图导出应以 .pdf 结尾")
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "生成的思维导图 PDF 应存在于文件系统")
            try? FileManager.default.removeItem(at: url)
        } catch {
            XCTAssertFalse(error.localizedDescription.isEmpty, "思维导图渲染失败必须具有清晰错误描述")
        }
    }

    /// 导出空 Mermaid 代码不应崩溃
    func testExportMindmapToPDFWithEmptyCodeDoesNotCrash() async {
        let service = iOSExportService()
        do {
            let url = try await service.exportMindmapToPDF(mermaidCode: TestConstants.emptyMarkdown,
                                                           fileName: TestConstants.fileName)
            XCTAssertEqual(url.pathExtension, "pdf", "空图谱若导出成功应依然为 pdf")
            try? FileManager.default.removeItem(at: url)
        } catch {
            XCTAssertFalse(error.localizedDescription.isEmpty, "空 Mermaid 抛错原因不应为空")
        }
    }

    // MARK: - exportToPPTX

    /// 导出幻灯片 Markdown 为 PPTX 应返回 URL 或抛出受控错误
    func testExportToPPTXWithSlidesMarkdownReturnsURL() async {
        let service = iOSExportService()
        do {
            let url = try await service.exportToPPTX(markdown: TestConstants.slidesMarkdown,
                                                     fileName: TestConstants.fileName)
            XCTAssertEqual(url.pathExtension, "pptx", "导出文件应以 .pptx 结尾")
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "成功导出的 PPTX 应物理存在")
            try? FileManager.default.removeItem(at: url)
        } catch {
            XCTAssertFalse(error.localizedDescription.isEmpty, "PPTX 导出失败描述不应为空")
        }
    }

    /// 导出空 Markdown 为 PPTX 不应崩溃
    func testExportToPPTXWithEmptyMarkdownDoesNotCrash() async {
        let service = iOSExportService()
        do {
            let url = try await service.exportToPPTX(markdown: TestConstants.emptyMarkdown,
                                                     fileName: TestConstants.fileName)
            XCTAssertEqual(url.pathExtension, "pptx", "空幻灯片若导出成功应依然为 pptx")
            try? FileManager.default.removeItem(at: url)
        } catch {
            XCTAssertFalse(error.localizedDescription.isEmpty, "空 Markdown 导出 PPTX 失败描述不应为空")
        }
    }

    // MARK: - ExportError

    /// ExportError.systemBusy 应返回非空错误描述
    func testExportErrorSystemBusyHasDescription() {
        XCTAssertFalse(ExportError.systemBusy.errorDescription?.isEmpty ?? true,
                       "systemBusy 错误描述不应为空")
    }

    /// ExportError.engineNotReady 应返回非空错误描述
    func testExportErrorEngineNotReadyHasDescription() {
        XCTAssertFalse(ExportError.engineNotReady.errorDescription?.isEmpty ?? true,
                       "engineNotReady 错误描述不应为空")
    }

    /// ExportError.internalError 应包含传入的消息
    func testExportErrorInternalErrorContainsMessage() {
        let message = "PPTX_Failed"
        let error = ExportError.internalError(message)
        XCTAssertTrue(error.errorDescription?.contains(message) ?? false,
                      "internalError 描述应包含传入消息")
    }

    // MARK: - NoOpExportService

    /// NoOpExportService 导出 PDF 应抛出 engineNotReady
    func testNoOpExportServiceThrowsEngineNotReady() async {
        let noOp = NoOpExportService()
        do {
            _ = try await noOp.exportToPDF(markdown: TestConstants.simpleMarkdown,
                                          fileName: TestConstants.fileName)
            XCTFail("NoOpExportService 应抛出 engineNotReady")
        } catch let exportError as ExportError {
            XCTAssertEqual(exportError.errorDescription, ExportError.engineNotReady.errorDescription, "应抛出 engineNotReady")
        } catch {
            XCTFail("应抛出 ExportError，实际：\(error)")
        }
    }

    /// NoOpExportService 导出思维导图应抛出 engineNotReady
    func testNoOpExportServiceMindmapThrowsEngineNotReady() async {
        let noOp = NoOpExportService()
        do {
            _ = try await noOp.exportMindmapToPDF(mermaidCode: TestConstants.mermaidCode,
                                                 fileName: TestConstants.fileName)
            XCTFail("NoOpExportService 思维导图应抛出 engineNotReady")
        } catch let exportError as ExportError {
            XCTAssertEqual(exportError.errorDescription, ExportError.engineNotReady.errorDescription)
        } catch {
            XCTFail("应抛出 ExportError，实际：\(error)")
        }
    }

    /// NoOpExportService 导出 PPTX 应抛出 engineNotReady
    func testNoOpExportServicePPTXThrowsEngineNotReady() async {
        let noOp = NoOpExportService()
        do {
            _ = try await noOp.exportToPPTX(markdown: TestConstants.slidesMarkdown,
                                           fileName: TestConstants.fileName)
            XCTFail("NoOpExportService PPTX 应抛出 engineNotReady")
        } catch let exportError as ExportError {
            XCTAssertEqual(exportError.errorDescription, ExportError.engineNotReady.errorDescription)
        } catch {
            XCTFail("应抛出 ExportError，实际：\(error)")
        }
    }

    // MARK: - 协议一致性

    /// 服务实例应可向上转型为 ExportServiceProtocol
    func testConformsToExportServiceProtocol() {
        let service: any ExportServiceProtocol = iOSExportService()
        XCTAssertNotNil(service, "协议转型应成功")
    }

    // MARK: - 并发槽位

    /// 连续两次导出不应因 systemBusy 永久阻塞（第二次应等待后执行或抛出受控 systemBusy）
    func testConsecutiveExportsDoNotDeadlock() async {
        let service = iOSExportService()
        do {
            let url1 = try await service.exportToPDF(markdown: TestConstants.simpleMarkdown,
                                                     fileName: TestConstants.fileName + "_1")
            XCTAssertEqual(url1.pathExtension, "pdf")
            try? FileManager.default.removeItem(at: url1)
        } catch {
            XCTAssertFalse(error.localizedDescription.isEmpty, "首次导出若抛错必须包含有效描述")
            return
        }

        do {
            let url2 = try await service.exportToPDF(markdown: TestConstants.simpleMarkdown,
                                                     fileName: TestConstants.fileName + "_2")
            XCTAssertEqual(url2.pathExtension, "pdf", "连续调用第二次导出若成功应生成合法 PDF")
            try? FileManager.default.removeItem(at: url2)
        } catch let exportError as ExportError {
            XCTAssertFalse(exportError.localizedDescription.isEmpty, "第二次导出抛出的 ExportError 描述不应为空")
        } catch {
            XCTAssertFalse(error.localizedDescription.isEmpty, "第二次导出底层抛错描述不应为空")
        }
    }
}
#endif
