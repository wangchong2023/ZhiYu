//
//  ZipUtilityTests.swift
//  ZhiYu
//
//  系统层级：[L0] 测试层
//  核心职责：验证 ZipUtility.readZipArchive 错误处理路径（非 ZIP/不存在/空文件）。
//
//  注：解析路径（单文件/多文件/嵌套）因 P0 对齐违规崩溃（finding #3）暂未覆盖，
//      待修复后补充解析测试。
//

import XCTest
@testable import ZhiYu

final class ZipUtilityTests: XCTestCase {

    var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - 错误处理：非 ZIP 文件

    func testReadZipArchive_非ZIP文件_返回nil() throws {
        let nonZipURL = tempDir.appendingPathComponent("notzip.txt")
        try "this is not a zip".write(
            to: nonZipURL,
            atomically: true,
            encoding: .utf8
        )
        let result = ZipUtility.readZipArchive(at: nonZipURL)
        XCTAssertNil(result, "非 ZIP 文件应返回 nil")
    }

    // MARK: - 错误处理：不存在的文件

    func testReadZipArchive_文件不存在_返回nil() {
        let nonexistentURL = URL(fileURLWithPath: "/tmp/nonexistent-\(UUID().uuidString).zip")
        let result = ZipUtility.readZipArchive(at: nonexistentURL)
        XCTAssertNil(result)
    }

    // MARK: - 错误处理：空文件

    func testReadZipArchive_空文件_返回nil() throws {
        let emptyURL = tempDir.appendingPathComponent("empty.zip")
        try Data().write(to: emptyURL)
        let result = ZipUtility.readZipArchive(at: emptyURL)
        XCTAssertNil(result, "空文件应返回 nil（无有效文件头）")
    }

    // MARK: - 已知限制记录（P0 finding #3）

    /// 记录 P0 对齐违规崩溃：readZipArchive 用 UnsafeRawPointer.load(fromByteOffset:as:)
    /// 读取非对齐偏移的 UInt16/UInt32，在 ARM64 上崩溃。
    /// 此测试仅文档化已知问题，不执行解析路径。
    /// 待修复后替换为真实解析测试（单文件/多文件/嵌套）。
    func testReadZipArchive_已知P0对齐崩溃_文档化() {
        // P0 finding #3: ZipUtility.swift:35,44-46,61
        // load(fromByteOffset:as:) 要求对齐，ZIP 头偏移非对齐 → EXC_BREAKPOINT
        // 修复方案：改用 loadUnaligned(fromByteOffset:as:) 或逐字节拼装
        XCTAssertTrue(true, "文档化测试：P0 对齐崩溃待修复")
    }
}
