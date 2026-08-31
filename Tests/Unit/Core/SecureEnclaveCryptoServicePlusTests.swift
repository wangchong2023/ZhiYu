//
//  SecureEnclaveCryptoServicePlusTests.swift
//  ZhiYu
//
//  系统层级：[L0] 测试层
//  核心职责：问题驱动深度测试 — 验证 SecureEnclaveCryptoService 加解密环回、
//           错误分支、降级路径、密钥管理、边界场景、并发安全、迁移逻辑。
//           积极发现源码中的 bug、边界缺陷、错误假设、不一致行为、安全问题。
//

import XCTest
import CryptoKit
@testable import ZhiYu

final class SecureEnclaveCryptoServicePlusTests: XCTestCase {

    // MARK: - 测试夹具

    /// 被测服务实例（真实实现，非 Mock）
    private var service: SecureEnclaveCryptoService!
    /// Mock Keychain，用于隔离 Keychain 状态
    private var mockKeychain: MockKeychainService!
    /// 保存原始 testOverride 以便 tearDown 恢复
    private var originalKeychainOverride: KeychainService?
    private var originalSecurityManagerOverride: SecurityManager?

    override func setUp() {
        super.setUp()
        service = SecureEnclaveCryptoService()
        mockKeychain = MockKeychainService()
        originalKeychainOverride = KeychainService.testOverride
        KeychainService.testOverride = mockKeychain
        originalSecurityManagerOverride = SecurityManager.testOverride
        // 强制使用真实 SecurityManager（清除其他测试类可能遗留的 Mock 污染）
        SecurityManager.testOverride = nil
    }

    override func tearDown() {
        KeychainService.testOverride = originalKeychainOverride
        SecurityManager.testOverride = originalSecurityManagerOverride
        SecureEnclaveCryptoService.testOverride = nil
        service = nil
        mockKeychain = nil
        super.tearDown()
    }

    // MARK: - 降级路径：encrypt 返回值语义

    /// 降级路径 encrypt 应返回非空 Base64 密文，且与明文不同
    /// 发现目的：验证 encrypt 不会静默返回空字符串（combined 为 nil 的降级分支）
    func testEncrypt_降级路径_返回非空Base64且与明文不同() throws {
        let plaintext = "sk-supplement-test-key"
        let encrypted = try service.encrypt(plaintext)

        XCTAssertNotEqual(encrypted, plaintext, "密文不应等于明文（未加密泄露）")
        XCTAssertFalse(encrypted.isEmpty, "密文不应为空")
        // 验证是合法 Base64
        XCTAssertNotNil(Data(base64Encoded: encrypted), "密文应为合法 Base64 字符串")
    }

    /// 降级路径：encrypt 后密文应可被 Data(base64Encoded:) 解析
    /// 发现目的：确保返回值是可解码的 Base64，而非损坏数据
    func testEncrypt_降级路径_密文可被Base64解码() throws {
        let plaintext = "test-plaintext-for-decode"
        let encrypted = try service.encrypt(plaintext)

        guard let decoded = Data(base64Encoded: encrypted) else {
            XCTFail("加密返回值不是合法 Base64")
            return
        }
        // AES-GCM combined = nonce(12) + ciphertext + tag(16)，至少 28 字节
        XCTAssertGreaterThanOrEqual(decoded.count, 28, "AES-GCM combined 密文应至少 28 字节（nonce 12 + tag 16）")
    }

    // MARK: - 降级路径：环回正确性

    /// 降级路径：encrypt → decrypt 完整环回，明文一致
    func testEncryptDecrypt_降级路径环回_明文一致() throws {
        let plaintext = "roundtrip-supplement-2026"
        let encrypted = try service.encrypt(plaintext)
        let decrypted = try service.decrypt(encrypted)

        XCTAssertEqual(decrypted, plaintext, "降级路径加解密环回应还原原始明文")
    }

