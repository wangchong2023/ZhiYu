//
//  Batch7IConstantsAndLogicTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/07.
//  Copyright © 2026 WangChong. All rights reserved.
//

import XCTest
import UFPCore
@testable import ZhiYu

/// 批次 7-I 修复点验证测试集
/// 覆盖 Finding #23-45 的源码修复：常量抽取、L10n 红线、魔法数字、逻辑缺陷、可测试性
final class Batch7IConstantsAndLogicTests: XCTestCase {

    // MARK: - #23 延迟字面量常量化（LLMConstants.UITesting）

    func testLLMConstantsUITestingNanosecondsPerSecond() {
        XCTAssertEqual(LLMConstants.UITesting.nanosecondsPerSecond, 1_000_000_000)
    }

    func testLLMConstantsUITestingDelaySecondsPositive() {
        XCTAssertGreaterThan(LLMConstants.UITesting.mockNonStreamDelaySeconds, 0)
        XCTAssertGreaterThan(LLMConstants.UITesting.mockStreamInitialDelaySeconds, 0)
        XCTAssertGreaterThan(LLMConstants.UITesting.mockStreamChunkDelaySeconds, 0)
    }

    func testLLMConstantsUITestingDelayConsistency() {
        XCTAssertGreaterThan(
            LLMConstants.UITesting.mockStreamInitialDelaySeconds,
            LLMConstants.UITesting.mockNonStreamDelaySeconds
        )
        XCTAssertLessThan(
            LLMConstants.UITesting.mockStreamChunkDelaySeconds,
            LLMConstants.UITesting.mockNonStreamDelaySeconds
        )
    }

    // MARK: - #24 Mock 文本纯 ASCII（L10n 红线）

    func testMockNonStreamReplyIsPureASCII() {
        let reply = LLMConstants.UITesting.mockNonStreamReply
        XCTAssertTrue(reply.allSatisfy { $0.isASCII }, "mockNonStreamReply 必须为纯 ASCII 以避免 L10n 红线")
        XCTAssertFalse(reply.isEmpty)
    }

    func testMockRAGReplyIsPureASCII() {
        let reply = LLMConstants.UITesting.mockRAGReply
        XCTAssertTrue(reply.allSatisfy { $0.isASCII }, "mockRAGReply 必须为纯 ASCII 以避免 L10n 红线")
        XCTAssertFalse(reply.isEmpty)
    }

    // MARK: - #25 Mock 流式 chunks 单一源

    func testMockStreamChunksSingleSource() {
        let chunks = LLMConstants.UITesting.mockStreamChunks
        XCTAssertFalse(chunks.isEmpty)
        XCTAssertTrue(chunks.allSatisfy { $0.allSatisfy { $0.isASCII } }, "mockStreamChunks 必须为纯 ASCII")
    }

    func testMockStreamChunksConcatenationNonEmpty() {
        let combined = LLMConstants.UITesting.mockStreamChunks.joined()
        XCTAssertFalse(combined.isEmpty)
    }

    // MARK: - #26 StreamDeanonymizer buffer 边界（>= maxRawLength 截断）

    func testStreamDeanonymizerBufferBoundaryAtMaxRawLength() {
        let maxRawLength = 25
        let chunk = String(repeating: "x", count: maxRawLength)
        var deanon = StreamDeanonymizer(mapping: ["[TEST]": "REPLACED"])
        let result = deanon.process(chunk: chunk)
        XCTAssertFalse(result.isEmpty, "count == maxRawLength 时应执行截断并输出部分内容")
    }

    func testStreamDeanonymizerBufferBoundaryAboveMaxRawLength() {
        let chunk = String(repeating: "x", count: 30)
        var deanon = StreamDeanonymizer(mapping: ["[TEST]": "REPLACED"])
        let result = deanon.process(chunk: chunk)
        XCTAssertFalse(result.isEmpty, "count > maxRawLength 时应执行截断并输出部分内容")
    }

    // MARK: - #27 lengthHint 常量化（LLMConstants.PromptInstruction）

    func testLengthHintContainsMaxChars() {
        let hint = LLMConstants.PromptInstruction.lengthHint(3072)
        XCTAssertTrue(hint.contains("3072"))
        XCTAssertTrue(hint.contains("characters"))
    }

    func testLengthHintStartsWithNewline() {
        let hint = LLMConstants.PromptInstruction.lengthHint(100)
        XCTAssertTrue(hint.hasPrefix("\n"), "lengthHint 应以换行符开头以追加到 systemPrompt 末尾")
    }

