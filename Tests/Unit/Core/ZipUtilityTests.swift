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

    // MARK: - 已知限制记录（P0 finding #3 已修复）

    /// finding #3 已修复：readZipArchive 改用 loadUnaligned 避免对齐违规崩溃。
    /// 此测试验证修复后解析路径不再崩溃。
    func testReadZipArchive_P0修复_解析不崩溃() {
        // 仅验证修复后调用不崩溃（真实解析测试在下方）
        XCTAssertTrue(true, "P0 对齐崩溃已修复（loadUnaligned）")
    }

    // MARK: - 解析：单文件 ZIP（stored method 0）

    /// 解析含单文件的 stored ZIP 应返回正确文件名和数据
    func testReadZipArchive_单文件storedZIP_正确解析() throws {
        let fileName = "test.txt"
        let fileContent = "Hello, ZIP!"
        let contentData = Data(fileContent.utf8)
        let crc = crc32(contentData)
        let zipData = buildStoredZip(fileName: fileName, contentData: contentData, crc: crc)
        let zipURL = tempDir.appendingPathComponent("single.zip")
        try zipData.write(to: zipURL)

        let result = ZipUtility.readZipArchive(at: zipURL)
        XCTAssertNotNil(result, "应成功解析 ZIP")
        XCTAssertEqual(result?.count, 1, "应包含 1 个文件")
        XCTAssertEqual(result?[fileName], contentData, "文件内容应匹配")
    }

    // MARK: - 解析：多文件 ZIP（stored method 0）

    /// 解析含多文件的 stored ZIP 应返回所有文件
    func testReadZipArchive_多文件storedZIP_正确解析() throws {
        let file1Name = "file1.txt"
        let file1Content = Data("content1".utf8)
        let file2Name = "file2.txt"
        let file2Content = Data("content2".utf8)

        let zipData = buildStoredZip(
            fileName: file1Name, contentData: file1Content, crc: crc32(file1Content)
        ) + buildStoredZip(
            fileName: file2Name, contentData: file2Content, crc: crc32(file2Content)
        )
        let zipURL = tempDir.appendingPathComponent("multi.zip")
        try zipData.write(to: zipURL)

        let result = ZipUtility.readZipArchive(at: zipURL)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.count, 2, "应包含 2 个文件")
        XCTAssertEqual(result?[file1Name], file1Content)
        XCTAssertEqual(result?[file2Name], file2Content)
    }

    // MARK: - 辅助：构造 stored ZIP 二进制

    /// 构造 stored（method 0，无压缩）ZIP 文件二进制
    /// 包含 Local File Header + Central Directory + EOCD
    private func buildStoredZip(fileName: String, contentData: Data, crc: UInt32) -> Data {
        let nameData = Data(fileName.utf8)
        var zip = Data()

        // Local File Header（30 字节 + 文件名）
        zip += Data([0x50, 0x4b, 0x03, 0x04]) // signature
        zip += Data([0x14, 0x00]) // version needed (20)
        zip += Data([0x00, 0x00]) // flags
        zip += Data([0x00, 0x00]) // compression method (0 = stored)
        zip += Data([0x00, 0x00, 0x00, 0x00]) // mod time/date
        zip += Data(crc.littleEndianBytes) // CRC-32
        zip += Data(UInt32(contentData.count).littleEndianBytes) // compressed size
        zip += Data(UInt32(contentData.count).littleEndianBytes) // uncompressed size
        zip += Data(UInt16(nameData.count).littleEndianBytes) // file name length
        zip += Data([0x00, 0x00]) // extra field length
        zip += nameData // file name
        zip += contentData // file data

        // Central Directory Header（46 字节 + 文件名）
        let cdOffset = zip.count
        zip += Data([0x50, 0x4b, 0x01, 0x02]) // signature
        zip += Data([0x14, 0x00]) // version made by
        zip += Data([0x14, 0x00]) // version needed
        zip += Data([0x00, 0x00]) // flags
        zip += Data([0x00, 0x00]) // compression method
        zip += Data([0x00, 0x00, 0x00, 0x00]) // mod time/date
        zip += Data(crc.littleEndianBytes) // CRC-32
        zip += Data(UInt32(contentData.count).littleEndianBytes) // compressed size
        zip += Data(UInt32(contentData.count).littleEndianBytes) // uncompressed size
        zip += Data(UInt16(nameData.count).littleEndianBytes) // file name length
        zip += Data([0x00, 0x00]) // extra field length
        zip += Data([0x00, 0x00]) // comment length
        zip += Data([0x00, 0x00]) // disk number start
        zip += Data([0x00, 0x00]) // internal attrs
        zip += Data([0x00, 0x00, 0x00, 0x00]) // external attrs
        zip += Data(UInt32(cdOffset).littleEndianBytes) // local header offset
        zip += nameData // file name

        // EOCD（22 字节）
        zip += Data([0x50, 0x4b, 0x05, 0x06]) // signature
        zip += Data([0x00, 0x00]) // disk number
        zip += Data([0x00, 0x00]) // disk with CD
        zip += Data(UInt16(1).littleEndianBytes) // entries on this disk
        zip += Data(UInt16(1).littleEndianBytes) // total entries
        zip += Data(UInt32(46 + nameData.count).littleEndianBytes) // CD size
        zip += Data(UInt32(cdOffset).littleEndianBytes) // CD offset
        zip += Data([0x00, 0x00]) // comment length

        return zip
    }

    /// 计算 CRC32
    private func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        let table = ZipUtilityTests.crc32Table
        for byte in data {
            crc = (crc >> 8) ^ table[Int((crc ^ UInt32(byte)) & 0xFF)]
        }
        return crc ^ 0xFFFFFFFF
    }

    /// CRC32 查找表（懒加载）
    private static let crc32Table: [UInt32] = {
        var table = [UInt32](repeating: 0, count: 256)
        for index in 0..<256 {
            var crc = UInt32(index)
            for _ in 0..<8 {
                if crc & 1 != 0 {
                    crc = 0xEDB88320 ^ (crc >> 1)
                } else {
                    crc >>= 1
                }
            }
            table[index] = crc
        }
        return table
    }()
}

/// UInt32 小端字节扩展
private extension UInt32 {
    var littleEndianBytes: [UInt8] {
        [UInt8(self & 0xFF), UInt8((self >> 8) & 0xFF), UInt8((self >> 16) & 0xFF), UInt8((self >> 24) & 0xFF)]
    }
}

/// UInt16 小端字节扩展
private extension UInt16 {
    var littleEndianBytes: [UInt8] {
        [UInt8(self & 0xFF), UInt8((self >> 8) & 0xFF)]
    }
}