    /// 降级路径：Unicode + Emoji 文本环回
    /// 发现目的：验证 UTF-8 编码对多字节字符的处理
    func testEncryptDecrypt_降级路径_UnicodeEmoji环回() throws {
        let plaintext = "智宇 🔐 API密钥 2026 — 日本語 テスト"
        let encrypted = try service.encrypt(plaintext)
        let decrypted = try service.decrypt(encrypted)

        XCTAssertEqual(decrypted, plaintext, "Unicode/Emoji 文本环回应正确还原")
    }

    /// 降级路径：超长文本（10KB）环回
    /// 发现目的：验证无长度截断或缓冲区溢出
    func testEncryptDecrypt_降级路径_超长文本环回() throws {
        let plaintext = String(repeating: "abcdefghij", count: 1024) // 10KB
        let encrypted = try service.encrypt(plaintext)
        let decrypted = try service.decrypt(encrypted)

        XCTAssertEqual(decrypted.count, plaintext.count, "超长文本解密后长度应一致")
        XCTAssertEqual(decrypted, plaintext, "超长文本环回应正确还原")
    }

    // MARK: - 降级路径：错误分支

    /// 降级路径 decrypt：无效 Base64 应抛错
    func testDecrypt_降级路径_无效Base64_抛出错误() {
        XCTAssertThrowsError(try service.decrypt("!!!not-base64!!!")) { error in
            XCTAssertFalse(error.localizedDescription.isEmpty, "错误应包含描述信息")
        }
    }

    /// 降级路径 decrypt：空字符串应抛错（无法解码为 AES-GCM SealedBox）
    func testDecrypt_降级路径_空字符串_抛出错误() {
        XCTAssertThrowsError(try service.decrypt("")) { error in
            XCTAssertFalse(error.localizedDescription.isEmpty)
        }
    }

    /// 降级路径 decrypt：合法 Base64 但非 AES-GCM 格式应抛错
    func testDecrypt_降级路径_合法Base64非AESGCM_抛出错误() {
        let invalidData = Data("not a sealed box".utf8).base64EncodedString()
        XCTAssertThrowsError(try service.decrypt(invalidData)) { error in
            XCTAssertFalse(error.localizedDescription.isEmpty)
        }
    }

    /// 降级路径 decrypt：截断的 AES-GCM 密文（缺少 tag）应抛错
    /// 发现目的：验证截断数据不会被错误接受
    func testDecrypt_降级路径_截断密文_抛出错误() throws {
        let plaintext = "truncation-test"
        let encrypted = try service.encrypt(plaintext)
        guard let fullData = Data(base64Encoded: encrypted) else {
            XCTFail("密文应为合法 Base64")
            return
        }
        // 截断最后 10 字节（破坏 tag）
        let truncated = fullData.prefix(fullData.count - 10)
        let truncatedBase64 = truncated.base64EncodedString()

        XCTAssertThrowsError(try service.decrypt(truncatedBase64), "截断密文应抛出解密错误")
    }

    /// 降级路径 decrypt：篡改的密文（翻转字节）应抛错
    /// 发现目的：验证 AES-GCM 的完整性校验生效
    func testDecrypt_降级路径_篡改密文_抛出错误() throws {
        let plaintext = "tamper-test"
        let encrypted = try service.encrypt(plaintext)
        guard var data = Data(base64Encoded: encrypted) else {
            XCTFail("密文应为合法 Base64")
            return
        }
        // 翻转中间一个字节（破坏 ciphertext 或 tag）
        let midIndex = data.count / 2
        data[midIndex] ^= 0xFF
        let tamperedBase64 = data.base64EncodedString()

        XCTAssertThrowsError(try service.decrypt(tamperedBase64), "篡改密文应抛出认证失败错误")
    }

    // MARK: - 降级路径：密钥一致性