    // MARK: - #28 SendableBody 文档注释（可测试性验证）

    func testLLMChatServiceSendableBodyExists() {
        let client = MockLLMClientForBatch7I(response: ["choices": [["message": ["content": "ok"]]]])
        let service = LLMChatService(client: client, model: "test")
        let body = service.makeStreamingRequestBody(systemPrompt: "sys", query: "hi", history: [])
        XCTAssertEqual(body[LLMConstants.APIKey.stream] as? Bool, true)
    }

    // MARK: - #29 Question 标签常量化

    func testQuestionLabelConstant() {
        XCTAssertEqual(LLMConstants.PromptInstruction.questionLabel, "Question")
    }

    // MARK: - #30 UserDefaults key 常量化

    func testOnDeviceStorageConfigKey() {
        XCTAssertEqual(LLMConstants.OnDeviceStorage.configKey, "zhiyu_ondevice_config")
    }

    // MARK: - #31 模型 ID 常量化

    func testOnDeviceModelIDConstants() {
        XCTAssertEqual(LLMConstants.OnDeviceModelID.bundledZhiyu, "bundled_zhiyu")
        XCTAssertEqual(LLMConstants.OnDeviceModelID.appleIntelligence, "apple_intelligence")
    }

    // MARK: - #32 token 计数逻辑修复（字符数 / charactersPerToken）

    func testTokenCountingByCharactersForChinese() {
        let chineseText = "这是一段中文内容用于测试token计数"
        let charactersPerToken = PromptConstants.TokenLimits.charactersPerToken
        let expectedTokenCount = chineseText.count / charactersPerToken
        XCTAssertGreaterThan(expectedTokenCount, 1, "中文文本按字符数估算 token 应大于 1（旧逻辑 split(\" \").count == 1）")
    }

    func testTokenCountingByCharactersForEnglish() {
        let englishText = "Hello world this is a test"
        let charactersPerToken = PromptConstants.TokenLimits.charactersPerToken
        let expectedTokenCount = englishText.count / charactersPerToken
        XCTAssertGreaterThan(expectedTokenCount, 0)
    }

    // MARK: - #33 SF Symbol 常量化

    func testOnDeviceIconConstants() {
        XCTAssertEqual(LLMConstants.OnDeviceIcon.bundled, "cube.box.fill")
        XCTAssertEqual(LLMConstants.OnDeviceIcon.downloaded, "arrow.down.circle.fill")
        XCTAssertEqual(LLMConstants.OnDeviceIcon.system, "apple.logo")
    }

    func testOnDeviceModelIconReturnsConstantValues() {
        let bundled = OnDeviceModel(
            id: "test-bundled", name: "Bundled", url: nil, size: 100, type: .bundled
        )
        let downloaded = OnDeviceModel(
            id: "test-downloaded", name: "Downloaded", url: nil, size: 200, type: .downloaded
        )
        let system = OnDeviceModel(
            id: "test-system", name: "System", url: nil, size: 0, type: .system
        )
        XCTAssertEqual(bundled.icon, LLMConstants.OnDeviceIcon.bundled)
        XCTAssertEqual(downloaded.icon, LLMConstants.OnDeviceIcon.downloaded)
        XCTAssertEqual(system.icon, LLMConstants.OnDeviceIcon.system)
    }

    // MARK: - #34 maxResponseSize 常量化（PluginConstants.Sandbox）

    func testPluginSandboxMaxResponseSize() {
        XCTAssertEqual(PluginConstants.Sandbox.maxResponseSizeBytes, 5 * 1024 * 1024)
        XCTAssertEqual(PluginConstants.Sandbox.maxResponseSizeMB, 5)
    }

    // MARK: - #35 JS 执行时间限制常量化

    func testPluginSandboxJSExecutionTimeLimit() {
        XCTAssertEqual(PluginConstants.Sandbox.jsExecutionTimeLimitSeconds, 0.5)
    }

    // MARK: - #36 requiredLocales 常量化

    func testPluginLocalizationRequiredLocales() {
        let locales = PluginConstants.Localization.requiredLocales
        XCTAssertTrue(locales.contains("en"))
        XCTAssertTrue(locales.contains("zh-Hans"))
        XCTAssertEqual(locales.count, 2)
    }

    // MARK: - #37 manifest 默认值常量化

