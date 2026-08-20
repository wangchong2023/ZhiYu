//
//  InfrastructureConstantsAndModelsTests.swift
//  ZhiYuTests
//
//  系统层级：[L1] 基础设施层测试
//  核心职责：验证 Infrastructure 层纯常量集与纯数据模型的完整性、
//           Codable 编解码往返、init 默认值、CodingKeys 映射。
//           覆盖 LLMConstants / PluginConstants / RegionCapabilities /
//           SpeechModels / PDFModels / RAGGovernanceModels。
//

import XCTest
@testable import ZhiYu

// MARK: - LLMConstants 常量完整性测试

final class LLMConstantsTests: XCTestCase {

    /// 验证 Memory 常量
    func testMemoryConstants() {
        XCTAssertEqual(LLMConstants.Memory.recentCountDefault, 5)
    }

    /// 验证 LogPreview 截断长度常量集
    func testLogPreviewConstants() {
        XCTAssertEqual(LLMConstants.LogPreview.memorySummaryLength, 300)
        XCTAssertEqual(LLMConstants.LogPreview.systemPromptLength, 300)
        XCTAssertEqual(LLMConstants.LogPreview.queryLength, 200)
        XCTAssertEqual(LLMConstants.LogPreview.maxDiagnosticLines, 15)
        XCTAssertEqual(LLMConstants.LogPreview.diagnosticLineLength, 250)
        XCTAssertEqual(LLMConstants.LogPreview.sseNonJsonLength, 120)
        XCTAssertEqual(LLMConstants.LogPreview.refactorPageContentLength, 150)
        XCTAssertEqual(LLMConstants.LogPreview.smartIngestSummaryLength, 100)
    }

    /// 验证 EntityPlaceholder 常量
    func testEntityPlaceholderConstants() {
        XCTAssertEqual(LLMConstants.EntityPlaceholder.maxRawLength, 25)
        XCTAssertEqual(LLMConstants.EntityPlaceholder.bufferSuffixLength, 10)
    }

    /// 验证 ContextCompression 常量
    func testContextCompressionConstants() {
        XCTAssertEqual(LLMConstants.ContextCompression.summaryScoreThreshold, 0.8)
        XCTAssertEqual(LLMConstants.ContextCompression.overflowTolerance, 500)
    }

    /// 验证 Anonymization 常量
    func testAnonymizationConstants() {
        XCTAssertEqual(LLMConstants.Anonymization.asciiUppercaseA, 65)
        XCTAssertEqual(LLMConstants.Anonymization.alphabetSize, 26)
        XCTAssertEqual(LLMConstants.Anonymization.minEntityLength, 2)
        XCTAssertEqual(LLMConstants.Anonymization.placeholderPrefix, "[ENTITY_")
        XCTAssertEqual(LLMConstants.Anonymization.placeholderSuffix, "]")
    }

    /// 验证 APIKeySecret 常量
    func testAPIKeySecretConstants() {
        XCTAssertEqual(LLMConstants.APIKeySecret.prefix, "sk-")
        XCTAssertEqual(LLMConstants.APIKeySecret.minLength, 20)
    }

    /// 验证 Rerank 常量
    func testRerankConstants() {
        XCTAssertEqual(LLMConstants.Rerank.candidateCount, 10)
    }

    /// 验证 Retry 退避参数
    func testRetryConstants() {
        XCTAssertEqual(LLMConstants.Retry.maxAttempts, 3)
        XCTAssertEqual(LLMConstants.Retry.initialDelaySeconds, 0.5)
        XCTAssertEqual(LLMConstants.Retry.backoffMultiplier, 2.0)
    }

    /// 验证 SmartIngest 常量
    func testSmartIngestConstants() {
        XCTAssertEqual(LLMConstants.SmartIngest.existingTitlesCount, 20)
    }

    /// 验证 APIKey 请求体字段名
    func testAPIKeyFieldNames() {
        XCTAssertEqual(LLMConstants.APIKey.role, "role")
        XCTAssertEqual(LLMConstants.APIKey.content, "content")
        XCTAssertEqual(LLMConstants.APIKey.model, "model")
        XCTAssertEqual(LLMConstants.APIKey.messages, "messages")
        XCTAssertEqual(LLMConstants.APIKey.temperature, "temperature")
        XCTAssertEqual(LLMConstants.APIKey.maxTokens, "max_tokens")
        XCTAssertEqual(LLMConstants.APIKey.stream, "stream")
        XCTAssertEqual(LLMConstants.APIKey.prompt, "prompt")
    }

