//
//  DomainDTOsTests.swift
//  ZhiYuTests
//
//  系统层级：[L1.5] 领域层测试
//  核心职责：验证 Domain/Protocols/DTOs.swift 中 DTO 的 Codable 编解码往返、
//           Identifiable 计算、ChatRole 枚举完整性。
//

import XCTest
@testable import ZhiYu

// MARK: - ChatMessageDTO 单元测试

final class ChatMessageDTOTests: XCTestCase {

    /// 验证 ChatMessageDTO init 含默认值
    func testChatMessageDTOInitWithDefaults() {
        let msg = ChatMessageDTO(role: .user, content: "你好")
        XCTAssertEqual(msg.role, .user)
        XCTAssertEqual(msg.content, "你好")
        XCTAssertNotNil(msg.id)
        XCTAssertNotNil(msg.timestamp)
        XCTAssertTrue(msg.relatedPageIDs.isEmpty)
    }

    /// 验证 ChatMessageDTO 带全部参数 init
    func testChatMessageDTOInitWithAllParameters() {
        let id = UUID()
        let date = Date()
        let relatedIDs = [UUID(), UUID()]
        let msg = ChatMessageDTO(
            id: id,
            role: .assistant,
            content: "回复",
            timestamp: date,
            relatedPageIDs: relatedIDs
        )
        XCTAssertEqual(msg.id, id)
        XCTAssertEqual(msg.role, .assistant)
        XCTAssertEqual(msg.timestamp, date)
        XCTAssertEqual(msg.relatedPageIDs, relatedIDs)
    }

    /// 验证 ChatRole 所有 case
    func testChatRoleAllCases() {
        let allRoles: [ChatMessageDTO.ChatRole] = [.user, .assistant, .system]
        XCTAssertEqual(allRoles.count, 3)
    }

    /// 验证 ChatRole rawValue
    func testChatRoleRawValues() {
        XCTAssertEqual(ChatMessageDTO.ChatRole.user.rawValue, "user")
        XCTAssertEqual(ChatMessageDTO.ChatRole.assistant.rawValue, "assistant")
        XCTAssertEqual(ChatMessageDTO.ChatRole.system.rawValue, "system")
    }

    /// 验证 ChatMessageDTO Codable 往返
    func testChatMessageDTOCodableRoundTrip() throws {
        let original = ChatMessageDTO(
            role: .system,
            content: "系统消息",
            relatedPageIDs: [UUID()]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ChatMessageDTO.self, from: data)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.role, original.role)
        XCTAssertEqual(decoded.content, original.content)
        XCTAssertEqual(decoded.relatedPageIDs, original.relatedPageIDs)
    }

    /// 验证 ChatMessage Identifiable
    func testChatMessageIdentifiable() {
        let msg = ChatMessageDTO(role: .user, content: "test")
        XCTAssertFalse(msg.id.uuidString.isEmpty)
    }

    /// 验证 ChatMessage typealias 等价
    func testChatMessageTypealias() {
        let msg: ChatMessage = ChatMessageDTO(role: .user, content: "x")
        XCTAssertEqual(msg.content, "x")
    }
}

// MARK: - SmartIngestResultDTO 单元测试

final class SmartIngestResultDTOTests: XCTestCase {

    /// 验证 SmartIngestResultDTO init
    func testSmartIngestResultDTOInit() {
        let result = SmartIngestResultDTO(
            title: "标题",
            compiledContent: "内容",
            suggestedTags: ["tag1"],
            suggestedType: "concept",
            relatedTitles: ["相关"],
            summary: "摘要"
        )
        XCTAssertEqual(result.title, "标题")
        XCTAssertEqual(result.compiledContent, "内容")
        XCTAssertEqual(result.suggestedTags, ["tag1"])
        XCTAssertEqual(result.suggestedType, "concept")
        XCTAssertEqual(result.relatedTitles, ["相关"])
        XCTAssertEqual(result.summary, "摘要")
    }

    /// 验证 SmartIngestResultDTO title 为 nil
    func testSmartIngestResultDTONilTitle() {
        let result = SmartIngestResultDTO(
            title: nil,
            compiledContent: "",
            suggestedTags: [],
            suggestedType: "raw",
            relatedTitles: [],
            summary: ""
        )
        XCTAssertNil(result.title)
    }

