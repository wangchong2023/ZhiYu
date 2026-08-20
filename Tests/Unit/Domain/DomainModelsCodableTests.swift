//
//  DomainModelsCodableTests.swift
//  ZhiYuTests
//
//  系统层级：[L1.5] 领域层测试
//  核心职责：验证 Domain/Models 中纯数据模型的 Codable 编解码往返、
//           属性默认值、Equatable 判定及自定义 CodingKeys 映射。
//

import XCTest
@testable import ZhiYu

// MARK: - AgentSkill 单元测试

final class AgentSkillTests: XCTestCase {

    // MARK: - 初始化与默认值

    /// 验证 AgentSkill init 正确赋值所有属性（含默认值）
    func testAgentSkillInitWithDefaults() {
        let skill = AgentSkill(
            skillId: "summarize",
            displayName: "摘要生成",
            description: "生成文本摘要",
            systemPromptTemplate: "请总结以下内容"
        )
        XCTAssertEqual(skill.skillId, "summarize")
        XCTAssertEqual(skill.displayName, "摘要生成")
        XCTAssertEqual(skill.description, "生成文本摘要")
        XCTAssertEqual(skill.systemPromptTemplate, "请总结以下内容")
        XCTAssertNil(skill.remotePromptURLString)
        XCTAssertNil(skill.remotePromptSHA256)
        XCTAssertNil(skill.inputSchema)
        XCTAssertTrue(skill.tags.isEmpty)
        XCTAssertNil(skill.customParameters)
        XCTAssertEqual(skill.version, "1.0.0")
        XCTAssertEqual(skill.id, "summarize")
    }

    /// 验证 AgentSkill 带全部参数的 init
    func testAgentSkillInitWithAllParameters() {
        let skill = AgentSkill(
            skillId: "translate",
            displayName: "翻译",
            description: "多语言翻译",
            systemPromptTemplate: "翻译以下文本",
            remotePromptURLString: "https://example.com/prompt.txt",
            remotePromptSHA256: "abc123",
            inputSchema: "{\"type\":\"object\"}",
            tags: ["translation", "multi-lang"],
            customParameters: nil,
            version: "2.0.0"
        )
        XCTAssertEqual(skill.remotePromptURLString, "https://example.com/prompt.txt")
        XCTAssertEqual(skill.remotePromptSHA256, "abc123")
        XCTAssertEqual(skill.inputSchema, "{\"type\":\"object\"}")
        XCTAssertEqual(skill.tags, ["translation", "multi-lang"])
        XCTAssertEqual(skill.version, "2.0.0")
    }

    // MARK: - Codable 编解码往返

    /// 验证 AgentSkill Codable 往返保持数据一致
    func testAgentSkillCodableRoundTrip() throws {
        let original = AgentSkill(
            skillId: "quiz",
            displayName: "测验",
            description: "生成测验题",
            systemPromptTemplate: "请生成测验",
            tags: ["education"],
            version: "1.5.0"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AgentSkill.self, from: data)
        XCTAssertEqual(decoded.skillId, original.skillId)
        XCTAssertEqual(decoded.displayName, original.displayName)
        XCTAssertEqual(decoded.tags, original.tags)
        XCTAssertEqual(decoded.version, original.version)
    }

    // MARK: - Equatable 判定

    /// 验证相同 skillId 的 AgentSkill 相等
    func testAgentSkillEquality() {
        let a = AgentSkill(skillId: "x", displayName: "X", description: "", systemPromptTemplate: "")
        let b = AgentSkill(skillId: "x", displayName: "X", description: "", systemPromptTemplate: "")
        XCTAssertEqual(a, b)
    }

    /// 验证不同 skillId 的 AgentSkill 不相等
    func testAgentSkillInequality() {
        let a = AgentSkill(skillId: "x", displayName: "X", description: "", systemPromptTemplate: "")
        let b = AgentSkill(skillId: "y", displayName: "Y", description: "", systemPromptTemplate: "")
        XCTAssertNotEqual(a, b)
    }
}

// MARK: - AgentTool 单元测试（补充 Codable 往返）

final class AgentToolCodableTests: XCTestCase {