    /// 验证 Role 角色取值
    func testRoleValues() {
        XCTAssertEqual(LLMConstants.Role.system, "system")
        XCTAssertEqual(LLMConstants.Role.user, "user")
        XCTAssertEqual(LLMConstants.Role.assistant, "assistant")
    }

    /// 验证 ModelIDPrefix 前缀
    func testModelIDPrefix() {
        XCTAssertEqual(LLMConstants.ModelIDPrefix.downloaded, "downloaded_")
        XCTAssertEqual(LLMConstants.ModelIDPrefix.bundled, "bundled_")
    }

    /// 验证 PromptTag 沙箱标签
    func testPromptTagValues() {
        XCTAssertEqual(LLMConstants.PromptTag.contextOpen, "<context>")
        XCTAssertEqual(LLMConstants.PromptTag.contextClose, "</context>")
        XCTAssertEqual(LLMConstants.PromptTag.userQueryOpen, "<user_query>")
        XCTAssertEqual(LLMConstants.PromptTag.userQueryClose, "</user_query>")
        XCTAssertEqual(LLMConstants.PromptTag.contextOpenEscaped, "[context]")
        XCTAssertEqual(LLMConstants.PromptTag.contextCloseEscaped, "[/context]")
        XCTAssertEqual(LLMConstants.PromptTag.userQueryOpenEscaped, "[user_query]")
        XCTAssertEqual(LLMConstants.PromptTag.userQueryCloseEscaped, "[/user_query]")
    }

    /// 验证 OnDeviceModel 显示名
    func testOnDeviceModelNames() {
        XCTAssertEqual(LLMConstants.OnDeviceModel.bundledName, "Bundled_Model")
        XCTAssertEqual(LLMConstants.OnDeviceModel.appleIntelligenceName, "Apple_Intelligence")
    }

    /// 验证 Loopback 回环地址标记
    func testLoopbackMarkers() {
        XCTAssertEqual(LLMConstants.Loopback.localhostMarker, "://localhost")
        XCTAssertEqual(LLMConstants.Loopback.ipv4LoopbackMarker, "://127.0.0.1")
        XCTAssertEqual(LLMConstants.Loopback.ipv6LoopbackMarker, "://[::1]")
        XCTAssertEqual(LLMConstants.Loopback.anyAddressMarker, "://0.0.0.0")
    }

    /// 验证 SSEStream 标记
    func testSSEStreamMarkers() {
        XCTAssertEqual(LLMConstants.SSEStream.doneMarker, "[DONE]")
        XCTAssertEqual(LLMConstants.SSEStream.dataPrefix, "data: ")
        XCTAssertEqual(LLMConstants.SSEStream.dataPrefixNoSpace, "data:")
    }

    /// 验证 TaskName 任务名
    func testTaskNames() {
        XCTAssertEqual(LLMConstants.TaskName.aiChat, "AI Chat")
        XCTAssertEqual(LLMConstants.TaskName.aiChatStream, "AI Chat Stream")
    }

    /// 验证 HealthCheck 常量
    func testHealthCheckConstants() {
        XCTAssertEqual(LLMConstants.HealthCheck.prompt, "Hi")
        XCTAssertEqual(LLMConstants.HealthCheck.systemPrompt, "Reply 'OK' only.")
    }

    /// 验证 MLFeature 特征名
    func testMLFeatureName() {
        XCTAssertEqual(LLMConstants.MLFeature.generatedText, "generated_text")
    }

    /// 验证 BundleResource 资源名
    func testBundleResourceNames() {
        XCTAssertEqual(LLMConstants.BundleResource.llmProviders, "LLMProviders")
        XCTAssertEqual(LLMConstants.BundleResource.appLLM, "AppLLM")
    }

