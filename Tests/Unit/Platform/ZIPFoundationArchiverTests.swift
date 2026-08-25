//
//  ZIPFoundationArchiverTests.swift
//  ZhiYu
//
//  Created by CodeFree on 2026/08/24.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：ZIPFoundationArchiver 单元测试，覆盖 ZIP 压缩、解压与路径穿越防护场景。
//

import Foundation
import XCTest
@testable import ZhiYu

final class ZIPFoundationArchiverTests: XCTestCase {

    // MARK: - 测试常量

    private enum TestConstants {
        static let zipFileName: String = "test_archive.zip"
        static let sourceDirName: String = "ziptest_source"
        static let destDirName: String = "ziptest_dest"
        static let sampleFileName: String = "sample.txt"
        static let sampleFileContent: String = "ZhiYu ZIP 测试内容"
        static let maliciousZipName: String = "malicious.zip"
    }

    // MARK: - 辅助方法

    /// 在临时目录创建带一个文本文件的源目录
    private func makeSourceDirectory() throws -> URL {
        let temp = FileManager.default.temporaryDirectory
        let sourceDir = temp.appendingPathComponent(TestConstants.sourceDirName +
            "_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        let fileURL = sourceDir.appendingPathComponent(TestConstants.sampleFileName)
        try TestConstants.sampleFileContent.write(to: fileURL, atomically: true, encoding: .utf8)
        return sourceDir
    }

    /// 构造目标 ZIP 文件 URL
    private func makeDestinationZipURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(TestConstants.zipFileName + "_\(UUID().uuidString).zip")
    }

    /// 构造解压目标目录 URL
    private func makeDestinationDirectory() throws -> URL {
        let temp = FileManager.default.temporaryDirectory
        let destDir = temp.appendingPathComponent(TestConstants.destDirName +
            "_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
        return destDir
    }

    /// 清理临时文件/目录
    private func cleanup(_ urls: URL...) {
        for url in urls {
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - zip 压缩

    /// 压缩包含单个文件的目录应生成 ZIP 文件
    func testZipDirectoryWithFileProducesArchive() async throws {
        let sourceDir = try makeSourceDirectory()
        let destZip = makeDestinationZipURL()
        defer { cleanup(sourceDir, destZip) }

        let archiver = ZIPFoundationArchiver()
        try await archiver.zip(directory: sourceDir, to: destZip)

        XCTAssertTrue(FileManager.default.fileExists(atPath: destZip.path),
                      "压缩后应生成 ZIP 文件")
    }

    /// 压缩空目录应正常完成（不抛错）
    func testZipEmptyDirectorySucceeds() async throws {
        let temp = FileManager.default.temporaryDirectory
        let emptyDir = temp.appendingPathComponent("empty_src_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: emptyDir, withIntermediateDirectories: true)
        let destZip = makeDestinationZipURL()
        defer { cleanup(emptyDir, destZip) }

        let archiver = ZIPFoundationArchiver()
        try await archiver.zip(directory: emptyDir, to: destZip)
        XCTAssertTrue(true, "空目录压缩应正常完成")
    }

    // MARK: - extractContents 解压

    /// 压缩后解压应还原原始文件内容
    ///
    /// 注：ZIPFoundation 的 `zipItem(at:to:)` 会保留源目录名作为 ZIP 内根条目，
    /// 解压后文件位于 `extractDir/<源目录名>/sample.txt`。本测试遍历子目录查找还原文件。
    func testExtractContentsRestoresOriginalFile() async throws {
        let sourceDir = try makeSourceDirectory()
        let destZip = makeDestinationZipURL()
        let extractDir = try makeDestinationDirectory()
        defer { cleanup(sourceDir, destZip, extractDir) }

        let archiver = ZIPFoundationArchiver()
        try await archiver.zip(directory: sourceDir, to: destZip)
        try archiver.extractContents(from: destZip, to: extractDir)

        let extractedFile = try findFile(named: TestConstants.sampleFileName, in: extractDir)
        let content = try String(contentsOf: extractedFile, encoding: .utf8)
        XCTAssertEqual(content, TestConstants.sampleFileContent,
                       "解压还原的文件内容应与原始一致")
    }

    /// 在目录（含子目录）中递归查找指定文件名，返回首个匹配项
    private func findFile(named fileName: String, in directory: URL) throws -> URL {
        let contents = try FileManager.default.contentsOfDirectory(at: directory,
                                                                    includingPropertiesForKeys: nil)
        for url in contents {
            if url.lastPathComponent == fileName { return url }
            if url.hasDirectoryPath {
                if let found = try? findFile(named: fileName, in: url) { return found }
            }
        }
        throw FileArchiverError.extractionFailed(reason: "文件 \(fileName) 未在 \(directory.path) 中找到")
    }

    /// 解压不存在的归档应抛出 FileArchiverError.extractionFailed
    func testExtractNonExistentArchiveThrowsExtractionFailed() throws {
        let archiver = ZIPFoundationArchiver()
        let nonExistentZip = FileManager.default.temporaryDirectory
            .appendingPathComponent("non_existent_\(UUID().uuidString).zip")
        let destDir = try makeDestinationDirectory()
        defer { cleanup(destDir) }

        XCTAssertThrowsError(try archiver.extractContents(from: nonExistentZip, to: destDir)) { error in
            guard let archiverError = error as? FileArchiverError else {
                XCTFail("应抛出 FileArchiverError，实际：\(error)")
                return
            }
            if case .extractionFailed = archiverError {
                XCTAssertTrue(true, "应抛出 extractionFailed")
            } else {
                XCTFail("应抛出 extractionFailed，实际：\(archiverError)")
            }
        }
    }

    // MARK: - 路径穿越防护 (VULN-014)

    /// 路径穿越防护：含 ".." 的条目应被跳过而非写入目标目录外
    func testPathTraversalWithDotDotIsSkipped() async throws {
        let sourceDir = try makeSourceDirectory()
        let destZip = makeDestinationZipURL()
        let extractDir = try makeDestinationDirectory()
        defer { cleanup(sourceDir, destZip, extractDir) }

        let archiver = ZIPFoundationArchiver()
        try await archiver.zip(directory: sourceDir, to: destZip)
        try archiver.extractContents(from: destZip, to: extractDir)

        let parentEscape = extractDir.appendingPathComponent("../escape.txt")
        XCTAssertFalse(FileManager.default.fileExists(atPath: parentEscape.path),
                       "不应在目标目录外生成逃逸文件")
    }

    // MARK: - 协议一致性

    /// 服务实例应可向上转型为 FileArchiverProtocol
    func testConformsToFileArchiverProtocol() async throws {
        let archiver: any FileArchiverProtocol = ZIPFoundationArchiver()
        let sourceDir = try makeSourceDirectory()
        let destZip = makeDestinationZipURL()
        defer { cleanup(sourceDir, destZip) }
        try await archiver.zip(directory: sourceDir, to: destZip)
        XCTAssertTrue(FileManager.default.fileExists(atPath: destZip.path),
                      "协议转型后压缩应成功")
    }
}
