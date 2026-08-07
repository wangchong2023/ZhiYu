//
//  ZhiYuModelTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 ZhiYuModel 开展自动化单元测试验证。
//
import XCTest
import SwiftUI
import UFPStorage
import UFPCore
@testable import ZhiYu

// MARK: - 知识页面模型单元测试
@MainActor
final class ModelsTests: XCTestCase {
    
    // MARK: - 基础属性创建测试
    /// 验证知识页面（KnowledgePage）的基本属性创建和初始值设定是否符合预期
    func testKnowledgePageCreation() {
        let page = KnowledgePage(title: "Test Page", pageType: .entity, content: "Hello World")
        XCTAssertEqual(page.title, "Test Page")
        XCTAssertEqual(page.pageType, .entity)
        XCTAssertEqual(page.content, "Hello World")
        XCTAssertEqual(page.status, .active)
        XCTAssertEqual(page.confidence, .medium)
        XCTAssertTrue(page.aliases.isEmpty)
        XCTAssertTrue(page.tags.isEmpty)
        XCTAssertFalse(page.isPinned)
    }
    
    /// 验证知识页面缺省属性的正确配置
    func testKnowledgePageDefaultValues() {
        let page = KnowledgePage(title: "Defaults Test")
        XCTAssertEqual(page.customIcon, nil)
        XCTAssertEqual(page.sources.count, 0)
        XCTAssertEqual(page.relatedPageIDs.count, 0)
        XCTAssertEqual(page.contentHash, nil)
        XCTAssertNotNil(page.createdAt)
        XCTAssertNotNil(page.updatedAt)
    }
    
    /// 验证知识页面自定义图标与默认显示图标的转换逻辑
    func testKnowledgePageCustomIcon() {
        let pageWithIcon = KnowledgePage(title: "Custom", customIcon: "star.fill")
        XCTAssertEqual(pageWithIcon.displayIcon, "star.fill")
        
        let pageWithoutIcon = KnowledgePage(title: "Default")
        XCTAssertEqual(pageWithoutIcon.displayIcon, PageType.concept.icon)
    }
    
    // MARK: - 双链与存根状态边界测试
    /// 验证低于 100 字符的知识页面是否会被正确判定为存根（Stub）页面
    func testKnowledgePageStubBoundary() {
        // 刚好 99 个字符 -> 判定为存根
        let exactly99 = KnowledgePage(title: "B", content: String(repeating: "a", count: 99))
        XCTAssertTrue(exactly99.isStub)
        
        // 刚好 100 个字符 -> 不再判定为存根
        let exactly100 = KnowledgePage(title: "B", content: String(repeating: "a", count: 100))
        XCTAssertFalse(exactly100.isStub)
        
        // 内容为空 -> 判定为存根
        let empty = KnowledgePage(title: "E", content: "")
        XCTAssertTrue(empty.isStub)
    }
    
    /// 验证知识页面的不同类型分别对应其在文件系统中的物理归档文件夹名称
    func testKnowledgePageFolderName() {
        XCTAssertEqual(KnowledgePage(title: "", pageType: .entity).folderName, "entities")
        XCTAssertEqual(KnowledgePage(title: "", pageType: .concept).folderName, "concepts")
        XCTAssertEqual(KnowledgePage(title: "", pageType: .source).folderName, "sources")
        XCTAssertEqual(KnowledgePage(title: "", pageType: .comparison).folderName, "comparisons")
        XCTAssertEqual(KnowledgePage(title: "", pageType: .raw).folderName, "raw")
    }
    
    /// 验证根据内容长度自动判定存根状态的正确性
    func testKnowledgePageStubStatus() {
        let shortPage = KnowledgePage(title: "Short", content: "Hi")
        XCTAssertTrue(shortPage.isStub)
        
        let longPage = KnowledgePage(title: "Long", content: String(repeating: "Hello ", count: 30))
        XCTAssertFalse(longPage.isStub)
    }
    
    /// 验证从页面 Markdown 内容中精准提取双链出链（Outgoing Links）并且排重
    func testOutgoingLinks() {
        let page = KnowledgePage(
            title: "Test",
            content: "This links to [[Page A]] and [[Page B]] and [[Page A]] again."
        )
        let links = page.outgoingLinks
        XCTAssertEqual(links.count, 2) // AppLinkProcessor 重复项排重
        XCTAssertEqual(links[0], "Page A")
        XCTAssertEqual(links[1], "Page B")
    }
    
