//
//  KnowledgeRepositoryTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 KnowledgeRepository 开展自动化单元测试验证。
//
import XCTest
import UFPStorage
@testable import ZhiYu

final class KnowledgeRepositoryTests: XCTestCase {
    
    var dbQueue: DatabaseQueue!
    var repository: KnowledgePageRepository!

    override func setUp() async throws {
        try await super.setUp()
        // 创建内存数据库进行测试
        dbQueue = try DatabaseQueue()
        // 执行真实数据库迁移以建立完整的物理表结构与触发器
        try await DatabaseManager.shared.setupForTesting(with: dbQueue)
        repository = KnowledgePageRepository(dbWriter: dbQueue)
    }

    override func tearDownWithError() throws {
        repository = nil
        dbQueue = nil
    }

    // MARK: - Encryption Tests

    func testPrivatePageContentIsEncryptedInDB() async throws {
        let plainContent = "This is a very secret message."
        let page = KnowledgePage(title: "Secret", content: plainContent, tags: ["private"])
        
        // 保存页面
        try await repository.save(page)
        
        // 1. 验证内存中读取时已解密
        let fetched = try await repository.fetch(id: page.id)
        XCTAssertEqual(fetched?.content, plainContent, "读取出的内容应与原始明文一致")
        
        // 2. 验证物理数据库中存储的是加密后的密文
        try await dbQueue.read { db in
            let row = try Table(AppConstants.Storage.Tables.pages).filter(Column(AppConstants.Storage.Columns.title) == "Secret").fetchOne(db)
            let dbContent = row?[AppConstants.Storage.Columns.content] as? String
            
            XCTAssertNotNil(dbContent)
            XCTAssertNotEqual(dbContent, plainContent, "数据库中的物理内容不应是明文")
            // 验证是否为 Base64 格式（简单校验）
            XCTAssertTrue(Data(base64Encoded: dbContent ?? "") != nil, "加密内容应为 Base64 编码")
        }
    }

    func testPublicPageContentIsPlainInDB() async throws {
        let plainContent = "This is public knowledge."
        let page = KnowledgePage(title: "Public", content: plainContent, tags: ["science"])
        
        try await repository.save(page)
        
        try await dbQueue.read { db in
            let row = try Table("pages").filter(Column("title") == "Public").fetchOne(db)
            let dbContent = row?[AppConstants.Storage.Columns.content] as? String
            XCTAssertEqual(dbContent, plainContent, "普通页面在数据库中应以明文存储")
        }
    }

    // MARK: - FTS5 全文检索 (Full-Text Search) 内存集成测试

    /// 测试 FTS5 对公开文档的多字段混合检索及 Rank 排名召回
    /// 验证点包括：标题与正文关键词的倒排索引召回、标签混合匹配、空结果防空响应等。
    func testFTSSearchPublicPages() async throws {
        // 1. 播种具有特定关键词的多篇公开文档（采用标准英文词，完美适配默认的 SQLite FTS5 分词边界）
        let doc1 = KnowledgePage(title: "RRF Algorithm Intro", content: "Reciprocal Rank Fusion (RRF) is an efficient algorithm to merge search results.", tags: ["rag", "algorithm"])
        let doc2 = KnowledgePage(title: "Vector Search and Embeddings", content: "Vector search can leverage embeddings to capture semantic similarity in text.", tags: ["vector", "search"])
        let doc3 = KnowledgePage(title: "RAG Hybrid Search Engine", content: "Hybrid search combines FTS5 and vector search. The core formula is RRF formula.", tags: ["rag", "hybrid"])
        
        try await repository.save(doc1)
        try await repository.save(doc2)
        try await repository.save(doc3)
        
        // 2. 检索 "RRF" 关键词
        let rrfResults = try await repository.search(query: "RRF")
        XCTAssertEqual(rrfResults.count, 2, "匹配 RRF 的文档应当有 2 篇")
        
        // 验证 RRF 文档匹配正确性
        let rrfTitles = rrfResults.map { $0.title }
        XCTAssertTrue(rrfTitles.contains("RRF Algorithm Intro"))
        XCTAssertTrue(rrfTitles.contains("RAG Hybrid Search Engine"))
        
        // 3. 检索 "vector" 关键词
        let searchResults = try await repository.search(query: "vector")
        XCTAssertEqual(searchResults.count, 2, "匹配 'vector' 的文档应当有 2 篇")
        
        // 验证倒排匹配标题及正文的功能正确性
        let searchTitles = searchResults.map { $0.title }
        XCTAssertTrue(searchTitles.contains("Vector Search and Embeddings"))
        XCTAssertTrue(searchTitles.contains("RAG Hybrid Search Engine"))
        
        // 4. 检索不存在的词，应返回空数组而不会报错
        let emptyResults = try await repository.search(query: "NonExistentMarsWord")
        XCTAssertTrue(emptyResults.isEmpty)
    }

