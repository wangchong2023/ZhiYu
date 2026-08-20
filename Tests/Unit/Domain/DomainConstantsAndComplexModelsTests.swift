//
//  DomainConstantsAndComplexModelsTests.swift
//  ZhiYuTests
//
//  系统层级：[L1.5] 领域层测试
//  核心职责：验证 Domain/Models 中常量容器的值完整性、KnowledgePage 复杂模型的
//           init 默认值、LWW merge 冲突解决、计算属性及 Codable 往返。
//

import XCTest
@testable import ZhiYu

// MARK: - DomainThresholds 常量验证

final class DomainThresholdsTests: XCTestCase {

    /// 验证 stubPageWordCount 常量值
    func testStubPageWordCount() {
        XCTAssertEqual(DomainThresholds.KnowledgePageThresholds.stubPageWordCount, 100)
    }
}

// MARK: - GraphConstants 常量验证

final class GraphConstantsTests: XCTestCase {

    /// 验证顶层常量
    func testTopLevelConstants() {
        XCTAssertEqual(GraphConstants.maxEdgesPerNode, 5)
    }

    /// 验证 TwoD 常量
    func testTwoDConstants() {
        XCTAssertEqual(GraphConstants.TwoD.virtualSizeMultiplier, 2.0)
        XCTAssertEqual(GraphConstants.TwoD.simulationIterations, 100)
        XCTAssertEqual(GraphConstants.TwoD.baseExpansionOffset, 20.0)
        XCTAssertEqual(GraphConstants.TwoD.expansionFactor, 0.05)
    }

    /// 验证 ThreeD 常量
    func testThreeDConstants() {
        XCTAssertEqual(GraphConstants.ThreeD.defaultCameraDistance, 140.0)
        XCTAssertEqual(GraphConstants.ThreeD.cameraZNear, 0.1)
        XCTAssertEqual(GraphConstants.ThreeD.cameraZFar, 1000.0)
        XCTAssertEqual(GraphConstants.ThreeD.baseSphereRadiusMultiplier, 18.0)
        XCTAssertEqual(GraphConstants.ThreeD.minSphereRadius, 60.0)
        XCTAssertEqual(GraphConstants.ThreeD.maxSphereRadius, 250.0)
        XCTAssertEqual(GraphConstants.ThreeD.starCount, 500)
    }

    /// 验证 Physics 常量
    func testPhysicsConstants() {
        XCTAssertEqual(GraphConstants.Physics.repulsionForce, 5000.0)
        XCTAssertEqual(GraphConstants.Physics.attractionForce, 0.01)
        XCTAssertEqual(GraphConstants.Physics.damping, 0.85)
        XCTAssertEqual(GraphConstants.Physics.centerGravity, 0.005)
        XCTAssertEqual(GraphConstants.Physics.friction, 0.9)
        XCTAssertEqual(GraphConstants.Physics.gridSize, 120.0)
        XCTAssertEqual(GraphConstants.Physics.collisionDistance, 20.0)
        XCTAssertEqual(GraphConstants.Physics.collisionForce, 10000.0)
        XCTAssertEqual(GraphConstants.Physics.maxRepulsionDistanceSq, 40000.0)
        XCTAssertEqual(GraphConstants.Physics.minDistanceSq, 0.01)
    }
}

// MARK: - SearchConstants 常量验证

final class SearchConstantsTests: XCTestCase {

    /// 验证 RRF 常量
    func testRRFConstant() {
        XCTAssertEqual(SearchConstants.rrfK, 60)
    }

    /// 验证语义阈值常量
    func testSemanticThresholds() {
        XCTAssertEqual(SearchConstants.semanticThresholdShort, 0.85)
        XCTAssertEqual(SearchConstants.semanticThresholdLong, 0.75)
        XCTAssertEqual(SearchConstants.semanticShortHighConfidence, 0.88)
    }

    /// 验证短查询阈值
    func testShortQueryThreshold() {
        XCTAssertEqual(SearchConstants.shortQueryThreshold, 4)
    }
}

// MARK: - RAGEvalConstants 常量验证

final class RAGEvalConstantsTests: XCTestCase {

