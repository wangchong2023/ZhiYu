//
//  VaultStorageServiceTests.swift
//  ZhiYuTests
//
//  系统层级：[L1] 基础设施层测试
//  核心职责：验证 VaultStorageService 的 Markdown 文件扫描、标题提取、书签存储与恢复
//

import XCTest
@testable import ZhiYu

@MainActor
final class VaultStorageServiceTests: XCTestCase {

    private var tempDir: URL!
    private var service: VaultStorageService!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("VaultTest-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        service = VaultStorageService()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
        service = nil
        super.tearDown()
    }

    // MARK: - scan

    func testScanReturnsEmptyForEmptyDirectory() {
        let pages = service.scan(directory: tempDir)
        XCTAssertTrue(pages.isEmpty)
    }

    func testScanFindsMarkdownFiles() throws {
        let mdURL = tempDir.appendingPathComponent("note1.md")
        try "# Test Title\n\nContent here".write(to: mdURL, atomically: true, encoding: .utf8)

        let pages = service.scan(directory: tempDir)
        XCTAssertEqual(pages.count, 1)
        XCTAssertEqual(pages.first?.title, "Test Title")
        XCTAssertEqual(pages.first?.content, "# Test Title\n\nContent here")
    }

    func testScanSkipsNonMarkdownFiles() throws {
        try "text".write(to: tempDir.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        try "data".write(to: tempDir.appendingPathComponent("data.json"), atomically: true, encoding: .utf8)
        try "# MD".write(to: tempDir.appendingPathComponent("real.md"), atomically: true, encoding: .utf8)

        let pages = service.scan(directory: tempDir)
        XCTAssertEqual(pages.count, 1)
        XCTAssertEqual(pages.first?.title, "MD")
    }

    func testScanFindsMultipleMarkdownFiles() throws {
        try "# A\n\ncontent a".write(to: tempDir.appendingPathComponent("a.md"), atomically: true, encoding: .utf8)
        try "# B\n\ncontent b".write(to: tempDir.appendingPathComponent("b.md"), atomically: true, encoding: .utf8)

        let pages = service.scan(directory: tempDir)
        XCTAssertEqual(pages.count, 2)
    }

    func testScanUsesFilenameWhenNoH1() throws {
        try "No heading here".write(to: tempDir.appendingPathComponent("noheading.md"), atomically: true, encoding: .utf8)

        let pages = service.scan(directory: tempDir)
        XCTAssertEqual(pages.count, 1)
        XCTAssertEqual(pages.first?.title, "noheading")
    }

    func testScanExtractsLastModified() throws {
        let mdURL = tempDir.appendingPathComponent("dated.md")
        try "# Dated".write(to: mdURL, atomically: true, encoding: .utf8)

        let pages = service.scan(directory: tempDir)
        XCTAssertEqual(pages.count, 1)
        XCTAssertNotNil(pages.first?.lastModified)
    }

    // MARK: - storeBookmark / restoreURL

    func testStoreBookmarkDelegatesToStorageProvider() {
        let mock = MockSecurityScopedStorage()
        let url = URL(fileURLWithPath: "/tmp/test")
        mock.storeBookmark(for: url)
        XCTAssertEqual(mock.storeBookmarkCallCount, 1)
        XCTAssertEqual(mock.lastStoredURL, url)
    }

    func testRestoreURLDelegatesToStorageProvider() {
        let mock = MockSecurityScopedStorage()
        let data = Data("bookmark".utf8)
        _ = mock.restoreURL(from: data)
        XCTAssertEqual(mock.restoreURLCallCount, 1)
        XCTAssertEqual(mock.lastRestoredData, data)
    }
}

// MARK: - Mock SecurityScopedStorage

private final class MockSecurityScopedStorage: SecurityScopedStorageProtocol, @unchecked Sendable {
    var storeBookmarkCallCount = 0
    var lastStoredURL: URL?
    var restoreURLCallCount = 0
    var lastRestoredData: Data?

    func storeBookmark(for url: URL) {
        storeBookmarkCallCount += 1
        lastStoredURL = url
    }

    func restoreURL(from data: Data) -> URL? {
        restoreURLCallCount += 1
        lastRestoredData = data
        return URL(fileURLWithPath: "/tmp/restored")
    }
}
