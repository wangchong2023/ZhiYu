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

        /// 路径穿越段标识
        static let parentDirectorySegment = ".."
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
            parseEntries(in: buffer, into: &archive)
        }

        return archive.isEmpty ? nil : archive
    }

    /// 顺序解析 ZIP 缓冲区中的所有本地文件头条目（含 Zip Slip 路径校验与总容量防线）
    private static func parseEntries(in buffer: UnsafeRawBufferPointer, into archive: inout [String: Data]) {
        guard let baseAddress = buffer.baseAddress else { return }
        var offset = 0
        var totalExtractedBytes = 0
        let count = buffer.count

        while offset + ZipFormat.localFileHeaderSize < count {
            let bytes = baseAddress.advanced(by: offset)
            guard bytes.loadUnaligned(as: UInt32.self) == ZipFormat.localFileHeaderSignature else {
                guard let nextOffset = findNextLocalFileHeader(in: buffer, start: offset) else { break }
                offset = nextOffset
                continue
            }

            let fileNameLength = Int(bytes.loadUnaligned(fromByteOffset: LocalFileHeaderOffset.fileNameLength, as: UInt16.self))
            let extraFieldLength = Int(bytes.loadUnaligned(fromByteOffset: LocalFileHeaderOffset.extraFieldLength, as: UInt16.self))
            let compressedSize = Int(bytes.loadUnaligned(fromByteOffset: LocalFileHeaderOffset.compressedSize, as: UInt32.self))
            let dataOffset = offset + ZipFormat.localFileHeaderSize + fileNameLength + extraFieldLength
            guard dataOffset + compressedSize <= count else { break }

            let nameBytes = UnsafeRawPointer(baseAddress).advanced(by: offset + ZipFormat.localFileHeaderSize)
            guard let fileName = String(data: Data(bytes: nameBytes, count: fileNameLength), encoding: .utf8) else {
                offset += MemoryLayout<UInt32>.size
                continue
            }
            guard isSafeArchiveEntryPath(fileName) else {
                offset = dataOffset + compressedSize
                continue
            }

            let compressionMethod = UInt16(bytes.loadUnaligned(fromByteOffset: LocalFileHeaderOffset.compressionMethod, as: UInt16.self))
            let compressedData = Data(bytes: baseAddress.advanced(by: dataOffset), count: compressedSize)
            if let extractedData = decodeEntryData(compressedData, method: compressionMethod) {
                guard extractedData.count <= ZipFormat.deflateBufferMaxSize - totalExtractedBytes else { break }
                totalExtractedBytes += extractedData.count
                archive[fileName] = extractedData
            }
            offset = dataOffset + compressedSize
        }
    }

    /// 按压缩方式解码单个 ZIP 条目二进制内容
    private static func decodeEntryData(_ compressedData: Data, method: UInt16) -> Data? {
        if method == ZipFormat.compressionMethodStored {
            return compressedData
        } else if method == ZipFormat.compressionMethodDeflate {
            return decompressDeflate(data: compressedData)
        }
        return nil
    }

    /// 校验 ZIP 条目路径安全性，拦截空路径、绝对路径、反斜杠及 `..` 目录穿越（Zip Slip）
    internal static func isSafeArchiveEntryPath(_ fileName: String) -> Bool {
        guard !fileName.isEmpty,
              !fileName.hasPrefix(SystemConstants.Character.slash),
              !fileName.contains(SystemConstants.Character.backslash) else {
            return false
        }
        let segments = fileName.split(separator: Character(SystemConstants.Character.slash), omittingEmptySubsequences: false)
        return !segments.contains { String($0) == ZipFormat.parentDirectorySegment }
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
        guard !data.isEmpty else { return nil }
        let (initialSize, overflow) = data.count.multipliedReportingOverflow(by: ZipFormat.deflateBufferInitialMultiplier)
        var destinationBufferSize = overflow
            ? ZipFormat.deflateBufferMaxSize
            : min(initialSize, ZipFormat.deflateBufferMaxSize)

        while destinationBufferSize > 0 && destinationBufferSize <= ZipFormat.deflateBufferMaxSize {
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