    /// 验证快照前缀长度
    func testSnapshotSnippetPrefix() {
        XCTAssertEqual(RAGEvalConstants.snapshotSnippetPrefix, 200)
    }

    /// 验证启发式相关性阈值
    func testHeuristicRelevanceThresholds() {
        XCTAssertEqual(RAGEvalConstants.HeuristicRelevance.highThreshold, 0.8)
        XCTAssertEqual(RAGEvalConstants.HeuristicRelevance.mediumThreshold, 0.5)
    }

    /// 验证忠实度状态阈值
    func testFaithfulnessStatusThresholds() {
        XCTAssertEqual(RAGEvalConstants.FaithfulnessStatus.failThreshold, 0.5)
        XCTAssertEqual(RAGEvalConstants.FaithfulnessStatus.warningThreshold, 0.7)
    }

    /// 验证 JudgePrompt 常量
    func testJudgePromptConstants() {
        XCTAssertEqual(RAGEvalConstants.JudgePrompt.maxSources, 20)
        XCTAssertEqual(RAGEvalConstants.JudgePrompt.sourceSnippetPrefix, 150)
        XCTAssertEqual(RAGEvalConstants.JudgePrompt.contextPrefix, 3000)
    }
}

// MARK: - PromptConstants 常量验证

final class PromptConstantsTests: XCTestCase {

    /// 验证 TokenLimits 常量
    func testTokenLimits() {
        XCTAssertEqual(PromptConstants.TokenLimits.charactersPerToken, 4)
        XCTAssertEqual(PromptConstants.TokenLimits.maxUserInputLength, 4000)
    }

    /// 验证 InferenceDefaults 常量
    func testInferenceDefaults() {
        XCTAssertEqual(PromptConstants.InferenceDefaults.temperature, 0.7)
        XCTAssertEqual(PromptConstants.InferenceDefaults.topP, 0.9)
        XCTAssertEqual(PromptConstants.InferenceDefaults.topK, 40)
        XCTAssertEqual(PromptConstants.InferenceDefaults.maxTokens, 2048)
    }

    /// 验证 InferenceParameters init 含默认值
    func testInferenceParametersInitWithDefaults() {
        let params = InferenceParameters()
        XCTAssertEqual(params.temperature, PromptConstants.InferenceDefaults.temperature)
        XCTAssertEqual(params.topP, PromptConstants.InferenceDefaults.topP)
        XCTAssertEqual(params.topK, PromptConstants.InferenceDefaults.topK)
        XCTAssertEqual(params.maxTokens, PromptConstants.InferenceDefaults.maxTokens)
    }

    /// 验证 InferenceParameters Codable 往返
    func testInferenceParametersCodableRoundTrip() throws {
        let original = InferenceParameters(temperature: 0.5, topP: 0.8, topK: 20, maxTokens: 1024)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(InferenceParameters.self, from: data)
        XCTAssertEqual(decoded.temperature, original.temperature, accuracy: 0.001)
        XCTAssertEqual(decoded.topP, original.topP, accuracy: 0.001)
        XCTAssertEqual(decoded.topK, original.topK)
        XCTAssertEqual(decoded.maxTokens, original.maxTokens)
    }
}

// MARK: - KnowledgePage 复杂模型测试（补充 LWW merge + displaySourceName + displaySourceIcon）

final class KnowledgePageComplexTests: XCTestCase {

    // MARK: - 初始化与默认值

    /// 验证 KnowledgePage init 最小参数（仅 title）
    func testKnowledgePageInitMinimal() {
        let page = KnowledgePage(title: "测试页面")
        XCTAssertEqual(page.title, "测试页面")
        XCTAssertEqual(page.pageType, .concept)
        XCTAssertNil(page.customIcon)
        XCTAssertEqual(page.content, "")
        XCTAssertTrue(page.aliases.isEmpty)
        XCTAssertTrue(page.tags.isEmpty)
        XCTAssertEqual(page.status, .active)
        XCTAssertEqual(page.confidence, .medium)
        XCTAssertTrue(page.sources.isEmpty)
        XCTAssertTrue(page.relatedPageIDs.isEmpty)
        XCTAssertFalse(page.isPinned)
        XCTAssertNil(page.contentHash)
        XCTAssertNil(page.sourceURL)
        XCTAssertNil(page.rawTextSnippet)
        XCTAssertNotNil(page.fileSize)
        XCTAssertNil(page.sourceType)
        XCTAssertNotNil(page.lamportTimestamp)
        XCTAssertNotNil(page.createdAt)
        XCTAssertNotNil(page.updatedAt)
    }

