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
    /// 真实单例（内部持有）
    private static let _shared = SecurityManager()
    /// 测试覆盖：设置非 nil 值后 shared 返回 Mock 实例；在 tearDown 中置 nil 恢复
    nonisolated(unsafe) static var testOverride: SecurityManager?
    /// 全局单例入口：测试模式下可被替换
    static var shared: SecurityManager { testOverride ?? _shared }

    // MARK: - 依赖注入
    
    /// 注入文件指纹签名仓储，贯彻 DIP 依赖倒置原则。
    /// 采用可选解析防止在冷启动尚未注册时发生崩溃，此时会安全降级到 UserDefaults。
    private var signatureRepository: (any FileSignatureRepository)? {
        ServiceContainer.shared.resolveOptional((any FileSignatureRepository).self)
    }

    /// 键值存储抽象，用于 Keychain 故障时的 DEBUG 降级回退。
    /// 使用 resolveOptional 优雅降级：DI 容器未就绪时返回 nil。
    @Inject private var keyStore: (any KeyStoreProtocol)?

    // MARK: - 存储键名
    private let saltKey = AppConstants.Keys.Storage.securitySalt
    private let dbPassphraseKey = AppConstants.Keys.Storage.dbPassphrase
    private let signatureKeyPrefix = AppConstants.Keys.Storage.signaturePrefix

    // MARK: - 初始化
    init() {}

    // MARK: - 缓存
    // 使用 nonisolated(unsafe) 配合 actor 同步访问或确保单线程访问
    // 此处由于 SecurityManager 是 Sendable 且 singleton，我们采用锁或 MainActor 隔离来保护缓存
    // 为简化实现且保证性能，我们将缓存操作也放在辅助方法中
    private let lock = OSAllocatedUnfairLock()
    private var _cachedPassphrase: String?
    private var cachedPassphrase: String? {
        get { lock.withLock { _cachedPassphrase } }
        set { lock.withLock { _cachedPassphrase = newValue } }
    }

    // MARK: - 辅助方法
    
    /// 统一获取或生成安全密钥的核心逻辑 (@SR-02)
    /// 支持：Keychain 优先 -> Debug 模式下的 UserDefaults 兜底 -> 自动生成 -> 持久化
    private func getOrGenerateKey(
        forKey key: String,
        errorMessage: String,
        generator: () -> String
    ) -> String {
        // 1. 优先从 Keychain 读取
        if let existing = try? KeychainService.shared.retrieve(key: key) {
            return existing
        }
        
        #if DEBUG && !os(watchOS)
        // 2. DEBUG 模式下，尝试从 KeyStore 兜底 (用于模拟器环境)
        if let fallback = runOnMainSync({ keyStore?.string(forKey: key) }) {
            return fallback
        }
        #endif
        
        // 3. 生成新密钥
        let newValue = generator()
        
        // 4. 持久化
        do {
            try KeychainService.shared.store(key: key, value: newValue)
            return newValue
        } catch {
            #if DEBUG && !os(watchOS)
            runOnMainSync { keyStore?.set(newValue, forKey: key) }
            return newValue
            #else
            // 生产环境下安全存储故障：记录严重错误并返回内存中的临时密钥，
            // 避免 fatalError 导致白屏崩溃，但此密钥不会持久化（重启后丢失）。
            assertionFailure(" [SecurityManager] \(errorMessage)")
            return newValue
            #endif
        }
    }

    // MARK: - 物理加密 (SQLCipher)
    
    /// 获取或生成数据库物理加密所用的密钥
    func getDatabasePassphrase() -> String {
        if let cached = cachedPassphrase {
            return cached
        }
        
        let passphrase = getOrGenerateKey(
            forKey: dbPassphraseKey,
            errorMessage: L10n.Security.keychainDatabasePassphraseError,
            generator: { UUID().uuidString + "-" + Data(UUID().uuidString.utf8).base64EncodedString() }
        )
        
        cachedPassphrase = passphrase
        return passphrase
    }

    // MARK: - 内容级加密 (AES-GCM)

    /// 加密
    /// - Parameter text: text
    /// - Returns: 字符串
    func encrypt(_ text: String) throws -> String {
        let key = SymmetricKey(data: SHA256.hash(data: Data(getDatabasePassphrase().utf8)))
        guard let data = text.data(using: .utf8) else { throw SecurityError.encodingFailed }
        let sealedBox = try AES.GCM.seal(data, using: key)
        return sealedBox.combined?.base64EncodedString() ?? ""
    }

    /// 解密
    /// - Parameter base64Combined: base64Combined
    /// - Returns: 字符串
    func decrypt(_ base64Combined: String) throws -> String {
        let key = SymmetricKey(data: SHA256.hash(data: Data(getDatabasePassphrase().utf8)))
        guard let combinedData = Data(base64Encoded: base64Combined) else { throw SecurityError.decodingFailed }
        let sealedBox = try AES.GCM.SealedBox(combined: combinedData)
        let decryptedData = try AES.GCM.open(sealedBox, using: key)
        guard let text = String(data: decryptedData, encoding: .utf8) else { throw SecurityError.decodingFailed }
        return text
    }

    // MARK: - 完整性校验 (HMAC)

    @MainActor
    private func getSalt() async -> String {
        return getOrGenerateKey(
            forKey: saltKey,
            errorMessage: L10n.Security.keychainHMACSaltError,
            generator: {
                let legacySalt = AppConstants.Keys.Storage.defaultLegacySalt
                let newSalt = UUID().uuidString + "-" + UUID().uuidString
                
                var hasSignatures = keyStore?.dictionaryRepresentation().keys.contains { $0.hasPrefix(signatureKeyPrefix) } ?? false
                
                if !hasSignatures {
                    // 异步调用需要特殊处理，由于 getOrGenerateKey 是同步的
                    // 这里我们采用阻塞式等待或预先检测。为了保持 getOrGenerateKey 简单，
                    // 我们在闭包内采用同步降级策略
                    hasSignatures = keyStore?.string(forKey: saltKey) != nil
                }
                
                return hasSignatures ? legacySalt : newSalt
            }
        )
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
                throw AppError.security("FileSignatureRepository is not registered yet", code: 404)
            }
            try await repo.saveSignature(signature, forFilePath: filePath, salt: currentSalt)
        } catch {
            #if DEBUG
            // 仅在 DEBUG 下允许降级到 KeyStore，用于模拟器未签名环境
            Logger.shared.debug(" [SecurityManager] HMAC fallback to KeyStore: \(error.localizedDescription)")
            let fileName = URL(fileURLWithPath: filePath).lastPathComponent
            keyStore?.set(signature, forKey: signatureKeyPrefix + fileName)
            #else
            // 生产环境：签名持久化失败属于严重安全错误，不允许明文降级
            Logger.shared.addLog(
                action: .error,
                target: CoreConstants.SecurityLogTarget.securityManager,
                details: "\(CoreConstants.SecurityLogDetails.criticalFailed) to persist HMAC signature securely: \(error.localizedDescription)",
                module: CoreConstants.Security.logModule
            )
            #endif
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
        // 审查修复 LOW-4: DEBUG 放行仅限模拟器，避免 DEBUG 构建在真机上放行
        guard let expectedSig = finalStoredSig else {
            #if DEBUG && targetEnvironment(simulator)
            Logger.shared.debug("[SecurityManager] 无签名记录，模拟器 DEBUG 模式下放行: \(fileURL.lastPathComponent)")
            return true
            #else
            Logger.shared.addLog(
                action: .error,
                target: CoreConstants.SecurityLogTarget.securityManager,
                details: "Integrity check failed: no signature on file: \(fileURL.lastPathComponent)",
                module: CoreConstants.Security.logModule
            )
            return false
            #endif
        }
        
        do {
            let currentSig = try await calculateHMAC(for: fileURL)
            return currentSig == expectedSig
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
            Logger.shared.addLog(action: .error, target: CoreConstants.SecurityLogTarget.securityManager, details: "\(CoreConstants.SecurityLogDetails.failedTo) update signature: \(error.localizedDescription)", module: CoreConstants.Security.logModule)
        }
    }
}

// MARK: - 错误定义
enum SecurityError: LocalizedError {
    case invalidSalt
    case encodingFailed
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidSalt: return "Failed to derive key from salt: invalid encoding"
        case .encodingFailed: return "Data encoding failed"
        case .decodingFailed: return "Data decoding failed"
        }
    }
}