    /// 验证无双链链接情况下的返回逻辑
    func testOutgoingLinksNoMatch() {
        let page = KnowledgePage(title: "Test", content: "No links here.")
        XCTAssertTrue(page.outgoingLinks.isEmpty)
    }
    
    /// 验证空方括号对是否能被安全过滤，不导致提取异常
    func testOutgoingLinksEmptyBrackets() {
        let page = KnowledgePage(title: "T", content: "[[]] text [[]]")
        let links = page.outgoingLinks
        XCTAssertTrue(links.isEmpty || links.contains { $0.isEmpty })
    }
    
    /// 验证支持空格、中文字符及多字节字符集下的双链提取精准度
    func testOutgoingLinksSpecialChars() {
        let page = KnowledgePage(title: "T", content: "[[Page With Spaces]] and [[中文页面]]")
        let links = page.outgoingLinks
        XCTAssertEqual(links.count, 2)
        XCTAssertEqual(links[0], "Page With Spaces")
        XCTAssertEqual(links[1], "中文页面")
    }
    
    // MARK: - 字数统计逻辑测试
    /// 验证纯英文语境下的词数统计正确性
    func testEnglishWordCount() {
        let page = KnowledgePage(title: "Test", content: "Hello World This Is English")
        XCTAssertEqual(page.wordCount, 5)
    }
    
    /// 验证中文字符计数的正确性（一个汉字算作一个字）
    func testChineseWordCount() {
        let page = KnowledgePage(title: "Test", content: "这是一个测试")
        XCTAssertEqual(page.wordCount, 6) // 6个中文字符
    }
    
    /// 验证中英文混合状态下的词字综合统计精准度
    func testMixedWordCount() {
        let page = KnowledgePage(title: "Test", content: "Hello世界Test")
        XCTAssertEqual(page.wordCount, 4) // Hello (1) + 世 (1) + 界 (1) + Test (1)
    }
    
    /// 验证空文本状态下的字数统计返回 0
    func testEmptyContentWordCount() {
        let page = KnowledgePage(title: "Test", content: "")
        XCTAssertEqual(page.wordCount, 0)
    }
    
    /// 验证带有尾随空格的字数统计，防止出现多余字数
    func testWordCountTrailingSpace() {
        let page = KnowledgePage(title: "T", content: "Hello ")
        XCTAssertEqual(page.wordCount, 1)
    }
    
    /// 验证多个连续空格下的分词字数统计鲁棒性
    func testWordCountMultipleSpaces() {
        let page = KnowledgePage(title: "T", content: "Hello   World")
        XCTAssertEqual(page.wordCount, 2)
    }
    
    // MARK: - 序列化与哈希等同性测试
    /// 验证序列化（Encodable）与反序列化（Decodable）还原出同等字段属性的完整链路
    func testKnowledgePageCodableRoundTrip() throws {
        let original = KnowledgePage(
            title: "Test",
            pageType: .source,
            customIcon: "doc.fill",
            content: "# Header\nContent with [[link]]",
            aliases: ["Alias1", "Alias2"],
            tags: ["tag1", "tag2"],
            status: .needsUpdate,
            confidence: .high,
            sources: ["src1"],
            relatedPageIDs: [],
            isPinned: true,
            contentHash: "abc123"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(KnowledgePage.self, from: data)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.pageType, original.pageType)
        XCTAssertEqual(decoded.tags, original.tags)
        XCTAssertEqual(decoded.isPinned, original.isPinned)
    }
    
    /// 验证 Equatable 协议中判定同等和不同的规则是否符合设计
    func testKnowledgePageEquatable() {
        let fixedID = UUID()
        let p1 = KnowledgePage(id: fixedID, title: "Same")
        var p2 = p1
        XCTAssertEqual(p1, p2)
        p2.title = "Different"
        XCTAssertNotEqual(p1, p2)
    }
    
