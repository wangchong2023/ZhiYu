//
//  KnowledgePageTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/13.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：提供对知识管理系统核心数据模型 KnowledgePage 及其扩展功能的单元测试覆盖。
//

import XCTest
@testable import ZhiYu

final class KnowledgePageTests: XCTestCase {
    
    // MARK: - 隐私属性测试
    
    /// 测试不包含任何 private 标签的普通页面
    func testIsPrivateWithoutPrivateTag() {
        // Arrange
        let page = KnowledgePage(
            title: "Normal Page",
            content: "This is a public page without any special tags."
        )
        
        // Act & Assert
        XCTAssertFalse(page.isPrivate, "页面如果不包含 private 标签，则不应该是私有的")
    }
    
    /// 测试元数据中带有 private 标签的页面
    func testIsPrivateWithMetadataTag() {
        // Arrange
        let page = KnowledgePage(
            title: "Secret Page",
            content: "This content is secret.",
            tags: ["private", "work"]
        )
        
        // Act & Assert
        XCTAssertTrue(page.isPrivate, "如果页面的元数据标签中包含 private，应当被判定为私有")
    }
    
    /// 测试正文中包含 #private 内联标签的页面
    func testIsPrivateWithInlineHashTag() {
        // Arrange
        let page = KnowledgePage(
            title: "Inline Secret",
            content: "This content has an inline tag #private hidden inside."
        )
        
        // Act & Assert
        XCTAssertTrue(page.isPrivate, "如果页面的正文内包含 #private，应当被判定为私有")
    }
    
    /// 测试多标签场景下的私有判定
    func testIsPrivateWithMixedTags() {
        // Arrange
        let page = KnowledgePage(
            title: "Mixed Secret 2",
            content: "We also have #private inside.",
            tags: ["Draft"]
        )
        
        // Assert
        XCTAssertTrue(page.isPrivate, "正文包含 #private 应该被判定为私有")
    }
    
    // MARK: - 基础计算属性与度量测试
    
    /// 测试页面的字数、存根状态以及出链提取逻辑
    func testPageMetricsAndStubStatus() {
        // 1. 测试存根状态（字符数小于 100）
        let stubPage = KnowledgePage(title: "Stub", content: "Short content")
        XCTAssertTrue(stubPage.isStub, "内容长度少于 100 字符时，isStub 应当为 true")
        
        let normalPage = KnowledgePage(
            title: "Long Page",
            content: String(repeating: "A", count: 150)
        )
        XCTAssertFalse(normalPage.isStub, "内容长度超过 100 字符时，isStub 应当为 false")
        
        // 2. 测试物理总字数计算
        let pageForWordCount = KnowledgePage(title: "Word Count Test", content: "Hello World ZhiYu")
        XCTAssertEqual(pageForWordCount.wordCount, 3, "应该能正确测算出物理词数")
        
        // 3. 测试 [[出链]] 提取功能
        let linkPage = KnowledgePage(
            title: "Link Test",
            content: "Here is a link to [[ConceptA]] and another [[ConceptB]]."
        )
        XCTAssertEqual(linkPage.outgoingLinks, ["ConceptA", "ConceptB"], "应该成功解析双向链接格式的出链")
    }
    
    // MARK: - 图标与文件夹映射测试
    
    /// 测试页面显示图标逻辑（优先使用 customIcon，否则使用 pageType.icon）
    func testDisplayIconLogic() {
        // 1. 无自定义图标时使用默认类型图标
        let pageNoIcon = KnowledgePage(title: "Concept Page", pageType: .concept)
        XCTAssertEqual(pageNoIcon.displayIcon, PageType.concept.icon, "默认应当使用 concept 的图标")
        
        // 2. 存在自定义图标时覆盖默认图标
        let pageWithCustomIcon = KnowledgePage(
            title: "Custom Icon Page",
            pageType: .concept,
            customIcon: "star.fill"
        )
        XCTAssertEqual(pageWithCustomIcon.displayIcon, "star.fill", "自定义图标应当覆盖默认类型图标")
    }
    
