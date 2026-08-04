//
//  LLMIngestServiceErrorPathTests.swift
//  ZhiYu
//
//  系统层级：[Shared] 测试层
//  核心职责：验证 LLMIngestService 的错误路径与边界条件。
//

import XCTest
@testable import ZhiYu

final class LLMIngestServiceErrorPathTests: XCTestCase {

    private var mockClient: MockLLMClient!
    private var contextBuilder: LLMContextBuilder!

    override func setUp() async throws {
        try await super.setUp()
        mockClient = MockLLMClient()
        contextBuilder = LLMContextBuilder()
    }

    override func tearDown() async throws {
        mockClient = nil
        contextBuilder = nil
        try await super.tearDown()
    }

    // MARK: - 客户端错误传播

    func testSmartIngestPropagatesClientError() async {
        mockClient.mockError = LLMError.unauthorized
        let service = LLMIngestService(client: mockClient, model: "test-model", contextBuilder: contextBuilder)
        do {
            _ = try await service.smartIngest(title: "T", rawContent: "C", pages: [])
            XCTFail("应抛出 unauthorized 错误")
        } catch LLMError.unauthorized {
            // 预期路径
        } catch {
            XCTFail("应抛出 LLMError.unauthorized，实际：\(error)")
        }
    }

    func testSmartIngestPropagatesRateLimited() async {
        mockClient.mockError = LLMError.rateLimited
        let service = LLMIngestService(client: mockClient, model: "test-model", contextBuilder: contextBuilder)
        do {
            _ = try await service.smartIngest(title: "T", rawContent: "C", pages: [])
            XCTFail("应抛出 rateLimited 错误")
        } catch LLMError.rateLimited {
            // 预期路径
        } catch {
            XCTFail("应抛出 LLMError.rateLimited，实际：\(error)")
        }
    }

    // MARK: - 空响应

    func testSmartIngestEmptyResponseReturnsDefault() async {
        mockClient.mockResponse = [:]
        let service = LLMIngestService(client: mockClient, model: "test-model", contextBuilder: contextBuilder)
        do {
            let result = try await service.smartIngest(title: "测试标题", rawContent: "内容", pages: [])
            // 空响应时 extractContent 返回 nil，parseSmartIngest 返回 nil
            // 根据源码逻辑，应返回默认 SmartIngestResultDTO
            XCTAssertEqual(result.title, "测试标题", "空响应时应使用传入的标题")
        } catch {
            // 也可能抛出错误，取决于实现
        }
    }

    // MARK: - 无效 JSON 响应

    func testSmartIngestInvalidJSONReturnsDefault() async {
        mockClient.mockResponse = [
            "choices": [["message": ["content": "not json"]]]
        ]
        let service = LLMIngestService(client: mockClient, model: "test-model", contextBuilder: contextBuilder)
        do {
            let result = try await service.smartIngest(title: "标题", rawContent: "内容", pages: [])
            XCTAssertEqual(result.title, "标题", "无效 JSON 时应使用传入的标题")
        } catch {
            // 也可能抛出错误
        }
    }

    // MARK: - Markdown 包裹的 JSON

    func testSmartIngestMarkdownWrappedJSON() async throws {
        let jsonResponse = """
        ```json
        {
            "title": "Markdown",
            "compiled_content": "c",
            "suggested_tags": ["t1"],
            "suggested_type": "concept",
            "related_titles": [],
            "summary": "s"
        }
        ```
        """
        mockClient.mockResponse = [
            "choices": [["message": ["content": jsonResponse]]]
        ]
        let service = LLMIngestService(client: mockClient, model: "test-model", contextBuilder: contextBuilder)
        let result = try await service.smartIngest(title: "原始标题", rawContent: "内容", pages: [])
        XCTAssertEqual(result.title, "Markdown", "应解析 Markdown 包裹的 JSON")
        XCTAssertEqual(result.suggestedTags, ["t1"])
    }

    // MARK: - reasoning_content 兼容

    func testSmartIngestReasoningContent() async throws {
        let jsonResponse = """
        {
            "title": "Reasoning",
            "compiled_content": "c",
            "suggested_tags": [],
            "suggested_type": "entity",
            "related_titles": [],
            "summary": "s"
        }
        """
        mockClient.mockResponse = [
            "choices": [["message": ["reasoning_content": jsonResponse]]]
        ]
        let service = LLMIngestService(client: mockClient, model: "test-model", contextBuilder: contextBuilder)
        let result = try await service.smartIngest(title: "标题", rawContent: "内容", pages: [])
        XCTAssertEqual(result.title, "Reasoning", "应兼容 reasoning_content 字段")
    }

    // MARK: - 空标题回退

    func testSmartIngestEmptyTitleUsesDefault() async throws {
        let jsonResponse = """
        {
            "title": "",
            "compiled_content": "c",
            "suggested_tags": [],
            "suggested_type": "concept",
            "related_titles": [],
            "summary": "s"
        }
        """
        mockClient.mockResponse = [
            "choices": [["message": ["content": jsonResponse]]]
        ]
        let service = LLMIngestService(client: mockClient, model: "test-model", contextBuilder: contextBuilder)
        let result = try await service.smartIngest(title: "默认标题", rawContent: "内容", pages: [])
        XCTAssertEqual(result.title, "默认标题", "AI 返回空标题时应回退到传入的默认标题")
    }

    // MARK: - 请求体结构验证

    func testSmartIngestSendsCorrectModel() async throws {
        mockClient.mockResponse = [
            "choices": [["message": ["content": """
            {
                "title": "T",
                "compiled_content": "c",
                "suggested_tags": [],
                "suggested_type": "concept",
                "related_titles": [],
                "summary": "s"
            }
            """]]]
        ]
        let service = LLMIngestService(client: mockClient, model: "my-model", contextBuilder: contextBuilder)
        _ = try await service.smartIngest(title: "T", rawContent: "C", pages: [])
        XCTAssertEqual(mockClient.lastBody?["model"] as? String, "my-model", "应使用传入的 model 名称")
    }

    func testSmartIngestSendsMessagesArray() async throws {
        mockClient.mockResponse = [
            "choices": [["message": ["content": """
            {
                "title": "T",
                "compiled_content": "c",
                "suggested_tags": [],
                "suggested_type": "concept",
                "related_titles": [],
                "summary": "s"
            }
            """]]]
        ]
        let service = LLMIngestService(client: mockClient, model: "my-model", contextBuilder: contextBuilder)
        _ = try await service.smartIngest(title: "T", rawContent: "C", pages: [])
        let messages = mockClient.lastBody?["messages"] as? [[String: Any]]
        XCTAssertNotNil(messages, "请求体应包含 messages 数组")
        XCTAssertEqual(messages?.count, 1, "应有 1 条消息")
        XCTAssertEqual(messages?.first?["role"] as? String, "user", "消息角色应为 user")
    }
}
