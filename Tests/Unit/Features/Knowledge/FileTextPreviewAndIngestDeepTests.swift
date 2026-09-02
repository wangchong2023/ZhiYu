//
//  FileTextPreviewAndIngestDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Unit] 单元测试层
//  核心职责：深度测试 FileChunkSequence 异步流式切片迭代器与 FileTextPreviewView 大文本增量流式渲染组件。
//

import XCTest
import SwiftUI
import Dependencies
import UFPCore
@testable import ZhiYu

@MainActor
final class FileTextPreviewAndIngestDeepTests: XCTestCase {

    private var tempDirectory: URL?

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        tempDirectory = dir
    }

    override func tearDown() async throws {
        if let temp = tempDirectory {
            try? FileManager.default.removeItem(at: temp)
        }
        try await super.tearDown()
    }

    // MARK: - 1. FileChunkSequence 异步迭代器测试

    func testFileChunkSequence_WithSmallFile_ReadsCompletely() async throws {
        guard let temp = tempDirectory else { return }
        let fileURL = temp.appendingPathComponent("small_test.txt")
        let testContent = "Hello ZhiYu Karpathy LLM Wiki Architecture\nLine 2\nLine 3"
        try testContent.write(to: fileURL, atomically: true, encoding: .utf8)

        let sequence = FileChunkSequence(filePath: fileURL.path, chunkSize: 1024)
        var accumulated = ""
        for try await chunk in sequence {
            accumulated += chunk
        }

        XCTAssertEqual(accumulated, testContent)
    }

    func testFileChunkSequence_WithMultiChunkFile_IteratesCorrectly() async throws {
        guard let temp = tempDirectory else { return }
        let fileURL = temp.appendingPathComponent("multi_chunk.txt")
        let repeatedLine = "1234567890\n" // 11 bytes
        let totalLines = 100
        let fullText = String(repeating: repeatedLine, count: totalLines)
        try fullText.write(to: fileURL, atomically: true, encoding: .utf8)

        let sequence = FileChunkSequence(filePath: fileURL.path, chunkSize: 50)
        var chunkCount = 0
        var accumulated = ""
        for try await chunk in sequence {
            chunkCount += 1
            accumulated += chunk
        }

        XCTAssertGreaterThan(chunkCount, 1)
        XCTAssertEqual(accumulated, fullText)
    }

    func testFileChunkSequence_WithEmptyFile_ReturnsNilImmediately() async throws {
        guard let temp = tempDirectory else { return }
        let fileURL = temp.appendingPathComponent("empty.txt")
        try "".write(to: fileURL, atomically: true, encoding: .utf8)

        let sequence = FileChunkSequence(filePath: fileURL.path, chunkSize: 1024)
        var chunkCount = 0
        for try await _ in sequence {
            chunkCount += 1
        }

        XCTAssertEqual(chunkCount, 0)
    }

    func testFileChunkSequence_WithNonExistentFile_HandlesSafely() async throws {
        guard let temp = tempDirectory else { return }
        let fakePath = temp.appendingPathComponent("not_exist.txt").path
        let sequence = FileChunkSequence(filePath: fakePath, chunkSize: 1024)

        var chunkCount = 0
        for try await _ in sequence {
            chunkCount += 1
        }
        XCTAssertEqual(chunkCount, 0)
    }

    // MARK: - 2. FileTextPreviewView 视图层测试

    func testFileTextPreviewView_RendersWithValidFile() throws {
        guard let temp = tempDirectory else { return }
        let fileURL = temp.appendingPathComponent("preview_sample.md")
        try "# 知识库导引\n基于 RAG 与 FTS5 混合检索".write(to: fileURL, atomically: true, encoding: .utf8)

        let host = FileTextPreviewView(filePath: fileURL.path)
            .snapshotEnvironment()
            .renderInWindow()

        XCTAssertNotNil(host.view)
    }

    func testFileTextPreviewView_RendersWithNonExistentFile() {
        guard let temp = tempDirectory else { return }
        let fakePath = temp.appendingPathComponent("ghost.md").path
        let host = FileTextPreviewView(filePath: fakePath)
            .snapshotEnvironment()
            .renderInWindow()

        XCTAssertNotNil(host.view)
    }
}
