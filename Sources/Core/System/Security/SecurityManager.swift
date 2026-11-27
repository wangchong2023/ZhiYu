//
//  SecurityManager.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0.5] 系统集成层
//  核心职责：安全基础设施：Keychain 密钥管理、Secure Enclave 加密、HMAC 签名。
//
import Foundation
import UFPCore
import CryptoKit
import UFPStorage
import os

/// 安全管理器：负责数据签名、加密与完整性校验。
class SecurityManager: @unchecked Sendable {
    /// 默认单例
    private static let _defaultShared = SecurityManager()
    /// 全局单例入口：优先从 DI 容器解析已注册实例，否则使用默认单例
    static var shared: SecurityManager {
        // inject_exempt: 静态单例优先从 DI 解析已注册实例，否则 fallback 默认单例（冷启动降级）
        ServiceContainer.shared.resolveOptional(SecurityManager.self) ?? _defaultShared
    }

    // MARK: - 依赖注入
    
    /// 注入文件指纹签名仓储，贯彻 DIP 依赖倒置原则。
    /// 采用可选解析防止在冷启动尚未注册时发生崩溃，此时会安全降级到 UserDefaults。
    private var signatureRepository: (any FileSignatureRepository)? {
        // inject_exempt: 可选解析，冷启动未注册时安全降级
        ServiceContainer.shared.resolveOptional((any FileSignatureRepository).self)
    }

    /// 键值存储抽象，用于 Keychain 故障时的 DEBUG 降级回退。
    /// 使用 resolveOptional 优雅降级：DI 容器未就绪时返回 nil。
    @Inject private var keyStore: (any KeyStoreProtocol)? // inject_exempt: @Inject 存量（Keychain 降级回退）

    // MARK: - 存储键名
    private let saltKey = AppConstants.Keys.Storage.securitySalt
    private let dbPassphraseKey = AppConstants.Keys.Storage.dbPassphrase
    private let signatureKeyPrefix = AppConstants.Keys.Storage.signaturePrefix

    // MARK: - 初始化
    init() {}

    // MARK: - 缓存
    // 使用 OSAllocatedUnfairLock 保护缓存，确保并发安全
    private let lock = OSAllocatedUnfairLock()
    private var _cachedPassphrase: String?
    private var cachedPassphrase: String? {
        get { lock.withLock { _cachedPassphrase } }
        set { lock.withLock { _cachedPassphrase = newValue } }
    }

    // MARK: - 辅助方法

    /// 密钥解析结果
    internal struct ResolvedKeyMaterial: Sendable, Equatable {
        let value: String
        /// 是否允许缓存到内存（仅在确认 Keychain 成功读取或成功持久化时才允许缓存）
        let shouldCache: Bool
    }

    /// 统一获取或生成安全密钥的核心纯逻辑 (@SR-02)
    /// 严禁在 Keychain 读取抛出异常（如锁屏 `errSecInteractionNotAllowed`）时吞错并生成/覆写新密钥，
    /// 否则会导致用户已加密数据库或历史签名永久不可解密；此时返回不可缓存的临时值并保留 Keychain 原状。
    internal static func resolveKeyMaterial(
        forKey key: String,
        errorMessage: String,
        retrieve: (String) throws -> String?,
        store: (String, String) throws -> Void,
        generator: () -> String
    ) -> ResolvedKeyMaterial {
        // 1. 优先从 Keychain 读取；区分「不存在 (nil)」与「访问异常 (throw)」
        do {
            if let existing = try retrieve(key) {
                return ResolvedKeyMaterial(value: existing, shouldCache: true)
            }
        } catch {
            // 锁屏/临时权限异常：严禁覆写 Keychain 且严禁写入内存缓存，等待设备解锁后重试恢复真实密钥
            SecurityLogHelper.logError(
                target: CoreConstants.SecurityLogTarget.securityManager,
                details: errorMessage
            )
            return ResolvedKeyMaterial(value: generator(), shouldCache: false)
        }

        // 2. 确认 Keychain 中确实不存在该密钥后，再生成新密钥并持久化
        let newValue = generator()
        do {
            try store(key, newValue)
            return ResolvedKeyMaterial(value: newValue, shouldCache: true)
        } catch {
            // 持久化失败：仅记录安全日志，不写入内存缓存，避免后续误认为已持久化
            SecurityLogHelper.logError(
                target: CoreConstants.SecurityLogTarget.securityManager,
                details: errorMessage
            )
            return ResolvedKeyMaterial(value: newValue, shouldCache: false)
        }
    }

    /// 恒定时间字符串字节比对，防御 HMAC 签名校验时序侧信道攻击
    internal static func constantTimeEquals(_ lhs: String, _ rhs: String) -> Bool {
        let lhsBytes = Array(lhs.utf8)
        let rhsBytes = Array(rhs.utf8)
        guard lhsBytes.count == rhsBytes.count else { return false }
        var diff: UInt8 = 0
        for (a, b) in zip(lhsBytes, rhsBytes) {
            diff |= a ^ b
        }
        return diff == 0
    }

    /// 统一获取或生成安全密钥的核心逻辑 (@SR-02)
    /// 支持：Keychain 优先 -> 仅在确实不存在时生成 -> 安全持久化
    private func getOrGenerateKey(
        forKey key: String,
        errorMessage: String,
        generator: () -> String
    ) -> ResolvedKeyMaterial {
        Self.resolveKeyMaterial(
            forKey: key,
            errorMessage: errorMessage,
            retrieve: { try KeychainService.shared.retrieve(key: $0) },
            store: { try KeychainService.shared.store(key: $0, value: $1) },
            generator: generator
        )
    }