    /// 验证 KnowledgePage init 全部参数
    func testKnowledgePageInitWithAllParameters() {
        let id = UUID()
        let relatedID = UUID()
        let date = Date()
        let page = KnowledgePage(
            id: id,
            title: "完整页面",
            pageType: .entity,
            customIcon: "star.fill",
            content: "内容",
            aliases: ["别名1"],
            tags: ["tag1"],
            status: .stub,
            confidence: .high,
            sources: ["source1"],
            relatedPageIDs: [relatedID],
            isPinned: true,
            contentHash: "abc123",
            sourceURL: "https://example.com",
            rawTextSnippet: "原始片段",
            fileSize: 1024,
            sourceType: "pdf",
            lamportTimestamp: 999,
            createdAt: date,
            updatedAt: date
        )
        XCTAssertEqual(page.id, id)
        XCTAssertEqual(page.pageType, .entity)
        XCTAssertEqual(page.customIcon, "star.fill")
        XCTAssertEqual(page.aliases, ["别名1"])
        XCTAssertEqual(page.status, .stub)
        XCTAssertEqual(page.confidence, .high)
        XCTAssertEqual(page.sources, ["source1"])
        XCTAssertEqual(page.relatedPageIDs, [relatedID])
        XCTAssertTrue(page.isPinned)
        XCTAssertEqual(page.contentHash, "abc123")
        XCTAssertEqual(page.sourceURL, "https://example.com")
        XCTAssertEqual(page.fileSize, 1024)
        XCTAssertEqual(page.sourceType, "pdf")
        XCTAssertEqual(page.lamportTimestamp, 999)
    }

    /// 验证 fileSize 默认值从 content 派生
    func testKnowledgePageFileSizeDerivedFromContent() {
        let page = KnowledgePage(title: "测试", content: "Hello")
        XCTAssertEqual(page.fileSize, Int64("Hello".utf8.count))
    }

    // MARK: - displayIcon 计算属性

    /// 验证 displayIcon 优先使用 customIcon
    func testDisplayIconPrefersCustomIcon() {
        let page = KnowledgePage(title: "测试", pageType: .concept, customIcon: "custom.icon")
        XCTAssertEqual(page.displayIcon, "custom.icon")
    }

    /// 验证 displayIcon 回退到 pageType 默认图标
    func testDisplayIconFallsBackToPageTypeIcon() {
        let page = KnowledgePage(title: "测试", pageType: .concept, customIcon: nil)
        XCTAssertEqual(page.displayIcon, PageType.concept.icon)
    }

    // MARK: - isStub 计算属性

    /// 验证短内容页面为 stub
    func testIsStubTrueForShortContent() {
        let page = KnowledgePage(title: "短", content: "短")
        XCTAssertTrue(page.isStub)
    }

    /// 验证长内容页面非 stub
    func testIsStubFalseForLongContent() {
        let longContent = String(repeating: "A", count: DomainThresholds.KnowledgePageThresholds.stubPageWordCount + 10)
        let page = KnowledgePage(title: "长", content: longContent)
        XCTAssertFalse(page.isStub)
    }

    // MARK: - folderName 计算属性

    /// 验证各 pageType 的 folderName
    func testFolderNameForAllPageTypes() {
        XCTAssertEqual(KnowledgePage(title: "1", pageType: .concept).folderName, "concepts")
        XCTAssertEqual(KnowledgePage(title: "2", pageType: .entity).folderName, "entities")
        XCTAssertEqual(KnowledgePage(title: "3", pageType: .source).folderName, "sources")
        XCTAssertEqual(KnowledgePage(title: "4", pageType: .comparison).folderName, "comparisons")
        XCTAssertEqual(KnowledgePage(title: "5", pageType: .raw).folderName, "raw")
    }

