//
//  ZipUtilityBatch6BTests.swift
//  ZhiYu
//
//  系统层级：[L0] 测试层
//  核心职责：验证 ZipUtility 解析边界路径：deflate 解压、损坏 ZIP 签名扫描恢复、
//           非 UTF-8 文件名跳过、数据截断 guard break。
//

import XCTest
@testable import ZhiYu
import Compression

final class ZipUtilityBatch6BTests: XCTestCase {

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

    // MARK: - deflate 解压路径

    /// 解析含 deflate 压缩文件的 ZIP 应正确解压并返回文件内容
    /// 注：源码 decompressDeflate 用 compressedSize * 10 作为解压缓冲区，
    /// 高压缩比数据（如重复字符串）会超出缓冲区导致解压不完整。
    /// 此测试用低压缩比数据（随机字节）确保 10 倍缓冲区足够。
    func testReadZipArchive_deflate压缩ZIP_正确解压() throws {
        let fileName = "deflate_test.txt"
        // 构造低压缩比数据：80 字节随机数据，压缩后约 80+ 字节，10 倍缓冲区足够
        var originalData = Data(count: 80)
        for index in 0..<80 {
            originalData[index] = UInt8.random(in: 0...255)
        }

        let compressedData = compressDeflate(originalData)
        XCTAssertNotNil(compressedData, "压缩数据不应为 nil")
        guard let compressed = compressedData else { return }
        // 确保压缩后数据未变大（低压缩比随机数据可能略大，但应 < 原始）
        XCTAssertLessThanOrEqual(compressed.count, originalData.count * 10, "压缩数据应在合理范围内")

        let zipData = buildDeflateZip(fileName: fileName, compressedData: compressed, originalSize: originalData.count)
        let zipURL = tempDir.appendingPathComponent("deflate.zip")
        try zipData.write(to: zipURL)

        let result = ZipUtility.readZipArchive(at: zipURL)
        XCTAssertNotNil(result, "应成功解析 deflate ZIP")
        XCTAssertEqual(result?[fileName], originalData, "解压后的内容应与原始内容匹配")
    }

    /// 解析 deflate 压缩但数据损坏的 ZIP 应跳过该文件（解压失败不崩溃）
    func testReadZipArchive_deflate数据损坏_跳过该文件() throws {
        let fileName = "corrupt_deflate.txt"
        let corruptCompressedData = Data([0x00, 0x01, 0x02, 0x03]) // 无效 deflate 数据

        let zipData = buildDeflateZip(fileName: fileName, compressedData: corruptCompressedData, originalSize: 100)
        let zipURL = tempDir.appendingPathComponent("corrupt.zip")
        try zipData.write(to: zipURL)

        let result = ZipUtility.readZipArchive(at: zipURL)
        // 损坏的 deflate 数据解压失败，该文件被跳过，archive 为空返回 nil
        XCTAssertNil(result, "损坏的 deflate 数据应导致 archive 为空，返回 nil")
    }

    /// Finding #16 修复验证：decompressDeflate 改用循环倍增缓冲区后，
    /// 高压缩比数据应正确完整解压（不再截断）。
    /// 源码 ZipUtility.swift `decompressDeflate` 初始 10 倍，倍增重试直到完整或达 256MB 上限。
    func testReadZipArchive_deflate高压缩比数据_循环倍增缓冲区完整解压() throws {
        let fileName = "high_ratio.txt"
        // 800 字节重复字符串，压缩后约 26 字节，10 倍缓冲区 = 260 < 800
        // 修复后应倍增到 520 仍不足，再倍增到 1040 足够完整解压
        let originalData = Data(String(repeating: "Hello, Deflate! ", count: 50).utf8)

        guard let compressed = compressDeflate(originalData) else {
            XCTFail("压缩失败")
            return
        }
        // 确认高压缩比：压缩后远小于原始
        XCTAssertLessThan(compressed.count * 10, originalData.count, "应构造高压缩比数据使 10 倍缓冲区不足")

        let zipData = buildDeflateZip(fileName: fileName, compressedData: compressed, originalSize: originalData.count)
        let zipURL = tempDir.appendingPathComponent("high_ratio.zip")
        try zipData.write(to: zipURL)

        let result = ZipUtility.readZipArchive(at: zipURL)
        // 修复后应完整解压，不再截断
        XCTAssertNotNil(result, "应成功解析 deflate ZIP")
        XCTAssertEqual(result?[fileName], originalData, "Finding #16 修复后：高压缩比数据应完整解压，不再截断")
    }

