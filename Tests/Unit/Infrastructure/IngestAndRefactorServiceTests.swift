//
//  IngestAndRefactorServiceTests.swift
//  ZhiYu
//
//  Created by CodeFree on 2026/08/09.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 IngestProcessor/LLMIngestService/LLMRefactorService 的降级逻辑、
//           错误处理路径与边界条件开展自动化单元测试，以发现问题为目标。
//

import XCTest
@testable import ZhiYu
import UFPCore

// MARK: - Mock LLM Client（IngestAndRefactor 专用）

/// 专用 Mock LLM 客户端，支持自定义响应内容和错误注入
private final class IngestMockLLMClient: LLMClientProtocol, @unchecked Sendable {
    var mockResponse: [String: Any] = [:]
    var mockError: Error?
    var capturedBodies: [[String: Any]] = []

    func sendRequest(body: [String: Any]) async throws -> [String: Any] {
        capturedBodies.append(body)
        if let error = mockError { throw error }
        return mockResponse
    }

    func sendStreamingRequest(body: [String: Any]) async throws -> URLSession.AsyncBytes {
        fatalError("流式请求在 IngestAndRefactor 测试中不应被调用")
    }
}

// MARK: - LLMIngestService 边界条件测试

/// 覆盖 `LLMIngestService.smartIngest` 的 title 回填分支和解析失败路径
final class LLMIngestServiceEdgeCaseTests: XCTestCase {

    private var mockClient: IngestMockLLMClient!
    private var contextBuilder: LLMContextBuilder!

    override func setUp() {
        super.setUp()
        mockClient = IngestMockLLMClient()
        contextBuilder = LLMContextBuilder()
    }

    /// 验证 LLM 返回的 JSON 中 title 为空时，应回填传入的默认标题
    func testSmartIngestFillsEmptyTitleFromParameter() async throws {
        let service = LLMIngestService(client: mockClient, model: "test-model", contextBuilder: contextBuilder)

        let jsonResponse = """
        {
            "title": "",
            "compiled_content": "编译内容",
            "suggested_tags": ["标签1"],
            "suggested_type": "concept",
            "related_titles": [],
            "summary": "摘要"
        }
        """
        mockClient.mockResponse = [
            "choices": [["message": ["content": jsonResponse]]]
        ]

        let result = try await service.smartIngest(title: "默认标题", rawContent: "原始内容", pages: [])

        XCTAssertEqual(result.title, "默认标题", "title 为空时应回填传入的默认标题")
        XCTAssertEqual(result.compiledContent, "编译内容")
    }

    /// 验证 LLM 返回的 JSON 中 title 为 null 时，也应回填传入的默认标题
    func testSmartIngestFillsNullTitleFromParameter() async throws {
        let service = LLMIngestService(client: mockClient, model: "test-model", contextBuilder: contextBuilder)

        let jsonResponse = """
        {
            "title": null,
            "compiled_content": "编译内容",
            "suggested_tags": [],
            "suggested_type": "entity",
            "related_titles": [],
            "summary": "摘要"
        }
        """
        mockClient.mockResponse = [
            "choices": [["message": ["content": jsonResponse]]]
        ]

        let result = try await service.smartIngest(title: "回填标题", rawContent: "内容", pages: [])

        XCTAssertEqual(result.title, "回填标题", "title 为 null 时应回填传入的默认标题")
    }

    /// 验证 LLM 返回的 JSON 中 title 有值时，应保留 LLM 返回的标题
    func testSmartIngestKeepsLLMGeneratedTitle() async throws {
        let service = LLMIngestService(client: mockClient, model: "test-model", contextBuilder: contextBuilder)

        let jsonResponse = """
        {
            "title": "LLM生成的标题",
            "compiled_content": "编译内容",
            "suggested_tags": [],
            "suggested_type": "concept",
            "related_titles": [],
            "summary": "摘要"
        }
        """
        mockClient.mockResponse = [
            "choices": [["message": ["content": jsonResponse]]]
        ]

        let result = try await service.smartIngest(title: "传入标题", rawContent: "内容", pages: [])

        XCTAssertEqual(result.title, "LLM生成的标题", "title 有值时应保留 LLM 返回的标题")
    }