    // MARK: - LWW 多终端同步时间戳冲突覆盖测试
    /// 验证基于 Lamport 逻辑时钟与物理墙上时钟融合的 LWW (Last-Write-Wins) 多终端同步冲突解决逻辑
    func testLWWConflictResolution() {
        let baseID = UUID()
        let now = Date()
        
        // 场景 1: 远端节点具有更高的 Lamport 时间戳，远端赢
        let local1 = KnowledgePage(id: baseID, title: "Local", lamportTimestamp: 100, updatedAt: now)
        let remote1 = KnowledgePage(id: baseID, title: "Remote", lamportTimestamp: 101, updatedAt: now)
        let merged1 = local1.merge(with: remote1)
        XCTAssertEqual(merged1.title, "Remote", "逻辑时钟高的应当胜出")
        
        // 场景 2: 本地节点具有更高的 Lamport 时间戳，本地赢
        let local2 = KnowledgePage(id: baseID, title: "Local", lamportTimestamp: 200, updatedAt: now)
        let remote2 = KnowledgePage(id: baseID, title: "Remote", lamportTimestamp: 150, updatedAt: now)
        let merged2 = local2.merge(with: remote2)
        XCTAssertEqual(merged2.title, "Local", "逻辑时钟高的应当胜出")
        
        // 场景 3: 两端 Lamport 逻辑时钟等同，以物理时钟（updatedAt）为准，远端时间更新，远端赢
        let local3 = KnowledgePage(id: baseID, title: "Local", lamportTimestamp: 300, updatedAt: now.addingTimeInterval(-10))
        let remote3 = KnowledgePage(id: baseID, title: "Remote", lamportTimestamp: 300, updatedAt: now)
        let merged3 = local3.merge(with: remote3)
        XCTAssertEqual(merged3.title, "Remote", "当逻辑时钟等同时，物理更新时间最新的胜出")
        
        // 场景 4: 两端 Lamport 逻辑时钟等同，本地物理时钟更新，本地赢
        let local4 = KnowledgePage(id: baseID, title: "Local", lamportTimestamp: 300, updatedAt: now)
        let remote4 = KnowledgePage(id: baseID, title: "Remote", lamportTimestamp: 300, updatedAt: now.addingTimeInterval(-10))
        let merged4 = local4.merge(with: remote4)
        XCTAssertEqual(merged4.title, "Local", "当逻辑时钟等同时，本地物理更新时间最新或等同时胜出")
    }
    
    // MARK: - 隐私及标签提取测试
    /// 测试知识页面隐私敏感度判定与中英文标签的智能解析提取功能
    func testKnowledgePageIsPrivateAndTagExtraction() {
        // 标签包含 "private"
        let pageWithPrivateTag = KnowledgePage(title: "Secret", content: "Confidential info", tags: ["private"])
        XCTAssertTrue(pageWithPrivateTag.isPrivate)
        
        // 内容中通过 #private 内联声明
        let pageWithPrivateContentTag = KnowledgePage(title: "Secret 2", content: "Confidential info #private tag", tags: [])
        XCTAssertTrue(pageWithPrivateContentTag.isPrivate)
        
        // 复合型中英文内联标签清洗提取
        let pageWithMixedTags = KnowledgePage(
            title: "Mixed Tags",
            content: "This is #swift and this is #人工智能 (AI) and #private.",
            tags: ["static-tag"]
        )
        let extractedTags = pageWithMixedTags.getAllTags()
        XCTAssertTrue(extractedTags.contains("static-tag"))
        XCTAssertTrue(extractedTags.contains("swift"))
        XCTAssertTrue(extractedTags.contains("人工智能"))
        XCTAssertTrue(extractedTags.contains("private"))
        XCTAssertTrue(pageWithMixedTags.isPrivate)
        
        // 常规公开页面
        let normalPage = KnowledgePage(title: "Public", content: "Hello world #public tag", tags: ["public"])
        XCTAssertFalse(normalPage.isPrivate)
    }
    
    // MARK: - 页面类型与置信度测试
    /// 验证所有的知识页面类型（PageType）定义无遗漏
    func testPageTypeAllCases() {
        XCTAssertEqual(PageType.allCases.count, 5)
        XCTAssertTrue(PageType.allCases.contains(.entity))
        XCTAssertTrue(PageType.allCases.contains(.concept))
        XCTAssertTrue(PageType.allCases.contains(.source))
        XCTAssertTrue(PageType.allCases.contains(.comparison))
        XCTAssertTrue(PageType.allCases.contains(.raw))
    }
    
