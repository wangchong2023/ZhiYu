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
}