    /// 验证 UITesting Mock 参数
    func testUITestingConstants() {
        XCTAssertEqual(LLMConstants.UITesting.launchArg, "--uitesting")
        XCTAssertEqual(LLMConstants.UITesting.nanosecondsPerSecond, 1_000_000_000)
        XCTAssertEqual(LLMConstants.UITesting.mockNonStreamDelaySeconds, 0.5)
        XCTAssertEqual(LLMConstants.UITesting.mockStreamInitialDelaySeconds, 1.5)
        XCTAssertEqual(LLMConstants.UITesting.mockStreamChunkDelaySeconds, 0.15)
        XCTAssertEqual(LLMConstants.UITesting.mockNonStreamReply, "Mock non-stream LLM reply for UI testing.")
        XCTAssertEqual(LLMConstants.UITesting.mockRAGReply, "Mock non-stream RAG reply for UI testing.")
        XCTAssertFalse(LLMConstants.UITesting.mockStreamChunks.isEmpty)
    }

    /// 验证 OnDeviceModelID 字面量
    func testOnDeviceModelIDLiterals() {
        XCTAssertEqual(LLMConstants.OnDeviceModelID.bundledZhiyu, "bundled_zhiyu")
        XCTAssertEqual(LLMConstants.OnDeviceModelID.appleIntelligence, "apple_intelligence")
    }

    /// 验证 OnDeviceStorage Key
    func testOnDeviceStorageKey() {
        XCTAssertEqual(LLMConstants.OnDeviceStorage.configKey, "zhiyu_ondevice_config")
    }

    /// 验证 OnDeviceIcon 图标名
    func testOnDeviceIconNames() {
        XCTAssertEqual(LLMConstants.OnDeviceIcon.bundled, "cube.box.fill")
        XCTAssertEqual(LLMConstants.OnDeviceIcon.downloaded, "arrow.down.circle.fill")
        XCTAssertEqual(LLMConstants.OnDeviceIcon.system, "apple.logo")
    }

    /// 验证 PromptInstruction.lengthHint 模板函数
    func testPromptInstructionLengthHint() {
        let hint = LLMConstants.PromptInstruction.lengthHint(500)
        XCTAssertTrue(hint.contains("500"))
        XCTAssertTrue(hint.contains("characters"))
    }

    /// 验证 PromptInstruction.questionLabel
    func testPromptInstructionQuestionLabel() {
        XCTAssertEqual(LLMConstants.PromptInstruction.questionLabel, "Question")
    }

    /// 验证 ChatHistory storageKey
    func testChatHistoryStorageKey() {
        XCTAssertEqual(LLMConstants.ChatHistory.storageKey, "zhiyu_chat_history")
    }

    /// 验证 PromptSecurity jailbreakPatterns 非空且含中英文
    func testPromptSecurityJailbreakPatterns() {
        let patterns = LLMConstants.PromptSecurity.jailbreakPatterns
        XCTAssertFalse(patterns.isEmpty)
        XCTAssertTrue(patterns.contains("ignore previous instructions"))
        XCTAssertTrue(patterns.contains("忽略之前的指令"))
        XCTAssertTrue(patterns.contains("jailbreak"))
        XCTAssertTrue(patterns.contains("越狱模式"))
    }
}

// MARK: - PluginConstants 常量完整性测试

final class PluginConstantsTests: XCTestCase {

    /// 验证 Sandbox 限制常量
    func testSandboxConstants() {
        XCTAssertEqual(PluginConstants.Sandbox.jsExecutionTimeLimitSeconds, 0.5)
        XCTAssertEqual(PluginConstants.Sandbox.maxResponseSizeMB, 5)
        XCTAssertGreaterThan(PluginConstants.Sandbox.maxResponseSizeBytes, 0)
    }

    /// 验证 maxResponseSizeBytes = 5MB * 1024 * 1024
    func testSandboxMaxResponseSizeBytesCalculation() {
        let expected = 5 * 1024 * 1024
        XCTAssertEqual(PluginConstants.Sandbox.maxResponseSizeBytes, expected)
    }

    /// 验证 Localization requiredLocales
    func testLocalizationRequiredLocales() {
        let locales = PluginConstants.Localization.requiredLocales
        XCTAssertEqual(locales.count, 2)
        XCTAssertTrue(locales.contains("en"))
        XCTAssertTrue(locales.contains("zh-Hans"))
    }