    /// 测试 5 种 PageType 对应的物理存储文件夹名称
    func testFolderNameMapping() {
        let mappings: [(PageType, String)] = [
            (.entity, "entities"),
            (.concept, "concepts"),
            (.source, "sources"),
            (.comparison, "comparisons"),
            (.raw, "raw")
        ]
        
        for (type, expectedFolder) in mappings {
            let page = KnowledgePage(title: "Test Folder Name", pageType: type)
            XCTAssertEqual(page.folderName, expectedFolder, "PageType \(type) 对应的物理文件夹应当为 \(expectedFolder)")
        }
    }
    
    // MARK: - LWW (Last Write Wins) 冲突合并算法测试
    
    /// 测试 LWW 分布式冲突解决机制（涵盖 Lamport 时间戳比较及最后更新时间兜底）
    func testLWWConflictResolution() {
        let baseTime = Date()
        let localPage = KnowledgePage(
            title: "Base Page",
            lamportTimestamp: 100,
            updatedAt: baseTime
        )
        
        // 1. 远程时间戳大于本地：远程胜出
        let remoteNewerTimestamp = KnowledgePage(
            title: "Remote Newer",
            lamportTimestamp: 101,
            updatedAt: baseTime
        )
        let merged1 = localPage.merge(with: remoteNewerTimestamp)
        XCTAssertEqual(merged1.title, "Remote Newer", "当远程 Lamport 时间戳更大时，应当采用远程版本")
        
        // 2. 远程时间戳小于本地：本地胜出
        let remoteOlderTimestamp = KnowledgePage(
            title: "Remote Older",
            lamportTimestamp: 99,
            updatedAt: baseTime
        )
        let merged2 = localPage.merge(with: remoteOlderTimestamp)
        XCTAssertEqual(merged2.title, "Base Page", "当本地 Lamport 时间戳更大时，应当采用本地版本")
        
        // 3. 时间戳相同，但远程更新时间更晚：远程胜出
        let remoteLaterUpdate = KnowledgePage(
            title: "Remote Later Update",
            lamportTimestamp: 100,
            updatedAt: baseTime.addingTimeInterval(10)
        )
        let merged3 = localPage.merge(with: remoteLaterUpdate)
        XCTAssertEqual(merged3.title, "Remote Later Update", "当 Lamport 时间戳一致，且远程更新时间更晚时，远程应当胜出")
        
        // 4. 时间戳相同，本地更新时间更晚或相同：本地胜出
        let remoteEarlierUpdate = KnowledgePage(
            title: "Remote Earlier Update",
            lamportTimestamp: 100,
            updatedAt: baseTime.addingTimeInterval(-10)
        )
        let merged4 = localPage.merge(with: remoteEarlierUpdate)
        XCTAssertEqual(merged4.title, "Base Page", "当 Lamport 时间戳一致，且本地更新时间更晚时，本地应当胜出")
    }
    
    // MARK: - 溯源展示与美化逻辑测试
    