    /// 验证 SmartIngestResultDTO Codable 往返（含 snake_case 映射）
    func testSmartIngestResultDTOCodableRoundTrip() throws {
        let original = SmartIngestResultDTO(
            title: "测试",
            compiledContent: "编译内容",
            suggestedTags: ["a", "b"],
            suggestedType: "entity",
            relatedTitles: ["x"],
            summary: "摘要"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SmartIngestResultDTO.self, from: data)
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.compiledContent, original.compiledContent)
        XCTAssertEqual(decoded.suggestedTags, original.suggestedTags)
        XCTAssertEqual(decoded.suggestedType, original.suggestedType)
        XCTAssertEqual(decoded.relatedTitles, original.relatedTitles)
        XCTAssertEqual(decoded.summary, original.summary)
    }

    /// 验证 SmartIngestResultDTO 从 JSON 解码（snake_case key）
    func testSmartIngestResultDTODecodeFromSnakeCaseJSON() throws {
        let json = """
        {
            "title": "标题",
            "compiled_content": "内容",
            "suggested_tags": ["t1"],
            "suggested_type": "concept",
            "related_titles": ["r1"],
            "summary": "摘要"
        }
        """
        guard let jsonData = json.data(using: .utf8) else {
            XCTFail("JSON 字符串转 Data 失败")
            return
        }
        let decoded = try JSONDecoder().decode(SmartIngestResultDTO.self, from: jsonData)
        XCTAssertEqual(decoded.compiledContent, "内容")
        XCTAssertEqual(decoded.suggestedTags, ["t1"])
        XCTAssertEqual(decoded.relatedTitles, ["r1"])
    }
}

// MARK: - RefactorSuggestionDTO 单元测试

final class RefactorSuggestionDTOTests: XCTestCase {

    /// 验证 RefactorSuggestionDTO init
    func testRefactorSuggestionDTOInit() {
        let suggestion = RefactorSuggestionDTO(
            type: "merge",
            target: "页面A",
            reason: "内容重复",
            suggestion: "合并到页面B"
        )
        XCTAssertEqual(suggestion.type, "merge")
        XCTAssertEqual(suggestion.target, "页面A")
        XCTAssertEqual(suggestion.reason, "内容重复")
        XCTAssertEqual(suggestion.suggestion, "合并到页面B")
    }

    /// 验证 RefactorSuggestionDTO Identifiable（id = target + ":" + type）
    func testRefactorSuggestionDTOIdentifiable() {
        let suggestion = RefactorSuggestionDTO(
            type: "split",
            target: "页面X",
            reason: "",
            suggestion: ""
        )
        XCTAssertEqual(suggestion.id, "页面X:split")
    }

    /// 验证 RefactorSuggestionDTO Codable 往返
    func testRefactorSuggestionDTOCodableRoundTrip() throws {
        let original = RefactorSuggestionDTO(
            type: "rename",
            target: "旧名",
            reason: "名称不清晰",
            suggestion: "新名"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RefactorSuggestionDTO.self, from: data)
        XCTAssertEqual(decoded.type, original.type)
        XCTAssertEqual(decoded.target, original.target)
        XCTAssertEqual(decoded.reason, original.reason)
        XCTAssertEqual(decoded.suggestion, original.suggestion)
        XCTAssertEqual(decoded.id, original.id)
    }

    /// 验证不同 type/target 组合产生不同 id
    func testRefactorSuggestionDTODifferentIDs() {
        let suggestionA = RefactorSuggestionDTO(type: "merge", target: "A", reason: "", suggestion: "")
        let suggestionB = RefactorSuggestionDTO(type: "split", target: "A", reason: "", suggestion: "")
        let suggestionC = RefactorSuggestionDTO(type: "merge", target: "B", reason: "", suggestion: "")
        XCTAssertNotEqual(suggestionA.id, suggestionB.id)
        XCTAssertNotEqual(suggestionA.id, suggestionC.id)
        XCTAssertNotEqual(suggestionB.id, suggestionC.id)
    }
}