    /// 验证 DefaultManifest 默认值
    func testDefaultManifestValues() {
        XCTAssertEqual(PluginConstants.DefaultManifest.author, "Local Developer")
        XCTAssertEqual(PluginConstants.DefaultManifest.permissions, ["log", "writeContent"])
        XCTAssertEqual(PluginConstants.DefaultManifest.descriptionEn, "Legacy .js plugin (migrate to .zyplugin format)")
        XCTAssertEqual(PluginConstants.DefaultManifest.idPrefix, "local.")
    }

    /// 验证 Permission 权限字面量
    func testPermissionStrings() {
        XCTAssertEqual(PluginConstants.Permission.network, "network")
        XCTAssertEqual(PluginConstants.Permission.llm, "llm")
        XCTAssertEqual(PluginConstants.Permission.pagesRead, "pages.read")
        XCTAssertEqual(PluginConstants.Permission.writeContent, "writeContent")
    }

    /// 验证 MarketJSON 文件名
    func testMarketJSONFilenames() {
        XCTAssertEqual(PluginConstants.MarketJSON.communityPlugins, "community-plugins.json")
        XCTAssertEqual(PluginConstants.MarketJSON.communityPluginsZhHans, "community-plugins_zh-Hans.json")
        XCTAssertEqual(PluginConstants.MarketJSON.community, "community.json")
        XCTAssertEqual(PluginConstants.MarketJSON.pluginsPathSegment, "plugins")
    }

    /// 验证 LanguagePrefix 标记
    func testLanguagePrefixMarkers() {
        XCTAssertEqual(PluginConstants.LanguagePrefix.zh, "zh")
        XCTAssertEqual(PluginConstants.LanguagePrefix.en, "en")
    }

    /// 验证 MarketError 错误域
    func testMarketErrorDomain() {
        XCTAssertEqual(PluginConstants.MarketError.domain, "PluginMarketService")
        XCTAssertEqual(PluginConstants.MarketError.httpPrefix, "HTTP ")
        XCTAssertEqual(PluginConstants.MarketError.documentsNotFound, "Failed to locate documents directory")
    }

    /// 验证 PluginID 前缀
    func testPluginIDPrefix() {
        XCTAssertEqual(PluginConstants.PluginID.officialPrefix, "com.zhiyu.plugin.")
        XCTAssertEqual(PluginConstants.PluginID.v1VersionPrefix, "1.")
    }

    /// 验证 JSGlobal 全局对象名
    func testJSGlobalObjectName() {
        XCTAssertEqual(PluginConstants.JSGlobal.hostBridge, "ZhiYu")
    }

    /// 验证 AnalyticsKey 事件参数 Key
    func testAnalyticsKeys() {
        XCTAssertEqual(PluginConstants.AnalyticsKey.id, "id")
        XCTAssertEqual(PluginConstants.AnalyticsKey.duration, "duration")
        XCTAssertEqual(PluginConstants.AnalyticsKey.error, "error")
    }
}

// MARK: - RegionCapabilities 模型测试

final class RegionCapabilitiesTests: XCTestCase {

    /// 验证 RegionInfo init
    func testRegionInfoInit() {
        let info = RegionCapabilities.RegionInfo(
            loginPageType: "localized",
            pluginMarketUrl: "https://example.com/plugins"
        )
        XCTAssertEqual(info.loginPageType, "localized")
        XCTAssertEqual(info.pluginMarketUrl, "https://example.com/plugins")
    }

    /// 验证 RegionCapabilities init
    func testRegionCapabilitiesInit() {
        let info = RegionCapabilities.RegionInfo(
            loginPageType: "international",
            pluginMarketUrl: "https://overseas.example.com"
        )
        let caps = RegionCapabilities(regions: ["US": info])
        XCTAssertEqual(caps.regions.count, 1)
        XCTAssertEqual(caps.regions["US"]?.loginPageType, "international")
    }

    /// 验证 RegionInfo Codable 往返（snake_case 映射）
    func testRegionInfoCodableRoundTrip() throws {
        let original = RegionCapabilities.RegionInfo(
            loginPageType: "localized",
            pluginMarketUrl: "https://cn.example.com"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RegionCapabilities.RegionInfo.self, from: data)
        XCTAssertEqual(decoded.loginPageType, original.loginPageType)
        XCTAssertEqual(decoded.pluginMarketUrl, original.pluginMarketUrl)
    }

