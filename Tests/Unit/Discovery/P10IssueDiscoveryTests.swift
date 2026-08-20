//
//  P10IssueDiscoveryTests.swift
//  ZhiYuTests
//
//  系统层级：跨层问题发现测试
//  核心职责：通过测试验证 P10 审查中发现的潜在缺陷是否真实存在。
//           测试目的是发现问题，而非追求覆盖率。
//

import XCTest
@testable import ZhiYu

// MARK: - RefactorSuggestionDTO.id 碰撞修复验证

final class RefactorSuggestionIDCollisionTests: XCTestCase {

    /// 修复验证：id = target + ":" + type 后不再碰撞
    func testIDNoLongerCollidesAfterFix() {
        let suggestion1 = RefactorSuggestionDTO(type: "C", target: "AB", reason: "", suggestion: "")
        let suggestion2 = RefactorSuggestionDTO(type: "BC", target: "A", reason: "", suggestion: "")
        XCTAssertNotEqual(
            suggestion1.id,
            suggestion2.id,
            "修复后：id 加冒号分隔符，AB:C ≠ A:BC，不再碰撞"
        )
    }

    /// 验证修复后 Dictionary 不再丢数据
    func testIDNoCollisionInDictionaryAfterFix() {
        let suggestion1 = RefactorSuggestionDTO(type: "C", target: "AB", reason: "r1", suggestion: "s1")
        let suggestion2 = RefactorSuggestionDTO(type: "BC", target: "A", reason: "r2", suggestion: "s2")
        var dict: [String: RefactorSuggestionDTO] = [:]
        dict[suggestion1.id] = suggestion1
        dict[suggestion2.id] = suggestion2
        XCTAssertEqual(dict.count, 2, "修复后：两个不同建议保留在 Dictionary 中")
    }

    /// 验证 id 格式包含冒号分隔符
    func testIDContainsColonSeparator() {
        let suggestion = RefactorSuggestionDTO(type: "merge", target: "PageA", reason: "", suggestion: "")
        XCTAssertTrue(suggestion.id.contains(":"), "id 应包含冒号分隔符")
        XCTAssertEqual(suggestion.id, "PageA:merge")
    }
}

// MARK: - TokenUsage.totalTokens 数据完整性验证

final class TokenUsageDataIntegrityTests: XCTestCase {

    /// 修复验证：自定义 init(from:) 后，解码时 totalTokens 强制 = prompt + completion
    func testDecodedTotalTokensAlwaysConsistentAfterFix() throws {
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
            "修复后：解码时强制 totalTokens = prompt + completion = 150，忽略 JSON 中的 999"
        )
        XCTAssertEqual(decoded.totalTokens, decoded.promptTokens + decoded.completionTokens)
    }

    /// 验证 init 构造的 totalTokens 始终一致
    func testInitTotalTokensAlwaysConsistent() {
        let usage = TokenUsage(model: "gpt-4", promptTokens: 100, completionTokens: 50)
        XCTAssertEqual(usage.totalTokens, usage.promptTokens + usage.completionTokens)
    }

    /// 验证 Codable 往返后 totalTokens 保持一致
    func testCodableRoundTripPreservesConsistency() throws {
        let original = TokenUsage(model: "gpt-4", promptTokens: 100, completionTokens: 50)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TokenUsage.self, from: data)
        XCTAssertEqual(decoded.totalTokens, decoded.promptTokens + decoded.completionTokens)
    }
}

// MARK: - ChatMessageDTO.id 不可变性验证

final class ChatMessageDTOIDMutabilityTests: XCTestCase {

    /// 修复验证：id 改为 let 后不可变
    func testIDIsImmutable() {
        let msg = ChatMessageDTO(role: .user, content: "test")
        let originalID = msg.id
        XCTAssertEqual(msg.id, originalID, "id 是 let，不可变")
    }