    // MARK: - 损坏 ZIP 签名扫描恢复

    /// ZIP 数据前缀有垃圾字节时，应通过签名扫描找到下一个文件头
    func testReadZipArchive_前缀垃圾字节_签名扫描恢复() throws {
        let fileName = "after_garbage.txt"
        let contentData = Data("recovered".utf8)

        // 构造：垃圾前缀 + 有效 stored ZIP
        let garbage = Data([0xFF, 0xFE, 0xFD, 0xFC, 0xFB]) // 5 字节垃圾
        let storedZip = buildStoredZip(fileName: fileName, contentData: contentData)
        let zipData = garbage + storedZip
        let zipURL = tempDir.appendingPathComponent("with_garbage.zip")
        try zipData.write(to: zipURL)

        let result = ZipUtility.readZipArchive(at: zipURL)
        // 签名扫描应找到垃圾后的有效文件头
        // 注意：findNextLocalFileHeader 从 offset+4 开始扫描，应能找到
        XCTAssertNotNil(result, "签名扫描应恢复并解析垃圾后的 ZIP 文件")
        XCTAssertEqual(result?[fileName], contentData)
    }

    // MARK: - 非 UTF-8 文件名跳过

    /// 文件名非 UTF-8 编码时应跳过该文件（不崩溃）
    func testReadZipArchive_非UTF8文件名_跳过该文件() throws {
        let invalidUtf8Name = Data([0xFF, 0xFE, 0xFD]) // 无效 UTF-8 字节
        let contentData = Data("content".utf8)

        let zipData = buildStoredZipWithRawFileName(rawNameData: invalidUtf8Name, contentData: contentData)
        let zipURL = tempDir.appendingPathComponent("non_utf8_name.zip")
        try zipData.write(to: zipURL)

        let result = ZipUtility.readZipArchive(at: zipURL)
        // 非 UTF-8 文件名解析失败，文件被跳过，archive 为空返回 nil
        XCTAssertNil(result, "非 UTF-8 文件名应被跳过，archive 为空返回 nil")
    }

    // MARK: - 数据截断 guard break

    /// ZIP 数据在文件头声明的大小超过实际数据时应 break（不越界读取）
    func testReadZipArchive_数据截断_不越界读取() throws {
        let fileName = "truncated.txt"
        let declaredSize = 1000 // 声明 1000 字节
        let actualData = Data("short".utf8) // 实际只有 5 字节

        let zipData = buildStoredZipWithDeclaredSize(
            fileName: fileName,
            contentData: actualData,
            declaredSize: declaredSize
        )
        let zipURL = tempDir.appendingPathComponent("truncated.zip")
        try zipData.write(to: zipURL)

        let result = ZipUtility.readZipArchive(at: zipURL)
        // 声明大小超过实际数据，guard break，archive 为空返回 nil
        XCTAssertNil(result, "数据截断时应 break，archive 为空返回 nil")
    }

    // MARK: - 辅助：构造 deflate ZIP 二进制

    /// 构造 deflate（method 8）ZIP 文件二进制
    private func buildDeflateZip(fileName: String, compressedData: Data, originalSize: Int) -> Data {
        let nameData = Data(fileName.utf8)
        var zip = Data()

        // Local File Header
        zip += Data([0x50, 0x4b, 0x03, 0x04]) // signature
        zip += Data([0x14, 0x00]) // version needed (20)
        zip += Data([0x00, 0x00]) // flags
        zip += Data([0x08, 0x00]) // compression method (8 = deflate)
        zip += Data([0x00, 0x00, 0x00, 0x00]) // mod time/date
        zip += Data([0x00, 0x00, 0x00, 0x00]) // CRC-32（测试简化，不校验）
        zip += Data(UInt32(compressedData.count).littleEndianBytes) // compressed size
        zip += Data(UInt32(originalSize).littleEndianBytes) // uncompressed size
        zip += Data(UInt16(nameData.count).littleEndianBytes) // file name length
        zip += Data([0x00, 0x00]) // extra field length
        zip += nameData // file name
        zip += compressedData // compressed data

        return zip
    }