    /// 验证 RegionInfo 从 snake_case JSON 解码
    func testRegionInfoDecodeFromSnakeCaseJSON() throws {
        let json = """
        {
            "login_page_type": "international",
            "plugin_market_url": "https://us.example.com"
        }
        """
        guard let jsonData = json.data(using: .utf8) else {
            XCTFail("JSON 字符串转 Data 失败")
            return
        }
        let decoded = try JSONDecoder().decode(RegionCapabilities.RegionInfo.self, from: jsonData)
        XCTAssertEqual(decoded.loginPageType, "international")
        XCTAssertEqual(decoded.pluginMarketUrl, "https://us.example.com")
    }

    /// 验证 RegionCapabilities Codable 往返
    func testRegionCapabilitiesCodableRoundTrip() throws {
        let cnInfo = RegionCapabilities.RegionInfo(
            loginPageType: "localized",
            pluginMarketUrl: "https://cn.example.com"
        )
        let usInfo = RegionCapabilities.RegionInfo(
            loginPageType: "international",
            pluginMarketUrl: "https://us.example.com"
        )
        let original = RegionCapabilities(regions: ["CN": cnInfo, "US": usInfo])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RegionCapabilities.self, from: data)
        XCTAssertEqual(decoded.regions.count, 2)
        XCTAssertEqual(decoded.regions["CN"]?.loginPageType, "localized")
        XCTAssertEqual(decoded.regions["US"]?.loginPageType, "international")
    }
}

// MARK: - SpeechModels 测试

final class SpeechModelsTests: XCTestCase {

    /// 验证 VoiceRecording init 含默认值
    func testVoiceRecordingInitWithDefaults() {
        let recording = VoiceRecording(title: "测试", text: "内容", language: "zh", duration: 10.0)
        XCTAssertNotNil(recording.id)
        XCTAssertEqual(recording.title, "测试")
        XCTAssertEqual(recording.text, "内容")
        XCTAssertEqual(recording.language, "zh")
        XCTAssertEqual(recording.duration, 10.0)
        XCTAssertNotNil(recording.createdAt)
    }

    /// 验证 VoiceRecording init 含全部参数
    func testVoiceRecordingInitWithAllParameters() {
        let id = UUID()
        let date = Date()
        let recording = VoiceRecording(
            id: id,
            title: "标题",
            text: "文本",
            language: "en",
            duration: 30.0,
            createdAt: date
        )
        XCTAssertEqual(recording.id, id)
        XCTAssertEqual(recording.createdAt, date)
    }

    /// 验证 VoiceRecording Codable 往返
    func testVoiceRecordingCodableRoundTrip() throws {
        let original = VoiceRecording(title: "录音", text: "转写", language: "zh", duration: 5.5)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(VoiceRecording.self, from: data)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.text, original.text)
        XCTAssertEqual(decoded.language, original.language)
        XCTAssertEqual(decoded.duration, original.duration)
    }

    /// 验证 VoiceRecording Identifiable
    func testVoiceRecordingIdentifiable() {
        let recording = VoiceRecording(title: "x", text: "", language: "en", duration: 1.0)
        XCTAssertFalse(recording.id.uuidString.isEmpty)
    }

    /// 验证 SpeechError 所有 case
    func testSpeechErrorAllCases() {
        let errors: [SpeechError] = [.localeNotSupported, .notAuthorized, .audioEngineError]
        XCTAssertEqual(errors.count, 3)
    }

    /// 验证 SpeechError errorDescription 非空
    func testSpeechErrorDescriptions() {
        XCTAssertNotNil(SpeechError.localeNotSupported.errorDescription)
        XCTAssertNotNil(SpeechError.notAuthorized.errorDescription)
        XCTAssertNotNil(SpeechError.audioEngineError.errorDescription)
    }
}

// MARK: - PDFModels 测试

final class PDFModelsSupplementTests: XCTestCase {