    /// 验证 AgentTool init 正确赋值（含默认 version）
    func testAgentToolInitWithDefaults() {
        let tool = AgentTool(
            toolName: "search",
            description: "搜索工具",
            parametersSchema: "{\"type\":\"object\"}"
        )
        XCTAssertEqual(tool.toolName, "search")
        XCTAssertEqual(tool.description, "搜索工具")
        XCTAssertEqual(tool.parametersSchema, "{\"type\":\"object\"}")
        XCTAssertEqual(tool.version, "1.0.0")
        XCTAssertEqual(tool.id, "search")
    }

    /// 验证 AgentTool Codable 往返
    func testAgentToolCodableRoundTrip() throws {
        let original = AgentTool(
            toolName: "calc",
            description: "计算器",
            parametersSchema: "{}",
            version: "3.0.0"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AgentTool.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}

// MARK: - AITaskProgress 单元测试

final class AITaskProgressTests: XCTestCase {

    /// 验证 AITaskMetadata init
    func testAITaskMetadataInit() {
        let date = Date()
        let metadata = AITaskMetadata(taskName: "embedding", startTime: date)
        XCTAssertEqual(metadata.taskName, "embedding")
        XCTAssertEqual(metadata.startTime, date)
    }

    /// 验证 AITaskProgressState init
    func testAITaskProgressStateInit() {
        let state = AITaskProgressState(progress: 0.75, status: "处理中")
        XCTAssertEqual(state.progress, 0.75, accuracy: 0.001)
        XCTAssertEqual(state.status, "处理中")
    }

    /// 验证 AITaskMetadata Codable 往返
    func testAITaskMetadataCodableRoundTrip() throws {
        let original = AITaskMetadata(taskName: "chunk", startTime: Date())
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AITaskMetadata.self, from: data)
        XCTAssertEqual(decoded.taskName, original.taskName)
        XCTAssertEqual(decoded.startTime, original.startTime)
    }

    /// 验证 AITaskProgressState Codable 往返
    func testAITaskProgressStateCodableRoundTrip() throws {
        let original = AITaskProgressState(progress: 0.5, status: "半完成")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AITaskProgressState.self, from: data)
        XCTAssertEqual(decoded.progress, original.progress, accuracy: 0.001)
        XCTAssertEqual(decoded.status, original.status)
    }
}

// MARK: - KnowledgePageFTS 单元测试（补充 Codable 往返）

final class KnowledgePageFTSCodableTests: XCTestCase {

    /// 验证 KnowledgePageFTS init 正确赋值
    func testKnowledgePageFTSInit() {
        let fts = KnowledgePageFTS(
            id: "page-1",
            title: "测试页面",
            content: "这是测试内容"
        )
        XCTAssertEqual(fts.id, "page-1")
        XCTAssertEqual(fts.title, "测试页面")
        XCTAssertEqual(fts.content, "这是测试内容")
        XCTAssertNil(fts.tags)
        XCTAssertNil(fts.aliases)
    }

    /// 验证 KnowledgePageFTS 带可选参数 init
    func testKnowledgePageFTSInitWithOptionals() {
        let fts = KnowledgePageFTS(
            id: "page-2",
            title: "带标签页面",
            content: "内容",
            tags: "swift,ios",
            aliases: "别名1,别名2"
        )
        XCTAssertEqual(fts.tags, "swift,ios")
        XCTAssertEqual(fts.aliases, "别名1,别名2")
    }

    /// 验证 KnowledgePageFTS Codable 往返
    func testKnowledgePageFTSCodableRoundTrip() throws {
        let original = KnowledgePageFTS(
            id: "fts-1",
            title: "标题",
            content: "内容",
            tags: "tag1",
            aliases: "alias1"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(KnowledgePageFTS.self, from: data)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.content, original.content)
        XCTAssertEqual(decoded.tags, original.tags)
        XCTAssertEqual(decoded.aliases, original.aliases)
    }
}

// MARK: - PageLink 单元测试

final class PageLinkTests: XCTestCase {

    /// 验证 PageLink init 正确赋值（含默认值）
    func testPageLinkInitWithDefaults() {
        let source = UUID()
        let target = UUID()
        let link = PageLink(sourceID: source, targetID: target)
        XCTAssertEqual(link.sourceID, source)
        XCTAssertEqual(link.targetID, target)
        XCTAssertNil(link.context)
        XCTAssertNotNil(link.createdAt)
    }

