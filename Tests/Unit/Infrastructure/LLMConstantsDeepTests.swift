//
//  LLMConstantsDeepTests.swift
//  ZhiYuTests
//
//  系统层级：[L1] 基础设施层测试
//  核心职责：验证 LLMConstants 纯常量集的完整性，覆盖 Memory / LogPreview /
//           EntityPlaceholder / ContextCompression / Anonymization / APIKeySecret /
//           Rerank / Retry / SmartIngest / APIKey / Role / ModelIDPrefix / PromptTag /
//           OnDeviceModel / Loopback / SSEStream / TaskName / HealthCheck / MLFeature /
//           BundleResource / UITesting / OnDeviceModelID / OnDeviceStorage /
//           OnDeviceIcon / PromptInstruction / ChatHistory / PromptSecurity。
//

import XCTest
@testable import ZhiYu

// MARK: - LLMConstants 常量完整性测试

final class LLMConstantsDeepTests: XCTestCase {

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
