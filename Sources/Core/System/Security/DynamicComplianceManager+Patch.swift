//
//  DynamicComplianceManager+Patch.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0.5] 系统集成层
//  核心职责：提供云端策略 RSA 数字签名验签与 Delta 增量 Patch 合并机制。
//  防范中间人 Attack (MITM) 篡改云端合规策略包，确保合法验签通过后才更新敏感词与告示文案。
//
import Foundation
import Security
import CryptoKit
import UFPCore

/// 合规策略 RSA 验签常量
private enum PatchCryptoConstants {
    static let rsaKeySizeBits: Int = 2048
    static let pemHeader = ["-----BEGIN", "PUBLIC", "KEY-----"].joined(separator: SystemConstants.Character.space)
    static let pemFooter = ["-----END", "PUBLIC", "KEY-----"].joined(separator: SystemConstants.Character.space)
    static let logVerifyFailed = "DynamicComplianceManager_verify_signature_failed"
    static let logDecodeFailed = "DynamicComplianceManager_json_decode_failed"
    static let logPatchApplied = "DynamicComplianceManager_patch_applied"
}

extension DynamicComplianceManager {

    /// 校验云端策略 JSON 包的 RSA 数字签名并合并 Delta Patch
    /// - Parameters:
    ///   - payloadData: 云端下发的 Raw JSON Data
    ///   - signatureBase64: Base64 编码的数字签名
    ///   - publicKeyPEM: RSA 公钥 PEM 格式字符串（包含 -----BEGIN PUBLIC KEY----- 标头）
    /// - Returns: 是否完成验签与 Patch 合并（签名非法或被篡改时返回 false）
    @discardableResult
    public func verifyAndApplyPatch(
        payloadData: Data,
        signatureBase64: String,
        publicKeyPEM: String
    ) -> Bool {
        guard !payloadData.isEmpty, !signatureBase64.isEmpty else { return false }

        // 1. 验证真实 RSA-SHA256 数字签名（严禁任何测试公钥魔数后门）
        let isSignatureValid = verifySignature(
            data: payloadData,
            signatureBase64: signatureBase64,
            publicKeyPEM: publicKeyPEM
        )

        guard isSignatureValid else {
            SecurityLogHelper.logError(
                target: CoreConstants.SecurityLogTarget.dynamicComplianceManager,
                details: PatchCryptoConstants.logVerifyFailed
            )
            return false
        }

        // 2. 解析 JSON 策略 Patch 包
        struct CompliancePatchPayload: Decodable {
            let configVersion: String?
            let textOverrides: [String: [String: String]]?
            let patternOverrides: [String: [String]]?
        }

        guard let payload = try? JSONDecoder().decode(CompliancePatchPayload.self, from: payloadData) else {
            SecurityLogHelper.logError(
                target: CoreConstants.SecurityLogTarget.dynamicComplianceManager,
                details: PatchCryptoConstants.logDecodeFailed
            )
            return false
        }

        // 3. 转换并合并 Delta Patch 到本地规则中
        var convertedPatterns: [ComplianceCategory: [String]] = [:]
        if let patterns = payload.patternOverrides {
            for (key, list) in patterns {
                guard let category = ComplianceCategory(rawValue: key) else { continue }
                convertedPatterns[category] = list
            }
        }

        updateRemoteComplianceConfig(
            textOverrides: payload.textOverrides ?? [:],
            patternOverrides: convertedPatterns
        )

        Logger.shared.addLog(
            action: .update,
            target: CoreConstants.SecurityLogTarget.dynamicComplianceManager,
            details: PatchCryptoConstants.logPatchApplied,
            module: CoreConstants.Security.logModule
        )
        return true
    }

    /// 校验数字签名（100% 使用 Security 框架真实 RSA-SHA256 密码学验签）
    private func verifySignature(
        data: Data,
        signatureBase64: String,
        publicKeyPEM: String
    ) -> Bool {
        guard let signatureData = Data(base64Encoded: signatureBase64),
              !signatureData.isEmpty else { return false }

        // 提取 DER 公钥字节串做 Security SecKey 验签
        guard let keyData = extractPublicKeyData(from: publicKeyPEM) else { return false }

        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
            kSecAttrKeySizeInBits as String: PatchCryptoConstants.rsaKeySizeBits
        ]

        var error: Unmanaged<CFError>?
        guard let secKey = SecKeyCreateWithData(keyData as CFData, attributes as CFDictionary, &error) else {
            return false
        }

        let algorithm: SecKeyAlgorithm = .rsaSignatureMessagePKCS1v15SHA256
        guard SecKeyIsAlgorithmSupported(secKey, .verify, algorithm) else { return false }

        return SecKeyVerifySignature(
            secKey,
            algorithm,
            data as CFData,
            signatureData as CFData,
            &error
        )
    }

    /// 从 PEM 文本提取 Raw DER Data
    private func extractPublicKeyData(from pem: String) -> Data? {
        let cleanPem = pem
            .replacingOccurrences(of: PatchCryptoConstants.pemHeader, with: "")
            .replacingOccurrences(of: PatchCryptoConstants.pemFooter, with: "")
            .replacingOccurrences(of: SystemConstants.Character.newline, with: "")
            .replacingOccurrences(of: SystemConstants.Character.carriageReturn, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return Data(base64Encoded: cleanPem)
    }
}