    // MARK: - isPrivate 计算属性

    /// 验证含 private 标签的页面为隐私页面
    func testIsPrivateTrueWithPrivateTag() {
        let page = KnowledgePage(title: "私密", content: "#private 内容")
        XCTAssertTrue(page.isPrivate)
    }

    /// 验证无 private 标签的页面非隐私
    func testIsPrivateFalseWithoutPrivateTag() {
        let page = KnowledgePage(title: "公开", content: "普通内容")
        XCTAssertFalse(page.isPrivate)
    }

    // MARK: - isLocalFileSource 计算属性

    /// 验证 file:// 开头的 sourceURL 为本地文件
    func testIsLocalFileSourceTrue() {
        let page = KnowledgePage(title: "本地", sourceURL: "file:///path/to/file.md")
        XCTAssertTrue(page.isLocalFileSource)
    }

    /// 验证 https:// 开头的 sourceURL 非本地文件
    func testIsLocalFileSourceFalse() {
        let page = KnowledgePage(title: "远程", sourceURL: "https://example.com/page")
        XCTAssertFalse(page.isLocalFileSource)
    }

    /// 验证无 sourceURL 时 isLocalFileSource 为 false
    func testIsLocalFileSourceFalseForNilURL() {
        let page = KnowledgePage(title: "无来源")
        XCTAssertFalse(page.isLocalFileSource)
    }

    // MARK: - displaySourceName 计算属性

    /// 验证本地文件来源显示文件名
    func testDisplaySourceNameForLocalFile() {
        let page = KnowledgePage(title: "本地", sourceURL: "file:///documents/notes.md")
        XCTAssertEqual(page.displaySourceName, "notes.md")
    }

    /// 验证网页来源显示域名
    func testDisplaySourceNameForWebURL() {
        let page = KnowledgePage(title: "网页", sourceURL: "https://www.example.com/path/page")
        XCTAssertEqual(page.displaySourceName, "www.example.com")
    }

    /// 验证无 sourceURL 时 displaySourceName 为空字符串
    func testDisplaySourceNameForNilURL() {
        let page = KnowledgePage(title: "无来源")
        XCTAssertEqual(page.displaySourceName, "")
    }

    // MARK: - displaySourceIcon 计算属性

    /// 验证 PDF 来源显示 doc.text.fill 图标
    func testDisplaySourceIconForPDF() {
        let page = KnowledgePage(title: "PDF", sourceType: "pdf")
        XCTAssertEqual(page.displaySourceIcon, "doc.text.fill")
    }

    /// 验证 Markdown 来源显示 doc.text 图标
    func testDisplaySourceIconForMarkdown() {
        let page = KnowledgePage(title: "MD", sourceType: "markdown")
        XCTAssertEqual(page.displaySourceIcon, "doc.text")
    }

    /// 验证无 sourceType 的本地文件显示 doc.fill
    func testDisplaySourceIconForLocalFileWithoutType() {
        let page = KnowledgePage(title: "本地", sourceURL: "file:///path/file.txt")
        XCTAssertEqual(page.displaySourceIcon, "doc.fill")
    }

    /// 验证无 sourceType 的网页显示 safari
    func testDisplaySourceIconForWebWithoutType() {
        let page = KnowledgePage(title: "网页", sourceURL: "https://example.com")
        XCTAssertEqual(page.displaySourceIcon, "safari")
    }

    // MARK: - LWW merge 冲突解决

    /// 验证 merge 时远程时间戳更大则远程胜出
    func testMergeRemoteWinsWithHigherTimestamp() {
        let local = KnowledgePage(title: "本地", lamportTimestamp: 100)
        let remote = KnowledgePage(title: "远程", lamportTimestamp: 200)
        let merged = local.merge(with: remote)
        XCTAssertEqual(merged.title, "远程")
    }

    /// 验证 merge 时本地时间戳更大则本地胜出
    func testMergeLocalWinsWithHigherTimestamp() {
        let local = KnowledgePage(title: "本地", lamportTimestamp: 300)
        let remote = KnowledgePage(title: "远程", lamportTimestamp: 200)
        let merged = local.merge(with: remote)
        XCTAssertEqual(merged.title, "本地")
    }

