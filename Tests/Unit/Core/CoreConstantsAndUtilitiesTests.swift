//
//  CoreConstantsAndUtilitiesTests.swift
//  ZhiYuTests
//
//  系统层级：[L0] 底层基座层测试
//  核心职责：验证 Core 层纯常量集与纯逻辑工具的完整性。
//           覆盖 CoreConstants / AppConstants / APIPaths / DocumentFormat /
//           PageContentUtility / LogEntry。
//

import XCTest
@testable import ZhiYu

// MARK: - CoreConstants 常量完整性测试

final class CoreConstantsTests: XCTestCase {

    /// 验证 LanguageCode 语言代码
    func testLanguageCodes() {
        XCTAssertEqual(CoreConstants.LanguageCode.zh, "zh")
        XCTAssertEqual(CoreConstants.LanguageCode.zhHans, "zh-Hans")
        XCTAssertEqual(CoreConstants.LanguageCode.zhHant, "zh-Hant")
        XCTAssertEqual(CoreConstants.LanguageCode.en, "en")
        XCTAssertEqual(CoreConstants.LanguageCode.ja, "ja")
        XCTAssertEqual(CoreConstants.LanguageCode.ko, "ko")
    }

    /// 验证 Localization 常量
    func testLocalizationConstants() {
        XCTAssertEqual(CoreConstants.Localization.lproj, "lproj")
        XCTAssertEqual(CoreConstants.Localization.commonTable, "Common")
    }

    /// 验证 Security 常量
    func testSecurityConstants() {
        XCTAssertEqual(CoreConstants.Security.redacted, "[REDACTED]")
        XCTAssertEqual(CoreConstants.Security.masked, "***")
        XCTAssertEqual(CoreConstants.Security.piiMask, "[PII]")
        XCTAssertEqual(CoreConstants.Security.logModule, "Security")
    }

    /// 验证 SecurityLogTarget 常量
    func testSecurityLogTargetConstants() {
        XCTAssertEqual(CoreConstants.SecurityLogTarget.contentModerationEngine, "ContentModerationEngine")
        XCTAssertEqual(CoreConstants.SecurityLogTarget.securityManager, "SecurityManager")
        XCTAssertEqual(CoreConstants.SecurityLogTarget.promptSecurityGuard, "PromptSecurityGuard")
    }

    /// 验证 ModerationReason 常量
    func testModerationReasonConstants() {
        XCTAssertEqual(CoreConstants.ModerationReason.emptyText, "empty_text")
        XCTAssertEqual(CoreConstants.ModerationReason.clean, "clean")
        XCTAssertEqual(CoreConstants.ModerationReason.detectedPromptInjection, "detected_prompt_injection")
    }

    /// 验证 Moderation 常量
    func testModerationConstants() {
        XCTAssertEqual(CoreConstants.Moderation.safe, "safe")
        XCTAssertEqual(CoreConstants.Moderation.unsafe, "unsafe")
        XCTAssertEqual(CoreConstants.Moderation.sensitive, "sensitive")
        XCTAssertEqual(CoreConstants.Moderation.unknown, "unknown")
    }

    /// 验证 Workflow 常量
    func testWorkflowConstants() {
        XCTAssertEqual(CoreConstants.Workflow.pending, "pending")
        XCTAssertEqual(CoreConstants.Workflow.running, "running")
        XCTAssertEqual(CoreConstants.Workflow.completed, "completed")
        XCTAssertEqual(CoreConstants.Workflow.failed, "failed")
        XCTAssertEqual(CoreConstants.Workflow.cancelled, "cancelled")
    }

    /// 验证 ErrorType 常量
    func testErrorTypeConstants() {
        XCTAssertEqual(CoreConstants.ErrorType.network, "network")
        XCTAssertEqual(CoreConstants.ErrorType.storage, "storage")
        XCTAssertEqual(CoreConstants.ErrorType.validation, "validation")
        XCTAssertEqual(CoreConstants.ErrorType.authorization, "authorization")
        XCTAssertEqual(CoreConstants.ErrorType.notFound, "notFound")
        XCTAssertEqual(CoreConstants.ErrorType.server, "server")
    }

