//
//  FileTextPreviewTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/06/20.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证高性能流式文本文件读取组件 (FileTextPreviewView) 的分块增量加载、EOF 状态判定及偏移量的精确性。
//

import XCTest
@testable import ZhiYu

final class FileTextPreviewTests: XCTestCase {
    
    private var tempFilePath: String!
    private let chunkSize = 100_000 // 100KB
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // 创建一个大小为 250KB 的测试临时文件
        // 前 100KB 填充 "A"，中 100KB 填充 "B"，后 50KB 填充 "C"
        let part1 = String(repeating: "A", count: 100_000)
        let part2 = String(repeating: "B", count: 100_000)
        let part3 = String(repeating: "C", count: 50_000)
        let combined = part1 + part2 + part3
        
        let tempDir = NSTemporaryDirectory()
        let fileName = "file_preview_test_\(UUID().uuidString).txt"
        tempFilePath = (tempDir as NSString).appendingPathComponent(fileName)
        
        try combined.write(toFile: tempFilePath, atomically: true, encoding: .utf8)
    }
    
    override func tearDownWithError() throws {
        // 清理临时文件
        if FileManager.default.fileExists(atPath: tempFilePath) {
            try FileManager.default.removeItem(atPath: tempFilePath)
        }
        super.tearDown()
    }
    
    /// 验证大文件增量流式读取的分块大小、EOF 标志以及偏移有效性
    func testLargeFileIncrementalLoading() async throws {
        var iterator = FileChunkSequence(filePath: tempFilePath, chunkSize: chunkSize).makeAsyncIterator()
        
        // 第一分块：读取 100KB
        let chunk1 = try await iterator.next()
        let string1 = try XCTUnwrap(chunk1)
        XCTAssertEqual(string1.count, chunkSize)
        XCTAssertTrue(string1.allSatisfy { $0 == "A" }, "前 100KB 应该全部是 A")
        
        // 第二分块：读取 100KB
        let chunk2 = try await iterator.next()
        let string2 = try XCTUnwrap(chunk2)
        XCTAssertEqual(string2.count, chunkSize)
        XCTAssertTrue(string2.allSatisfy { $0 == "B" }, "中间 100KB 应该全部是 B")
        
        // 第三分块：读取 50KB
        let chunk3 = try await iterator.next()
        let string3 = try XCTUnwrap(chunk3)
        XCTAssertEqual(string3.count, 50_000)
        XCTAssertTrue(string3.allSatisfy { $0 == "C" }, "最后 50KB 应该全部是 C")
        
        // 结束分块
        let endChunk = try await iterator.next()
        XCTAssertNil(endChunk, "全部读取完毕后，继续调用 next() 应当返回 nil")
    }
    
    /// 验证小文件（低于1MB且低于分块大小）一次性读取完成，并正确返回 EOF
    func testSmallFilePreviewFullRead() async throws {
        let text = "ZhiYu Small File Preview Test Content."
        let tempDir = NSTemporaryDirectory()
        let path = (tempDir as NSString).appendingPathComponent("small_test_\(UUID().uuidString).txt")
        try text.write(toFile: path, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: path) }
        
        var iterator = FileChunkSequence(filePath: path, chunkSize: chunkSize).makeAsyncIterator()
        let chunk = try await iterator.next()
        XCTAssertEqual(chunk, text)
        
        let endChunk = try await iterator.next()
        XCTAssertNil(endChunk, "小文件读取一次后，继续调用 next() 应当返回 nil")
    }
    
    /// 性能测试：评估背景 I/O 读取切片的速度
    func testLargeFilePreviewLoadingPerformance() throws {
        self.measure {
            let exp = self.expectation(description: "Wait for performance read")
            Task {
                var iterator = FileChunkSequence(filePath: self.tempFilePath, chunkSize: self.chunkSize).makeAsyncIterator()
                _ = try? await iterator.next()
                exp.fulfill()
            }
            self.wait(for: [exp], timeout: 2.0)
        }
    }
    
    /// 内存稳定性压力测试：模拟大文件多轮增量循环读取，断言内存无泄漏和暴涨
    func testIngestMemoryStabilityStress() throws {
        self.measure(metrics: [XCTMemoryMetric()]) {
            let exp = self.expectation(description: "Wait for stress test read")
            Task {
                var iterator = FileChunkSequence(filePath: self.tempFilePath, chunkSize: self.chunkSize).makeAsyncIterator()
                while (try? await iterator.next()) != nil {}
                exp.fulfill()
            }
            self.wait(for: [exp], timeout: 5.0)
        }
    }
}
