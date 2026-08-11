//
//  DomainModelsTests.swift
//  ZhiYuTests
//
//  系统层级：[L1.5] 领域层测试
//  核心职责：验证 Domain/Models 中无测试覆盖的纯数据模型的 Codable 编解码往返、
//           属性默认值、Equatable 判定及边界条件。
//

import XCTest
@testable import ZhiYu

// MARK: - AsyncStatus 单元测试

final class AsyncStatusTests: XCTestCase {

    // MARK: - isLoading 判定

    /// 验证 .loading 状态下 isLoading 为 true
    func testLoadingStateIsLoading() {
        let status: AsyncStatus<String> = .loading("加载中")
        XCTAssertTrue(status.isLoading, ".loading 状态下 isLoading 应为 true")
    }

    /// 验证 .idle 状态下 isLoading 为 false
    func testIdleStateIsNotLoading() {
        let status: AsyncStatus<String> = .idle
        XCTAssertFalse(status.isLoading, ".idle 状态下 isLoading 应为 false")
    }

    /// 验证 .success 状态下 isLoading 为 false
    func testSuccessStateIsNotLoading() {
        let status: AsyncStatus<String> = .success("完成")
        XCTAssertFalse(status.isLoading, ".success 状态下 isLoading 应为 false")
    }

    /// 验证 .failure 状态下 isLoading 为 false
    func testFailureStateIsNotLoading() {
        let status: AsyncStatus<String> = .failure("出错了")
        XCTAssertFalse(status.isLoading, ".failure 状态下 isLoading 应为 false")
    }

    // MARK: - Equatable 判定

    /// 验证相同 loading 状态相等
    func testLoadingEquality() {
        let a: AsyncStatus<String> = .loading("加载中")
        let b: AsyncStatus<String> = .loading("加载中")
        XCTAssertEqual(a, b, "相同描述的 .loading 状态应相等")
    }

    /// 验证不同 loading 描述不相等
    func testLoadingInequalityWithDifferentDescription() {
        let a: AsyncStatus<String> = .loading("加载中")
        let b: AsyncStatus<String> = .loading("请稍候")
        XCTAssertNotEqual(a, b, "不同描述的 .loading 状态不应相等")
    }

    /// 验证 success 值相等
    func testSuccessEquality() {
        let a: AsyncStatus<Int> = .success(42)
        let b: AsyncStatus<Int> = .success(42)
        XCTAssertEqual(a, b, "相同值的 .success 状态应相等")
    }

    /// 验证不同 failure 原因不相等
    func testFailureInequality() {
        let a: AsyncStatus<String> = .failure("错误A")
        let b: AsyncStatus<String> = .failure("错误B")
        XCTAssertNotEqual(a, b, "不同原因的 .failure 状态不应相等")
    }

    /// 验证 idle 与其他状态不相等
    func testIdleInequalityWithOtherStates() {
        let idle: AsyncStatus<String> = .idle
        let loading: AsyncStatus<String> = .loading("加载中")
        let success: AsyncStatus<String> = .success("完成")
        let failure: AsyncStatus<String> = .failure("出错")
        XCTAssertNotEqual(idle, loading)
        XCTAssertNotEqual(idle, success)
        XCTAssertNotEqual(idle, failure)
    }
}

// MARK: - PageSchema 单元测试

final class PageSchemaTests: XCTestCase {

    // MARK: - 初始化与属性访问

    /// 验证 PageSchema init 正确赋值所有属性
    func testPageSchemaInitAssignsAllProperties() {
        let schema = PageSchema(
            type: .concept,
            requiredFields: ["title", "content"],
            template: "# {{title}}\n\n{{content}}",
            promptInstruction: "请创建一个概念页面"
        )
        XCTAssertEqual(schema.type, .concept)
        XCTAssertEqual(schema.requiredFields, ["title", "content"])
        XCTAssertEqual(schema.template, "# {{title}}\n\n{{content}}")
        XCTAssertEqual(schema.promptInstruction, "请创建一个概念页面")
    }

    // MARK: - Codable 编解码往返

    /// 验证 PageSchema Codable 往返保持数据一致
    func testPageSchemaCodableRoundTrip() throws {
        let original = PageSchema(
            type: .entity,
            requiredFields: ["name", "definition"],
            template: "## {{name}}\n\n{{definition}}",
            promptInstruction: "创建实体页面"
        )
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(PageSchema.self, from: data)
        XCTAssertEqual(decoded.type, original.type)
        XCTAssertEqual(decoded.requiredFields, original.requiredFields)
        XCTAssertEqual(decoded.template, original.template)
        XCTAssertEqual(decoded.promptInstruction, original.promptInstruction)
    }