    /// 验证 ErrorDomain 常量（反向 DNS 格式）
    func testErrorDomainConstants() {
        XCTAssertTrue(CoreConstants.ErrorDomain.insight.hasPrefix("com.zhiyu."))
        XCTAssertTrue(CoreConstants.ErrorDomain.ingestStore.hasPrefix("com.zhiyu."))
        XCTAssertTrue(CoreConstants.ErrorDomain.export.hasPrefix("com.zhiyu."))
    }

    /// 验证 DeepLink 常量
    func testDeepLinkConstants() {
        XCTAssertEqual(CoreConstants.DeepLink.scheme, "zhiyu")
        XCTAssertEqual(CoreConstants.DeepLink.host, "page")
        XCTAssertEqual(CoreConstants.DeepLink.createHost, "create")
        XCTAssertEqual(CoreConstants.DeepLink.searchHost, "search")
        XCTAssertEqual(CoreConstants.DeepLink.chatHost, "chat")
        XCTAssertEqual(CoreConstants.DeepLink.pageIDKey, "pageID")
    }

    /// 验证 MarkdownSyntax 常量
    func testMarkdownSyntaxConstants() {
        XCTAssertEqual(CoreConstants.MarkdownSyntax.taskOpen, "- [ ] ")
        XCTAssertEqual(CoreConstants.MarkdownSyntax.taskDone, "- [x] ")
        XCTAssertEqual(CoreConstants.MarkdownSyntax.boldItalic, "***")
        XCTAssertEqual(CoreConstants.MarkdownSyntax.italic, "__")
        XCTAssertEqual(CoreConstants.MarkdownSyntax.strikethrough, "~~")
    }

    /// 验证 PromptInjection 定界符
    func testPromptInjectionDelimiters() {
        XCTAssertEqual(CoreConstants.PromptInjection.imStart, "<|im_start|>")
        XCTAssertEqual(CoreConstants.PromptInjection.imEnd, "<|im_end|>")
        XCTAssertEqual(CoreConstants.PromptInjection.systemMarker, "### System:")
        XCTAssertEqual(CoreConstants.PromptInjection.escapedPrefix, "[ESCAPED_")
    }

    /// 验证 Frontmatter 常量
    func testFrontmatterConstants() {
        XCTAssertEqual(CoreConstants.Frontmatter.minPartCount, 3)
        XCTAssertEqual(CoreConstants.Frontmatter.dropFirstCount, 2)
    }

    /// 验证 PerformanceLabel 常量
    func testPerformanceLabelConstants() {
        XCTAssertEqual(CoreConstants.PerformanceLabel.save, "save")
        XCTAssertEqual(CoreConstants.PerformanceLabel.load, "load")
        XCTAssertEqual(CoreConstants.PerformanceLabel.lint, "lint")
        XCTAssertEqual(CoreConstants.PerformanceLabel.ragChain, "ragChain")
    }

    /// 验证 RemoteConfig 常量
    func testRemoteConfigConstants() {
        XCTAssertEqual(CoreConstants.RemoteConfig.modelAllowlist, "model_allowlist")
        XCTAssertEqual(CoreConstants.RemoteConfig.jsonKeyModels, "models")
        XCTAssertEqual(CoreConstants.RemoteConfig.SkillID.chunkingFormatter, "chunking_formatter")
        XCTAssertEqual(CoreConstants.RemoteConfig.SkillID.linkDiscovery, "link_discovery")
    }

    /// 验证 Benchmark 常量
    func testBenchmarkConstants() {
        XCTAssertEqual(CoreConstants.Benchmark.tagBenchmark, "benchmark")
        XCTAssertEqual(CoreConstants.Benchmark.tagStressTest, "stress-test")
        XCTAssertEqual(CoreConstants.Benchmark.searchQuery, "Stress Test")
    }

    /// 验证 Export 常量
    func testExportConstants() {
        XCTAssertEqual(CoreConstants.Export.unsupported, "unsupported")
        XCTAssertFalse(CoreConstants.Export.unsupportedMessage.isEmpty)
    }
}