    /// 测试来源显示名称解析逻辑（覆盖本地协议切割、标准 Web 解析及兜底）
    func testDisplaySourceName() {
        // 1. 无来源地址
        let pageNoSource = KnowledgePage(title: "No Source")
        XCTAssertEqual(pageNoSource.displaySourceName, "", "无 sourceURL 时展示名称应当为空")
        
        // 2. 本地文件来源，可被解析为标准 URL
        let pageLocalFile = KnowledgePage(
            title: "Local File",
            sourceURL: "file:///Users/test/Documents/ZhiYuHelp.md"
        )
        XCTAssertTrue(pageLocalFile.isLocalFileSource, "含有 file:// 前缀的源应识别为本地文件")
        XCTAssertEqual(pageLocalFile.displaySourceName, "ZhiYuHelp.md", "本地文件应当解析出最后的文件名组件")
        
        // 3. 本地文件来源，不可解析为 URL，但包含 '/'
        let pageLocalFileFallbackSlash = KnowledgePage(
            title: "Local File Fallback",
            sourceURL: "file://invalid_url_with_slash/but_has/last_component.txt"
        )
        XCTAssertEqual(pageLocalFileFallbackSlash.displaySourceName, "last_component.txt", "不可解析的本地 URL 应当通过切片拿到最后一部分")
        
        // 4. 本地文件来源，不可解析为 URL，且不包含 '/'
        let pageLocalFileFallbackNoSlash = KnowledgePage(
            title: "Local File Raw",
            sourceURL: "file://noslashhere"
        )
        XCTAssertEqual(pageLocalFileFallbackNoSlash.displaySourceName, "file://noslashhere", "无可切割的本地 URL 应返回原始 URL 字符串")
        
        // 5. 网页来源，包含合法 Web Host
        let pageWebSource = KnowledgePage(
            title: "Web Source",
            sourceURL: "https://wikipedia.org/wiki/RAG"
        )
        XCTAssertFalse(pageWebSource.isLocalFileSource, "https:// 协议的源不应当被判定为本地文件")
        XCTAssertEqual(pageWebSource.displaySourceName, "wikipedia.org", "网页文件应当正确展示其 Host 域名")
        
        // 6. 网页来源，域名提取失败时返回原地址
        let pageWebSourceInvalid = KnowledgePage(
            title: "Web Source Invalid",
            sourceURL: "invalid_url_string"
        )
        XCTAssertEqual(pageWebSourceInvalid.displaySourceName, "invalid_url_string", "提取域名失败时应直接返回原始字符串")
    }
    
    /// 测试来源在 UI 上的友好图标适配（PDF, Markdown, Web, 本地文件兜底等）
    func testDisplaySourceIcon() {
        // 1. 无 sourceType：本地文件使用 doc.fill，Web 页面使用 safari
        let pageNilLocal = KnowledgePage(title: "Nil Local", sourceURL: "file:///Users/test/a.txt", sourceType: nil)
        XCTAssertEqual(pageNilLocal.displaySourceIcon, "doc.fill", "无明确类型但属于本地文件，应显示 doc.fill")
        
        let pageNilWeb = KnowledgePage(title: "Nil Web", sourceURL: "https://wikipedia.org", sourceType: nil)
        XCTAssertEqual(pageNilWeb.displaySourceIcon, "safari", "无明确类型且非本地文件，应显示 safari")
        
        // 2. sourceType 明确指定为 pdf (不区分大小写)
        let pagePDF = KnowledgePage(title: "PDF Source", sourceType: "pDf")
        XCTAssertEqual(pagePDF.displaySourceIcon, "doc.text.fill", "pdf 类型应展示 doc.text.fill 图标")
        
        // 3. sourceType 明确指定为 markdown/md/txt (不区分大小写)
        let pageMD = KnowledgePage(title: "Markdown Source", sourceType: "Markdown")
        XCTAssertEqual(pageMD.displaySourceIcon, "doc.text", "Markdown 类型应展示 doc.text 图标")
        
        let pageTxt = KnowledgePage(title: "Txt Source", sourceType: "TXT")
        XCTAssertEqual(pageTxt.displaySourceIcon, "doc.text", "TXT 类型应展示 doc.text 图标")
        
        // 4. 其他指定类型，本地文件返回 doc.fill，Web 页面返回 safari
        let pageOtherLocal = KnowledgePage(title: "Other Local", sourceURL: "file:///Users/test/a.zip", sourceType: "zip")
        XCTAssertEqual(pageOtherLocal.displaySourceIcon, "doc.fill", "其他类型的本地文件，应返回 doc.fill 兜底")
        
        let pageOtherWeb = KnowledgePage(title: "Other Web", sourceURL: "https://a.com", sourceType: "json")
        XCTAssertEqual(pageOtherWeb.displaySourceIcon, "safari", "其他类型的 Web 页面，应返回 safari 兜底")
    }
}