    /// 验证 LLM 返回无法解析的 JSON 时，应抛出 invalidResponse
    func testSmartIngestThrowsInvalidResponseOnUnparseableJSON() async throws {
        let service = LLMIngestService(client: mockClient, model: "test-model", contextBuilder: contextBuilder)

        mockClient.mockResponse = [
            "choices": [["message": ["content": "这不是JSON"]]]
        ]

        do {
            _ = try await service.smartIngest(title: "标题", rawContent: "内容", pages: [])
            XCTFail("无法解析的 JSON 应抛出 invalidResponse")
        } catch {
            if let llmError = error as? LLMError, case .invalidResponse = llmError {
                // 通过
            } else {
                XCTFail("应抛出 LLMError.invalidResponse，实际：\(error)")
            }
        }
    }

    /// 验证 LLM 返回 Markdown 代码块包裹的 JSON 时，应正确解析
    func testSmartIngestParsesMarkdownWrappedJSON() async throws {
        let service = LLMIngestService(client: mockClient, model: "test-model", contextBuilder: contextBuilder)

        let jsonResponse = """
        ```json
        {
            "title": "Markdown标题",
            "compiled_content": "编译内容",
            "suggested_tags": ["标签"],
            "suggested_type": "concept",
            "related_titles": [],
            "summary": "摘要"
        }
        ```
        """
        mockClient.mockResponse = [
            "choices": [["message": ["content": jsonResponse]]]
        ]

        let result = try await service.smartIngest(title: "默认", rawContent: "内容", pages: [])

        XCTAssertEqual(result.title, "Markdown标题")
        XCTAssertEqual(result.compiledContent, "编译内容")
    }

    /// 验证 LLM 返回空 content 时，应抛出 invalidResponse
    func testSmartIngestThrowsInvalidResponseOnEmptyContent() async throws {
        let service = LLMIngestService(client: mockClient, model: "test-model", contextBuilder: contextBuilder)

        mockClient.mockResponse = [
            "choices": [["message": ["content": ""]]]
        ]

        do {
            _ = try await service.smartIngest(title: "标题", rawContent: "内容", pages: [])
            XCTFail("空 content 应抛出 invalidResponse")
        } catch {
            if let llmError = error as? LLMError, case .invalidResponse = llmError {
                // 通过
            } else {
                XCTFail("应抛出 LLMError.invalidResponse，实际：\(error)")
            }
        }
    }
}

// MARK: - LLMRefactorService 降级与边界测试

/// 覆盖 `LLMRefactorService` 的 foldContent 降级、analyzeForRefactoring 解析失败等路径
final class LLMRefactorServiceEdgeCaseTests: XCTestCase {

    private var mockClient: IngestMockLLMClient!

    override func setUp() {
        super.setUp()
        mockClient = IngestMockLLMClient()
    }

    /// 验证 foldContent 在 LLM 返回有效内容时使用 LLM 结果
    func testFoldContentUsesLLMResultWhenValid() async throws {
        let service = LLMRefactorService(client: mockClient, model: "test-model")

        mockClient.mockResponse = [
            "choices": [["message": ["content": "合并后的内容"]]]
        ]

        let result = try await service.foldContent(existingContent: "旧内容", newContent: "新内容", title: "标题")
        XCTAssertEqual(result, "合并后的内容")
    }

    /// 验证 foldContent 在 LLM 返回空 content 时降级为拼接
    func testFoldContentFallsBackToConcatenationOnEmptyResponse() async throws {
        let service = LLMRefactorService(client: mockClient, model: "test-model")

        mockClient.mockResponse = [
            "choices": [["message": ["content": ""]]]
        ]

        let result = try await service.foldContent(existingContent: "旧内容", newContent: "新内容", title: "标题")
        XCTAssertEqual(result, "旧内容\n\n新内容", "LLM 返回空时应降级为拼接")
    }