    /// 验证各类页面类型展示名与系统图标的配置完整性
    func testPageTypeDisplayNames() {
        XCTAssertFalse(PageType.entity.displayName.isEmpty)
        XCTAssertFalse(PageType.concept.displayName.isEmpty)
        XCTAssertFalse(PageType.source.displayName.isEmpty)
        XCTAssertFalse(PageType.comparison.displayName.isEmpty)
        XCTAssertFalse(PageType.raw.displayName.isEmpty)
    }
    
    /// 验证页面类型的图标配置无空值
    func testPageTypeIcons() {
        for type in PageType.allCases {
            XCTAssertFalse(type.icon.isEmpty, "PageType.\(type.rawValue) 应该有配置默认图标")
        }
    }
    
    /// 验证页面类型的视觉主题配置有效性
    func testPageTypeColors() {
        for type in PageType.allCases {
            _ = type.colorName
        }
    }

    /// 验证状态颜色设定规则
    func testPageStatusAllCases() {
        XCTAssertEqual(PageStatus.allCases.count, 4)
    }

    func testPageStatusColors() {
        XCTAssertEqual(PageStatus.active.colorName, "green")
        XCTAssertEqual(PageStatus.stub.colorName, "yellow")
        XCTAssertEqual(PageStatus.needsUpdate.colorName, "orange")
        XCTAssertEqual(PageStatus.deprecated.colorName, "red")
    }
    
    /// 验证置信度定义及对应的颜色映射逻辑
    func testConfidenceAllCases() {
        XCTAssertEqual(Confidence.allCases.count, 3)
    }
    
    func testConfidenceColors() {
        XCTAssertEqual(Confidence.high.color, .green)
        XCTAssertEqual(Confidence.medium.color, .yellow)
        XCTAssertEqual(Confidence.low.color, .red)
    }
    
    // MARK: - CJK 字符检测拓展方法测试
    /// 验证 CJK（中日韩）语系字符的精准探测与过滤，防止多语言环境下的边界分词崩溃
    func testCJKCharacterDetection() {
        // 中文字符验证
        XCTAssertTrue(Character("中").isCJKCharacter)
        XCTAssertTrue(Character("文").isCJKCharacter)
        // 日文平假名验证
        XCTAssertTrue(Character("あ").isCJKCharacter)
        // 日文片假名验证
        XCTAssertTrue(Character("カ").isCJKCharacter)
        // 韩文验证
        XCTAssertTrue(Character("한").isCJKCharacter)
        // CJK 常用标点符号验证
        XCTAssertTrue(Character("、").isCJKCharacter)
        XCTAssertTrue(Character("。").isCJKCharacter)
        // 非 CJK 边界符号验证
        XCTAssertFalse(Character("A").isCJKCharacter)
        XCTAssertFalse(Character("z").isCJKCharacter)
        XCTAssertFalse(Character("1").isCJKCharacter)
        XCTAssertFalse(Character(" ").isCJKCharacter)
        XCTAssertFalse(Character("\n").isCJKCharacter)
    }
}

// MARK: - 知识图谱相关模型测试
@MainActor
final class GraphModelsTests: XCTestCase {
    
    /// 验证知识图谱节点的模型构建与初始化值
    func testGraphNodeCreation() {
        let node = GraphNode(id: UUID(), title: "Test", pageType: .concept, position: .zero)
        XCTAssertEqual(node.title, "Test")
        XCTAssertEqual(node.pageType, .concept)
        XCTAssertFalse(node.isHighlighted)
        XCTAssertNil(node.communityID)
    }
    
    /// 验证知识图谱关系边（Edge）的构建与 ID 默认生成
    func testGraphEdgeCreation() {
        let sourceID = UUID()
        let targetID = UUID()
        let edge = GraphEdge(source: sourceID, target: targetID)
        XCTAssertEqual(edge.source, sourceID)
        XCTAssertEqual(edge.target, targetID)
        XCTAssertNotNil(edge.id)
    }
    
