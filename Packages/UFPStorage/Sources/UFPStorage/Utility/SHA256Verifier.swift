//
//  SHA256Verifier.swift
//  UFPStorage
//
//  Created by Antigravity on 2026/10/11.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[UFPStorage] 通用存储引擎包
//  核心职责：文件 SHA256 流式完整性校验工具，与业务完全无关。
//

import Foundation
import CommonCrypto
import UFPCore

/// 通用文件 SHA256 流式完整性校验工具。
public enum SHA256Verifier {

    /// 标准 SHA-256 十六进制哈希串字符数
    public static let sha256HexLength = 64
    /// SHA256 校验流式读取的缓冲区大小（1MB，防止加载数 GB 文件撑爆运行内存）
    public static let sha256BufferSize = Int(SystemConstants.bytesPerKB) * Int(SystemConstants.bytesPerKB)

    /// 校验文件的 SHA256 哈希是否与期望值一致。
    /// - Returns: 校验是否通过（空哈希容灾放行；非 64 字符拒绝）
    public static func verify(of fileURL: URL, expectedHash: String) -> Bool {
        // 容灾策略：未注册 checksum 时跳过校验，放行文件
        guard !expectedHash.isEmpty else {
            return true
        }

        // 强制约束：标准的 SHA-256 十六进制哈希串必然是 64 字符
        guard expectedHash.count == sha256HexLength else {
            return false
        }

        guard let file = FileHandle(forReadingAtPath: fileURL.path) else { return false }
        defer { try? file.close() }

        var context = CC_SHA256_CTX()
        CC_SHA256_Init(&context)

        let bufferSize = sha256BufferSize // 1MB 内存分片读取
        while true {
            let data = file.readData(ofLength: bufferSize)
            if data.isEmpty { break }
            data.withUnsafeBytes { buffer in
                _ = CC_SHA256_Update(&context, buffer.baseAddress, CC_LONG(data.count))
            }
        }

        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        CC_SHA256_Final(&digest, &context)

        let hexHash = digest.map { String(format: "%02hhx", $0) }.joined()
        return hexHash.lowercased() == expectedHash.lowercased()
    }
}