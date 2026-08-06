//
//  FileImportFileStoreTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 FileImportFileStore 的文件保存、拷贝、目录映射与 fallback 路径逻辑。
//

import XCTest
@testable import ZhiYu

final class FileImportFileStoreTests: XCTestCase {

    private var store: FileImportFileStore!

    override func setUp() {
        super.setUp()
        store = FileImportFileStore()
    }

    override func tearDown() {
        store = nil
        super.tearDown()
    }

    // MARK: - saveContent

    func testSaveContent_returnsNonNilPath() throws {
        let path = try XCTUnwrap(store.saveContent("测试内容", category: .manual))
        XCTAssertTrue(path.contains("manual"))
        try? FileManager.default.removeItem(atPath: path)
    }

    func testSaveContent_fileActuallyWritten() throws {
        let path = try XCTUnwrap(store.saveContent("Hello World", category: .manual))
        let url = URL(fileURLWithPath: path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

        let content = try String(contentsOf: url, encoding: .utf8)
        XCTAssertEqual(content, "Hello World")

        try? FileManager.default.removeItem(at: url)
    }

    func testSaveContent_withCustomExtension() throws {
        let path = try XCTUnwrap(store.saveContent("{}", category: .file, ext: "json"))
        XCTAssertTrue(path.hasSuffix(".json"))
        try? FileManager.default.removeItem(atPath: path)
    }

    func testSaveContent_defaultExtensionIsMd() throws {
        let path = try XCTUnwrap(store.saveContent("text", category: .clipboard))
        XCTAssertTrue(path.hasSuffix(".md"))
        try? FileManager.default.removeItem(atPath: path)
    }

    func testSaveContent_emptyString_stillWrites() throws {
        let path = try XCTUnwrap(store.saveContent("", category: .manual))
        try? FileManager.default.removeItem(atPath: path)
    }

    func testSaveContent_fileNameContainsCategoryPrefix() throws {
        let path = try XCTUnwrap(store.saveContent("data", category: .ocr))
        let fileName = URL(fileURLWithPath: path).lastPathComponent
        XCTAssertTrue(fileName.hasPrefix("ocr_"))
        try? FileManager.default.removeItem(atPath: path)
    }

    // MARK: - saveData

    func testSaveData_writesBinaryContent() throws {
        let data = Data([0x00, 0x01, 0x02, 0xFF])
        let path = try XCTUnwrap(store.saveData(data, category: .voice, ext: "bin"))
        let url = URL(fileURLWithPath: path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

        let readData = try Data(contentsOf: url)
        XCTAssertEqual(readData, data)

        try? FileManager.default.removeItem(at: url)
    }

    func testSaveData_fileNameContainsVoicePrefix() throws {
        let path = try XCTUnwrap(store.saveData(Data([0x00]), category: .voice, ext: "wav"))
        let fileName = URL(fileURLWithPath: path).lastPathComponent
        XCTAssertTrue(fileName.hasPrefix("voice_"))
        try? FileManager.default.removeItem(atPath: path)
    }

    // MARK: - copyFile

    func testCopyFile_copiesToSandbox() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let sourceURL = tempDir.appendingPathComponent("source_test_\(UUID().uuidString).txt")
        try "source content".write(to: sourceURL, atomically: true, encoding: .utf8)

        let destPath = try XCTUnwrap(store.copyFile(at: sourceURL, category: .file))
        let destURL = URL(fileURLWithPath: destPath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: destURL.path))

        let content = try String(contentsOf: destURL, encoding: .utf8)
        XCTAssertEqual(content, "source content")

        try? FileManager.default.removeItem(at: sourceURL)
        try? FileManager.default.removeItem(at: destURL)
    }

    func testCopyFile_preservesExtension() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let sourceURL = tempDir.appendingPathComponent("test_\(UUID().uuidString).json")
        try "{}".write(to: sourceURL, atomically: true, encoding: .utf8)

        let destPath = try XCTUnwrap(store.copyFile(at: sourceURL, category: .file))
        XCTAssertTrue(destPath.hasSuffix(".json"))

        try? FileManager.default.removeItem(at: sourceURL)
        try? FileManager.default.removeItem(atPath: destPath)
    }

    func testCopyFile_nonExistentSource_returnsNil() {
        let nonExistent = URL(fileURLWithPath: "/tmp/nonexistent_\(UUID().uuidString).txt")
        let result = store.copyFile(at: nonExistent, category: .file)
        XCTAssertNil(result)
    }

    // MARK: - 各 category 路径验证

    func testSaveContent_linkCategory_writesSuccessfully() throws {
        let path = try XCTUnwrap(store.saveContent("https://example.com", category: .link))
        try? FileManager.default.removeItem(atPath: path)
    }

    func testSaveContent_fileCategory_writesSuccessfully() throws {
        let path = try XCTUnwrap(store.saveContent("file content", category: .file))
        try? FileManager.default.removeItem(atPath: path)
    }

    func testSaveContent_clipboardCategory_writesSuccessfully() throws {
        let path = try XCTUnwrap(store.saveContent("clipboard text", category: .clipboard))
        try? FileManager.default.removeItem(atPath: path)
    }

    // MARK: - 重复保存不冲突

    func testSaveContent_multipleSaves_allSucceed() {
        var paths: [String] = []
        for i in 0..<3 {
            if let path = store.saveContent("content_\(i)", category: .manual) {
                paths.append(path)
            }
        }
        XCTAssertEqual(paths.count, 3)
        for path in paths {
            try? FileManager.default.removeItem(atPath: path)
        }
    }
}