    /// 验证 PageSchema 空字段编解码
    func testPageSchemaCodableWithEmptyFields() throws {
        let original = PageSchema(
            type: .raw,
            requiredFields: [],
            template: "",
            promptInstruction: ""
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PageSchema.self, from: data)
        XCTAssertEqual(decoded.type, .raw)
        XCTAssertTrue(decoded.requiredFields.isEmpty)
        XCTAssertTrue(decoded.template.isEmpty)
        XCTAssertTrue(decoded.promptInstruction.isEmpty)
    }
}

// MARK: - KnowledgeSource 单元测试

final class KnowledgeSourceTests: XCTestCase {

    // MARK: - 初始化与默认值

    /// 验证 KnowledgeSource init 正确赋值所有属性
    func testKnowledgeSourceInitAssignsAllProperties() {
        let pageID = UUID()
        let source = KnowledgeSource(
            pageID: pageID,
            title: "Swift 入门",
            snippet: "Swift 是一种安全的编程语言",
            score: 0.95
        )
        XCTAssertEqual(source.pageID, pageID)
        XCTAssertEqual(source.title, "Swift 入门")
        XCTAssertEqual(source.snippet, "Swift 是一种安全的编程语言")
        XCTAssertNil(source.anchorPath)
        XCTAssertEqual(source.score, 0.95, accuracy: 0.001)
        XCTAssertNotNil(source.id)
    }

    /// 验证 KnowledgeSource 带可选参数的 init
    func testKnowledgeSourceInitWithAnchorPath() {
        let source = KnowledgeSource(
            pageID: UUID(),
            title: "测试",
            snippet: "片段",
            anchorPath: " > 章节1",
            score: 0.5
        )
        XCTAssertEqual(source.anchorPath, " > 章节1")
    }

    // MARK: - Equatable 判定（合成 Equatable，所有属性参与比较）

    /// 验证所有属性相同的 KnowledgeSource 相等
    func testKnowledgeSourceEqualityWithSameProperties() {
        let id = UUID()
        let pageID = UUID()
        let timestamp = Date()
        let a = KnowledgeSource(id: id, pageID: pageID, title: "A", snippet: "s", anchorPath: nil, score: 0.1, timestamp: timestamp)
        let b = KnowledgeSource(id: id, pageID: pageID, title: "A", snippet: "s", anchorPath: nil, score: 0.1, timestamp: timestamp)
        XCTAssertEqual(a, b, "所有属性相同的 KnowledgeSource 应相等")
    }

    /// 验证任一属性不同的 KnowledgeSource 不相等
    func testKnowledgeSourceInequalityWithDifferentTitle() {
        let id = UUID()
        let pageID = UUID()
        let timestamp = Date()
        let a = KnowledgeSource(id: id, pageID: pageID, title: "A", snippet: "s", score: 0.1, timestamp: timestamp)
        let b = KnowledgeSource(id: id, pageID: pageID, title: "B", snippet: "s", score: 0.1, timestamp: timestamp)
        XCTAssertNotEqual(a, b, "title 不同的 KnowledgeSource 不应相等")
    }

    /// 验证不同 id 的 KnowledgeSource 不相等
    func testKnowledgeSourceInequalityWithDifferentID() {
        let a = KnowledgeSource(pageID: UUID(), title: "A", snippet: "s", score: 0.1)
        let b = KnowledgeSource(pageID: UUID(), title: "A", snippet: "s", score: 0.1)
        XCTAssertNotEqual(a, b, "不同 id 的 KnowledgeSource 不应相等")
    }

    // MARK: - Codable 编解码往返

