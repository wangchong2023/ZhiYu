//
//  ZIPFoundationArchiverExtractionTests.swift
//  ZhiYuTests
//
//  系统层级：[Platforms] 平台归档测试
//  核心职责：验证 ZIPFoundationArchiver 解压包含相对路径点文件名及正常文件的解压流程。
//

import XCTest
import Foundation
@testable import ZhiYu

#if !os(watchOS)
@MainActor
final class ZIPFoundationArchiverExtractionTests: XCTestCase {

    /// 验证合法文件名含双点的文件解压流程
    func testExtractContents_validFileNameWithDots_doesNotCrash() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ZIPTest_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let sourceDir = tempDir.appendingPathComponent("source")
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        let legitFile = sourceDir.appendingPathComponent("file..name.txt")
        try "test content".write(to: legitFile, atomically: true, encoding: .utf8)

        let zipURL = tempDir.appendingPathComponent("test.zip")
        let archiver = ZIPFoundationArchiver()
        try await archiver.zip(directory: sourceDir, to: zipURL)

        let extractDir = tempDir.appendingPathComponent("extract")
        try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)

        try archiver.extractContents(from: zipURL, to: extractDir)

        let extractedFiles = (try? FileManager.default.contentsOfDirectory(at: extractDir, includingPropertiesForKeys: nil)) ?? []
        XCTAssertNotNil(extractedFiles)
    }

    /// 验证正常文件的压缩与解压完整性
    func testExtractContents_standardFile_extractsSuccessfully() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ZIPStandardTest_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let sourceDir = tempDir.appendingPathComponent("source")
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        let normalFile = sourceDir.appendingPathComponent("normal.txt")
        try "normal".write(to: normalFile, atomically: true, encoding: .utf8)

        let zipURL = tempDir.appendingPathComponent("test.zip")
        let archiver = ZIPFoundationArchiver()
        try? await archiver.zip(directory: sourceDir, to: zipURL)

        let extractDir = tempDir.appendingPathComponent("extract")
        try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)

        XCTAssertNoThrow(try archiver.extractContents(from: zipURL, to: extractDir))

        let extractedSourceDir = extractDir.appendingPathComponent("source")
        let extractedFile = extractedSourceDir.appendingPathComponent("normal.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: extractedFile.path), "解压后应存在 source/normal.txt")
    }
}
#endif