    /// 构造 stored（method 0）ZIP 文件二进制（简化版，无 Central Directory）
    private func buildStoredZip(fileName: String, contentData: Data) -> Data {
        let nameData = Data(fileName.utf8)
        var zip = Data()

        // Local File Header
        zip += Data([0x50, 0x4b, 0x03, 0x04]) // signature
        zip += Data([0x14, 0x00]) // version needed (20)
        zip += Data([0x00, 0x00]) // flags
        zip += Data([0x00, 0x00]) // compression method (0 = stored)
        zip += Data([0x00, 0x00, 0x00, 0x00]) // mod time/date
        zip += Data([0x00, 0x00, 0x00, 0x00]) // CRC-32
        zip += Data(UInt32(contentData.count).littleEndianBytes) // compressed size
        zip += Data(UInt32(contentData.count).littleEndianBytes) // uncompressed size
        zip += Data(UInt16(nameData.count).littleEndianBytes) // file name length
        zip += Data([0x00, 0x00]) // extra field length
        zip += nameData // file name
        zip += contentData // file data

        return zip
    }

    /// 构造 stored ZIP，文件名使用原始字节数据（可能非 UTF-8）
    private func buildStoredZipWithRawFileName(rawNameData: Data, contentData: Data) -> Data {
        var zip = Data()

        // Local File Header
        zip += Data([0x50, 0x4b, 0x03, 0x04]) // signature
        zip += Data([0x14, 0x00]) // version needed (20)
        zip += Data([0x00, 0x00]) // flags
        zip += Data([0x00, 0x00]) // compression method (0 = stored)
        zip += Data([0x00, 0x00, 0x00, 0x00]) // mod time/date
        zip += Data([0x00, 0x00, 0x00, 0x00]) // CRC-32
        zip += Data(UInt32(contentData.count).littleEndianBytes) // compressed size
        zip += Data(UInt32(contentData.count).littleEndianBytes) // uncompressed size
        zip += Data(UInt16(rawNameData.count).littleEndianBytes) // file name length
        zip += Data([0x00, 0x00]) // extra field length
        zip += rawNameData // file name (raw bytes)
        zip += contentData // file data

        return zip
    }

    /// 构造 stored ZIP，声明大小与实际数据大小不一致（用于截断测试）
    private func buildStoredZipWithDeclaredSize(fileName: String, contentData: Data, declaredSize: Int) -> Data {
        let nameData = Data(fileName.utf8)
        var zip = Data()

        // Local File Header
        zip += Data([0x50, 0x4b, 0x03, 0x04]) // signature
        zip += Data([0x14, 0x00]) // version needed (20)
        zip += Data([0x00, 0x00]) // flags
        zip += Data([0x00, 0x00]) // compression method (0 = stored)
        zip += Data([0x00, 0x00, 0x00, 0x00]) // mod time/date
        zip += Data([0x00, 0x00, 0x00, 0x00]) // CRC-32
        zip += Data(UInt32(declaredSize).littleEndianBytes) // compressed size (声明值)
        zip += Data(UInt32(declaredSize).littleEndianBytes) // uncompressed size (声明值)
        zip += Data(UInt16(nameData.count).littleEndianBytes) // file name length
        zip += Data([0x00, 0x00]) // extra field length
        zip += nameData // file name
        zip += contentData // file data (实际比声明小)

        return zip
    }

    /// 使用 Compression 框架压缩数据（deflate/zlib）
    private func compressDeflate(_ data: Data) -> Data? {
        let destinationBufferSize = data.count * 10
        var destinationData = Data(count: destinationBufferSize)

        let result = destinationData.withUnsafeMutableBytes { destBuffer -> Int? in
            data.withUnsafeBytes { sourceBuffer -> Int? in
                guard let sourcePointer = sourceBuffer.baseAddress,
                      let destPointer = destBuffer.baseAddress else { return nil }

                let size = compression_encode_buffer(
                    destPointer.bindMemory(to: UInt8.self, capacity: destinationBufferSize),
                    destinationBufferSize,
                    sourcePointer.bindMemory(to: UInt8.self, capacity: data.count),
                    data.count,
                    nil,
                    COMPRESSION_ZLIB
                )
                return size > 0 ? size : nil
            }
        }

        guard let size = result else { return nil }
        return destinationData.prefix(size)
    }
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