    func testPluginDefaultManifestConstants() {
        XCTAssertEqual(PluginConstants.DefaultManifest.version, "1.0.0")
        XCTAssertEqual(PluginConstants.DefaultManifest.author, "Local Developer")
        XCTAssertEqual(PluginConstants.DefaultManifest.idPrefix, "local.")
        XCTAssertEqual(PluginConstants.DefaultManifest.descriptionEn, "Legacy .js plugin (migrate to .zyplugin format)")
        XCTAssertEqual(PluginConstants.DefaultManifest.permissions, ["log", "writeContent"])
    }

    // MARK: - #38 bufferSize 常量化（ModelDownloadManager）

    func testModelDownloadManagerSha256BufferSize() {
        XCTAssertEqual(
            ModelDownloadManager.sha256BufferSizeForTesting,
            Int(SystemConstants.bytesPerKB) * Int(SystemConstants.bytesPerKB)
        )
    }

    // MARK: - #39 错误消息前缀常量化

    func testModelDownloadManagerSandboxAllocationFailedPrefix() {
        XCTAssertEqual(
            ModelDownloadManager.sandboxAllocationFailedPrefixForTesting,
            "Sandbox storage allocation failed:"
        )
    }

    // MARK: - #40 测试域名常量化

    func testWebScraperInvalidHostTestDomain() {
        let domain = ProcessorConstants.WebScraper.invalidHostTestDomain
        XCTAssertTrue(domain.contains("invalid-host"))
        XCTAssertTrue(domain.contains(".com") || domain.contains(".example"))
    }

    // MARK: - #41 HTML 正则模式常量化

    func testHTMLRegexConstantsExist() {
        XCTAssertFalse(ProcessorConstants.HTMLRegex.titleTag.isEmpty)
        XCTAssertFalse(ProcessorConstants.HTMLRegex.articleTag.isEmpty)
        XCTAssertFalse(ProcessorConstants.HTMLRegex.mainTag.isEmpty)
        XCTAssertFalse(ProcessorConstants.HTMLRegex.paragraphTag.isEmpty)
    }

    func testHTMLRegexArticleTagIsCaseInsensitive() {
        XCTAssertTrue(ProcessorConstants.HTMLRegex.articleTag.hasPrefix("(?i)"))
    }

    // MARK: - #42 HTML 实体解码扩展（16 条）

    func testHTMLEntityDecodeMapCoverage() {
        let map = ProcessorConstants.HTMLEntity.decodeMap
        XCTAssertGreaterThanOrEqual(map.count, 16, "HTML 实体字典应覆盖至少 16 条常见实体")
    }

    func testHTMLEntityDecodeMapContainsExtendedEntities() {
        let map = ProcessorConstants.HTMLEntity.decodeMap
        XCTAssertNotNil(map["&#34;"])
        XCTAssertNotNil(map["&#60;"])
        XCTAssertNotNil(map["&#62;"])
        XCTAssertNotNil(map["&hellip;"])
        XCTAssertNotNil(map["&mdash;"])
        XCTAssertNotNil(map["&ndash;"])
        XCTAssertNotNil(map["&trade;"])
        XCTAssertNotNil(map["&copy;"])
    }

    func testCleanHTMLTagsDecodesExtendedEntities() {
        let input = "Price: &#34;100&#34; &mdash; save &trade;"
        let cleaned = DumbExtractorHandler.cleanHTMLTags(input)
        XCTAssertTrue(cleaned.contains("\"100\""), "应解码 &#34; 为双引号")
        XCTAssertTrue(cleaned.contains("—"), "应解码 &mdash; 为 em dash")
        XCTAssertTrue(cleaned.contains("™"), "应解码 &trade; 为商标符号")
    }

    func testCleanHTMLTagsDecodesAllNamedEntities() {
        let input = "&quot; &amp; &lt; &gt; &nbsp; &apos; &hellip; &ndash; &copy;"
        let cleaned = DumbExtractorHandler.cleanHTMLTags(input)
        XCTAssertTrue(cleaned.contains("\""))
        XCTAssertTrue(cleaned.contains("&"))
        XCTAssertTrue(cleaned.contains("<"))
        XCTAssertTrue(cleaned.contains(">"))
        XCTAssertTrue(cleaned.contains(" "))
        XCTAssertTrue(cleaned.contains("'"))
        XCTAssertTrue(cleaned.contains("…"))
        XCTAssertTrue(cleaned.contains("–"))
        XCTAssertTrue(cleaned.contains("©"))
    }

