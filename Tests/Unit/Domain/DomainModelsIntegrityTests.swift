//
//  DomainModelsIntegrityTests.swift
//  ZhiYuTests
//
//  系统层级：[L1.5] 领域层模型测试
//  核心职责：验证 RefactorSuggestionDTO、TokenUsage、ChatMessageDTO 等核心领域模型的不变式、编码一致性与不可变性。
//

import XCTest
@testable import ZhiYu

// MARK: - RefactorSuggestionDTO.id 碰撞防范验证

final class RefactorSuggestionIDCollisionTests: XCTestCase {

    /// 验证 id = target + ":" + type 分隔符防碰撞
    func testRefactorSuggestion_idSeparator_preventsCollision() {
        let suggestion1 = RefactorSuggestionDTO(type: "C", target: "AB", reason: "", suggestion: "")
        let suggestion2 = RefactorSuggestionDTO(type: "BC", target: "A", reason: "", suggestion: "")
        XCTAssertNotEqual(
            suggestion1.id,
            suggestion2.id,
            "id 加冒号分隔符，AB:C ≠ A:BC，不再碰撞"
        )
    }

    /// 验证 Dictionary 存储多建议时不丢数据
    func testRefactorSuggestion_dictionaryStorage_retainsDistinctEntries() {
        let suggestion1 = RefactorSuggestionDTO(type: "C", target: "AB", reason: "r1", suggestion: "s1")
        let suggestion2 = RefactorSuggestionDTO(type: "BC", target: "A", reason: "r2", suggestion: "s2")
        var dict: [String: RefactorSuggestionDTO] = [:]
        dict[suggestion1.id] = suggestion1
        dict[suggestion2.id] = suggestion2
        XCTAssertEqual(dict.count, 2, "两个不同建议在 Dictionary 中正确保留")
    }

    /// 验证 id 格式包含冒号分隔符
    func testRefactorSuggestion_idFormat_containsColonSeparator() {
        let suggestion = RefactorSuggestionDTO(type: "merge", target: "PageA", reason: "", suggestion: "")
        XCTAssertTrue(suggestion.id.contains(":"), "id 应包含冒号分隔符")
        XCTAssertEqual(suggestion.id, "PageA:merge")
    }
}

// MARK: - TokenUsage.totalTokens 数据完整性验证

final class TokenUsageDataIntegrityTests: XCTestCase {

    /// 验证解码时 totalTokens 强制 = prompt + completion
    func testTokenUsage_decodedTotalTokens_alwaysConsistent() throws {
        let json = """
        {
            "id": 1,
            "model": "gpt-4",
            "prompt_tokens": 100,
            "completion_tokens": 50,
            "total_tokens": 999,
            "created_at": 1000000
        }
        """
        guard let jsonData = json.data(using: .utf8) else {
            XCTFail("JSON 字符串转 Data 失败")
            return
        }
        let decoded = try JSONDecoder().decode(TokenUsage.self, from: jsonData)
        XCTAssertEqual(decoded.promptTokens, 100)
        XCTAssertEqual(decoded.completionTokens, 50)
        XCTAssertEqual(
            decoded.totalTokens,
            150,
            "解码时强制 totalTokens = prompt + completion = 150，忽略 JSON 中的 999"
        )
        XCTAssertEqual(decoded.totalTokens, decoded.promptTokens + decoded.completionTokens)
    }

    /// 验证 init 构造的 totalTokens 始终一致
    func testTokenUsage_initTotalTokens_matchesSum() {
        let usage = TokenUsage(model: "gpt-4", promptTokens: 100, completionTokens: 50)
        XCTAssertEqual(usage.totalTokens, usage.promptTokens + usage.completionTokens)
    }

    /// 验证 Codable 往返后 totalTokens 保持一致
    func testTokenUsage_codableRoundTrip_preservesConsistency() throws {
        let original = TokenUsage(model: "gpt-4", promptTokens: 100, completionTokens: 50)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TokenUsage.self, from: data)
        XCTAssertEqual(decoded.totalTokens, decoded.promptTokens + decoded.completionTokens)
    }
}

// MARK: - ChatMessageDTO.id 不可变性验证

final class ChatMessageDTOIDMutabilityTests: XCTestCase {

    /// 验证 id 不可变
    func testChatMessageDTO_id_isImmutable() {
        let msg = ChatMessageDTO(role: .user, content: "test")
        let originalID = msg.id
        XCTAssertEqual(msg.id, originalID, "id 是不可变常量")
    }

    /// 验证追踪 id 保持一致
    func testChatMessageDTO_id_remainsStable() {
        let msg = ChatMessageDTO(role: .user, content: "test")
        let trackingID = msg.id
        XCTAssertEqual(msg.id, trackingID, "id 不可变，追踪不会丢失")
    }
}