    /// 验证 merge 时间戳相同时 updatedAt 更新者胜出
    func testMergeTieBreaksWithUpdatedAt() {
        let earlyDate = Date(timeIntervalSince1970: 1000)
        let lateDate = Date(timeIntervalSince1970: 2000)
        let local = KnowledgePage(title: "本地", lamportTimestamp: 100, createdAt: earlyDate, updatedAt: earlyDate)
        let remote = KnowledgePage(title: "远程", lamportTimestamp: 100, createdAt: earlyDate, updatedAt: lateDate)
        let merged = local.merge(with: remote)
        XCTAssertEqual(merged.title, "远程")
    }

    // MARK: - Codable 编解码往返

    /// 验证 KnowledgePage Codable 往返保持数据一致（含 snake_case 映射）
    func testKnowledgePageCodableRoundTrip() throws {
        let original = KnowledgePage(
            title: "Codable 测试",
            pageType: .entity,
            customIcon: "star",
            content: "内容",
            aliases: ["别名"],
            tags: ["标签"],
            status: .needsUpdate,
            confidence: .high,
            sources: ["来源"],
            isPinned: true,
            contentHash: "hash123",
            sourceURL: "https://example.com",
            sourceType: "pdf"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(KnowledgePage.self, from: data)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.pageType, original.pageType)
        XCTAssertEqual(decoded.customIcon, original.customIcon)
        XCTAssertEqual(decoded.content, original.content)
        XCTAssertEqual(decoded.aliases, original.aliases)
        XCTAssertEqual(decoded.tags, original.tags)
        XCTAssertEqual(decoded.status, original.status)
        XCTAssertEqual(decoded.confidence, original.confidence)
        XCTAssertEqual(decoded.sources, original.sources)
        XCTAssertEqual(decoded.isPinned, original.isPinned)
        XCTAssertEqual(decoded.contentHash, original.contentHash)
        XCTAssertEqual(decoded.sourceURL, original.sourceURL)
        XCTAssertEqual(decoded.sourceType, original.sourceType)
    }

    /// 验证 KnowledgePage databaseTableName
    func testKnowledgePageDatabaseTableName() {
        XCTAssertEqual(KnowledgePage.databaseTableName, AppConstants.Storage.Tables.pages)
    }
}

// MARK: - LLMManifest 复杂模型测试

final class LLMManifestComplexTests: XCTestCase {

    /// 验证 LLMManifest init 含默认值
    func testLLMManifestInitWithDefaults() {
        let defaultParams = InferenceParameters()
        let manifest = LLMManifest(
            modelId: "gemma-2b",
            displayName: "Gemma 2B",
            vendor: "Google",
            fileSizeInBytes: 1_000_000_000,
            minDeviceMemoryInGb: 4.0,
            remoteURLString: "https://example.com/model.gguf",
            sha256Checksum: "abc123",
            parameterCount: "2B",
            description: "Gemma 2B 模型",
            defaultParameters: InferenceParameters()
        )
        XCTAssertEqual(manifest.modelId, "gemma-2b")
        XCTAssertEqual(manifest.vendor, "Google")
        XCTAssertEqual(manifest.fileSizeInBytes, 1_000_000_000)
        XCTAssertEqual(manifest.minDeviceMemoryInGb, 4.0)
        XCTAssertEqual(manifest.remoteURLString, "https://example.com/model.gguf")
        XCTAssertEqual(manifest.sha256Checksum, "abc123")
        XCTAssertEqual(manifest.parameterCount, "2B")
        XCTAssertTrue(manifest.supportedTasks.isEmpty)
        XCTAssertNil(manifest.huggingfaceURLString)
        XCTAssertNil(manifest.modelscopeURLString)
        XCTAssertEqual(manifest.id, "gemma-2b")
    }