// MARK: - AppConstants 常量完整性测试

final class AppConstantsTests: XCTestCase {

    /// 验证 Network 常量
    func testNetworkConstants() {
        XCTAssertEqual(AppConstants.Network.jwtTokenKey, "jwt_token_key")
        XCTAssertEqual(AppConstants.Network.refreshTokenKey, "refresh_token")
        XCTAssertEqual(AppConstants.Network.avatarFileName, "avatar.png")
        XCTAssertEqual(AppConstants.Network.requestTimeout, 30.0)
        XCTAssertEqual(AppConstants.Network.oauthCallbackScheme, "zhiyu")
    }

    /// 验证 Storage 数据库文件名
    func testStorageDatabaseNames() {
        XCTAssertEqual(AppConstants.Storage.databaseName, "App.sqlite")
        XCTAssertEqual(AppConstants.Storage.globalDatabaseName, "global.sqlite3")
        XCTAssertEqual(AppConstants.Storage.vaultDatabaseName, "vault.sqlite3")
        XCTAssertEqual(AppConstants.Storage.vaultsDirectoryName, "Vaults")
    }

    /// 验证 Storage appGroupIdentifier
    func testStorageAppGroup() {
        XCTAssertEqual(AppConstants.Storage.appGroupIdentifier, "group.com.zhiyu.app")
    }

    /// 验证 Storage defaultEaseFactor（SuperMemo-2 默认值）
    func testStorageDefaultEaseFactor() {
        XCTAssertEqual(AppConstants.Storage.defaultEaseFactor, 2.5)
    }

    /// 验证 Tables 表名非空
    func testTableNames() {
        XCTAssertEqual(AppConstants.Storage.Tables.pages, "pages")
        XCTAssertEqual(AppConstants.Storage.Tables.pagesFTS, "pages_fts")
        XCTAssertEqual(AppConstants.Storage.Tables.links, "links")
        XCTAssertEqual(AppConstants.Storage.Tables.tokenUsage, "token_usage")
        XCTAssertEqual(AppConstants.Storage.Tables.ragEvaluations, "rag_evaluations")
        XCTAssertEqual(AppConstants.Storage.Tables.pluginRecords, "plugin_records")
    }

    /// 验证 Columns 列名
    func testColumnNames() {
        XCTAssertEqual(AppConstants.Storage.Columns.id, "id")
        XCTAssertEqual(AppConstants.Storage.Columns.title, "title")
        XCTAssertEqual(AppConstants.Storage.Columns.created, "created_at")
        XCTAssertEqual(AppConstants.Storage.Columns.updated, "updated_at")
    }

    /// 验证 Performance latencyWarningThreshold
    func testPerformanceConstants() {
        XCTAssertEqual(AppConstants.Performance.latencyWarningThreshold, 2000)
    }

    /// 验证 Keys.Storage 常量
    func testKeysStorageConstants() {
        XCTAssertEqual(AppConstants.Keys.Storage.languageMode, "app_language_mode")
        XCTAssertEqual(AppConstants.Keys.Storage.userHasOnboarded, "app_user_has_onboarded")
        XCTAssertEqual(AppConstants.Keys.Storage.themePreference, "app_theme_preference")
        XCTAssertEqual(AppConstants.Keys.Storage.authIsAuthenticated, "auth.isAuthenticated")
    }

    /// 验证 ImportLimits 常量
    func testImportLimitsConstants() {
        XCTAssertEqual(AppConstants.Keys.ImportLimits.maxVoiceDurationSeconds, 15 * 60)
        XCTAssertEqual(AppConstants.Keys.ImportLimits.aiTagSnippetLength, 3000)
        XCTAssertEqual(AppConstants.Keys.ImportLimits.maxURLCount, 10)
        XCTAssertEqual(AppConstants.Keys.ImportLimits.maxImagesPerPage, 10)
        XCTAssertEqual(AppConstants.Keys.ImportLimits.uuidPrefixLength, 8)
    }