    /// 验证 KnowledgeSource Codable 往返保持数据一致
    func testKnowledgeSourceCodableRoundTrip() throws {
        let original = KnowledgeSource(
            pageID: UUID(),
            title: "引用源",
            snippet: "引用片段",
            anchorPath: " > 路径",
            score: 0.88
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(KnowledgeSource.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}

// MARK: - PageChunk 单元测试

final class PageChunkTests: XCTestCase {

    // MARK: - 初始化与默认值

    /// 验证 PageChunk init 正确赋值所有属性
    func testPageChunkInitAssignsAllProperties() {
        let pageID = UUID()
        let chunk = PageChunk(
            id: "chunk_0",
            pageID: pageID,
            content: "测试内容",
            index: 0
        )
        XCTAssertEqual(chunk.id, "chunk_0")
        XCTAssertEqual(chunk.pageID, pageID)
        XCTAssertNil(chunk.parentID)
        XCTAssertEqual(chunk.chunkType, .regular)
        XCTAssertEqual(chunk.content, "测试内容")
        XCTAssertNil(chunk.anchorPath)
        XCTAssertEqual(chunk.index, 0)
        XCTAssertEqual(chunk.startIndex, 0)
        XCTAssertNil(chunk.embedding)
        XCTAssertNotNil(chunk.createdAt)
        XCTAssertNotNil(chunk.updatedAt)
    }

    /// 验证 PageChunk 带全部参数的 init
    func testPageChunkInitWithAllParameters() {
        let pageID = UUID()
        let embedding = Data([0x01, 0x02, 0x03])
        let chunk = PageChunk(
            id: "chunk_1",
            pageID: pageID,
            parentID: "chunk_0",
            chunkType: .summary,
            content: "摘要",
            anchorPath: " > 概要",
            index: 1,
            startIndex: 10,
            embedding: embedding
        )
        XCTAssertEqual(chunk.parentID, "chunk_0")
        XCTAssertEqual(chunk.chunkType, .summary)
        XCTAssertEqual(chunk.anchorPath, " > 概要")
        XCTAssertEqual(chunk.startIndex, 10)
        XCTAssertEqual(chunk.embedding, embedding)
    }

    // MARK: - Codable 编解码往返

    /// 验证 PageChunk Codable 往返保持数据一致（含 snake_case 映射）
    func testPageChunkCodableRoundTrip() throws {
        let original = PageChunk(
            id: "chunk_test",
            pageID: UUID(),
            parentID: "parent",
            chunkType: .qaPair,
            content: "问答对",
            anchorPath: " > FAQ",
            index: 5,
            startIndex: 100,
            embedding: Data([0xFF, 0x00])
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PageChunk.self, from: data)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.pageID, original.pageID)
        XCTAssertEqual(decoded.parentID, original.parentID)
        XCTAssertEqual(decoded.chunkType, original.chunkType)
        XCTAssertEqual(decoded.content, original.content)
        XCTAssertEqual(decoded.anchorPath, original.anchorPath)
        XCTAssertEqual(decoded.index, original.index)
        XCTAssertEqual(decoded.startIndex, original.startIndex)
        XCTAssertEqual(decoded.embedding, original.embedding)
    }

    /// 验证 PageChunk databaseTableName 正确
    func testPageChunkDatabaseTableName() {
        XCTAssertEqual(PageChunk.databaseTableName, AppConstants.Storage.Tables.pageChunks)
    }
}

// MARK: - PageEmbedding 单元测试

final class PageEmbeddingTests: XCTestCase {

    /// 验证 PageEmbedding init 正确赋值
    func testPageEmbeddingInit() {
        let id = UUID()
        let vector: [Float] = [0.1, 0.2, 0.3]
        let embedding = PageEmbedding(id: id, vector: vector, modelName: "gemma")
        XCTAssertEqual(embedding.id, id)
        XCTAssertEqual(embedding.vector, vector)
        XCTAssertEqual(embedding.modelName, "gemma")
    }

    /// 验证 PageEmbedding Codable 往返
    func testPageEmbeddingCodableRoundTrip() throws {
        let original = PageEmbedding(id: UUID(), vector: [0.5, -0.5, 1.0], modelName: "test-model")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PageEmbedding.self, from: data)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.vector, original.vector)
        XCTAssertEqual(decoded.modelName, original.modelName)
    }

    /// 验证 PageEmbedding databaseTableName 正确
    func testPageEmbeddingDatabaseTableName() {
        XCTAssertEqual(PageEmbedding.databaseTableName, AppConstants.Storage.Tables.pageEmbeddings)
    }

    /// 验证 PageEmbedding 空向量
    func testPageEmbeddingEmptyVector() throws {
        let original = PageEmbedding(id: UUID(), vector: [], modelName: "empty")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PageEmbedding.self, from: data)
        XCTAssertTrue(decoded.vector.isEmpty)
    }
}