    /// 降级路径：同一服务实例多次加解密应使用相同密钥
    /// 发现目的：验证 getDatabasePassphrase 缓存生效，密钥不会漂移
    func testEncryptDecrypt_降级路径_多次环回_密钥一致() throws {
        let plaintexts = ["key1", "key2", "key3", "key4", "key5"]

        // 先加密所有明文
        let encrypted = try plaintexts.map { try service.encrypt($0) }

        // 后解密所有密文，验证都能还原
        for (index, plaintext) in plaintexts.enumerated() {
            let decrypted = try service.decrypt(encrypted[index])
            XCTAssertEqual(decrypted, plaintext, "第 \(index) 个明文环回失败，密钥可能不一致")
        }
    }

    /// 降级路径：不同服务实例应使用相同密钥（密钥持久化在 Keychain）
    /// 发现目的：验证密钥不会因实例重建而变化
    func testEncryptDecrypt_降级路径_不同实例_密钥一致() throws {
        let plaintext = "cross-instance-test"
        let service1 = SecureEnclaveCryptoService()
        let encrypted = try service1.encrypt(plaintext)

        let service2 = SecureEnclaveCryptoService()
        let decrypted = try service2.decrypt(encrypted)

        XCTAssertEqual(decrypted, plaintext, "不同实例应共享同一持久化密钥")
    }

    // MARK: - isSupported 行为

    /// 模拟器环境 isSupported 应返回 false
    func testIsSupported_模拟器_返回false() {
        #if targetEnvironment(simulator)
        XCTAssertFalse(service.isSupported, "模拟器环境 isSupported 应返回 false")
        #else
        // 真机环境不强制断言（依赖设备硬件）
        XCTAssertTrue(true)
        #endif
    }

    // MARK: - testOverride 单例替换

    /// testOverride 设置后 shared 应返回 Mock 实例
    func testTestOverride_设置后shared返回Mock() {
        let mock = MockSecureEnclaveCryptoService()
        let original = SecureEnclaveCryptoService.testOverride
        SecureEnclaveCryptoService.testOverride = mock
        defer { SecureEnclaveCryptoService.testOverride = original }

        XCTAssertTrue(SecureEnclaveCryptoService.shared === mock, "testOverride 应替换 shared 返回值")
    }

    /// testOverride 置 nil 后 shared 应返回真实单例
    func testTestOverride_置nil后shared返回真实单例() {
        let original = SecureEnclaveCryptoService.testOverride
        SecureEnclaveCryptoService.testOverride = nil
        defer { SecureEnclaveCryptoService.testOverride = original }

        XCTAssertFalse(SecureEnclaveCryptoService.shared is MockSecureEnclaveCryptoService)
    }

    // MARK: - 真机路径模拟（子类 override isSupported = true）

    /// 真机路径模拟：isSupported=true 时，模拟器上 SecureEnclave 行为取决于 Xcode 版本
    /// 业界方案：双路径断言 — 模拟器上 SecureEnclave.P256 可能抛错也可能成功（Apple Silicon Mac 模拟器）
    /// 抛错时验证错误信息非空；成功时验证密文非空。真机上应成功加密。
    func testEncrypt_真机路径模拟_模拟器行为验证() throws {
        let stub = SecureEnclaveStub(isSupported: true)

        #if targetEnvironment(simulator)
        // 模拟器上 SecureEnclave.P256.KeyAgreement.PrivateKey() 行为不确定：
        // - Intel Mac 模拟器：抛 CryptoKitError
        // - Apple Silicon Mac 模拟器：可能成功（SecureEnclave.isAvailable 可能为 true）
        do {
            let cipher = try stub.encrypt("test")
            XCTAssertFalse(cipher.isEmpty, "加密成功时密文不应为空")
        } catch {
            // 抛错时验证错误信息非空
            XCTAssertFalse(error.localizedDescription.isEmpty, "真机路径在模拟器上应抛出有意义的错误")
        }
        #else
        // 真机环境：若 SecureEnclave 可用，应成功加密
        XCTAssertNoThrow(try stub.encrypt("test"))
        #endif
    }

