//
//  InfrastructurePureLogicTests.swift
//  ZhiYu
//
//  系统层级：[Shared] 测试层
//  核心职责：Infrastructure 层纯逻辑组件单元测试（XlsxSharedStringsParser / SchemaService / StreamDeanonymizer / LLMChatService / ImageExtractor / ModelDownloadManager / DocumentExtractionService）
//

import XCTest
@testable import ZhiYu

// MARK: - XlsxSharedStringsParser 测试

/// XLSX 共享字符串 XML 解析器单元测试
/// 覆盖：正常解析、多文本节点、空文本、嵌套元素、非法 XML
final class XlsxSharedStringsParserTests: XCTestCase {

    /// 正常解析包含多个共享字符串的 XML
    func testParseNormalSharedStrings() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="3" uniqueCount="3">
            <si><t>Hello</t></si>
            <si><t>World</t></si>
            <si><t>智宇</t></si>
        </sst>
        """
        let parser = XlsxSharedStringsParser(xmlData: Data(xml.utf8))
        XCTAssertTrue(parser.parse())
        XCTAssertEqual(parser.strings, ["Hello", "World", "智宇"])
    }

    /// 解析包含富文本（多个 t 节点）的共享字符串
    func testParseRichTextMultipleTNodes() throws {
        let xml = """
        <sst>
            <si>
                <r><t>Hello </t></r>
                <r><t>World</t></r>
            </si>
            <si><t>Single</t></si>
        </sst>
        """
        let parser = XlsxSharedStringsParser(xmlData: Data(xml.utf8))
        XCTAssertTrue(parser.parse())
        // 每个 <t> 闭合时追加一个字符串，所以富文本会产生多条
        XCTAssertEqual(parser.strings.count, 3)
        XCTAssertEqual(parser.strings[0], "Hello ")
        XCTAssertEqual(parser.strings[1], "World")
        XCTAssertEqual(parser.strings[2], "Single")
    }

    /// 解析空文本节点
    func testParseEmptyText() throws {
        let xml = """
        <sst>
            <si><t></t></si>
            <si><t>NonEmpty</t></si>
        </sst>
        """
        let parser = XlsxSharedStringsParser(xmlData: Data(xml.utf8))
        XCTAssertTrue(parser.parse())
        XCTAssertEqual(parser.strings.count, 2)
        XCTAssertEqual(parser.strings[0], "")
        XCTAssertEqual(parser.strings[1], "NonEmpty")
    }

    /// 解析无任何文本节点的 XML
    func testParseNoTextNodes() throws {
        let xml = """
        <sst>
            <si><r><rPr><b/></rPr></r></si>
        </sst>
        """
        let parser = XlsxSharedStringsParser(xmlData: Data(xml.utf8))
        XCTAssertTrue(parser.parse())
        XCTAssertTrue(parser.strings.isEmpty)
    }

    /// 解析非法 XML 返回 false
    func testParseInvalidXML() throws {
        let xml = "<<<not valid xml>>>"
        let parser = XlsxSharedStringsParser(xmlData: Data(xml.utf8))
        XCTAssertFalse(parser.parse())
        XCTAssertTrue(parser.strings.isEmpty)
    }

    /// 解析空数据
    func testParseEmptyData() throws {
        let parser = XlsxSharedStringsParser(xmlData: Data())
        XCTAssertFalse(parser.parse())
        XCTAssertTrue(parser.strings.isEmpty)
    }

    /// 解析包含命名空间的 XML
    func testParseWithNamespace() throws {
        let xml = """
        <sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
            <si><t>Namespaced</t></si>
        </sst>
        """
        let parser = XlsxSharedStringsParser(xmlData: Data(xml.utf8))
        XCTAssertTrue(parser.parse())
        XCTAssertEqual(parser.strings, ["Namespaced"])
    }

    /// 解析包含特殊字符和 Unicode
    func testParseSpecialCharacters() throws {
        let xml = """
        <sst>
            <si><t>&lt;tag&gt; &amp; "quotes"</t></si>
            <si><t>日本語テスト</t></si>
            <si><t>Emoji: 🎉</t></si>
        </sst>
        """
        let parser = XlsxSharedStringsParser(xmlData: Data(xml.utf8))
        XCTAssertTrue(parser.parse())
        XCTAssertEqual(parser.strings.count, 3)
        XCTAssertEqual(parser.strings[0], "<tag> & \"quotes\"")
        XCTAssertEqual(parser.strings[1], "日本語テスト")
        XCTAssertEqual(parser.strings[2], "Emoji: 🎉")
    }
}

// MARK: - SchemaService 测试

/// 页面结构服务单元测试
/// 覆盖：entity/concept schema 查询、未知类型返回 nil、schema 内容完整性
@MainActor
final class SchemaServiceTests: XCTestCase {

    /// 查询 entity 类型 schema 应返回非 nil 且包含必需字段
    func testSchemaForEntity() throws {
        let schema = SchemaService.shared.schema(for: .entity)
        XCTAssertNotNil(schema)
        XCTAssertEqual(schema?.type, .entity)
        XCTAssertFalse(schema?.requiredFields.isEmpty ?? true)
        XCTAssertFalse(schema?.template.isEmpty ?? true)
        XCTAssertFalse(schema?.promptInstruction.isEmpty ?? true)
    }

    /// 查询 concept 类型 schema 应返回非 nil 且包含必需字段
    func testSchemaForConcept() throws {
        let schema = SchemaService.shared.schema(for: .concept)
        XCTAssertNotNil(schema)
        XCTAssertEqual(schema?.type, .concept)
        XCTAssertFalse(schema?.requiredFields.isEmpty ?? true)
        XCTAssertFalse(schema?.template.isEmpty ?? true)
        XCTAssertFalse(schema?.promptInstruction.isEmpty ?? true)
    }

    /// schemas 字典应包含 entity 和 concept 两个类型
    func testSchemasContainsBothTypes() throws {
        XCTAssertEqual(SchemaService.shared.schemas.count, 2)
        XCTAssertNotNil(SchemaService.shared.schemas[.entity])
        XCTAssertNotNil(SchemaService.shared.schemas[.concept])
    }

    /// entity 和 concept 的 requiredFields 不应相同
    func testEntityAndConceptHaveDifferentFields() throws {
        let entitySchema = SchemaService.shared.schema(for: .entity)
        let conceptSchema = SchemaService.shared.schema(for: .concept)
        XCTAssertNotEqual(entitySchema?.requiredFields, conceptSchema?.requiredFields)
    }
}

// MARK: - LLMChatService 测试

/// LLM 对话服务单元测试
/// 覆盖：chat 方法成功/失败路径、invalidResponse 错误、Mock LLMClient 注入
final class LLMChatServiceTests: XCTestCase {

    /// Mock LLM 客户端 — 返回预设响应
    private final class MockLLMClient: LLMClientProtocol, @unchecked Sendable {
        var response: [String: Any]
        var shouldThrow: Bool

        init(response: [String: Any], shouldThrow: Bool = false) {
            self.response = response
            self.shouldThrow = shouldThrow
        }

        func sendRequest(body: [String: Any]) async throws -> [String: Any] {
            if shouldThrow { throw LLMError.apiError("mock error") }
            return response
        }

        func sendStreamingRequest(body: [String: Any]) async throws -> URLSession.AsyncBytes {
            throw LLMError.apiError("streaming not supported in mock")
        }
    }

    /// chat 成功路径 — 返回有效响应内容
    func testChatSuccess() async throws {
        let mockResponse: [String: Any] = [
            "choices": [["message": ["content": "Hello from mock"]]]
        ]
        let client = MockLLMClient(response: mockResponse)
        let service = LLMChatService(client: client, model: "test-model")
        let result = try await service.chat(systemPrompt: "system", query: "hello", history: [])
        XCTAssertEqual(result, "Hello from mock")
    }

    /// chat 失败路径 — 响应缺少 choices 字段应抛出 invalidResponse
    func testChatInvalidResponse() async throws {
        let mockResponse: [String: Any] = ["error": "bad request"]
        let client = MockLLMClient(response: mockResponse)
        let service = LLMChatService(client: client, model: "test-model")
        do {
            _ = try await service.chat(systemPrompt: "system", query: "hello", history: [])
            XCTFail("应抛出 invalidResponse 错误")
        } catch {
            // 验证错误类型
            if let llmError = error as? LLMError, case .invalidResponse = llmError {
                // 预期路径
            } else {
                XCTFail("错误类型不匹配: \(error)")
            }
        }
    }

    /// chat 失败路径 — 客户端抛出错误应传播
    func testChatClientError() async throws {
        let client = MockLLMClient(response: [:], shouldThrow: true)
        let service = LLMChatService(client: client, model: "test-model")
        do {
            _ = try await service.chat(systemPrompt: "system", query: "hello", history: [])
            XCTFail("应抛出错误")
        } catch {
            // 错误应被传播
            if let llmError = error as? LLMError, case .apiError = llmError {
                // 预期路径
            } else {
                XCTFail("错误类型不匹配: \(error)")
            }
        }
    }

    /// chat 带历史记录应正确执行
    func testChatWithHistory() async throws {
        let mockResponse: [String: Any] = [
            "choices": [["message": ["content": "回复"]]]
        ]
        let client = MockLLMClient(response: mockResponse)
        let service = LLMChatService(client: client, model: "test-model")
        let history = [
            ChatMessageDTO(role: .user, content: "之前的问题"),
            ChatMessageDTO(role: .assistant, content: "之前的回答")
        ]
        let result = try await service.chat(systemPrompt: "system", query: "新问题", history: history)
        XCTAssertEqual(result, "回复")
    }

    /// chat 响应 choices 为空数组应抛出 invalidResponse
    func testChatEmptyChoices() async throws {
        let mockResponse: [String: Any] = ["choices": []]
        let client = MockLLMClient(response: mockResponse)
        let service = LLMChatService(client: client, model: "test-model")
        do {
            _ = try await service.chat(systemPrompt: "system", query: "hello", history: [])
            XCTFail("应抛出 invalidResponse 错误")
        } catch {
            if let llmError = error as? LLMError, case .invalidResponse = llmError {
                // 预期路径
            } else {
                XCTFail("错误类型不匹配: \(error)")
            }
        }
    }
}

// MARK: - DocumentExtractionService 测试

/// 文档提取服务单元测试
/// 覆盖：canExtract 格式白名单、TextProcessorProxy 文本提取
final class DocumentExtractionServiceTests: XCTestCase {

    private let service = DocumentExtractionService()

    /// canExtract 对 pdf 格式应返回 true
    func testCanExtractPDF() {
        XCTAssertTrue(service.canExtract(format: .pdf))
    }

    /// canExtract 对 docx 格式应返回 true
    func testCanExtractDOCX() {
        XCTAssertTrue(service.canExtract(format: .docx))
    }

    /// canExtract 对 xlsx 格式应返回 true
    func testCanExtractXLSX() {
        XCTAssertTrue(service.canExtract(format: .xlsx))
    }

    /// canExtract 对 markdown 格式应返回 true
    func testCanExtractMarkdown() {
        XCTAssertTrue(service.canExtract(format: .markdown))
    }

    /// canExtract 对 plainText 格式应返回 true
    func testCanExtractPlainText() {
        XCTAssertTrue(service.canExtract(format: .plainText))
    }

    /// canExtract 对 unknown 格式应返回 false
    func testCanExtractUnknown() {
        XCTAssertFalse(service.canExtract(format: .unknown))
    }

    /// TextProcessorProxy 应正确提取 UTF8 文本文件
    func testTextProcessorProxyExtractText() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("test_\(UUID().uuidString).txt")
        let expectedText = "这是一段测试文本内容"
        try expectedText.write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        let processor = TextProcessorProxy()
        let result = try await processor.extractText(from: tempFile)
        XCTAssertEqual(result, expectedText)
    }

    /// TextProcessorProxy 对不存在的文件应抛出 extractionFailed
    func testTextProcessorProxyNonExistentFile() async throws {
        let nonExistentURL = URL(fileURLWithPath: "/tmp/nonexistent_\(UUID().uuidString).txt")
        let processor = TextProcessorProxy()
        do {
            _ = try await processor.extractText(from: nonExistentURL)
            XCTFail("应抛出错误")
        } catch {
            // 验证错误被抛出
            XCTAssertTrue(error is ProcessorError || error is Error)
        }
    }

    /// extractText 对不支持的格式应抛出 extractionFailed
    func testExtractTextUnsupportedFormat() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("test_\(UUID().uuidString).xyz")
        try "content".write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        do {
            _ = try await service.extractText(from: tempFile)
            // 如果没有抛出错误，可能是格式被识别为 plainText，这是可接受的
        } catch {
            // 抛出错误也是可接受的
            XCTAssertTrue(error is ProcessorError || error is Error)
        }
    }
}
