//
//  SecurityManagerTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 SecurityManager 开展自动化单元测试验证。
//
import XCTest
import UFPCore
import CryptoKit
@testable import ZhiYu

@MainActor
final class SecurityManagerTests: XCTestCase {
    
    private var securityManager: SecurityManager!
    
    @MainActor
    override func setUp() {
        super.setUp()
        setupFullMockEnvironment()
        securityManager = SecurityManager.shared
    }
    
    @MainActor
    override func tearDown() {
        securityManager = nil
        ServiceContainer.shared.reset()
        super.tearDown()
    }
    
    // MARK: - AES-GCM 加解密测试
    
    func testAESGCMEncryptionAndDecryption() throws {
        let originalText = "Hello, ZhiYu Security! 🚀"
        
        // 1. 测试加密
        let encryptedBase64 = try securityManager.encrypt(originalText)
        XCTAssertNotEqual(originalText, encryptedBase64, "加密后的内容不应与原文相同")
        XCTAssertFalse(encryptedBase64.isEmpty, "加密产物不应为空")
        
        // 2. 测试解密
        let decryptedText = try securityManager.decrypt(encryptedBase64)
        XCTAssertEqual(originalText, decryptedText, "解密后的内容应与原文完全一致")
    }
    
    func testEncryptionProducesDifferentResultsForSameInput() throws {
        let text = "Static Content"
        let encrypted1 = try securityManager.encrypt(text)
        let encrypted2 = try securityManager.encrypt(text)
        
        // 由于 AES-GCM 使用随机 Nonce，每次加密结果应不同 (Base64 包含 Combined Data)
        XCTAssertNotEqual(encrypted1, encrypted2, "由于使用了随机 Nonce，每次加密的结果应具有差异性")
    }
    
    /// 测试 HMAC 完整性验证流（计算层验证）
    /// 说明：SecurityManager 是单例，@Inject FileSignatureRepository 在进程启动时固定绑定，
    ///       测试 reset() 后的 Mock 注册无法被单例感知，故本测试仅验证：
    ///       1. HMAC 计算的幂等性（相同文件 → 相同摘要）
    ///       2. HMAC 计算的差异敏感性（不同内容 → 不同摘要）
    func testHMACIntegrityCheck() async throws {
        // 创建临时测试文件
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("integrity_test_\(UUID().uuidString).db")
        let content = Data("Fake Database Content".utf8)
        try content.write(to: fileURL)

        defer { try? FileManager.default.removeItem(at: fileURL) }

        // 1. 两次计算同一文件的 HMAC，验证幂等性
        let sig1 = try await securityManager.calculateHMAC(for: fileURL)
        let sig2 = try await securityManager.calculateHMAC(for: fileURL)
        XCTAssertFalse(sig1.isEmpty, "HMAC 摘要不应为空")
        XCTAssertEqual(sig1, sig2, "同一文件两次计算应产生相同 HMAC 摘要（幂等性）")

        // 2. 修改文件内容后重新计算，验证差异敏感性
        let corruptedContent = Data("Corrupted Data".utf8)
        try corruptedContent.write(to: fileURL)

        let sig3 = try await securityManager.calculateHMAC(for: fileURL)
        XCTAssertNotEqual(sig1, sig3, "文件内容变更后 HMAC 摘要应不同（差异敏感性）")

        // 3. updateSignature 调用安全性验证（不应 crash）
        await securityManager.updateSignature(for: fileURL)
    }

    // MARK: - 密钥管理测试
    
    func testDatabasePassphrasePersistence() {
        let passphrase1 = securityManager.getDatabasePassphrase()
        let passphrase2 = securityManager.getDatabasePassphrase()
        
        XCTAssertFalse(passphrase1.isEmpty)
        XCTAssertEqual(passphrase1, passphrase2, "密钥一旦生成并存储于 Keychain，后续获取应保持一致")
    }
}
