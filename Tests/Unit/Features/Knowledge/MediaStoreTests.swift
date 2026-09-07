//
//  MediaStoreTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/09.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层测试
//  核心职责：验证 MediaStore 的附件保存（MD5 命名）、读取、删除与目录自动创建逻辑。
//

import XCTest
import CryptoKit
@testable import ZhiYu

final class MediaStoreTests: XCTestCase {

    /// 临时 vault 根目录
    private var tempDir: URL!

    /// 被测 MediaStore
    private var mediaStore: MediaStore!

    override func setUp() async throws {
        try await super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        mediaStore = MediaStore(vaultURL: tempDir)
    }

    override func tearDown() async throws {
        if let tempDir, FileManager.default.fileExists(atPath: tempDir.path) {
            try? FileManager.default.removeItem(at: tempDir)
        }
        tempDir = nil
        mediaStore = nil
        try await super.tearDown()
    }

    // MARK: - 初始化与目录创建

    /// 验证 init 自动创建 Attachments 子目录
    func testInitCreatesAttachmentsDirectory() {
        let attachmentsURL = tempDir.appendingPathComponent("Attachments", isDirectory: true)
        XCTAssertTrue(FileManager.default.fileExists(atPath: attachmentsURL.path),
                      "init 应自动创建 Attachments 目录")
    }

    /// 验证 attachmentsDirectoryURL 指向正确子目录
    func testAttachmentsDirectoryURL() {
        let expected = tempDir.appendingPathComponent("Attachments", isDirectory: true)
        XCTAssertEqual(mediaStore.attachmentsDirectoryURL, expected)
    }

    /// 验证 vaultURL 属性正确存储
    func testVaultURLStored() {
        XCTAssertEqual(mediaStore.vaultURL, tempDir)
    }

    // MARK: - saveMedia

    /// 验证 saveMedia 返回 MD5 命名的文件名
    func testSaveMediaReturnsMD5FileName() throws {
        let data = Data("测试内容".utf8)
        let fileName = try mediaStore.saveMedia(data: data, fileExtension: "txt")

        // 手动计算预期 MD5
        let expectedHash = Insecure.MD5.hash(data: data)
            .map { String(format: "%02hhx", $0) }.joined()
        XCTAssertEqual(fileName, "\(expectedHash).txt", "文件名应为 MD5 哈希 + 扩展名")
    }

    /// 验证 saveMedia 扩展名转小写
    func testSaveMediaLowercasesExtension() throws {
        let data = Data("test".utf8)
        let fileName = try mediaStore.saveMedia(data: data, fileExtension: "PNG")
        XCTAssertTrue(fileName.hasSuffix(".png"), "扩展名应转小写")
    }

    /// 验证 saveMedia 物理写入文件
    func testSaveMediaWritesFile() throws {
        let data = Data("物理写入测试".utf8)
        let fileName = try mediaStore.saveMedia(data: data, fileExtension: "md")

        let fileURL = mediaStore.attachmentsDirectoryURL.appendingPathComponent(fileName)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path), "文件应被物理写入")

        let written = try Data(contentsOf: fileURL)
        XCTAssertEqual(written, data, "写入内容应与输入一致")
    }

    /// 验证相同内容 saveMedia 返回相同文件名（去重）
    func testSaveMediaSameContentReturnsSameFileName() throws {
        let data = Data("相同内容".utf8)
        let name1 = try mediaStore.saveMedia(data: data, fileExtension: "txt")
        let name2 = try mediaStore.saveMedia(data: data, fileExtension: "txt")
        XCTAssertEqual(name1, name2, "相同内容应返回相同文件名（MD5 去重）")
    }

    /// 验证不同内容 saveMedia 返回不同文件名
    func testSaveMediaDifferentContentReturnsDifferentFileName() throws {
        let name1 = try mediaStore.saveMedia(data: Data("内容1".utf8), fileExtension: "txt")
        let name2 = try mediaStore.saveMedia(data: Data("内容2".utf8), fileExtension: "txt")
        XCTAssertNotEqual(name1, name2, "不同内容应返回不同文件名")
    }

    // MARK: - loadMedia

    /// 验证 loadMedia 读取已保存的文件
    func testLoadMediaReadsSavedFile() throws {
        let originalData = Data("读取测试".utf8)
        let fileName = try mediaStore.saveMedia(data: originalData, fileExtension: "txt")

        let loaded = try mediaStore.loadMedia(fileName: fileName)
        XCTAssertEqual(loaded, originalData, "读取内容应与保存内容一致")
    }

    /// 验证 loadMedia 不存在文件抛错
    func testLoadMediaNonExistentThrows() {
        XCTAssertThrowsError(try mediaStore.loadMedia(fileName: "nonexistent.png")) { error in
            XCTAssertNotNil(error, "读取不存在的文件应抛错")
        }
    }

    // MARK: - deleteMedia

    /// 验证 deleteMedia 删除已保存的文件
    func testDeleteMediaRemovesFile() throws {
        let data = Data("删除测试".utf8)
        let fileName = try mediaStore.saveMedia(data: data, fileExtension: "txt")

        let fileURL = mediaStore.attachmentsDirectoryURL.appendingPathComponent(fileName)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path), "前置：文件应存在")

        try mediaStore.deleteMedia(fileName: fileName)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path), "删除后文件不应存在")
    }

    /// 验证 deleteMedia 不存在文件不抛错（静默）
    func testDeleteMediaNonExistentNoThrow() {
        XCTAssertNoThrow(try mediaStore.deleteMedia(fileName: "nonexistent.png"),
                         "删除不存在的文件不应抛错")
    }

    // MARK: - 完整循环

    /// 验证 save → load → delete 完整循环
    func testSaveLoadDeleteCycle() throws {
        let data = Data("完整循环测试内容".utf8)

        // Save
        let fileName = try mediaStore.saveMedia(data: data, fileExtension: "json")
        XCTAssertFalse(fileName.isEmpty)

        // Load
        let loaded = try mediaStore.loadMedia(fileName: fileName)
        XCTAssertEqual(loaded, data)

        // Delete
        try mediaStore.deleteMedia(fileName: fileName)

        // 再读应失败
        XCTAssertThrowsError(try mediaStore.loadMedia(fileName: fileName))
    }
}