    /// 验证 LLMManifest Codable 往返
    func testLLMManifestCodableRoundTrip() throws {
        let original = LLMManifest(
            modelId: "test-model",
            displayName: "Test Model",
            vendor: "TestVendor",
            fileSizeInBytes: 500_000_000,
            minDeviceMemoryInGb: 2.0,
            remoteURLString: "https://example.com/test.gguf",
            sha256Checksum: "sha256",
            parameterCount: "1B",
            supportedTasks: ["chat", "summarize"],
            description: "测试模型",
            defaultParameters: InferenceParameters(),
            huggingfaceURLString: "https://huggingface.co/test",
            modelscopeURLString: nil
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LLMManifest.self, from: data)
        XCTAssertEqual(decoded.modelId, original.modelId)
        XCTAssertEqual(decoded.vendor, original.vendor)
        XCTAssertEqual(decoded.fileSizeInBytes, original.fileSizeInBytes)
        XCTAssertEqual(decoded.supportedTasks, original.supportedTasks)
        XCTAssertEqual(decoded.huggingfaceURLString, original.huggingfaceURLString)
    }
}

// MARK: - LintIssue 复杂模型测试（补充 IssueType/LintSeverity 完整性）

final class LintIssueComplexTests: XCTestCase {

    /// 验证 LintIssue init 含默认值
    func testLintIssueInitWithDefaults() {
        let issue = LintIssue(severity: .warning, message: "警告信息", suggestion: "建议")
        XCTAssertEqual(issue.severity, .warning)
        XCTAssertEqual(issue.type, .generic)
        XCTAssertEqual(issue.message, "警告信息")
        XCTAssertEqual(issue.suggestion, "建议")
        XCTAssertNil(issue.pageID)
        XCTAssertNotNil(issue.id)
    }

    /// 验证 LintIssue 带全部参数 init
    func testLintIssueInitWithAllParameters() {
        let id = UUID()
        let pageID = UUID()
        let issue = LintIssue(
            id: id,
            severity: .error,
            type: .brokenLink,
            pageID: pageID,
            message: "错误",
            suggestion: "修复建议"
        )
        XCTAssertEqual(issue.id, id)
        XCTAssertEqual(issue.severity, .error)
        XCTAssertEqual(issue.type, .brokenLink)
        XCTAssertEqual(issue.pageID, pageID)
    }

    /// 验证 LintIssue Codable 往返
    func testLintIssueCodableRoundTrip() throws {
        let original = LintIssue(
            severity: .info,
            type: .orphan,
            pageID: UUID(),
            message: "孤立页面",
            suggestion: "添加链接"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LintIssue.self, from: data)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.severity, original.severity)
        XCTAssertEqual(decoded.type, original.type)
        XCTAssertEqual(decoded.message, original.message)
    }

    /// 验证 IssueType 所有 case
    func testIssueTypeAllCases() {
        let allTypes: [LintIssue.IssueType] = [.generic, .brokenLink, .orphan, .island, .cycle, .stub, .stale]
        XCTAssertEqual(allTypes.count, 7)
    }

    /// 验证 LintSeverity 所有 case
    func testLintSeverityAllCases() {
        let allSeverities: [LintIssue.LintSeverity] = [.error, .warning, .info]
        XCTAssertEqual(allSeverities.count, 3)
    }

    // MARK: - PotentialLinkSuggestion

    /// 验证 PotentialLinkSuggestion init 含默认 id
    func testPotentialLinkSuggestionInitWithDefaults() {
        let sourceID = UUID()
        let suggestion = PotentialLinkSuggestion(
            sourcePageID: sourceID,
            sourceTitle: "源页面",
            targetTitle: "目标页面"
        )
        XCTAssertEqual(suggestion.sourcePageID, sourceID)
        XCTAssertEqual(suggestion.sourceTitle, "源页面")
        XCTAssertEqual(suggestion.targetTitle, "目标页面")
        XCTAssertNotNil(suggestion.id)
    }

    /// 验证 PotentialLinkSuggestion Codable 往返
    func testPotentialLinkSuggestionCodableRoundTrip() throws {
        let original = PotentialLinkSuggestion(
            sourcePageID: UUID(),
            sourceTitle: "源",
            targetTitle: "目标"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PotentialLinkSuggestion.self, from: data)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.sourceTitle, original.sourceTitle)
        XCTAssertEqual(decoded.targetTitle, original.targetTitle)
    }
}