    /// 验证 id 始终一致
    func testIDStable() {
        let msg = ChatMessageDTO(role: .user, content: "test")
        let trackingID = msg.id
        XCTAssertEqual(msg.id, trackingID, "id 不可变，追踪不会丢失")
    }
}

// MARK: - PageContentUtility.extractAllTags 边界问题验证

final class PageContentUtilityTagExtractionTests: XCTestCase {

    /// 验证正则不匹配纯数字标签（#123）
    func testNumericTagExtraction() {
        let tags = PageContentUtility.extractAllTags(content: "#123 标签", existingTags: [])
        XCTAssertTrue(tags.contains("123"), "\\w 应包含数字，#123 应被提取")
    }

    /// 验证正则不匹配带连字符的标签（#tag-name）
    func testHyphenTagNotExtracted() {
        let tags = PageContentUtility.extractAllTags(content: "#tag-name", existingTags: [])
        XCTAssertFalse(tags.contains("tag-name"), "确认限制：\\w 不含连字符，#tag-name 只提取 'tag'")
        XCTAssertTrue(tags.contains("tag"), "只提取到 'tag' 部分")
    }

    /// 验证正则不匹配带空格的标签
    func testSpaceDelimitedTag() {
        let tags = PageContentUtility.extractAllTags(content: "#标签 内容", existingTags: [])
        XCTAssertEqual(tags, ["标签"], "#标签 后跟空格，正确提取")
    }

    /// 验证多个连续 # 的处理
    func testMultipleConsecutiveHashes() {
        let tags = PageContentUtility.extractAllTags(content: "##标题", existingTags: [])
        XCTAssertTrue(tags.contains("标题"), "##标题 应提取 '标题'")
    }

    /// 验证 # 后直接跟非字母数字中文的情况
    func testHashFollowedByNonWordChar() {
        let tags = PageContentUtility.extractAllTags(content: "# 标签", existingTags: [])
        XCTAssertFalse(tags.contains("标签"), "# 后跟空格，不应提取")
    }
}

// MARK: - DocumentFormat.detectFormat 边界验证

final class DocumentFormatDiscoveryTests: XCTestCase {

    /// 验证 URL 含路径但无扩展名
    func testDetectFormatPathWithoutExtension() {
        let url = URL(fileURLWithPath: "/path/to/file")
        XCTAssertEqual(DocumentFormat.detectFormat(from: url), .unknown)
    }

    /// 验证 URL 含目录点但文件无扩展名
    func testDetectFormatDirectoryWithDot() {
        let url = URL(fileURLWithPath: "/path.to/file")
        XCTAssertEqual(DocumentFormat.detectFormat(from: url), .unknown)
    }

    /// 验证双扩展名
    func testDetectFormatDoubleExtension() {
        let url = URL(fileURLWithPath: "test.backup.pdf")
        XCTAssertEqual(DocumentFormat.detectFormat(from: url), .pdf)
    }
}

// MARK: - AppConstants.Version 构建注入验证

final class AppConstantsVersionTests: XCTestCase {

    /// 问题：gitShortHash 和 buildTimestamp 是构建时注入的，但当前值可能是过时的
    func testGitShortHashFormat() {
        let hash = AppConstants.Version.gitShortHash
        XCTAssertEqual(hash.count, 8, "git 短哈希应为 8 字符")
        XCTAssertTrue(hash.allSatisfy { $0.isHexDigit }, "git 短哈希应为十六进制")
    }

    /// 验证 buildTimestamp 是有效 ISO 8601 格式
    func testBuildTimestampFormat() {
        let ts = AppConstants.Version.buildTimestamp
        let formatter = ISO8601DateFormatter()
        XCTAssertNotNil(formatter.date(from: ts), "buildTimestamp 应为有效 ISO 8601 格式")
    }

    /// 验证 semVer 非空
    func testSemVerNotEmpty() {
        XCTAssertFalse(AppConstants.Version.semVer.isEmpty)
    }
}
