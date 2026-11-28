//
//  EmbeddingManagerCrashResistanceTests.swift
//  ZhiYuTests
//
//  系统层级：[L1] 基础设施测试 - 向量与嵌入
//  核心职责：验证 EmbeddingManager 与向量反序列化在哈希边界极端输入及非4字节对齐数据下的抗崩溃容错能力。
//

import XCTest
import Foundation
@testable import ZhiYuUnitTestHost

@MainActor
final class EmbeddingManagerCrashResistanceTests: XCTestCase {

    /// 验证极端字符输入与哈希边界下搜索不发生溢出崩溃
    func testGetVector_extremeTextInput_doesNotCrashOnHashOverflow() async {
        let extremeText = String(repeating: "\u{0}", count: 1000)
        let repository = MockVectorRepository()
        let manager = EmbeddingManager(repository: repository)
        let results = await manager.search(query: extremeText, topK: 5)
        XCTAssertNotNil(results)
    }

    /// 缺陷 #110 回归：非 4 字节对齐/截断字节安全拒绝，合法字节精准还原，负数/零 topK 不触发 Array.prefix 崩溃
    func testVectorDeserializationAndNegativeTopKHandledSafely() async {
        // 1. 截断字节（3 字节）与空 Data 必须返回 nil，不得触发 bindMemory 崩溃
        XCTAssertNil(EmbeddingManager.decodeFloatVector(from: Data([0x01, 0x02, 0x03])))
        XCTAssertNil(EmbeddingManager.decodeFloatVector(from: Data()))

        // 2. 合法 Float 序列化数据（含非对齐 Data Slice）必须精准反序列化
        let original: [Float] = [0.25, -0.5, 1.0]
        let rawBytes = original.withUnsafeBufferPointer { Data(buffer: $0) }
        var padded = Data([0xFF])
        padded.append(rawBytes)
        let unalignedSlice = padded.dropFirst()
        let decoded = EmbeddingManager.decodeFloatVector(from: Data(unalignedSlice))
        XCTAssertEqual(decoded, original)

        // 3. topK <= 0 不得触发 Array.prefix(topK) 致命崩溃
        let manager = EmbeddingManager(repository: MockVectorRepository())
        let negPageResults = await manager.search(query: "Swift", topK: -3)
        XCTAssertTrue(negPageResults.isEmpty)
        let zeroPageResults = await manager.search(query: "Swift", topK: 0)
        XCTAssertTrue(zeroPageResults.isEmpty)
        let negChunkResults = await manager.multiQuerySearch(query: "Swift", topK: -5)
        XCTAssertTrue(negChunkResults.isEmpty)
    }

    /// 缺陷 #168 回归：多 Vault 切换发出 `.vaultWillSwitch` 时必须立即清空内存向量与分块缓存，杜绝跨 Vault 数据泄露
    func testVaultWillSwitchClearsInMemoryVectorAndChunkCaches() async {
        let repository = MockVectorRepository()
        let manager = EmbeddingManager(repository: repository)

        let pageID = UUID()
        let page = KnowledgePage(
            id: pageID,
            title: "Vault A 私密笔记",
            pageType: .concept,
            content: "仅属于 Vault A 的敏感向量内容",
            createdAt: Date(),
            updatedAt: Date()
        )
        await manager.updateEmbedding(for: page)
        let chunk = PageChunk(
            id: "vaultA-chunk-1",
            pageID: pageID,
            content: "Vault A 私密分块",
            index: 0
        )
        await manager.indexChunks(pageID: pageID, chunks: [chunk])

        let beforeEmbeddings = await manager.getAllEmbeddings()
        XCTAssertNotNil(beforeEmbeddings[pageID], "前置：Vault A 向量应已缓存在内存中")

        // 触发跨 Vault 切换通知
        NotificationCenter.default.post(name: .vaultWillSwitch, object: nil)
        try? await Task.sleep(for: .milliseconds(80))

        let afterEmbeddings = await manager.getAllEmbeddings()
        XCTAssertTrue(afterEmbeddings.isEmpty, "收到 .vaultWillSwitch 后必须立即清空旧 Vault 内存页面向量缓存")
        let leakedChunks = await manager.multiQuerySearch(query: "Vault A 私密分块", topK: 5)
        XCTAssertTrue(leakedChunks.isEmpty, "收到 .vaultWillSwitch 后不得继续召回旧 Vault 的内存分块")
    }

    /// 缺陷 #271 回归：decodeFloatVector 必须拦截含 NaN 或 Infinity 的损坏二进制向量
    func testDecodeFloatVectorRejectsNaNAndInfinity() {
        let nanVector: [Float] = [0.5, .nan, 0.2]
        let nanData = nanVector.withUnsafeBufferPointer { Data(buffer: $0) }
        XCTAssertNil(EmbeddingManager.decodeFloatVector(from: nanData), "含 NaN 的损坏向量必须被拒绝")

        let infVector: [Float] = [0.5, .infinity, -0.1]
        let infData = infVector.withUnsafeBufferPointer { Data(buffer: $0) }
        XCTAssertNil(EmbeddingManager.decodeFloatVector(from: infData), "含 Infinity 的损坏向量必须被拒绝")

        let validVector: [Float] = [0.25, -0.5, 0.75]
        let validData = validVector.withUnsafeBufferPointer { Data(buffer: $0) }
        XCTAssertEqual(EmbeddingManager.decodeFloatVector(from: validData), validVector)
    }
}