    /// 验证 foldContent 在 LLM 返回 null content 时降级为拼接
    func testFoldContentFallsBackToConcatenationOnNullResponse() async throws {
        let service = LLMRefactorService(client: mockClient, model: "test-model")

        mockClient.mockResponse = [
            "choices": [["message": [:]]]
        ]

        let result = try await service.foldContent(existingContent: "旧", newContent: "新", title: "标题")
        XCTAssertEqual(result, "旧\n\n新", "LLM 返回 null content 时应降级为拼接")
    }

    /// 验证 discoverPotentialLinks 在 LLM 返回数字数组时转为字符串数组
    func testDiscoverPotentialLinksParsesNumericArray() async throws {
        let service = LLMRefactorService(client: mockClient, model: "test-model")

        mockClient.mockResponse = [
            "choices": [["message": ["content": "[1, 2, 3]"]]]
        ]

        let links = try await service.discoverPotentialLinks(content: "内容", existingTitles: ["标题1", "标题2"])
        XCTAssertEqual(links, ["1", "2", "3"], "数字数组应转为字符串数组")
    }

    /// 验证 discoverPotentialLinks 在 LLM 返回非 JSON 时返回空数组
    func testDiscoverPotentialLinksReturnsEmptyOnNonJSON() async throws {
        let service = LLMRefactorService(client: mockClient, model: "test-model")

        mockClient.mockResponse = [
            "choices": [["message": ["content": "这不是JSON数组"]]]
        ]

        let links = try await service.discoverPotentialLinks(content: "内容", existingTitles: [])
        XCTAssertEqual(links, [], "非 JSON 应返回空数组")
    }

    /// 验证 analyzeForRefactoring 在 LLM 返回有效建议时正确解析
    func testAnalyzeForRefactoringParsesValidSuggestions() async throws {
        let service = LLMRefactorService(client: mockClient, model: "test-model")

        let jsonResponse = """
        [
            {"type": "merge", "target": "页面A", "reason": "内容重复", "suggestion": "合并到页面A"},
            {"type": "split", "target": "页面B", "reason": "内容过长", "suggestion": "拆分为两个页面"}
        ]
        """
        mockClient.mockResponse = [
            "choices": [["message": ["content": jsonResponse]]]
        ]

        let page = KnowledgePage(title: "测试页面", pageType: .concept, content: "内容")
        let suggestions = try await service.analyzeForRefactoring(pages: [page])

        XCTAssertEqual(suggestions.count, 2)
        XCTAssertEqual(suggestions[0].type, "merge")
        XCTAssertEqual(suggestions[0].target, "页面A")
        XCTAssertEqual(suggestions[1].type, "split")
    }

    /// 验证 analyzeForRefactoring 在 LLM 返回非 JSON 时返回空数组
    func testAnalyzeForRefactoringReturnsEmptyOnNonJSON() async throws {
        let service = LLMRefactorService(client: mockClient, model: "test-model")

        mockClient.mockResponse = [
            "choices": [["message": ["content": "无法解析"]]]
        ]

        let page = KnowledgePage(title: "测试", pageType: .concept, content: "内容")
        let suggestions = try await service.analyzeForRefactoring(pages: [page])
        XCTAssertTrue(suggestions.isEmpty, "非 JSON 应返回空数组")
    }

    /// 验证 analyzeForRefactoring 在 LLM 返回空数组时返回空数组
    func testAnalyzeForRefactoringReturnsEmptyOnEmptyArray() async throws {
        let service = LLMRefactorService(client: mockClient, model: "test-model")

        mockClient.mockResponse = [
            "choices": [["message": ["content": "[]"]]]
        ]

        let page = KnowledgePage(title: "测试", pageType: .concept, content: "内容")
        let suggestions = try await service.analyzeForRefactoring(pages: [page])
        XCTAssertTrue(suggestions.isEmpty, "空数组应返回空数组")
    }
}

// MARK: - IngestProcessor 降级逻辑测试

