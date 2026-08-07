//
//  ZipUtility.swift
//  UFPCore
//
//  Created by CodeFree on 2026/08/07.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 基础设施层
//  核心职责：通用 ZIP 文件格式解析工具，与业务无关。
//           依据 APPNOTE.TXT 6.3.10 / PKWARE ZIP File Format Specification。
//

import Foundation
import Compression

/// ZIP 工具类：支持解压与解析 ZIP 存档中的特定文件。
public enum ZipUtility {

    /// ZIP 格式常量（依据 APPNOTE.TXT 6.3.10 / PKWARE ZIP File Format Specification）
    private enum ZipFormat {
        /// Local File Header 固定部分长度（30 字节：签名 4 + 版本 2 + 标志 2 + 方法 2 + 时间 4 + CRC 4 + 压缩大小 4 + 未压缩大小 4 + 文件名长度 2 + 额外字段长度 2）
        static let localFileHeaderSize = 30

        /// Local File Header 签名（小端 `50 4B 03 04`）
        static let localFileHeaderSignature: UInt32 = 0x04034B50

        /// Central Directory 签名（小端 `50 4B 01 02`）
        static let centralDirectorySignature: UInt32 = 0x02014B50

        /// End of Central Directory 签名（小端 `50 4B 05 06`）
        static let endOfCentralDirectorySignature: UInt32 = 0x06054B50

        /// 压缩方法：Stored（无压缩）
        static let compressionMethodStored: UInt16 = 0

        /// 压缩方法：Deflate
        static let compressionMethodDeflate: UInt16 = 8

        /// Deflate 解压缓冲区初始放大倍数（预估未压缩大小为压缩数据的倍数）
        static let deflateBufferInitialMultiplier = 10

        /// Deflate 解压缓冲区倍增因子（每次重试时缓冲区大小翻倍）
        static let deflateBufferGrowthFactor = 2

        /// Deflate 解压缓冲区最大容量上限（256MB，防止恶意 ZIP 导致内存耗尽）
        static let deflateBufferMaxSize = 268435456

        /// 签名扫描步长（逐字节搜索下一个文件头）
        static let signatureScanStep = 1
    }

    /// Local File Header 字段偏移量（依据 ZIP 规范）
    private enum LocalFileHeaderOffset {
        static let signature = 0
        static let compressionMethod = 8
        static let compressedSize = 18
        static let fileNameLength = 26
        static let extraFieldLength = 28
    }

    /// 读取 ZIP 存档并返回文件路径与二进制数据的映射。
    public static func readZipArchive(at url: URL) -> [String: Data]? {
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }

        var archive: [String: Data] = [:]

        data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
            guard let baseAddress = buffer.baseAddress else { return }

            var offset = 0
            let count = buffer.count

            while offset + ZipFormat.localFileHeaderSize < count {
                let bytes = baseAddress.advanced(by: offset)

                // Local file header signature（使用 loadUnaligned 避免对齐违规崩溃）
                guard bytes.loadUnaligned(as: UInt32.self) == ZipFormat.localFileHeaderSignature else {
                    // Try to find next file header
                    if let nextOffset = findNextLocalFileHeader(in: buffer, start: offset) {
                        offset = nextOffset
                        continue
                    }
                    break
                }

                let fileNameLength = Int(bytes.loadUnaligned(
                    fromByteOffset: LocalFileHeaderOffset.fileNameLength,
                    as: UInt16.self
                ))
                let extraFieldLength = Int(bytes.loadUnaligned(
                    fromByteOffset: LocalFileHeaderOffset.extraFieldLength,
                    as: UInt16.self
                ))
                let compressedSize = Int(bytes.loadUnaligned(
                    fromByteOffset: LocalFileHeaderOffset.compressedSize,
                    as: UInt32.self
                ))

                let headerSize = ZipFormat.localFileHeaderSize + fileNameLength + extraFieldLength
                let dataOffset = offset + headerSize

                guard dataOffset + compressedSize <= count else { break }

                let nameBytes = UnsafeRawPointer(baseAddress).advanced(
                    by: offset + ZipFormat.localFileHeaderSize
                )
                let fileNameData = Data(bytes: nameBytes, count: fileNameLength)
                guard let fileName = String(data: fileNameData, encoding: .utf8) else {
                    offset += MemoryLayout<UInt32>.size
                    continue
                }

                // Decompress if needed (method 0 = stored, 8 = deflate)
                let compressionMethod = UInt16(bytes.loadUnaligned(
                    fromByteOffset: LocalFileHeaderOffset.compressionMethod,
                    as: UInt16.self
                ))
                let compressedData = Data(bytes: baseAddress.advanced(by: dataOffset), count: compressedSize)

                if compressionMethod == ZipFormat.compressionMethodStored {
                    archive[fileName] = compressedData
                } else if compressionMethod == ZipFormat.compressionMethodDeflate {
                    if let decompressed = decompressDeflate(data: compressedData) {
                        archive[fileName] = decompressed
                    }
                }

                offset = dataOffset + compressedSize
            }
        }

        return archive.isEmpty ? nil : archive
    }

    /// 查找NextLocalFileHeader
    /// - Parameter start: 启动
    /// - Returns: 可选值
    private static func findNextLocalFileHeader(in buffer: UnsafeRawBufferPointer, start: Int) -> Int? {
        let count = buffer.count
        var i = start + MemoryLayout<UInt32>.size
        while i + MemoryLayout<UInt32>.size <= count {
            let sig = buffer.loadUnaligned(fromByteOffset: i, as: UInt32.self)
            if sig == ZipFormat.localFileHeaderSignature {
                return i
            }
            i += ZipFormat.signatureScanStep
        }
        return nil
    }

    /// 解压 Deflate 数据
    ///
    /// Finding #16 修复：原实现用固定 10 倍缓冲区，对高压缩比数据（如重复字符串）
    /// 会导致 `compression_decode_buffer` 返回值被截断。改为循环倍增重试策略：
    /// 初始 10 倍，若返回值等于缓冲区大小（可能截断）则倍增重试，直到返回值 < 缓冲区
    /// 大小（解压完整）或达到 256MB 上限。
    /// - Parameter data: 压缩数据
    /// - Returns: 解压后的数据，解压失败返回 nil
    private static func decompressDeflate(data: Data) -> Data? {
        var destinationBufferSize = data.count * ZipFormat.deflateBufferInitialMultiplier

        while destinationBufferSize <= ZipFormat.deflateBufferMaxSize {
            var destinationData = Data(count: destinationBufferSize)

            let result = destinationData.withUnsafeMutableBytes { destBuffer in
                data.withUnsafeBytes { sourceBuffer -> Int? in
                    guard let sourcePointer = sourceBuffer.baseAddress,
                          let destPointer = destBuffer.baseAddress else { return nil }

                    let size = compression_decode_buffer(
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

            // 若返回值 < 缓冲区大小，解压完整；否则可能被截断，倍增重试
            if size < destinationBufferSize {
                return destinationData.prefix(size)
            }

            // 缓冲区不足，倍增重试
            destinationBufferSize *= ZipFormat.deflateBufferGrowthFactor
        }

        // 超过 256MB 上限仍未解压完整，返回 nil 避免内存耗尽
        return nil
    }
}