    // MARK: - 物理加密 (SQLCipher)
    
    /// 获取或生成数据库物理加密所用的密钥
    func getDatabasePassphrase() -> String {
        if let cached = cachedPassphrase {
            return cached
        }
        
        let resolved = getOrGenerateKey(
            forKey: dbPassphraseKey,
            errorMessage: L10n.Security.keychainDatabasePassphraseError,
            generator: { UUID().uuidString + SystemConstants.Character.dash + Data(UUID().uuidString.utf8).base64EncodedString() }
        )
        
        if resolved.shouldCache {
            cachedPassphrase = resolved.value
        }
        return resolved.value
    }

    // MARK: - 内容级加密 (AES-GCM)

    /// 加密
    /// - Parameter text: text
    /// - Returns: 字符串
    func encrypt(_ text: String) throws -> String {
        return try AESGCMCryptoHelper.encrypt(text, using: contentEncryptionKey)
    }

    /// 解密
    /// - Parameter base64Combined: base64Combined
    /// - Returns: 字符串
    func decrypt(_ base64Combined: String) throws -> String {
        return try AESGCMCryptoHelper.decrypt(base64Combined, using: contentEncryptionKey)
    }

    /// 内容级加密对称密钥（基于数据库口令派生）
    private var contentEncryptionKey: SymmetricKey {
        SymmetricKey(data: SHA256.hash(data: Data(getDatabasePassphrase().utf8)))
    }

    // MARK: - 完整性校验 (HMAC)

    @MainActor
    private func getSalt() async -> String {
        return getOrGenerateKey(
            forKey: saltKey,
            errorMessage: L10n.Security.keychainHMACSaltError,
            generator: {
                let legacySalt = AppConstants.Keys.Storage.defaultLegacySalt
                let newSalt = UUID().uuidString + SystemConstants.Character.dash + UUID().uuidString
                
                var hasSignatures = keyStore?.dictionaryRepresentation().keys.contains { $0.hasPrefix(signatureKeyPrefix) } ?? false
                
                if !hasSignatures {
                    // 异步调用需要特殊处理，由于 getOrGenerateKey 是同步的
                    // 这里我们采用阻塞式等待或预先检测。为了保持 getOrGenerateKey 简单，
                    // 我们在闭包内采用同步降级策略
                    hasSignatures = keyStore?.string(forKey: saltKey) != nil
                }
                
                return hasSignatures ? legacySalt : newSalt
            }
        ).value
    }

    /// 计算HMAC
    /// - Returns: 字符串
    func calculateHMAC(for fileURL: URL) async throws -> String {
        let fileData = try Data(contentsOf: fileURL, options: .mappedIfSafe)
        let currentSalt = await getSalt()
        guard let saltData = currentSalt.data(using: .utf8) else {
            throw SecurityError.invalidSalt
        }
        let key = SymmetricKey(data: saltData)
        let signature = HMAC<SHA256>.authenticationCode(for: fileData, using: key)
        return Data(signature).base64EncodedString()
    }
    
    /// 保存Signature
    /// - Parameter signature: signature
    @MainActor
    func saveSignature(_ signature: String, forFilePath filePath: String) async {
        let currentSalt = await getSalt()
        do {
            guard let repo = signatureRepository else {
                throw AppError.security(L10n.Security.signatureRepositoryNotRegistered, code: SystemConstants.HTTPStatusCode.notFound)
            }
            try await repo.saveSignature(signature, forFilePath: filePath, salt: currentSalt)
        } catch {
            // 生产环境：签名持久化失败属于严重安全错误，不允许明文降级
            SecurityLogHelper.logError(
                target: CoreConstants.SecurityLogTarget.securityManager,
                details: "\(CoreConstants.SecurityLogDetails.criticalFailed) to persist HMAC signature securely: \(error.localizedDescription)"
            )

        }
    }
    
    /// 验证Integrity
    /// - Returns: 是否成功
    @MainActor
    func verifyIntegrity(for fileURL: URL) async -> Bool {
        let filePath = fileURL.path
        
        let storedSig: String?
        if let repo = signatureRepository {
            storedSig = try? await repo.fetchSignature(forFilePath: filePath)
        } else {
            storedSig = nil
        }
        
        var finalStoredSig = storedSig
        if finalStoredSig == nil {
            let fileName = fileURL.lastPathComponent
            finalStoredSig = keyStore?.string(forKey: signatureKeyPrefix + fileName)
        }
        
        // VULN-004 修复：无签名时 fail-closed（返回 false），而非 fail-open（返回 true）
        guard let expectedSig = finalStoredSig else {
            SecurityLogHelper.logError(
                target: CoreConstants.SecurityLogTarget.securityManager,
                details: "Integrity check failed: no signature on file: \(fileURL.lastPathComponent)"
            )
            return false

        }
        
        do {
            let currentSig = try await calculateHMAC(for: fileURL)
            return Self.constantTimeEquals(currentSig, expectedSig)
        } catch {
            return false
        }
    }
    
    /// 更新Signature
    func updateSignature(for fileURL: URL) async {
        do {
            let sig = try await calculateHMAC(for: fileURL)
            await saveSignature(sig, forFilePath: fileURL.path)
        } catch {
            SecurityLogHelper.logError(
                target: CoreConstants.SecurityLogTarget.securityManager,
                details: "\(CoreConstants.SecurityLogDetails.failedTo) update signature: \(error.localizedDescription)"
            )
        }
    }
}