    /// 验证 ImportLimits liteMaxFileSizeBytes = 10MB
    func testImportLimitsLiteMaxFileSize() {
        let tenMB = 10 * 1024 * 1024
        XCTAssertEqual(AppConstants.Keys.ImportLimits.liteMaxFileSizeBytes, Int64(tenMB))
    }

    /// 验证 ImportLimits maxFileSizeBytes = 50MB
    func testImportLimitsMaxFileSize() {
        let fiftyMB = 50 * 1024 * 1024
        XCTAssertEqual(AppConstants.Keys.ImportLimits.maxFileSizeBytes, Int64(fiftyMB))
    }

    /// 验证 ImportLimits officeExtensions
    func testImportLimitsOfficeExtensions() {
        let exts = AppConstants.Keys.ImportLimits.officeExtensions
        XCTAssertEqual(exts.count, 3)
        XCTAssertTrue(exts.contains("docx"))
        XCTAssertTrue(exts.contains("xlsx"))
        XCTAssertTrue(exts.contains("pptx"))
    }

    /// 验证 ImportLimits imageExtensions
    func testImportLimitsImageExtensions() {
        let exts = AppConstants.Keys.ImportLimits.imageExtensions
        XCTAssertEqual(exts.count, 4)
        XCTAssertTrue(exts.contains("png"))
        XCTAssertTrue(exts.contains("jpg"))
        XCTAssertTrue(exts.contains("jpeg"))
        XCTAssertTrue(exts.contains("gif"))
    }

    /// 验证 Stats 常量
    func testStatsConstants() {
        XCTAssertEqual(AppConstants.Keys.Stats.dailyStatsDays, 30)
        XCTAssertEqual(AppConstants.Keys.Stats.dailyDateFormat, "yyyy-MM-dd")
    }

    /// 验证 ExportLimits 常量
    func testExportLimitsConstants() {
        XCTAssertEqual(AppConstants.ExportLimits.minValidSynthesisTextBytes, 10)
        XCTAssertEqual(AppConstants.ExportLimits.minValidPDFBytes, 100)
        XCTAssertEqual(AppConstants.ExportLimits.webRenderFallbackTimeoutMS, 800)
    }

    /// 验证 Subscription 产品 ID
    func testSubscriptionProductIds() {
        XCTAssertEqual(AppConstants.Subscription.monthlyProductId, "com.zhiyu.pro.monthly")
        XCTAssertEqual(AppConstants.Subscription.yearlyProductId, "com.zhiyu.pro.yearly")
        XCTAssertEqual(AppConstants.Subscription.allProductIds.count, 2)
    }

    /// 验证 Version 常量非空
    func testVersionConstants() {
        XCTAssertFalse(AppConstants.Version.semVer.isEmpty)
        XCTAssertFalse(AppConstants.Version.gitShortHash.isEmpty)
        XCTAssertFalse(AppConstants.Version.buildTimestamp.isEmpty)
    }

    /// 验证 AppModel 枚举
    func testAppModelAllCases() {
        XCTAssertEqual(AppModel.allCases.count, 3)
        XCTAssertEqual(AppModel.gpt4o.rawValue, "gpt-4o")
        XCTAssertEqual(AppModel.evaluator.rawValue, "evaluator")
    }

    /// 验证 EvaluationMetric 枚举
    func testEvaluationMetricAllCases() {
        XCTAssertEqual(EvaluationMetric.allCases.count, 5)
        XCTAssertEqual(EvaluationMetric.faithfulness.rawValue, "faithfulness")
        XCTAssertEqual(EvaluationMetric.hallucinationRate.rawValue, "hallucination_rate")
        XCTAssertEqual(EvaluationMetric.citationAccuracy.rawValue, "citation_accuracy")
    }
}

// MARK: - APIPaths 常量完整性测试

final class APIPathsTests: XCTestCase {

