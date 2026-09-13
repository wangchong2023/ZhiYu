//
//  ZipUtilityArchiveParsingTests.swift
//  UFPCoreTests
//
//  系统层级：[UFPCoreTests]
//  核心职责：验证 ZipUtility.readZipArchive 对 stored、deflate、损坏文件、不存在路径与未对齐签名的解包能力。
//

import XCTest
import Compression
@testable import UFPCore

final class ZipUtilityArchiveParsingTests: XCTestCase {

    private var temporaryDirectoryURL: URL!

    override func setUp() {
        super.setUp()
        temporaryDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(
            at: temporaryDirectoryURL,
            withIntermediateDirectories: true
        )
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: temporaryDirectoryURL)
        super.tearDown()
    }

    // MARK: - 错误路径与边界防御

    func testReadZipArchive_nonExistentFile_returnsNil() {
        let nonExistent = temporaryDirectoryURL.appendingPathComponent("missing.zip")
        let result = ZipUtility.readZipArchive(at: nonExistent)
        XCTAssertNil(result, "文件不存在时应安全返回 nil")
    }

    func testReadZipArchive_emptyFile_returnsNil() throws {
        let emptyURL = temporaryDirectoryURL.appendingPathComponent("empty.zip")
        try Data().write(to: emptyURL)
        let result = ZipUtility.readZipArchive(at: emptyURL)
        XCTAssertNil(result, "空文件应返回 nil")
    }

    func testReadZipArchive_invalidMagicBytes_returnsNil() throws {
        let invalidURL = temporaryDirectoryURL.appendingPathComponent("invalid.txt")
        try "NotAZipArchiveContent".data(using: .utf8)?.write(to: invalidURL)
        let result = ZipUtility.readZipArchive(at: invalidURL)
        XCTAssertNil(result, "非 ZIP 文件头签名应返回 nil")
    }

    // MARK: - Stored (Method 0) 格式解析

    func testReadZipArchive_singleStoredEntry_extractsAccurately() throws {
        let fileName = "sample.txt"
        let content = "UFPCore Stored Zip Test Content"
        guard let contentData = content.data(using: .utf8) else {
            XCTFail("无法生成测试数据")
            return
        }

        let zipData = buildStoredZip(fileName: fileName, contentData: contentData)
        let zipURL = temporaryDirectoryURL.appendingPathComponent("stored.zip")
        try zipData.write(to: zipURL)

        let result = ZipUtility.readZipArchive(at: zipURL)
        XCTAssertNotNil(result, "Stored ZIP 必须成功解析")
        XCTAssertEqual(result?.count, 1)
        XCTAssertEqual(result?[fileName], contentData, "解包后的字节数据必须与原始数据完全一致")
    }

    // MARK: - Deflate (Method 8) 格式解析与解压

    func testReadZipArchive_deflateEntry_decompressesSuccessfully() throws {
        let fileName = "compressed.dat"
        var originalData = Data(count: 100)
        for i in 0..<100 {
            originalData[i] = UInt8(i % 256)
        }

        guard let compressedData = compressDeflate(originalData) else {
            XCTFail("Deflate 压缩失败")
            return
        }

        let zipData = buildDeflateZip(
            fileName: fileName,
            compressedData: compressedData,
            originalSize: originalData.count
        )
        let zipURL = temporaryDirectoryURL.appendingPathComponent("deflate.zip")
        try zipData.write(to: zipURL)

        let result = ZipUtility.readZipArchive(at: zipURL)
        XCTAssertNotNil(result, "Deflate ZIP 必须成功解压与解析")
        XCTAssertEqual(result?[fileName], originalData, "解压后的字节数据必须与未压缩数据完全一致")
    }

    // MARK: - 未对齐与损坏签名扫描恢复

    func testReadZipArchive_unalignedSignatureScan_recoversNextValidHeader() throws {
        let dummyGarbage = Data([0xDE, 0xAD, 0xBE, 0xEF, 0x01, 0x02])
        let fileName = "recovered.txt"
        guard let validContent = "Recovered Content".data(using: .utf8) else { return }
        let validZip = buildStoredZip(fileName: fileName, contentData: validContent)

        // 在正常 ZIP 前插入损坏字节模拟偏移扫描
        let combinedData = dummyGarbage + validZip
        let corruptURL = temporaryDirectoryURL.appendingPathComponent("corrupted_prefix.zip")
        try combinedData.write(to: corruptURL)

        let result = ZipUtility.readZipArchive(at: corruptURL)
        XCTAssertNotNil(result, "签名扫描算法应跳过无效前导字节并找到有效本地文件头")
        XCTAssertEqual(result?[fileName], validContent)
    }

    // MARK: - 二进制构造辅助函数

    private func buildStoredZip(fileName: String, contentData: Data) -> Data {
        let nameData = Data(fileName.utf8)
        var zip = Data()

        // Local File Header (30 字节)
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

    private func buildDeflateZip(fileName: String, compressedData: Data, originalSize: Int) -> Data {
        let nameData = Data(fileName.utf8)
        var zip = Data()

        // Local File Header
        zip += Data([0x50, 0x4b, 0x03, 0x04]) // signature
        zip += Data([0x14, 0x00]) // version needed (20)
        zip += Data([0x00, 0x00]) // flags
        zip += Data([0x08, 0x00]) // compression method (8 = deflate)
        zip += Data([0x00, 0x00, 0x00, 0x00]) // mod time/date
        zip += Data([0x00, 0x00, 0x00, 0x00]) // CRC-32
        zip += Data(UInt32(compressedData.count).littleEndianBytes) // compressed size
        zip += Data(UInt32(originalSize).littleEndianBytes) // uncompressed size
        zip += Data(UInt16(nameData.count).littleEndianBytes) // file name length
        zip += Data([0x00, 0x00]) // extra field length
        zip += nameData // file name
        zip += compressedData // compressed data

        return zip
    }

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

private extension UInt16 {
    var littleEndianBytes: [UInt8] {
        var val = self.littleEndian
        return withUnsafeBytes(of: &val) { Array($0) }
    }
}

private extension UInt32 {
    var littleEndianBytes: [UInt8] {
        var val = self.littleEndian
        return withUnsafeBytes(of: &val) { Array($0) }
    }
}