    /// 验证 FTS5 对私密加密文档的安全检索隔离特质
    /// 确保加密正文在物理上被 FTS5 表安全隔离（无法通过明文检索正文），但标题明文字段可以正常检索，且召回后能正确自动解密。
    func testFTSSearchPrivatePages() async throws {
        // 1. 播种包含敏感词的私密加密文档（开启 private 保护）
        let privateDoc = KnowledgePage(title: "Confidential ZhiYu Research Whitepaper", content: "This is a secret RAG research document containing business key values.", tags: ["private"])
        // 播种包含相同敏感词的公开文档
        let publicDoc = KnowledgePage(title: "Public ZhiYu Security Guidelines", content: "We define standard security guidelines and public keys in general corporate cases.", tags: ["standard"])
        
        try await repository.save(privateDoc)
        try await repository.save(publicDoc)
        
        // 2. 检索私密文档特有的正文敏感词 "secret"
        // 预期：因为私密文档在数据库 pages 表中是以加密后的密文 Base64 存储的，同步到 pages_fts 虚拟表时也是密文，
        // 故通过 FTS5 匹配明文敏感词 "secret" 应当【无法搜到】该私密文档，确保数据不泄露！
        let confidentialResults = try await repository.search(query: "secret")
        XCTAssertTrue(confidentialResults.isEmpty, "出于安全防护，通过明文敏感词不应检索到加密后的私密文档正文")
        
        // 3. 检索两篇文档共有的标题关键词 "ZhiYu"
        // 预期：虽然私密文档正文加密，但它的标题是以明文物理落盘的，因此全文检索标题词 "ZhiYu" 应当能够检索出这两篇文档！
        let keywordResults = try await repository.search(query: "ZhiYu")
        XCTAssertEqual(keywordResults.count, 2, "明文标题的检索应当能够同时召回公开和私密文档")
        
        let fetchedTitles = keywordResults.map { $0.title }
        XCTAssertTrue(fetchedTitles.contains("Confidential ZhiYu Research Whitepaper"))
        XCTAssertTrue(fetchedTitles.contains("Public ZhiYu Security Guidelines"))
        
        // 4. 验证私密文档被检索召回后，读取出的正文依然已经正确自动解密为明文
        if let decryptedPrivate = keywordResults.first(where: { $0.title == "Confidential ZhiYu Research Whitepaper" }) {
            XCTAssertEqual(decryptedPrivate.content, "This is a secret RAG research document containing business key values.")
        } else {
            XCTFail("私密文档应该被正确检索召回")
        }
    }

    // MARK: - CJK 中文双向链接全文检索

    /// 测试 FTS5 对 CJK（中日韩）中文双向链接标记 [[ 词条 ]] 的倒排索引分词及精准匹配召回表现
    func testFTSSearchCJKBilateralLinks() async throws {
        // 1. 播种中英混合及包含 [[ 中文双向链接 ]] 语法特性的页面数据
        let page1 = KnowledgePage(title: "AI时代的 [[ 知识管理 ]] 架构", content: "智宇是一款专为知识工作者打造的 AI 原生知识管理应用，核心理念是打造语义分块与混合 RAG 全文索引。", tags: ["architecture", "AI"])
        let page2 = KnowledgePage(title: "如何构建 [[ 深度学习 ]] 个人闭环", content: "通过在本地物理运行神经网络进行自然语言分析，对 PDF 页面与剪贴板进行全自动的 OCR 识别与索引归集。", tags: ["learning", "neural"])
        let page3 = KnowledgePage(title: "FTS5 全文搜索与向量检索的混合引擎", content: "我们采用 SQLite 原生的 FTS5 全文搜索模块，对公开以及解密后的私密文本进行高效率的倒排匹配。", tags: ["search", "sqlite"])
        
        try await repository.save(page1)
        try await repository.save(page2)
        try await repository.save(page3)
        
        // 2. 检索中文关键词 "知识管理"
        // 预期：虽然标题中包含特殊双向链接符号 "[[ 知识管理 ]]"，但 FTS5 的分词系统应当能够无视括号符号的干扰，
        // 提取出核心汉字词并成功召回该页面。
        let cjkResults1 = try await repository.search(query: "知识管理")
        XCTAssertEqual(cjkResults1.count, 1, "应当能够检索出标题包含 '知识管理' 双向链接的页面")
        XCTAssertEqual(cjkResults1.first?.title, "AI时代的 [[ 知识管理 ]] 架构")
        
        // 3. 检索正文中的中文词 "神经网络"
        let cjkResults2 = try await repository.search(query: "神经网络")
        XCTAssertEqual(cjkResults2.count, 1)
        XCTAssertEqual(cjkResults2.first?.title, "如何构建 [[ 深度学习 ]] 个人闭环")
        
        // 4. 检索中文及英文混合的词 "SQLite"
        let hybridResults = try await repository.search(query: "SQLite")
        XCTAssertEqual(hybridResults.count, 1)
        XCTAssertEqual(hybridResults.first?.title, "FTS5 全文搜索与向量检索的混合引擎")
    }
}