    /// 验证 PageLink 带全部参数 init
    func testPageLinkInitWithAllParameters() {
        let source = UUID()
        let target = UUID()
        let date = Date()
        let link = PageLink(sourceID: source, targetID: target, context: "引用上下文", createdAt: date)
        XCTAssertEqual(link.context, "引用上下文")
        XCTAssertEqual(link.createdAt, date)
    }

    /// 验证 PageLink Codable 往返（含 snake_case 映射）
    func testPageLinkCodableRoundTrip() throws {
        let original = PageLink(
            sourceID: UUID(),
            targetID: UUID(),
            context: "上下文",
            createdAt: Date()
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PageLink.self, from: data)
        XCTAssertEqual(decoded.sourceID, original.sourceID)
        XCTAssertEqual(decoded.targetID, original.targetID)
        XCTAssertEqual(decoded.context, original.context)
        XCTAssertEqual(decoded.createdAt, original.createdAt)
    }

    /// 验证 PageLink Hashable（用于 Set 去重）
    func testPageLinkHashable() {
        let source = UUID()
        let target = UUID()
        let date1 = Date(timeIntervalSince1970: 1000)
        let date2 = Date(timeIntervalSince1970: 2000)
        let link1 = PageLink(sourceID: source, targetID: target, createdAt: date1)
        let link2 = PageLink(sourceID: source, targetID: target, createdAt: date2)
        let set: Set<PageLink> = [link1, link2]
        XCTAssertEqual(set.count, 2, "不同 createdAt 的 PageLink 应视为不同")
    }
}

// MARK: - PluginRecord 单元测试（补充 Codable 往返）

final class PluginRecordCodableTests: XCTestCase {

    /// 验证 PluginRecord init 正确赋值（含默认值）
    func testPluginRecordInitWithDefaults() {
        let record = PluginRecord(
            id: "plugin-1",
            name: "测试插件",
            version: "1.0.0",
            author: "开发者",
            source: "local",
            status: "active",
            permissionsJSON: "[]"
        )
        XCTAssertEqual(record.id, "plugin-1")
        XCTAssertEqual(record.name, "测试插件")
        XCTAssertEqual(record.version, "1.0.0")
        XCTAssertEqual(record.author, "开发者")
        XCTAssertEqual(record.source, "local")
        XCTAssertEqual(record.status, "active")
        XCTAssertEqual(record.permissionsJSON, "[]")
        XCTAssertEqual(record.loadDuration, 0.0)
        XCTAssertEqual(record.unloadDuration, 0.0)
        XCTAssertEqual(record.totalExecutionTime, 0.0)
        XCTAssertEqual(record.callCount, 0)
        XCTAssertEqual(record.manifestJSON, "")
        XCTAssertNotNil(record.installedAt)
        XCTAssertNotNil(record.updatedAt)
    }

    /// 验证 PluginRecord Codable 往返（含 snake_case 映射）
    func testPluginRecordCodableRoundTrip() throws {
        let original = PluginRecord(
            id: "p-2",
            name: "插件",
            version: "2.0",
            author: "作者",
            source: "remote",
            status: "disabled",
            permissionsJSON: "[\"storage\"]",
            loadDuration: 1.5,
            unloadDuration: 0.3,
            totalExecutionTime: 100.0,
            callCount: 42,
            manifestJSON: "{\"name\":\"插件\"}"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PluginRecord.self, from: data)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.loadDuration, original.loadDuration, accuracy: 0.001)
        XCTAssertEqual(decoded.callCount, original.callCount)
        XCTAssertEqual(decoded.manifestJSON, original.manifestJSON)
    }
}

// MARK: - PluginRecordFTS 单元测试（补充 Equatable + Codable）

final class PluginRecordFTSCodableTests: XCTestCase {

    /// 验证 PluginRecordFTS init
    func testPluginRecordFTSInit() {
        let fts = PluginRecordFTS(
            id: "fts-1",
            name: "搜索插件",
            author: "作者",
            description: "描述"
        )
        XCTAssertEqual(fts.id, "fts-1")
        XCTAssertEqual(fts.name, "搜索插件")
        XCTAssertEqual(fts.author, "作者")
        XCTAssertEqual(fts.description, "描述")
    }

