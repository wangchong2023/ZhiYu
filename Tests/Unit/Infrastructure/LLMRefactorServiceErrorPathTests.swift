//
//  LLMRefactorServiceErrorPathTests.swift
//  ZhiYu
//
//  系统层级：[Shared] 测试层
//  核心职责：验证 LLMRefactorService 的错误路径与边界条件。
//

import XCTest
@testable import ZhiYu

final class LLMRefactorServiceErrorPathTests: XCTestCase {

    private var mockClient: MockLLMClient!

    override func setUp() async throws {
        try await super.setUp()
        mockClient = MockLLMClient()
    }

    override func tearDown() async throws {
        mockClient = nil
        try await super.tearDown()
    }

    // MARK: - discoverPotentialLinks 错误路径

    func testDiscoverLinksPropagatesClientError() async {
        mockClient.mockError = LLMError.unauthorized
        let service = LLMRefactorService(client: mockClient, model: "test")
        do {
            _ = try await service.discoverPotentialLinks(content: "C", existingTitles: [])
            XCTFail("应抛出 unauthorized 错误")
        } catch LLMError.unauthorized {
            // 预期路径
        } catch {
            XCTFail("应抛出 LLMError.unauthorized，实际：\(error)")
        }
    }

    func testDiscoverLinksEmptyResponseReturnsEmpty() async {
        mockClient.mockResponse = [:]
        let service = LLMRefactorService(client: mockClient, model: "test")
        let links = try? await service.discoverPotentialLinks(content: "C", existingTitles: [])
        XCTAssertEqual(links ?? [], [], "空响应应返回空数组")
    }

    func testDiscoverLinksInvalidJSONReturnsEmpty() async {
        mockClient.mockResponse = [
            "choices": [["message": ["content": "not json"]]]
        ]
        let service = LLMRefactorService(client: mockClient, model: "test")
        let links = try? await service.discoverPotentialLinks(content: "C", existingTitles: [])
        XCTAssertEqual(links ?? [], [], "无效 JSON 应返回空数组")
    }

    func testDiscoverLinksMarkdownWrappedJSON() async throws {
        mockClient.mockResponse = [
            "choices": [["message": ["content": "```json\n[\"Link1\", \"Link2\"]\n```"]]]
        ]
        let service = LLMRefactorService(client: mockClient, model: "test")
        let links = try await service.discoverPotentialLinks(content: "C", existingTitles: [])
        XCTAssertEqual(links, ["Link1", "Link2"], "应解析 Markdown 包裹的 JSON 数组")
    }

    func testDiscoverLinksEmptyArray() async throws {
        mockClient.mockResponse = [
            "choices": [["message": ["content": "[]"]]]
        ]
        let service = LLMRefactorService(client: mockClient, model: "test")
        let links = try await service.discoverPotentialLinks(content: "C", existingTitles: [])
        XCTAssertEqual(links, [], "空数组应返回空数组")
    }

    // MARK: - foldContent 错误路径

    func testFoldContentPropagatesClientError() async {
        mockClient.mockError = LLMError.apiError("test error")
        let service = LLMRefactorService(client: mockClient, model: "test")
        do {
            _ = try await service.foldContent(existingContent: "A", newContent: "B", title: "T")
            XCTFail("应抛出 apiError 错误")
        } catch LLMError.apiError {
            // 预期路径
        } catch {
            XCTFail("应抛出 LLMError.apiError，实际：\(error)")
        }
    }

    func testFoldContentEmptyResponseReturnsConcatenation() async {
        mockClient.mockResponse = [:]
        let service = LLMRefactorService(client: mockClient, model: "test")
        let result = try? await service.foldContent(existingContent: "已有", newContent: "新增", title: "T")
        XCTAssertEqual(result, "已有\n\n新增", "空响应时应返回 existing + newContent 拼接")
    }

    func testFoldContentValidResponse() async throws {
        mockClient.mockResponse = [
            "choices": [["message": ["content": "合并后的内容"]]]
        ]
        let service = LLMRefactorService(client: mockClient, model: "test")
        let result = try await service.foldContent(existingContent: "A", newContent: "B", title: "T")
        XCTAssertEqual(result, "合并后的内容", "应返回 AI 合并后的内容")
    }

    // MARK: - analyzeForRefactoring 错误路径

    func testAnalyzeForRefactoringPropagatesClientError() async {
        mockClient.mockError = LLMError.rateLimited
        let service = LLMRefactorService(client: mockClient, model: "test")
        do {
            _ = try await service.analyzeForRefactoring(pages: [])
            XCTFail("应抛出 rateLimited 错误")
        } catch LLMError.rateLimited {
            // 预期路径
        } catch {
            XCTFail("应抛出 LLMError.rateLimited，实际：\(error)")
        }
    }

    func testAnalyzeForRefactoringEmptyResponseReturnsEmpty() async {
        mockClient.mockResponse = [:]
        let service = LLMRefactorService(client: mockClient, model: "test")
        let suggestions = try? await service.analyzeForRefactoring(pages: [])
        XCTAssertEqual(suggestions?.count ?? 0, 0, "空响应应返回空数组")
    }

    func testAnalyzeForRefactoringInvalidJSONReturnsEmpty() async {
        mockClient.mockResponse = [
            "choices": [["message": ["content": "not json"]]]
        ]
        let service = LLMRefactorService(client: mockClient, model: "test")
        let suggestions = try? await service.analyzeForRefactoring(pages: [])
        XCTAssertEqual(suggestions?.count ?? 0, 0, "无效 JSON 应返回空数组")
    }

    func testAnalyzeForRefactoringValidResponse() async throws {
        let jsonResponse = """
        [
            {
                "type": "merge",
                "target": "PageA",
                "reason": "duplicate",
                "suggestion": "merge into PageB"
            }
        ]
        """
        mockClient.mockResponse = [
            "choices": [["message": ["content": jsonResponse]]]
        ]
        let service = LLMRefactorService(client: mockClient, model: "test")
        let suggestions = try await service.analyzeForRefactoring(pages: [])
        XCTAssertEqual(suggestions.count, 1, "应解析 1 条重构建议")
        XCTAssertEqual(suggestions.first?.type, "merge")
        XCTAssertEqual(suggestions.first?.target, "PageA")
    }

    // MARK: - 请求体结构验证

    func testDiscoverLinksSendsCorrectModel() async throws {
        mockClient.mockResponse = [
            "choices": [["message": ["content": "[]"]]]
        ]
        let service = LLMRefactorService(client: mockClient, model: "my-model")
        _ = try await service.discoverPotentialLinks(content: "C", existingTitles: [])
        XCTAssertEqual(mockClient.lastBody?["model"] as? String, "my-model", "应使用传入的 model 名称")
    }

    func testFoldContentSendsMessagesArray() async throws {
        mockClient.mockResponse = [
            "choices": [["message": ["content": "result"]]]
        ]
        let service = LLMRefactorService(client: mockClient, model: "my-model")
        _ = try await service.foldContent(existingContent: "A", newContent: "B", title: "T")
        let messages = mockClient.lastBody?["messages"] as? [[String: Any]]
        XCTAssertNotNil(messages, "请求体应包含 messages 数组")
        XCTAssertEqual(messages?.first?["role"] as? String, "user")
    }
}