/// 覆盖 `IngestProcessor` 在子服务未初始化时的降级行为
@MainActor
final class IngestProcessorFallbackTests: XCTestCase {

    /// 验证 IngestProcessor 在未配置 LLM 时 smartIngest 抛出 notConfigured
    func testSmartIngestThrowsNotConfiguredWhenServiceIsNil() async throws {
        let configManager = LLMConfigManager()
        configManager.apiKey = ""
        configManager.isEnabled = false
        ServiceContainer.shared.register(configManager, for: LLMConfigManager.self)

        let processor = IngestProcessor()

        do {
            _ = try await processor.smartIngest(title: "标题", rawContent: "内容", pages: [])
            XCTFail("未配置时应抛出 notConfigured")
        } catch {
            if let llmError = error as? LLMError, case .notConfigured = llmError {
                // 通过
            } else {
                XCTFail("应抛出 LLMError.notConfigured，实际：\(error)")
            }
        }
    }

    /// 验证 IngestProcessor 在未配置 LLM 时 discoverPotentialLinks 返回空数组
    func testDiscoverPotentialLinksReturnsEmptyWhenServiceIsNil() async throws {
        let configManager = LLMConfigManager()
        configManager.apiKey = ""
        configManager.isEnabled = false
        ServiceContainer.shared.register(configManager, for: LLMConfigManager.self)

        let processor = IngestProcessor()

        let links = try await processor.discoverPotentialLinks(content: "内容", existingTitles: ["标题"])
        XCTAssertEqual(links, [], "未配置时应返回空数组而非抛出错误")
    }

    /// 验证 IngestProcessor 在未配置 LLM 时 foldContent 降级为拼接
    func testFoldContentFallsBackToConcatenationWhenServiceIsNil() async throws {
        let configManager = LLMConfigManager()
        configManager.apiKey = ""
        configManager.isEnabled = false
        ServiceContainer.shared.register(configManager, for: LLMConfigManager.self)

        let processor = IngestProcessor()

        let result = try await processor.foldContent(existingContent: "旧", newContent: "新", title: "标题")
        XCTAssertEqual(result, "旧\n\n新", "未配置时应降级为拼接而非抛出错误")
    }

    /// 验证 IngestProcessor 在未配置 LLM 时 analyzeForRefactoring 返回空数组
    func testAnalyzeForRefactoringReturnsEmptyWhenServiceIsNil() async throws {
        let configManager = LLMConfigManager()
        configManager.apiKey = ""
        configManager.isEnabled = false
        ServiceContainer.shared.register(configManager, for: LLMConfigManager.self)

        let processor = IngestProcessor()

        let page = KnowledgePage(title: "测试", pageType: .concept, content: "内容")
        let suggestions = try await processor.analyzeForRefactoring(pages: [page])
        XCTAssertTrue(suggestions.isEmpty, "未配置时应返回空数组而非抛出错误")
    }
}

// MARK: - DocumentExtractionService XLSX/DOCX 处理测试

/// 覆盖 `DocumentExtractionService` 的 XLSX 和 DOCX 处理路径
final class DocumentExtractionXlsxDocxTests: XCTestCase {

    private let service = DocumentExtractionService()

    /// 验证 XlsxSharedStringsParser 正确解析共享字符串池
    func testXlsxSharedStringsParserExtractsStrings() {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="3" uniqueCount="3">
            <si><t>你好</t></si>
            <si><t>世界</t></si>
            <si><t>测试</t></si>
        </sst>
        """
        let data = Data(xml.utf8)
        let parser = XlsxSharedStringsParser(xmlData: data)
        XCTAssertTrue(parser.parse())
        XCTAssertEqual(parser.strings, ["你好", "世界", "测试"])
    }

    /// 验证 ExcelProcessor 正确解析单元格中的共享字符串索引
    func testExcelProcessorExtractsSharedStringIndices() {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
            <sheetData>
                <row r="1">
                    <c r="A1" t="s"><v>0</v></c>
                    <c r="B1" t="s"><v>1</v></c>
                    <c r="C1" t="n"><v>42</v></c>
                </row>
            </sheetData>
        </worksheet>
        """
        let data = Data(xml.utf8)
        let parser = ExcelProcessor(xmlData: data)
        XCTAssertTrue(parser.parse())
        XCTAssertEqual(parser.values, ["[0]", "[1]"], "共享字符串索引应被提取，数字类型应被跳过")
    }