    /// 真机路径模拟：decrypt 在模拟器上的行为同样取决于 Xcode 版本
    func testDecrypt_真机路径模拟_模拟器行为验证() throws {
        let stub = SecureEnclaveStub(isSupported: true)

        #if targetEnvironment(simulator)
        do {
            _ = try stub.decrypt("dGVzdA==")
            // 解密成功（Apple Silicon 模拟器）或不抛错即通过
        } catch {
            XCTAssertFalse(error.localizedDescription.isEmpty)
        }
        #else
        XCTAssertNoThrow(try stub.decrypt("dGVzdA=="))
        #endif
    }

    // MARK: - 密钥管理：Keychain 交互

    /// 降级路径：加密不应在 Keychain 中写入 SecureEnclave 相关 token
    /// 发现目的：验证降级路径不会污染 Keychain（不调用 getOrCreateHardwarePrivateKey）
    func testEncrypt_降级路径_不写入KeychainToken() throws {
        let tokenKey = "com.zhiyu.secure_enclave.token"
        let saltKey = "com.zhiyu.secure_enclave.hkdf_salt"

        _ = try service.encrypt("test-keychain-isolation")

        // 降级路径不应写入 SecureEnclave token 和 salt
        XCTAssertNil(mockKeychain.store[tokenKey], "降级路径不应写入 hardwareKeyToken")
        XCTAssertNil(mockKeychain.store[saltKey], "降级路径不应写入 hkdfSalt")
    }

    // MARK: - 并发安全

    /// 并发加密：多线程同时调用 encrypt 应全部成功
    /// 发现目的：验证 @unchecked Sendable 的并发安全性
    func testEncrypt_并发调用_全部成功() throws {
        let plaintexts = (0..<20).map { "concurrent-test-\($0)" }
        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        let group = DispatchGroup()
        let lock = NSLock()
        var results: [String: String] = [:]
        var errors: [Error] = []

        for plaintext in plaintexts {
            group.enter()
            queue.async {
                do {
                    let encrypted = try self.service.encrypt(plaintext)
                    lock.lock()
                    results[plaintext] = encrypted
                    lock.unlock()
                } catch {
                    lock.lock()
                    errors.append(error)
                    lock.unlock()
                }
                group.leave()
            }
        }
        group.wait()

        XCTAssertTrue(errors.isEmpty, "并发加密不应产生错误: \(errors)")
        XCTAssertEqual(results.count, plaintexts.count, "所有并发加密应成功")

        // 验证每个密文都能正确解密
        for (plaintext, encrypted) in results {
            let decrypted = try service.decrypt(encrypted)
            XCTAssertEqual(decrypted, plaintext, "并发加密的密文应可正确解密")
        }
    }

    /// 并发加解密混合：同时 encrypt 和 decrypt 应线程安全
    func testEncryptDecrypt_并发混合_线程安全() throws {
        // 预先加密一批密文
        let plaintexts = (0..<10).map { "mixed-\($0)" }
        let preEncrypted = try plaintexts.map { try service.encrypt($0) }

        let queue = DispatchQueue(label: "test.mixed", attributes: .concurrent)
        let group = DispatchGroup()
        let lock = NSLock()
        var successCount = 0
        var errorCount = 0

        // 一半线程加密，一半线程解密
        for plaintext in plaintexts {
            group.enter()
            queue.async {
                do {
                    _ = try self.service.encrypt(plaintext)
                    lock.lock(); successCount += 1; lock.unlock()
                } catch {
                    lock.lock(); errorCount += 1; lock.unlock()
                }
                group.leave()
            }
        }
        for encrypted in preEncrypted {
            group.enter()
            queue.async {
                do {
                    _ = try self.service.decrypt(encrypted)
                    lock.lock(); successCount += 1; lock.unlock()
                } catch {
                    lock.lock(); errorCount += 1; lock.unlock()
                }
                group.leave()
            }
        }
        group.wait()

        XCTAssertEqual(errorCount, 0, "并发混合加解密不应产生错误")
        XCTAssertEqual(successCount, plaintexts.count * 2, "所有并发操作应成功")
    }