    /// 验证 PluginRecordFTS Codable 往返
    func testPluginRecordFTSCodableRoundTrip() throws {
        let original = PluginRecordFTS(
            id: "fts-2",
            name: "名称",
            author: "作者",
            description: "描述文本"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PluginRecordFTS.self, from: data)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.author, original.author)
        XCTAssertEqual(decoded.description, original.description)
    }
}

// MARK: - SearchDiagnosticInfo 单元测试

final class SearchDiagnosticInfoTests: XCTestCase {

    /// 验证 SearchDiagnosticInfo init（含默认 id）
    func testSearchDiagnosticInfoInitWithDefaults() {
        let info = SearchDiagnosticInfo(
            query: "测试查询",
            rewrittenQuery: "重写查询",
            ftsCount: 10,
            vectorCount: 5,
            rrfTopResults: []
        )
        XCTAssertEqual(info.query, "测试查询")
        XCTAssertEqual(info.rewrittenQuery, "重写查询")
        XCTAssertEqual(info.ftsCount, 10)
        XCTAssertEqual(info.vectorCount, 5)
        XCTAssertTrue(info.rrfTopResults.isEmpty)
        XCTAssertNotNil(info.id)
    }

    /// 验证 ResultScore init
    func testResultScoreInit() {
        let score = SearchDiagnosticInfo.ResultScore(
            id: UUID(),
            title: "结果标题",
            ftsRank: 1,
            vectorRank: 3,
            finalScore: 0.85
        )
        XCTAssertEqual(score.ftsRank, 1)
        XCTAssertEqual(score.vectorRank, 3)
        XCTAssertEqual(score.finalScore, 0.85, accuracy: 0.001)
    }

    /// 验证 SearchDiagnosticInfo Equatable
    func testSearchDiagnosticInfoEquality() {
        let id = UUID()
        let a = SearchDiagnosticInfo(id: id, query: "q", rewrittenQuery: "r", ftsCount: 1, vectorCount: 2, rrfTopResults: [])
        let b = SearchDiagnosticInfo(id: id, query: "q", rewrittenQuery: "r", ftsCount: 1, vectorCount: 2, rrfTopResults: [])
        XCTAssertEqual(a, b)
    }
}

// MARK: - VaultTheme 单元测试（补充 Codable 往返）

final class VaultThemeCodableTests: XCTestCase {

    /// 验证 VaultTheme init（含默认 style）
    func testVaultThemeInitWithDefaults() {
        let theme = VaultTheme(
            id: "custom",
            name: "自定义主题",
            primaryColors: ["#FF0000", "#00FF00"],
            accentColor: "#0000FF"
        )
        XCTAssertEqual(theme.id, "custom")
        XCTAssertEqual(theme.name, "自定义主题")
        XCTAssertEqual(theme.style, "linear")
        XCTAssertEqual(theme.primaryColors, ["#FF0000", "#00FF00"])
        XCTAssertEqual(theme.accentColor, "#0000FF")
    }

    /// 验证 VaultTheme 带自定义 style init
    func testVaultThemeInitWithCustomStyle() {
        let theme = VaultTheme(
            id: "radial",
            name: "径向",
            style: "radial",
            primaryColors: ["#000"],
            accentColor: "#FFF"
        )
        XCTAssertEqual(theme.style, "radial")
    }

    /// 验证 VaultTheme Codable 往返
    func testVaultThemeCodableRoundTrip() throws {
        let original = VaultTheme(
            id: "test",
            name: "测试",
            style: "angular",
            primaryColors: ["#AAA", "#BBB"],
            accentColor: "#CCC"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(VaultTheme.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    /// 验证 VaultTheme 预设主题存在
    func testVaultThemePresetThemesExist() {
        XCTAssertFalse(VaultTheme.standard.id.isEmpty)
        XCTAssertFalse(VaultTheme.sunset.id.isEmpty)
        XCTAssertFalse(VaultTheme.neonPurple.id.isEmpty)
    }
}