    /// 验证认证 API 路径
    func testAuthAPIPaths() {
        XCTAssertEqual(APIPaths.refreshPath, "/api/v1/auth/refresh")
        XCTAssertEqual(APIPaths.logoutPath, "/api/v1/auth/logout")
        XCTAssertEqual(APIPaths.phoneLoginPath, "/api/v1/auth/login")
        XCTAssertEqual(APIPaths.smsSendPath, "/api/v1/auth/sms/send")
        XCTAssertEqual(APIPaths.oauthApplePath, "/api/v1/auth/oauth/apple")
        XCTAssertEqual(APIPaths.oauthWeChatPath, "/api/v1/auth/oauth/wechat")
        XCTAssertEqual(APIPaths.oauthGooglePath, "/api/v1/auth/oauth/google")
        XCTAssertEqual(APIPaths.oauthGitHubPath, "/api/v1/auth/oauth/github")
        XCTAssertEqual(APIPaths.carrierAuthPath, "/api/v1/auth/carrier")
    }

    /// 验证用户 API 路径
    func testUserAPIPaths() {
        XCTAssertEqual(APIPaths.userProfilePath, "/api/v1/user/profile")
        XCTAssertEqual(APIPaths.avatarUploadPath, "/api/v1/user/profile/avatar")
    }

    /// 验证订阅 API 路径
    func testSubscriptionAPIPaths() {
        XCTAssertEqual(APIPaths.subscriptionAppleVerifyPath, "/api/v1/subscriptions/apple/verify")
        XCTAssertEqual(APIPaths.subscriptionsMePath, "/api/v1/subscriptions/me")
    }

    /// 验证外部服务 URL
    func testExternalServiceURLs() {
        XCTAssertEqual(APIPaths.officialWebsite, "https://www.izhiyu.top")
        XCTAssertEqual(APIPaths.multiAvatarAPI, "https://api.multiavatar.com")
        XCTAssertTrue(APIPaths.gitHubOAuthAuthorize.hasPrefix("https://github.com/"))
    }

    /// 验证 LLM 提供商 URL
    func testLLMProviderURLs() {
        XCTAssertTrue(APIPaths.llmProviderZhipu.hasPrefix("https://"))
        XCTAssertTrue(APIPaths.llmProviderMinimax.hasPrefix("https://"))
        XCTAssertTrue(APIPaths.llmProviderQwen.hasPrefix("https://"))
        XCTAssertTrue(APIPaths.llmProviderDeepSeek.hasPrefix("https://"))
        XCTAssertTrue(APIPaths.llmProviderKimi.hasPrefix("https://"))
        XCTAssertTrue(APIPaths.llmProviderSiliconFlow.hasPrefix("https://"))
    }

    /// 验证模型下载 CDN URL
    func testModelCDNURLs() {
        XCTAssertTrue(APIPaths.cdnModelGemma.hasPrefix("https://"))
        XCTAssertTrue(APIPaths.cdnModelLlama.hasPrefix("https://"))
        XCTAssertTrue(APIPaths.cdnModelPhi.hasPrefix("https://"))
    }

    /// 验证 Web 存档与示例链接
    func testWebArchiveAndExampleLinks() {
        XCTAssertEqual(APIPaths.webArchivePrefix, "https://web.archive.org/web/2/")
        XCTAssertTrue(APIPaths.exampleKarpathyLLM.hasPrefix("https://github.com/"))
    }

    /// 验证本地开发地址
    func testLocalhostDefault() {
        XCTAssertEqual(APIPaths.localhostDefault, "http://localhost:8000")
    }

    /// 验证所有 API 路径以 /api/v1 开头
    func testAllAPIPathsStartWithApiV1() {
        let apiPaths = [
            APIPaths.refreshPath, APIPaths.logoutPath, APIPaths.phoneLoginPath,
            APIPaths.smsSendPath, APIPaths.oauthApplePath, APIPaths.oauthWeChatPath,
            APIPaths.oauthGooglePath, APIPaths.oauthGitHubPath, APIPaths.carrierAuthPath,
            APIPaths.userProfilePath, APIPaths.avatarUploadPath,
            APIPaths.subscriptionAppleVerifyPath, APIPaths.subscriptionsMePath
        ]
        for path in apiPaths {
            XCTAssertTrue(path.hasPrefix("/api/v1/"), "路径 \(path) 不以 /api/v1/ 开头")
        }
    }
}

// MARK: - DocumentFormat 测试

final class DocumentFormatSupplementTests: XCTestCase {