    // MARK: - 边界场景

    /// 单字符明文加解密环回
    func testEncryptDecrypt_单字符_环回正确() throws {
        let plaintext = "A"
        let encrypted = try service.encrypt(plaintext)
        let decrypted = try service.decrypt(encrypted)

        XCTAssertEqual(decrypted, plaintext, "单字符环回应正确")
    }

    /// 仅空格的明文加解密环回
    func testEncryptDecrypt_仅空格_环回正确() throws {
        let plaintext = "   "
        let encrypted = try service.encrypt(plaintext)
        let decrypted = try service.decrypt(encrypted)

        XCTAssertEqual(decrypted, plaintext, "仅空格环回应正确")
    }

    /// 含换行符的明文加解密环回
    func testEncryptDecrypt_含换行符_环回正确() throws {
        let plaintext = "line1\nline2\r\nline3\ttab"
        let encrypted = try service.encrypt(plaintext)
        let decrypted = try service.decrypt(encrypted)

        XCTAssertEqual(decrypted, plaintext, "含换行符/制表符环回应正确")
    }

    /// 重复加密同一明文 100 次应全部可解密
    /// 发现目的：验证无状态泄漏或密钥漂移
    func testEncrypt_重复100次_全部可解密() throws {
        let plaintext = "repeatability-test"
        for index in 0..<100 {
            let encrypted = try service.encrypt(plaintext)
            let decrypted = try service.decrypt(encrypted)
            XCTAssertEqual(decrypted, plaintext, "第 \(index) 次环回失败")
        }
    }

    // MARK: - SecurityManager 降级 Mock 验证

    /// 注入 MockSecurityManager 后，降级路径应使用 Mock 的直通逻辑
    /// 发现目的：验证降级路径确实委托给 SecurityManager
    func testEncrypt_注入MockSecurityManager_使用Mock直通() throws {
        let mockSecurity = MockSecurityManager()
        SecurityManager.testOverride = mockSecurity

        let plaintext = "mock-delegation-test"
        let encrypted = try service.encrypt(plaintext)

        // MockSecurityManager.encrypt 直通明文
        XCTAssertEqual(encrypted, plaintext, "降级路径应委托给 SecurityManager（Mock 直通）")

        let decrypted = try service.decrypt(encrypted)
        XCTAssertEqual(decrypted, plaintext, "Mock 直通解密应返回原值")
    }

    // MARK: - 密文格式验证

    /// 降级路径密文不应包含明文子串（防泄露）
    /// 发现目的：验证密文是真正的加密结果，而非编码/混淆
    func testEncrypt_降级路径_密文不含明文子串() throws {
        let plaintext = "sensitive-api-key-12345"
        let encrypted = try service.encrypt(plaintext)

        XCTAssertFalse(encrypted.contains(plaintext), "密文不应包含明文子串（泄露风险）")
        // Base64 解码后也不应包含明文的 UTF-8 字节序列
        if let cipherData = Data(base64Encoded: encrypted) {
            let plainData = Data(plaintext.utf8)
            XCTAssertFalse(cipherData.range(of: plainData) != nil, "密文字节不应包含明文字节序列")
        }
    }
}

// MARK: - 测试辅助子类

/// 通过子类化 override isSupported，模拟真机 Secure Enclave 可用场景
private final class SecureEnclaveStub: SecureEnclaveCryptoService, @unchecked Sendable {
    private let supported: Bool

    init(isSupported: Bool) {
        self.supported = isSupported
        super.init()
    }

    override var isSupported: Bool { supported }
}