    /// 验证 PDFDocumentInfo init 含默认值
    func testPDFDocumentInfoInitWithDefaults() {
        let doc = PDFDocumentInfo(title: "文档", fileName: "doc.pdf", pageCount: 10)
        XCTAssertNotNil(doc.id)
        XCTAssertEqual(doc.title, "文档")
        XCTAssertEqual(doc.fileName, "doc.pdf")
        XCTAssertEqual(doc.pageCount, 10)
        XCTAssertEqual(doc.lastReadPage, 0)
        XCTAssertTrue(doc.highlights.isEmpty)
        XCTAssertTrue(doc.linkedPageTitles.isEmpty)
    }

    /// 验证 PDFDocumentInfo init 含全部参数
    func testPDFDocumentInfoInitWithAllParameters() {
        let id = UUID()
        let date = Date()
        let highlight = PDFHighlight(pageIndex: 0, text: "高亮")
        let doc = PDFDocumentInfo(
            id: id,
            title: "完整",
            fileName: "full.pdf",
            pageCount: 50,
            addedDate: date,
            lastReadPage: 5,
            highlights: [highlight],
            linkedPageTitles: ["页面A"]
        )
        XCTAssertEqual(doc.id, id)
        XCTAssertEqual(doc.addedDate, date)
        XCTAssertEqual(doc.lastReadPage, 5)
        XCTAssertEqual(doc.highlights.count, 1)
        XCTAssertEqual(doc.linkedPageTitles, ["页面A"])
    }

    /// 验证 PDFDocumentInfo Codable 往返
    func testPDFDocumentInfoCodableRoundTrip() throws {
        let highlight = PDFHighlight(pageIndex: 3, text: "重点", color: "blue", note: "备注")
        let original = PDFDocumentInfo(
            title: "PDF",
            fileName: "test.pdf",
            pageCount: 20,
            highlights: [highlight],
            linkedPageTitles: ["链接1", "链接2"]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PDFDocumentInfo.self, from: data)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.pageCount, original.pageCount)
        XCTAssertEqual(decoded.highlights.count, 1)
        XCTAssertEqual(decoded.highlights.first?.text, "重点")
        XCTAssertEqual(decoded.linkedPageTitles, ["链接1", "链接2"])
    }

    /// 验证 PDFHighlight init 含默认值
    func testPDFHighlightInitWithDefaults() {
        let highlight = PDFHighlight(pageIndex: 1, text: "文本")
        XCTAssertNotNil(highlight.id)
        XCTAssertEqual(highlight.pageIndex, 1)
        XCTAssertEqual(highlight.text, "文本")
        XCTAssertEqual(highlight.color, "yellow")
        XCTAssertEqual(highlight.note, "")
    }

    /// 验证 PDFHighlight init 含全部参数
    func testPDFHighlightInitWithAllParameters() {
        let id = UUID()
        let date = Date()
        let highlight = PDFHighlight(
            id: id,
            pageIndex: 5,
            text: "高亮文本",
            color: "green",
            note: "笔记",
            creationDate: date
        )
        XCTAssertEqual(highlight.id, id)
        XCTAssertEqual(highlight.color, "green")
        XCTAssertEqual(highlight.note, "笔记")
        XCTAssertEqual(highlight.creationDate, date)
    }

    /// 验证 PDFHighlight Codable 往返
    func testPDFHighlightCodableRoundTrip() throws {
        let original = PDFHighlight(pageIndex: 2, text: "内容", color: "pink", note: "注释")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PDFHighlight.self, from: data)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.pageIndex, original.pageIndex)
        XCTAssertEqual(decoded.text, original.text)
        XCTAssertEqual(decoded.color, original.color)
        XCTAssertEqual(decoded.note, original.note)
    }

    /// 验证 PDFHighlight Identifiable
    func testPDFHighlightIdentifiable() {
        let highlight = PDFHighlight(pageIndex: 0, text: "")
        XCTAssertFalse(highlight.id.uuidString.isEmpty)
    }
}

// MARK: - RAGGovernanceModels 测试

final class RAGGovernanceModelsSupplementTests: XCTestCase {

    /// 验证 TokenUsage init 含默认值
    func testTokenUsageInitWithDefaults() {
        let usage = TokenUsage(model: "gpt-4", promptTokens: 100, completionTokens: 50)
        XCTAssertNil(usage.id)
        XCTAssertEqual(usage.model, "gpt-4")
        XCTAssertEqual(usage.promptTokens, 100)
        XCTAssertEqual(usage.completionTokens, 50)
        XCTAssertEqual(usage.totalTokens, 150)
        XCTAssertNotNil(usage.createdAt)
    }

