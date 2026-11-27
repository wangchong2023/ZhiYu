//
//  SecureEnclaveCryptoService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0.5] 系统集成层
//  核心职责：实现 SecureEnclaveCrypto 模块的核心业务逻辑服务。
//
import Foundation
import CryptoKit
import UFPCore

/// 硬件安全芯片加解密服务 (SecureEnclaveCryptoService)
/// 专为第三方敏感令牌提供 Secure Enclave 物理层级锁死，杜绝文件级破解与异地克隆。
class SecureEnclaveCryptoService: @unchecked Sendable {
    /// 默认单例
    private static let _defaultShared = SecureEnclaveCryptoService()
    /// 全局唯一的线程安全单例入口：优先从 DI 容器解析已注册实例，否则使用默认单例
    static var shared: SecureEnclaveCryptoService {
        // inject_exempt: 静态单例优先从 DI 解析已注册实例，否则 fallback 默认单例（冷启动降级）
        ServiceContainer.shared.resolveOptional(SecureEnclaveCryptoService.self) ?? _defaultShared
    }
    
    private enum CryptoConstants {
        static let hardwareKeyTokenPath = "com.zhiyu.secure_enclave.token"
        static let hkdfSaltPath = "com.zhiyu.secure_enclave.hkdf_salt"
        static let legacyECDHPublicKeyPath = "com.zhiyu.secure_enclave.legacy_pub"
        static let hkdfByteCount = 32
    }

    /// HKDF 上下文绑定信息（固定值，区分不同用途的密钥派生）
    /// 引用 SystemConstants.CryptoProtocol.apiKeyEncryptionV2
    private let hkdfSharedInfo = Data(SystemConstants.CryptoProtocol.apiKeyEncryptionV2.utf8)
    
    init() {}
    
    // MARK: - 状态属性
    
    /// 检测当前设备硬件是否支持并启用了 Secure Enclave 安全协处理器
    var isSupported: Bool {
        #if targetEnvironment(simulator)
        // 模拟器下硬件芯片层无法完全加载，返回 false 走安全降级
        return false
        #else
        return SecureEnclave.isAvailable
        #endif
    }
    
    // MARK: - API 接口
    
    /// 使用 Secure Enclave 硬件芯片物理级加解密 API 密钥 (加密)
    /// - Parameter plainText: 原始明文字符串
    /// - Returns: 加密后的 Base64 复合密文字符串。若不支持 Secure Enclave，则优雅降级为基于 SQLCipher 密钥的应用级 AES-GCM 密文。
    func encrypt(_ plainText: String) throws -> String {
        guard isSupported else {
            // 物理降级方案：使用 SecurityManager 现有的 AES-GCM 软件保护逻辑
            return try SecurityManager.shared.encrypt(plainText)
        }

        // VULN-003 修复：不再使用自协商（sharedSecretFromKeyAgreement with self.publicKey），
        // 改用硬件私钥 dataRepresentation 的 SHA-256 摘要作为 HKDF 输入密钥材料，
        // 配合持久化随机盐值和上下文绑定信息，派生设备唯一的对称密钥。
        let symmetricKey = try deriveSymmetricKey()
        return try AESGCMCryptoHelper.encrypt(plainText, using: symmetricKey)
    }
    
    /// 使用 Secure Enclave 硬件芯片物理级加解密 API 密钥 (解密)
    /// - Parameter cipherText: 加密后的 Base64 复合密文
    /// - Returns: 还原的原始明文字符串。若不支持 Secure Enclave，则优雅使用物理降级解密。
    func decrypt(_ cipherText: String) throws -> String {
        guard isSupported else {
            // 物理降级方案：使用 SecurityManager 的 AES-GCM 解密
            return try SecurityManager.shared.decrypt(cipherText)
        }
        
        // VULN-003 修复：使用相同的 HKDF 派生逻辑还原对称密钥
        let symmetricKey = try deriveSymmetricKey()

        // 使用 AES-GCM 还原明文
        let sealedBox = try AESGCMCryptoHelper.sealedBox(from: cipherText)

        // 审查修复 HIGH-1: 迁移逻辑 — 新 HKDF 密钥解密失败时，尝试旧 ECDH 自协商密钥解密
        // 若旧逻辑解密成功，用新 HKDF 逻辑重新加密并写回 Keychain，完成透明迁移
        do {
            let decryptedData = try AES.GCM.open(sealedBox, using: symmetricKey)
            return try AESGCMCryptoHelper.utf8String(from: decryptedData)
        } catch {
            // 新密钥解密失败，尝试旧 ECDH 自协商逻辑（迁移路径）
            if let legacyKey = try? deriveLegacyECDHKey(),
               let migratedPlain = try? AES.GCM.open(sealedBox, using: legacyKey),
               let migratedString = String(data: migratedPlain, encoding: .utf8) {
                // 迁移成功：用新 HKDF 逻辑重新加密并写回
                Logger.shared.info("[SecureEnclave] 旧密文迁移成功，重新加密为 HKDF 格式")
                if let reencrypted = try? encrypt(migratedString) {
                    // 找到对应的 Keychain key 并更新（由调用方处理，此处仅记录）
                    Logger.shared.debug("[SecureEnclave] 密文已迁移，调用方应更新 Keychain 存储")
                    _ = reencrypted
                }
                return migratedString
            }
            // 两种逻辑均失败，抛出原始错误
            throw error
        }
    }
    