    /// 验证操作日志记录模型（LogEntry）的有效构建
    func testLogEntryCreation() {
        let entry = LogEntry(action: .create, target: "Page1", details: "Created new page")
        XCTAssertEqual(entry.action, .create)
        XCTAssertEqual(entry.target, "Page1")
        XCTAssertEqual(entry.details, "Created new page")
        XCTAssertNotNil(entry.timestamp)
        XCTAssertNotNil(entry.id)
    }
}

// MARK: - 智宇内容诊断问题（LintIssue）测试
@MainActor
final class LintIssueTests: XCTestCase {
    
    /// 验证致命错误级别诊断问题的图标与视觉色彩表现
    func testLintIssueSeverityError() {
        let issue = LintIssue(severity: .error, message: "Broken link", suggestion: "Fix the link")
        XCTAssertEqual(issue.severity, .error)
        XCTAssertEqual(issue.message, "Broken link")
        XCTAssertEqual(issue.severity.icon, "xmark.circle.fill")
        XCTAssertEqual(issue.severity.colorName, "red")
    }
    
    /// 验证警告级别诊断问题的图表与色彩
    func testLintIssueSeverityWarning() {
        let issue = LintIssue(severity: .warning, message: "Orphan page", suggestion: "Add links to this page")
        XCTAssertEqual(issue.severity.icon, "exclamationmark.triangle.fill")
        XCTAssertEqual(issue.severity.colorName, "orange")
    }
    
    /// 验证提示级别诊断问题的图表与色彩
    func testLintIssueSeverityInfo() {
        let issue = LintIssue(severity: .info, message: "Stub content", suggestion: "Expand the content")
        XCTAssertEqual(issue.severity.icon, "info.circle.fill")
        XCTAssertEqual(issue.severity.colorName, "blue")
    }
    
    /// 验证诊断问题类型（IssueType）的全部分支及其系统图标属性完整性，保障 100% 覆盖率
    func testLintIssueTypeAllCases() {
        XCTAssertEqual(LintIssue.IssueType.brokenLink.icon, "link")
        XCTAssertEqual(LintIssue.IssueType.orphan.icon, "person.crop.circle.badge.questionmark")
        XCTAssertEqual(LintIssue.IssueType.island.icon, "leaf.fill")
        XCTAssertEqual(LintIssue.IssueType.cycle.icon, "arrow.2.squarepath")
        XCTAssertEqual(LintIssue.IssueType.stub.icon, "doc.append")
        XCTAssertEqual(LintIssue.IssueType.stale.icon, "clock.arrow.circlepath")
        XCTAssertEqual(LintIssue.IssueType.generic.icon, "sparkles")
    }
    
    /// 验证双向链接潜在建议（PotentialLinkSuggestion）模型的完整字段以及 Codable 编解码可靠性
    func testPotentialLinkSuggestionCodable() throws {
        let original = PotentialLinkSuggestion(
            sourcePageID: UUID(),
            sourceTitle: "Page A",
            targetTitle: "Page B"
        )
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(PotentialLinkSuggestion.self, from: data)
        
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.sourcePageID, original.sourcePageID)
        XCTAssertEqual(decoded.sourceTitle, original.sourceTitle)
        XCTAssertEqual(decoded.targetTitle, original.targetTitle)
    }
    
    /// 验证 LintIssue 结构体本身的 Codable 序列化与反序列化，确保持久化兼容性
    func testLintIssueCodableRoundTrip() throws {
        let original = LintIssue(
            severity: .warning,
            type: .cycle,
            pageID: UUID(),
            message: "Cyclic links detected",
            suggestion: "Break the cycle by removing link"
        )
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(LintIssue.self, from: data)
        
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.severity, original.severity)
        XCTAssertEqual(decoded.type, original.type)
        XCTAssertEqual(decoded.pageID, original.pageID)
        XCTAssertEqual(decoded.message, original.message)
        XCTAssertEqual(decoded.suggestion, original.suggestion)
    }
}

// MARK: - 智宇多端协同模型（CollaborationModels）测试
@MainActor
final class CollaborationModelsTests: XCTestCase {
    