    /// 验证 TokenUsage totalTokens 自动计算
    func testTokenUsageTotalTokensCalculation() {
        let usage = TokenUsage(model: "claude", promptTokens: 200, completionTokens: 80)
        XCTAssertEqual(usage.totalTokens, 280)
    }

    /// 验证 TokenUsage databaseTableName
    func testTokenUsageDatabaseTableName() {
        XCTAssertFalse(TokenUsage.databaseTableName.isEmpty)
    }

    /// 验证 TokenUsage Codable 往返（snake_case 映射）
    func testTokenUsageCodableRoundTrip() throws {
        let original = TokenUsage(id: 1, model: "gpt-4", promptTokens: 100, completionTokens: 50)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TokenUsage.self, from: data)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.model, original.model)
        XCTAssertEqual(decoded.promptTokens, original.promptTokens)
        XCTAssertEqual(decoded.completionTokens, original.completionTokens)
        XCTAssertEqual(decoded.totalTokens, original.totalTokens)
    }

    /// 验证 RAGEvaluation init 含默认值
    func testRAGEvaluationInitWithDefaults() {
        let eval = RAGEvaluation(
            query: "问题",
            answer: "回答",
            faithfulness: 0.9,
            relevance: 0.8,
            precision: 0.7,
            evaluatorModel: "gpt-4"
        )
        XCTAssertNil(eval.id)
        XCTAssertEqual(eval.query, "问题")
        XCTAssertEqual(eval.answer, "回答")
        XCTAssertEqual(eval.faithfulness, 0.9)
        XCTAssertEqual(eval.relevance, 0.8)
        XCTAssertEqual(eval.precision, 0.7)
        XCTAssertEqual(eval.hallucinationRate, 0.0)
        XCTAssertEqual(eval.citationAccuracy, 0.0)
        XCTAssertEqual(eval.answerCorrectness, 0.0)
        XCTAssertEqual(eval.contextSufficiency, 0.0)
        XCTAssertNil(eval.userRating)
        XCTAssertEqual(eval.evaluatorModel, "gpt-4")
    }

    /// 验证 RAGEvaluation init 含全部参数
    func testRAGEvaluationInitWithAllParameters() {
        let eval = RAGEvaluation(
            id: 10,
            query: "Q",
            answer: "A",
            faithfulness: 0.95,
            relevance: 0.85,
            precision: 0.75,
            hallucinationRate: 0.1,
            citationAccuracy: 0.9,
            answerCorrectness: 0.88,
            contextSufficiency: 0.8,
            userRating: 2,
            evaluatorModel: "claude"
        )
        XCTAssertEqual(eval.id, 10)
        XCTAssertEqual(eval.hallucinationRate, 0.1)
        XCTAssertEqual(eval.citationAccuracy, 0.9)
        XCTAssertEqual(eval.answerCorrectness, 0.88)
        XCTAssertEqual(eval.contextSufficiency, 0.8)
        XCTAssertEqual(eval.userRating, 2)
    }

    /// 验证 RAGEvaluation Codable 往返
    func testRAGEvaluationCodableRoundTrip() throws {
        let original = RAGEvaluation(
            id: 1,
            query: "查询",
            answer: "答案",
            faithfulness: 0.9,
            relevance: 0.8,
            precision: 0.7,
            hallucinationRate: 0.05,
            citationAccuracy: 0.95,
            answerCorrectness: 0.9,
            contextSufficiency: 0.85,
            userRating: 1,
            evaluatorModel: "gpt-4"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RAGEvaluation.self, from: data)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.query, original.query)
        XCTAssertEqual(decoded.faithfulness, original.faithfulness)
        XCTAssertEqual(decoded.hallucinationRate, original.hallucinationRate)
        XCTAssertEqual(decoded.citationAccuracy, original.citationAccuracy)
        XCTAssertEqual(decoded.userRating, original.userRating)
    }

    /// 验证 LLMCallLog init
    func testLLMCallLogInit() {
        let log = LLMCallLog(
            model: "gpt-4",
            promptTokens: 100,
            completionTokens: 50,
            latencyMS: 200,
            status: "success"
        )
        XCTAssertNil(log.id)
        XCTAssertEqual(log.model, "gpt-4")
        XCTAssertEqual(log.promptTokens, 100)
        XCTAssertEqual(log.completionTokens, 50)
        XCTAssertEqual(log.latencyMS, 200)
        XCTAssertEqual(log.status, "success")
    }

    /// 验证 LLMCallLog Codable 往返
    func testLLMCallLogCodableRoundTrip() throws {
        let original = LLMCallLog(
            id: 5,
            model: "claude",
            promptTokens: 200,
            completionTokens: 100,
            latencyMS: 500,
            status: "error"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LLMCallLog.self, from: data)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.model, original.model)
        XCTAssertEqual(decoded.latencyMS, original.latencyMS)
        XCTAssertEqual(decoded.status, original.status)
    }

    /// 验证 RetrievalSnapshot init
    func testRetrievalSnapshotInit() {
        let snapshot = RetrievalSnapshot(
            evaluationID: 1,
            rank: 1,
            sourceID: "uuid-123",
            pageTitle: "标题",
            snippet: "片段",
            score: 0.95
        )
        XCTAssertNil(snapshot.id)
        XCTAssertEqual(snapshot.evaluationID, 1)
        XCTAssertEqual(snapshot.rank, 1)
        XCTAssertEqual(snapshot.sourceID, "uuid-123")
        XCTAssertEqual(snapshot.pageTitle, "标题")
        XCTAssertEqual(snapshot.snippet, "片段")
        XCTAssertEqual(snapshot.score, 0.95)
    }

    /// 验证 RetrievalSnapshot Codable 往返
    func testRetrievalSnapshotCodableRoundTrip() throws {
        let original = RetrievalSnapshot(
            id: 10,
            evaluationID: 2,
            rank: 3,
            sourceID: "src-456",
            pageTitle: "页面",
            snippet: "文本片段",
            score: 0.88
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RetrievalSnapshot.self, from: data)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.evaluationID, original.evaluationID)
        XCTAssertEqual(decoded.rank, original.rank)
        XCTAssertEqual(decoded.sourceID, original.sourceID)
        XCTAssertEqual(decoded.score, original.score)
    }

    /// 验证 RelevanceJudgment init 含默认值
    func testRelevanceJudgmentInitWithDefaults() {
        let judgment = RelevanceJudgment(
            queryHash: "abc123",
            query: "查询",
            sourceID: "src-1",
            relevanceLevel: 2
        )
        XCTAssertNil(judgment.id)
        XCTAssertEqual(judgment.queryHash, "abc123")
        XCTAssertEqual(judgment.query, "查询")
        XCTAssertEqual(judgment.sourceID, "src-1")
        XCTAssertEqual(judgment.relevanceLevel, 2)
        XCTAssertEqual(judgment.judgeSource, "llm-auto")
        XCTAssertNil(judgment.evaluationID)
    }

    /// 验证 RelevanceJudgment init 含全部参数
    func testRelevanceJudgmentInitWithAllParameters() {
        let judgment = RelevanceJudgment(
            id: 20,
            queryHash: "hash",
            query: "Q",
            sourceID: "src",
            relevanceLevel: 0,
            judgeSource: "manual",
            evaluationID: 5
        )
        XCTAssertEqual(judgment.id, 20)
        XCTAssertEqual(judgment.judgeSource, "manual")
        XCTAssertEqual(judgment.evaluationID, 5)
    }

    /// 验证 RelevanceJudgment Codable 往返
    func testRelevanceJudgmentCodableRoundTrip() throws {
        let original = RelevanceJudgment(
            id: 1,
            queryHash: "sha256",
            query: "问题",
            sourceID: "source",
            relevanceLevel: 1,
            judgeSource: "manual",
            evaluationID: 3
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RelevanceJudgment.self, from: data)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.queryHash, original.queryHash)
        XCTAssertEqual(decoded.relevanceLevel, original.relevanceLevel)
        XCTAssertEqual(decoded.judgeSource, original.judgeSource)
        XCTAssertEqual(decoded.evaluationID, original.evaluationID)
    }
}
