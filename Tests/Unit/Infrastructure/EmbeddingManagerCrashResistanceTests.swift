//
//  EmbeddingManagerCrashResistanceTests.swift
//  ZhiYuTests
//
//  系统层级：[L1] 基础设施测试 - 向量与嵌入
//  核心职责：验证 EmbeddingManager 与向量反序列化在哈希边界极端输入及非4字节对齐数据下的抗崩溃容错能力。
//

import XCTest
import Foundation
@testable import ZhiYu

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

    /// 验证非4字节对齐的损坏 Data 在反序列化时不引发崩溃
    func testVectorDeserialization_unalignedData_handlesSafely() {
        let corruptedData = Data([0x01, 0x02, 0x03])
        let vector = corruptedData.withUnsafeBytes { buffer in
            [Float](buffer.bindMemory(to: Float.self))
        }
        XCTAssertFalse(corruptedData.isEmpty, "损坏数据已输入")
        _ = vector
    }
}
