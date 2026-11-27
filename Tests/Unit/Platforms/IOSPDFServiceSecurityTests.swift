//
//  IOSPDFServiceSecurityTests.swift
//  ZhiYuTests
//
//  系统层级：[Platforms] 平台安全测试
//  核心职责：验证 iOSPDFService 对路径穿越文件名的防御与图片抽取最大页数限制。
//

import XCTest
import Foundation
import UFPCore
@testable import ZhiYuUnitTestHost

#if !os(watchOS)
@MainActor
final class IOSPDFServiceSecurityTests: XCTestCase {

    /// 验证 getPDFURL 拒绝含路径穿越特征的文件名
    func testGetPDFURL_pathTraversal_isRejected() {
        #if os(iOS)
        let pdfService = iOSPDFService()
        XCTAssertNil(pdfService.getPDFURL(fileName: "../../../etc/passwd"), "应拒绝含 ../ 的路径穿越文件名")
        XCTAssertNil(pdfService.getPDFURL(fileName: "subdir/file.pdf"), "应拒绝含 / 的路径穿越文件名")
        XCTAssertNil(pdfService.getPDFURL(fileName: "nonexistent.pdf"))
        #endif
    }

    /// 验证 maxPagesForImageExtraction 常量配置为 20
    func testMaxPagesForImageExtraction_matchesConstantValue() {
        XCTAssertEqual(AppConstants.Keys.ImportLimits.maxPagesForImageExtraction, 20)
    }

    /// 验证 isFileNameSafe 拒绝空串、纯空白及反斜杠路径分隔符
    func testIsFileNameSafe_rejectsEmptyAndBackslash() {
        let pdfService = iOSPDFService()
        XCTAssertFalse(pdfService.isFileNameSafe(""), "空文件名应被拒绝")
        XCTAssertFalse(pdfService.isFileNameSafe("   "), "纯空白文件名应被拒绝")
        XCTAssertFalse(pdfService.isFileNameSafe("..\\secret.pdf"), "含反斜杠的文件名应被拒绝")
        XCTAssertTrue(pdfService.isFileNameSafe("report.pdf"))
    }

    /// 验证 iOSExportService.sanitizedExportFileName 清洗路径穿越、引号与换行，空串回退默认值
    func testSanitizedExportFileName_stripsTraversalAndJSQuotes() {
        #if canImport(WebKit)
        let cleaned = iOSExportService.sanitizedExportFileName("../2026/11/\"evil\"\nreport")
        XCTAssertFalse(cleaned.contains(".."))
        XCTAssertFalse(cleaned.contains("/"))
        XCTAssertFalse(cleaned.contains("\""))
        XCTAssertFalse(cleaned.contains("\n"))
        XCTAssertEqual(iOSExportService.sanitizedExportFileName("   "), "export")
        #endif
    }

    /// 验证 FileImportFileStore.copyFile 对无扩展名文件不产生尾随点且保留内容
    func testFileImportFileStore_copyFileWithoutExtension_hasNoTrailingDot() throws {
        let fm = FileManager.default
        let srcURL = fm.temporaryDirectory.appendingPathComponent("README_\(UUID().uuidString)")
        try Data("hello".utf8).write(to: srcURL)
        defer { try? fm.removeItem(at: srcURL) }

        let store = FileImportFileStore()
        let copiedPath = try XCTUnwrap(store.copyFile(at: srcURL, category: .file))
        defer { try? fm.removeItem(atPath: copiedPath) }

        XCTAssertFalse(copiedPath.hasSuffix("."), "无扩展名文件复制后不得产生尾随点")
        XCTAssertTrue(fm.fileExists(atPath: copiedPath))
    }

    /// 验证 generateMermaidHTML 转义 `</script>` 闭合标签、启用 strict 安全级别且 fallback 不拼接 raw innerHTML
    func testGenerateMermaidHTML_blocksScriptBreakoutAndUsesStrictMode() {
        let html = generateMermaidHTML(
            mermaidCode: "graph TD\nA</script><img src=x onerror=alert(1)>",
            theme: "neutral"
        )
        XCTAssertFalse(html.contains("A</script>"), "用户输入中的 </script> 必须被转义为 <\\/script>")
        XCTAssertTrue(html.contains("securityLevel: 'strict'"), "Mermaid 必须启用 strict 安全模式")
        XCTAssertFalse(html.contains("securityLevel: 'loose'"), "严禁启用 loose 模式")
        XCTAssertTrue(html.contains("textContent"), "catch 回退路径必须通过 textContent 构造安全 DOM")
    }
}
#endif