    /// 验证 DocxProcessor 正确提取 w:t 元素中的文本
    func testDocxProcessorExtractsTextFromWordDocument() {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
            <w:body>
                <w:p>
                    <w:r>
                        <w:t>第一段</w:t>
                    </w:r>
                    <w:r>
                        <w:t>第二行</w:t>
                    </w:r>
                </w:p>
                <w:p>
                    <w:r>
                        <w:t>第二段</w:t>
                    </w:r>
                </w:p>
            </w:body>
        </w:document>
        """
        let data = Data(xml.utf8)
        let parser = DocxProcessor(xmlData: data)
        XCTAssertTrue(parser.parse())
        XCTAssertTrue(parser.extractedText.contains("第一段"), "应包含第一段文本")
        XCTAssertTrue(parser.extractedText.contains("第二行"), "应包含第二行文本")
        XCTAssertTrue(parser.extractedText.contains("第二段"), "应包含第二段文本")
    }

    /// 验证 DocxProcessor 对空 XML 不崩溃且返回空字符串
    func testDocxProcessorHandlesEmptyXML() {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
            <w:body>
            </w:body>
        </w:document>
        """
        let data = Data(xml.utf8)
        let parser = DocxProcessor(xmlData: data)
        XCTAssertTrue(parser.parse())
        XCTAssertEqual(parser.extractedText, "", "空文档应返回空字符串")
    }