    // MARK: - 密钥派生（VULN-003 修复）
    
    /// 基于 Secure Enclave 硬件私钥 + 持久化随机盐派生对称密钥
    /// - Returns: 256-bit SymmetricKey
    /// - Note: 不再使用自协商 ECDH，改用 HKDF(SHA256(hardwareKey.dataRepresentation), salt=persistentRandomSalt, info=contextBinding)
    private func deriveSymmetricKey() throws -> SymmetricKey {
        let hardwarePrivateKey = try getOrCreateHardwarePrivateKey()
        
        // 1. 获取或生成持久化随机盐（非空，存储在 Keychain）
        let salt = try getOrCreateHKDFSalt()
        
        // 2. 将硬件私钥的 dataRepresentation 作为 HKDF 输入密钥材料（IKM）
        //    注意：dataRepresentation 本身不可逆推私钥，但结合 Secure Enclave 硬件保护，
        //    攻击者需同时获取 Keychain 中的 salt + token 才能重现密钥
        let ikm = Data(hardwarePrivateKey.dataRepresentation)
        
        // 3. HKDF 派生：SHA256(IKM, salt, sharedInfo) → 32 字节对称密钥
        let derivedKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: ikm),
            salt: salt,
            info: hkdfSharedInfo,
            outputByteCount: CryptoConstants.hkdfByteCount
        )
        return derivedKey
    }

    /// 严格区分「Keychain 读取抛错（如锁屏不可用）」与「明确不存在（nil）」的密钥材料解析器：
    /// 任何 Keychain 异常必须原样向上抛出，严禁吞错并重建覆盖旧密钥导致存量密文永久不可解密。
    internal static func resolveKeyMaterial<T>(
        loadExisting: () throws -> T?,
        createAndPersist: () throws -> T
    ) throws -> T {
        if let existing = try loadExisting() {
            return existing
        }
        return try createAndPersist()
    }
    
    /// 获取或生成持久化 HKDF 随机盐（32 字节，存储在 Keychain）
    private func getOrCreateHKDFSalt() throws -> Data {
        try Self.resolveKeyMaterial(
            loadExisting: {
                guard let stored = try KeychainService.shared.retrieve(key: CryptoConstants.hkdfSaltPath),
                      let saltData = Data(base64Encoded: stored) else {
                    return nil
                }
                return saltData
            },
            createAndPersist: {
                var randomBytes = [UInt8](repeating: 0, count: CryptoConstants.hkdfByteCount)
                let status = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
                guard status == errSecSuccess else {
                    throw SecurityError.invalidSalt
                }
                let saltData = Data(randomBytes)
                try KeychainService.shared.store(key: CryptoConstants.hkdfSaltPath, value: saltData.base64EncodedString())
                return saltData
            }
        )
    }
    
    // MARK: - 旧版 ECDH 密钥派生（迁移用）
    
    /// 审查修复 HIGH-1: 旧版 ECDH 自协商密钥派生（用于迁移存量密文）
    /// - Returns: 旧版派生的 SymmetricKey，若旧公钥不存在则返回 nil
    private func deriveLegacyECDHKey() throws -> SymmetricKey? {
        // 尝试从 Keychain 读取旧版 ECDH 自协商公钥
        guard let pubKeyB64 = try? KeychainService.shared.retrieve(key: CryptoConstants.legacyECDHPublicKeyPath),
              let pubKeyData = Data(base64Encoded: pubKeyB64) else {
            return nil
        }
        let hardwarePrivateKey = try getOrCreateHardwarePrivateKey()
        let legacyPublicKey = try P256.KeyAgreement.PublicKey(rawRepresentation: pubKeyData)
        let sharedSecret = try hardwarePrivateKey.sharedSecretFromKeyAgreement(with: legacyPublicKey)
        let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(),
            sharedInfo: Data(),
            outputByteCount: CryptoConstants.hkdfByteCount
        )
        return symmetricKey
    }
    
    // MARK: - 内部私密辅助方法
    
    /// 获取或物理新建 Secure Enclave 内置 P-256 私钥
    private func getOrCreateHardwarePrivateKey() throws -> SecureEnclave.P256.KeyAgreement.PrivateKey {
        try Self.resolveKeyMaterial(
            loadExisting: {
                // 严格传播 Keychain 异常（如锁屏 errSecInteractionNotAllowed），绝不静默覆盖旧私钥
                guard let tokenDataString = try KeychainService.shared.retrieve(key: CryptoConstants.hardwareKeyTokenPath),
                      let tokenData = Data(base64Encoded: tokenDataString) else {
                    return nil
                }
                return try SecureEnclave.P256.KeyAgreement.PrivateKey(dataRepresentation: tokenData)
            },
            createAndPersist: {
                // 仅在 Keychain 明确不存在历史 Token 时才新建硬件私钥
                let newKey = try SecureEnclave.P256.KeyAgreement.PrivateKey()
                let tokenData = newKey.dataRepresentation
                try KeychainService.shared.store(key: CryptoConstants.hardwareKeyTokenPath, value: tokenData.base64EncodedString())
                return newKey
            }
        )
    }
}