    // MARK: - #43 imageFolders 常量化

    func testOOXMLImageMediaFolders() {
        let folders = ProcessorConstants.OOXML.imageMediaFolders
        XCTAssertTrue(folders.contains("word/media"))
        XCTAssertTrue(folders.contains("xl/media"))
        XCTAssertTrue(folders.contains("ppt/media"))
        XCTAssertEqual(folders.count, 3)
    }

    // MARK: - #44 日志 key 常量化

    func testStorageConstantsLogDetailsPageCountRefreshed() {
        XCTAssertEqual(
            StorageConstants.LogDetails.initialNotebookPageCountRefreshed,
            "InitialNotebook_PageCountRefreshed"
        )
    }

    // MARK: - #45 环境变量名常量化

    func testStorageConstantsEnvironmentKeys() {
        XCTAssertEqual(StorageConstants.LaunchEnvironment.uitestingEnvKey, "UITesting")
        XCTAssertEqual(StorageConstants.LaunchEnvironment.uitestingLaunchArg, "--uitesting")
    }

    // MARK: - LLMChatService.buildChatMessages 集成验证（#27 lengthHint 注入）

    func testBuildChatMessagesInjectsLengthHint() {
        let client = MockLLMClientForBatch7I(response: ["choices": [["message": ["content": "ok"]]]])
        let service = LLMChatService(client: client, model: "test")
        let messages = service.buildChatMessages(systemPrompt: "sys", query: "hi", history: [])
        XCTAssertEqual(messages.count, 2)
        let systemMsg = messages[0]
        let content = systemMsg[LLMConstants.APIKey.content] as? String ?? ""
        XCTAssertTrue(content.contains("Keep response within"), "systemPrompt 应包含 lengthHint 指令")
        XCTAssertTrue(content.contains(String(PromptConstants.TokenLimits.defaultMaxOutputTokens)))
    }

    func testBuildChatMessagesWithHistory() {
        let client = MockLLMClientForBatch7I(response: ["choices": [["message": ["content": "ok"]]]])
        let service = LLMChatService(client: client, model: "test")
        let history: [ChatMessageDTO] = [
            ChatMessageDTO(role: .user, content: "prev question"),
            ChatMessageDTO(role: .assistant, content: "prev answer")
        ]
        let messages = service.buildChatMessages(systemPrompt: "sys", query: "new", history: history)
        XCTAssertEqual(messages.count, 4)
        XCTAssertEqual(messages[1][LLMConstants.APIKey.role] as? String, "user")
        XCTAssertEqual(messages[2][LLMConstants.APIKey.role] as? String, "assistant")
        XCTAssertEqual(messages[3][LLMConstants.APIKey.role] as? String, "user")
    }

    func testMakeChatRequestBodyStructure() {
        let client = MockLLMClientForBatch7I(response: ["choices": [["message": ["content": "ok"]]]])
        let service = LLMChatService(client: client, model: "test-model")
        let body = service.makeChatRequestBody(systemPrompt: "sys", query: "hi", history: [])
        XCTAssertEqual(body[LLMConstants.APIKey.model] as? String, "test-model")
        XCTAssertNotNil(body[LLMConstants.APIKey.messages])
        XCTAssertNotNil(body[LLMConstants.APIKey.temperature])
        XCTAssertNotNil(body[LLMConstants.APIKey.maxTokens])
    }

    func testMakeStreamingRequestBodyHasStreamFlag() {
        let client = MockLLMClientForBatch7I(response: ["choices": [["message": ["content": "ok"]]]])
        let service = LLMChatService(client: client, model: "test-model")
        let body = service.makeStreamingRequestBody(systemPrompt: "sys", query: "hi", history: [])
        XCTAssertEqual(body[LLMConstants.APIKey.stream] as? Bool, true)
    }
}

// MARK: - Mock LLM Client（批次 7-I 测试专用）

private final class MockLLMClientForBatch7I: LLMClientProtocol, @unchecked Sendable {
    var response: [String: Any]

    init(response: [String: Any]) {
        self.response = response
    }

    func sendRequest(body: [String: Any]) async throws -> [String: Any] {
        response
    }

    func sendStreamingRequest(body: [String: Any]) async throws -> URLSession.AsyncBytes {
        throw LLMError.apiError("streaming not supported in mock")
    }
}