    /// 验证 XlsxProcessorProxy 对无效 ZIP 文件抛出 invalidArchive
    func testXlsxProcessorProxyThrowsOnInvalidArchive() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("test_\(UUID().uuidString).xlsx")
        try "这不是ZIP文件".write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        let processor = XlsxProcessorProxy()
        do {
            _ = try await processor.extractText(from: tempFile)
            XCTFail("无效 ZIP 应抛出错误")
        } catch {
            // 通过：应抛出 invalidArchive 或 extractionFailed
        }
    }

    /// 验证 DocxProcessorProxy 对无效 ZIP 文件抛出 invalidArchive
    func testDocxProcessorProxyThrowsOnInvalidArchive() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("test_\(UUID().uuidString).docx")
        try "这不是ZIP文件".write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        let processor = DocxProcessorProxy()
        do {
            _ = try await processor.extractText(from: tempFile)
            XCTFail("无效 ZIP 应抛出错误")
        } catch {
            // 通过：应抛出 invalidArchive 或 extractionFailed
        }
    }

    /// 验证 XlsxProcessorProxy 对缺少 sharedStrings.xml 的 ZIP 返回空或抛出错误
    func testXlsxProcessorProxyHandlesZipWithoutSharedStrings() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("test_\(UUID().uuidString).xlsx")
        // 创建一个有效的 ZIP 但不包含 sharedStrings.xml
        let zipData = createMinimalZip(files: [
            "xl/worksheets/sheet1.xml": Data("""
                <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
                    <sheetData>
                        <row r="1">
                            <c r="A1" t="n"><v>42</v></c>
                        </row>
                    </sheetData>
                </worksheet>
                """.utf8)
        ])
        try zipData.write(to: tempFile)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        let processor = XlsxProcessorProxy()
        do {
            let text = try await processor.extractText(from: tempFile)
            // 数字单元格不通过共享字符串池，allText 为空，应抛出 extractionFailed
            XCTFail("无共享字符串且只有数字时应抛出 extractionFailed，实际返回：\(text)")
        } catch {
            // 通过：应抛出 extractionFailed
        }
    }

    // MARK: - 辅助方法

    /// 创建最小化 ZIP 文件（Stored 方式，无压缩）
    private func createMinimalZip(files: [String: Data]) -> Data {
        var zipData = Data()
        var centralDirectory = Data()
        var offset = 0

        for (fileName, fileData) in files {
            let fileNameData = Data(fileName.utf8)

            // Local File Header
            var localHeader = Data()
            localHeader.append(uint32LE: 0x04034B50)  // 签名
            localHeader.append(uint16LE: 20)          // 版本
            localHeader.append(uint16LE: 0)           // 标志
            localHeader.append(uint16LE: 0)           // 压缩方法：Stored
            localHeader.append(uint16LE: 0)           // 修改时间
            localHeader.append(uint16LE: 0)           // 修改日期
            localHeader.append(uint32LE: crc32(fileData))  // CRC32
            localHeader.append(uint32LE: UInt32(fileData.count))  // 压缩大小
            localHeader.append(uint32LE: UInt32(fileData.count))  // 未压缩大小
            localHeader.append(uint16LE: UInt16(fileNameData.count))  // 文件名长度
            localHeader.append(uint16LE: 0)           // 额外字段长度

            zipData.append(localHeader)
            zipData.append(fileNameData)
            zipData.append(fileData)

            // Central Directory Header
            var centralHeader = Data()
            centralHeader.append(uint32LE: 0x02014B50)  // 签名
            centralHeader.append(uint16LE: 20)          // 版本
            centralHeader.append(uint16LE: 20)          // 版本需要
            centralHeader.append(uint16LE: 0)           // 标志
            centralHeader.append(uint16LE: 0)           // 压缩方法
            centralHeader.append(uint16LE: 0)           // 修改时间
            centralHeader.append(uint16LE: 0)           // 修改日期
            centralHeader.append(uint32LE: crc32(fileData))  // CRC32
            centralHeader.append(uint32LE: UInt32(fileData.count))  // 压缩大小
            centralHeader.append(uint32LE: UInt32(fileData.count))  // 未压缩大小
            centralHeader.append(uint16LE: UInt16(fileNameData.count))  // 文件名长度
            centralHeader.append(uint16LE: 0)           // 额外字段长度
            centralHeader.append(uint16LE: 0)           // 文件注释长度
            centralHeader.append(uint16LE: 0)           // 磁盘号开始
            centralHeader.append(uint16LE: 0)           // 内部文件属性
            centralHeader.append(uint32LE: 0)           // 外部文件属性
            centralHeader.append(uint32LE: UInt32(offset))  // 相对偏移量

            centralHeader.append(fileNameData)
            centralDirectory.append(centralHeader)

            offset += localHeader.count + fileNameData.count + fileData.count
        }

        // End of Central Directory
        var endRecord = Data()
        endRecord.append(uint32LE: 0x06054B50)  // 签名
        endRecord.append(uint16LE: 0)           // 磁盘号
        endRecord.append(uint16LE: 0)           // 磁盘号开始
        endRecord.append(uint16LE: UInt16(files.count))  // 中央目录条目数
        endRecord.append(uint16LE: UInt16(files.count))  // 总条目数
        endRecord.append(uint32LE: UInt32(centralDirectory.count))  // 中央目录大小
        endRecord.append(uint32LE: UInt32(offset))  // 中央目录偏移量
        endRecord.append(uint16LE: 0)           // 注释长度

        zipData.append(centralDirectory)
        zipData.append(endRecord)

        return zipData
    }

    /// 计算 CRC32 校验值
    private func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                if crc & 1 != 0 {
                    crc = (crc >> 1) ^ 0xEDB88320
                } else {
                    crc >>= 1
                }
            }
        }
        return crc ^ 0xFFFFFFFF
    }
}

// MARK: - Data 扩展：小端字节序写入

private extension Data {
    mutating func append(uint16LE value: UInt16) {
        append(UInt8(value & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
    }

    mutating func append(uint32LE value: UInt32) {
        append(UInt8(value & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
        append(UInt8((value >> 16) & 0xFF))
        append(UInt8((value >> 24) & 0xFF))
    }
}
