//
//  IngestPipelineDeepTests.swift
//  ZhiYuTests
//
//  合并自 2 个碎片化测试文件：IngestPipelineFuzzAndFaultInjectionTests.swift, IngestPipelineInteractiveDeepTests.swift
//

import Dependencies
import SwiftUI
import UFPCore
import UFPStorage
import XCTest

@testable import ZhiYu

@MainActor
final class IngestPipelineDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    func testIngestSanitationPipeline_MultiModalFuzzPayloads_NeverCrashes() {
        let fuzzPayloads: [String] = [
            "",
            "   \n\t\r   ",
            "\0\u{0001}\u{0002}\u{001F}\u{007F}",
            "\u{200B}\u{200C}\u{200D}\u{FEFF}\u{202E}Bidirectional Injection\u{202C}",
            String(repeating: "💥🔥✨🚀🧠", count: 2000),
            String(repeating: "> ", count: 100) + "Deep nested blockquotes",
            "```swift\nlet x = 1\n```\n```mermaid\ngraph TD\nA[Unclosed\n```",
            "<div><script>alert('xss')</script><p>Text with <b>broken tags<i></p>",
            "混合 中文 和 English ， 标点 符号   ，，， 异常 空格  测试 。。。",
            "OCR Line 1\n \nOCR Line 2\n\n\n\nOCR Line 3",
            "Here is a link [[Concept A|Alias 1]] and broken [[Concept B and [[Concept C]]]]",
            String(repeating: "A", count: 50_000)
        ]

        for mode in IngestSourceMode.allCases {
            for payload in fuzzPayloads {
                let sanitized = IngestSanitationPipeline.shared.sanitize(payload, mode: mode)
                XCTAssertNotNil(sanitized, "Sanitized string should never be nil for mode \(mode)")
            }
        }
    }

    func testIngestService_FuzzRawContent_ProducesValidPage() async throws {
        let store = AppStore()
        let ingestService = IngestService()

        let edgeContents = [
            ("Empty Content", ""),
            ("Null Byte Payload", "Header\0NullByte\0Footer"),
            ("Huge Repetitive Text", String(repeating: "Knowledge ingestion scalability test. ", count: 1000)),
            ("Deep Nested Markdown", String(repeating: "1. Item\n  ", count: 50) + "Final item"),
            ("Special Unicode", "测试全角字符【】（）！￥……——以及Emoji💡🎉")
        ]

        for (title, content) in edgeContents {
            do {
                let page = try await ingestService.ingestRawContent(
                    title: title,
                    content: content,
                    type: .source,
                    sourceURL: "https://zhiyu.app/fuzz/\(UUID().uuidString)",
                    pageStore: store
                )
                XCTAssertFalse(page.title.isEmpty)
                XCTAssertNotNil(page.id)
            } catch {
                XCTFail("IngestService should handle edge content '\(title)' gracefully without throwing unhandled error: \(error)")
            }
        }
    }

    func testIngestService_FaultInjection_DBTransactionDraining_ThrowsCorrectly() async throws {
        let store = AppStore()
        let ingestService = IngestService()

        // 模拟数据库锁排空状态 (Transaction Gatekeeper Draining)
        let dbManager = DatabaseManager.shared
        await dbManager.setDrainingForTesting(true)

        do {
            _ = try await ingestService.ingestRawContent(
                title: "Blocked by Drain",
                content: "Content that should be rejected during db draining",
                type: .source,
                pageStore: store
            )
            XCTFail("IngestService must fail when database is in draining state")
        } catch {
            // 验证抛出预期事务阻止错误 (DatabaseError.draining)
            XCTAssertTrue(String(describing: error).contains("draining"))
        }

        // 恢复数据库状态以便后续测试
        await dbManager.resetDrainingState()
    }

    func testIngestCoordinator_FuzzCorruptedAndGhostFilePaths() async throws {
        let coordinator = IngestCoordinator()

        let ghostPaths = [
            "/non/existent/path/ghost.txt",
            "/tmp/zero_byte_temp_\(UUID().uuidString).docx",
            "/private/var/folders/corrupted_\(UUID().uuidString).unknown_ext",
            "relative/path/not/in/sandbox.pdf"
        ]

        for path in ghostPaths {
            // 调度导入不存在或空路径文件
            coordinator.handleFileImport(.success([URL(fileURLWithPath: path)]))
            // 验证未发生 Fatal Error，状态机安全复位
            XCTAssertFalse(coordinator.isIngesting)
        }
    }

    func testIngestURLHandler_FuzzMaliciousURLs_RejectsSafely() async throws {
        let coordinator = IngestCoordinator()

        let maliciousURLs = [
            "javascript:alert(document.cookie)",
            "data:text/html;base64,PHNjcmlwdD5hbGVydCgxKTwvc2NyaXB0Pg==",
            "file:///etc/passwd",
            "ftp://anonymous@malicious.server/dump",
            "http://256.256.256.256/invalid",
            "https://[::1]:99999/overflow",
            "about:blank",
            "   https://zhiyu.app/spaced-url   "
        ]

        for urlStr in maliciousURLs {
            if let validURL = URL(string: urlStr.trimmingCharacters(in: .whitespacesAndNewlines)) {
                if !SSRFGuard.isSafeURL(validURL) {
                    let task = coordinator.handleBatchURLImport([validURL])
                    await task.value
                }
            }
            let res = try? await coordinator.extractImagesFromURL(urlStr)
            XCTAssertEqual(res, "")
        }
    }

    func testIngestCoordinatorStateAndFlows() async throws {
        let coordinator = IngestCoordinator()

        // 1. 验证初始状态
        XCTAssertFalse(coordinator.isIngesting)
        XCTAssertFalse(coordinator.showManualForm)
        XCTAssertFalse(coordinator.showFileImporter)
        XCTAssertFalse(coordinator.showURLImport)
        XCTAssertFalse(coordinator.showOCRScan)
        XCTAssertFalse(coordinator.showVoiceNote)

        // 2. 切换各种录入弹窗触发态
        coordinator.showManualForm = true
        coordinator.newTitle = "Manual Markdown Note"
        coordinator.newContent = "## Summary\n\nDirect manual entry."
        XCTAssertTrue(coordinator.showManualForm)
        coordinator.showManualForm = false

        coordinator.showURLImport = true
        XCTAssertTrue(coordinator.showURLImport)
        coordinator.showURLImport = false

        coordinator.showOCRScan = true
        coordinator.hasNewContent = true
        XCTAssertTrue(coordinator.showOCRScan)
        coordinator.showOCRScan = false

        // 3. 执行剪贴板内容导入探测
        coordinator.performClipboardImport()
    }

}