    /// 验证 detectFormat markdown
    func testDetectFormatMarkdown() {
        let url = URL(fileURLWithPath: "test.md")
        XCTAssertEqual(DocumentFormat.detectFormat(from: url), .markdown)
    }

    /// 验证 detectFormat markdownLong
    func testDetectFormatMarkdownLong() {
        let url = URL(fileURLWithPath: "test.markdown")
        XCTAssertEqual(DocumentFormat.detectFormat(from: url), .markdown)
    }

    /// 验证 detectFormat plainText
    func testDetectFormatPlainText() {
        let url = URL(fileURLWithPath: "test.txt")
        XCTAssertEqual(DocumentFormat.detectFormat(from: url), .plainText)
    }

    /// 验证 detectFormat textLong
    func testDetectFormatTextLong() {
        let url = URL(fileURLWithPath: "test.text")
        XCTAssertEqual(DocumentFormat.detectFormat(from: url), .plainText)
    }

    /// 验证 detectFormat docx
    func testDetectFormatDocx() {
        let url = URL(fileURLWithPath: "test.docx")
        XCTAssertEqual(DocumentFormat.detectFormat(from: url), .docx)
    }

    /// 验证 detectFormat xlsx
    func testDetectFormatXlsx() {
        let url = URL(fileURLWithPath: "test.xlsx")
        XCTAssertEqual(DocumentFormat.detectFormat(from: url), .xlsx)
    }

    /// 验证 detectFormat pdf
    func testDetectFormatPDF() {
        let url = URL(fileURLWithPath: "test.pdf")
        XCTAssertEqual(DocumentFormat.detectFormat(from: url), .pdf)
    }

    /// 验证 detectFormat unknown
    func testDetectFormatUnknown() {
        let url = URL(fileURLWithPath: "test.xyz")
        XCTAssertEqual(DocumentFormat.detectFormat(from: url), .unknown)
    }

    /// 验证 detectFormat 大写扩展名
    func testDetectFormatUppercaseExtension() {
        let url = URL(fileURLWithPath: "test.PDF")
        XCTAssertEqual(DocumentFormat.detectFormat(from: url), .pdf)
    }

    /// 验证 detectFormat 混合大小写扩展名
    func testDetectFormatMixedCaseExtension() {
        let url = URL(fileURLWithPath: "test.Md")
        XCTAssertEqual(DocumentFormat.detectFormat(from: url), .markdown)
    }

    /// 验证 detectFormat 无扩展名
    func testDetectFormatNoExtension() {
        let url = URL(fileURLWithPath: "test")
        XCTAssertEqual(DocumentFormat.detectFormat(from: url), .unknown)
    }
}

// MARK: - PageContentUtility 测试

final class PageContentUtilitySupplementTests: XCTestCase {

    /// 验证 calculateWordCount 空字符串
    func testCalculateWordCountEmpty() {
        XCTAssertEqual(PageContentUtility.calculateWordCount(""), 0)
    }

    /// 验证 calculateWordCount 纯英文
    func testCalculateWordCountEnglish() {
        let count = PageContentUtility.calculateWordCount("hello world test")
        XCTAssertGreaterThan(count, 0)
    }

    /// 验证 calculateWordCount 纯中文
    func testCalculateWordCountChinese() {
        let count = PageContentUtility.calculateWordCount("你好世界")
        XCTAssertGreaterThan(count, 0)
    }

    /// 验证 calculateWordCount 中英混排
    func testCalculateWordCountMixed() {
        let count = PageContentUtility.calculateWordCount("hello 世界 test 测试")
        XCTAssertGreaterThan(count, 0)
    }

    /// 验证 extractAllTags 仅 existingTags
    func testExtractAllTagsExistingOnly() {
        let tags = PageContentUtility.extractAllTags(content: "无标签内容", existingTags: ["tag1", "tag2"])
        XCTAssertEqual(tags, ["tag1", "tag2"])
    }

    /// 验证 extractAllTags 仅内容标签
    func testExtractAllTagsContentOnly() {
        let tags = PageContentUtility.extractAllTags(content: "内容 #标签1 #标签2", existingTags: [])
        XCTAssertEqual(tags, ["标签1", "标签2"])
    }

