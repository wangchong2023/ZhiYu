//
//  AESGCMCryptoHelper.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/14.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0.5] 系统集成层
//  核心职责：提供 AES-GCM 加解密的公共辅助方法，消除 SecurityManager 与 SecureEnclaveCryptoService 之间重复的加解密代码块。
//
import Foundation
import CryptoKit

/// AES-GCM 对称加解密辅助
/// 抽取 SecurityManager.encrypt/decrypt 与 SecureEnclaveCryptoService.encrypt/decrypt 中重复的
/// `text.data(using:.utf8)` + `AES.GCM.seal` / `AES.GCM.SealedBox` + `String(data:encoding:.utf8)` 模式。
enum AESGCMCryptoHelper {

    /// 使用对称密钥加密明文字符串
    /// - Parameters:
    ///   - plainText: 原始明文
    ///   - symmetricKey: 对称密钥
    /// - Returns: Base64 编码的复合密文
    /// - Throws: `SecurityError.encodingFailed`（明文编码失败）或底层 CryptoKit 错误
    static func encrypt(_ plainText: String, using symmetricKey: SymmetricKey) throws -> String {
        guard let data = plainText.data(using: .utf8) else {
            throw SecurityError.encodingFailed
        }
        let sealedBox = try AES.GCM.seal(data, using: symmetricKey)
        return sealedBox.combined?.base64EncodedString() ?? ""
    }

    /// 使用对称密钥解密 Base64 复合密文
    /// - Parameters:
    ///   - cipherText: Base64 编码的复合密文
    ///   - symmetricKey: 对称密钥
    /// - Returns: 还原的原始明文
    /// - Throws: `SecurityError.decodingFailed`（Base64 解码或 UTF-8 还原失败）或底层 CryptoKit 错误
    static func decrypt(_ cipherText: String, using symmetricKey: SymmetricKey) throws -> String {
        let sealedBox = try sealedBox(from: cipherText)
        let decryptedData = try AES.GCM.open(sealedBox, using: symmetricKey)
        return try utf8String(from: decryptedData)
    }

    /// 从 Base64 编码的复合密文构造 AES-GCM SealedBox，消除 AESGCMCryptoHelper 与 SecureEnclaveCryptoService 间的解码样板重复。
    /// - Parameter cipherText: Base64 编码的复合密文
    /// - Returns: AES-GCM SealedBox
    /// - Throws: `SecurityError.decodingFailed`（Base64 解码失败）或底层 CryptoKit 错误
    static func sealedBox(from cipherText: String) throws -> AES.GCM.SealedBox {
        guard let combinedData = Data(base64Encoded: cipherText) else {
            throw SecurityError.decodingFailed
        }
        return try AES.GCM.SealedBox(combined: combinedData)
    }

    /// 将解密后的 Data 还原为 UTF-8 字符串，统一错误类型为 SecurityError.decodingFailed。
    /// - Parameter data: 解密后的原始数据
    /// - Returns: 还原的明文字符串
    /// - Throws: `SecurityError.decodingFailed`（UTF-8 还原失败）
    static func utf8String(from data: Data) throws -> String {
        guard let decryptedString = String(data: data, encoding: .utf8) else {
            throw SecurityError.decodingFailed
        }
        return decryptedString
    }
}