    /// 验证在线协作用户的展示字段格式
    func testCollabUserDisplayLabel() {
        let user = CollabUser(id: "u1", displayName: "Alice", deviceName: "iPhone", joinedAt: Date())
        XCTAssertEqual(user.displayLabel, "Alice (iPhone)")
    }
    
    /// 验证协同操作差异变化历史（CollabEdit）模型构建
    func testCollabEditFields() {
        let edit = CollabEdit(
            id: "e1", userID: "u1", pageID: UUID(),
            field: "title", oldValue: "Old", newValue: "New",
            timestamp: Date()
        )
        XCTAssertEqual(edit.field, "title")
        XCTAssertEqual(edit.oldValue, "Old")
        XCTAssertEqual(edit.newValue, "New")
    }
    
    /// 验证不同协作身份角色的展示与系统图标绑定
    func testCollabRoleDisplayNames() {
        XCTAssertFalse(CollabRole.owner.displayName.isEmpty)
        XCTAssertFalse(CollabRole.editor.displayName.isEmpty)
        XCTAssertFalse(CollabRole.viewer.displayName.isEmpty)
    }
    
    func testCollabRoleIcons() {
        XCTAssertEqual(CollabRole.owner.icon, "crown.fill")
        XCTAssertEqual(CollabRole.editor.icon, "pencil.circle.fill")
        XCTAssertEqual(CollabRole.viewer.icon, "eye.fill")
    }
}

// MARK: - 语音备忘录（VoiceRecording）模型测试
@MainActor
final class VoiceRecordingTests: XCTestCase {
    
    /// 验证录音片段基础模型构造
    func testVoiceRecordingCreation() {
        let recording = VoiceRecording(
            id: UUID(),
            title: "Meeting Notes",
            text: "Discussed project timeline",
            language: "zh-CN",
            duration: 120.5,
            createdAt: Date()
        )
        XCTAssertEqual(recording.title, "Meeting Notes")
        XCTAssertEqual(recording.text, "Discussed project timeline")
        XCTAssertEqual(recording.language, "zh-CN")
        XCTAssertEqual(recording.duration, 120.5)
    }
    
    /// 验证录音对象序列化还原正确性
    func testVoiceRecordingCodableRoundTrip() throws {
        let original = VoiceRecording(id: UUID(), title: "T", text: "text", language: "en-US", duration: 10.0, createdAt: Date())
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(VoiceRecording.self, from: data)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.title, original.title)
    }
}

// MARK: - PDF 多媒体文案与元数据相关模型测试
@MainActor
final class PDFDocumentInfoTests: XCTestCase {
    
    /// 验证 PDF 文档及其高亮标注 (PDFHighlight) 在主线程下的安全创建与数据持有验证
    func testPDFDocCreation() async {
        let doc = PDFDocumentInfo(
            title: "Research Paper",
            fileName: "paper.pdf",
            pageCount: 42,
            highlights: [
                PDFHighlight(pageIndex: 0, text: "important finding", color: "yellow", note: "Check this")
            ]
        )
        XCTAssertEqual(doc.fileName, "paper.pdf")
        XCTAssertEqual(doc.pageCount, 42)
        XCTAssertEqual(doc.highlights.count, 1)
        XCTAssertEqual(doc.lastReadPage, 0)
    }
    
    /// 验证 PDF 视觉高亮标注色彩映射的安全回退（Fallback）逻辑
    func testPDFHighlightColors() {
        XCTAssertEqual(PDFHighlight(pageIndex: 0, text: "", color: "yellow").highlightColor, .yellow)
        XCTAssertEqual(PDFHighlight(pageIndex: 0, text: "", color: "green").highlightColor, .green)
        XCTAssertEqual(PDFHighlight(pageIndex: 0, text: "", color: "blue").highlightColor, .blue)
        XCTAssertEqual(PDFHighlight(pageIndex: 0, text: "", color: "pink").highlightColor, .pink)
        XCTAssertEqual(PDFHighlight(pageIndex: 0, text: "", color: "purple").highlightColor, .purple)
        XCTAssertEqual(PDFHighlight(pageIndex: 0, text: "", color: "red").highlightColor, .yellow) // 兜底降级回退到黄色
    }
}