    /// 验证 extractAllTags 合并去重
    func testExtractAllTagsMergeAndDeduplicate() {
        let tags = PageContentUtility.extractAllTags(content: "#共享 #新标签", existingTags: ["共享", "旧标签"])
        XCTAssertEqual(tags, ["共享", "新标签", "旧标签"])
    }

    /// 验证 extractAllTags 排序
    func testExtractAllTagsSorted() {
        let tags = PageContentUtility.extractAllTags(content: "#zebra #apple #mango", existingTags: [])
        XCTAssertEqual(tags, ["apple", "mango", "zebra"])
    }

    /// 验证 extractAllTags 空内容
    func testExtractAllTagsEmptyContent() {
        let tags = PageContentUtility.extractAllTags(content: "", existingTags: [])
        XCTAssertTrue(tags.isEmpty)
    }

    /// 验证 extractAllTags 英文标签
    func testExtractAllTagsEnglishTags() {
        let tags = PageContentUtility.extractAllTags(content: "#hello #world", existingTags: [])
        XCTAssertEqual(tags, ["hello", "world"])
    }
}

// MARK: - LogEntry 测试

final class LogEntryTests: XCTestCase {

    /// 验证 LogEntry init 含默认值
    func testLogEntryInitWithDefaults() {
        let entry = LogEntry(action: .create, target: "页面A")
        XCTAssertNotNil(entry.id)
        XCTAssertEqual(entry.action, .create)
        XCTAssertEqual(entry.target, "页面A")
        XCTAssertEqual(entry.details, "")
        XCTAssertNotNil(entry.timestamp)
        XCTAssertNil(entry.duration)
        XCTAssertNil(entry.startTime)
        XCTAssertNil(entry.endTime)
        XCTAssertNil(entry.module)
        XCTAssertNil(entry.status)
        XCTAssertNil(entry.failureReason)
    }

    /// 验证 LogEntry init 含全部参数
    func testLogEntryInitWithAllParameters() {
        let id = UUID()
        let date = Date()
        let start = Date(timeIntervalSince1970: 1000)
        let end = Date(timeIntervalSince1970: 1005)
        let entry = LogEntry(
            id: id,
            action: .ingest,
            target: "target",
            details: "详情",
            timestamp: date,
            duration: 5.0,
            startTime: start,
            endTime: end,
            module: "Knowledge",
            status: .success,
            failureReason: "无"
        )
        XCTAssertEqual(entry.id, id)
        XCTAssertEqual(entry.action, .ingest)
        XCTAssertEqual(entry.details, "详情")
        XCTAssertEqual(entry.timestamp, date)
        XCTAssertEqual(entry.duration, 5.0)
        XCTAssertEqual(entry.startTime, start)
        XCTAssertEqual(entry.endTime, end)
        XCTAssertEqual(entry.module, "Knowledge")
        XCTAssertEqual(entry.status, .success)
        XCTAssertEqual(entry.failureReason, "无")
    }

    /// 验证 LogEntry Codable 往返
    func testLogEntryCodableRoundTrip() throws {
        let original = LogEntry(
            action: .lint,
            target: "查询",
            details: "搜索详情",
            duration: 1.5,
            module: "Search",
            status: .processing
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LogEntry.self, from: data)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.action, original.action)
        XCTAssertEqual(decoded.target, original.target)
        XCTAssertEqual(decoded.details, original.details)
        XCTAssertEqual(decoded.duration, original.duration)
        XCTAssertEqual(decoded.module, original.module)
        XCTAssertEqual(decoded.status, original.status)
    }

    /// 验证 LogEntry Identifiable
    func testLogEntryIdentifiable() {
        let entry = LogEntry(action: .create, target: "x")
        XCTAssertFalse(entry.id.uuidString.isEmpty)
    }

    /// 验证 LogEntry Sendable
    func testLogEntrySendable() {
        let entry = LogEntry(action: .create, target: "x")
        XCTAssertTrue(type(of: entry) is any Sendable.Type)
    }
}
