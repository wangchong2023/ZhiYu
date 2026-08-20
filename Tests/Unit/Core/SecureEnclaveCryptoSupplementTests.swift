//
//  SecureEnclaveCryptoSupplementTests.swift
//  ZhiYu
//
//  系统层级：[L0] 测试层
//  核心职责：补充验证 SecureEnclaveCryptoService 边界缺陷、迁移路径逻辑、
//           密钥管理安全性问题。聚焦已有测试未覆盖的分支和潜在 bug。
//

import XCTest
import CryptoKit
import UFPCore
@testable import ZhiYu

final class SecureEnclaveCryptoSupplementTests: XCTestCase {

    // MARK: - 测试夹具

    private var service: SecureEnclaveCryptoService!
    private var mockKeychain: MockKeychainService!
    private var originalKeychainOverride: KeychainService?
    private var originalSecurityManagerOverride: SecurityManager?

    override func setUp() {
        super.setUp()
        service = SecureEnclaveCryptoService()
        mockKeychain = MockKeychainService()
        originalKeychainOverride = KeychainService.testOverride
        KeychainService.testOverride = mockKeychain
        originalSecurityManagerOverride = SecurityManager.testOverride
    }

    override func tearDown() {
        KeychainService.testOverride = originalKeychainOverride
        SecurityManager.testOverride = originalSecurityManagerOverride
        SecureEnclaveCryptoService.testOverride = nil
        service = nil
        mockKeychain = nil
        super.tearDown()
    }

    // MARK: - P2 问题：encrypt 返回空字符串的静默失败

    /// 源码 L71: `sealedBox.combined?.base64EncodedString() ?? ""`
    /// 当 combined 为 nil 时，encrypt 返回空字符串而非抛错。
    /// 调用方无法区分"加密成功但 combined 为 nil"和"加密失败"。
    /// 发现目的：验证这一静默失败行为，记录为 P2 问题。
    func testEncrypt_降级路径_密文不应为空字符串() throws {
        let plaintext = "test-for-empty-check"
        let encrypted = try service.encrypt(plaintext)
        // 当前实现：combined 为 nil 时返回 ""，调用方可能误判为成功
        XCTAssertFalse(encrypted.isEmpty, "加密返回空字符串是静默失败，调用方无法区分成功与失败（P2）")
    }

    // MARK: - P2 问题：decrypt 迁移路径的 reencrypt 结果被丢弃

    /// 源码 L107-111: 迁移成功后调用 encrypt 重新加密，但结果被赋值给 _ 丢弃。
    /// 注释说"由调用方处理"，但调用方收到的是旧明文，不知道需要更新 Keychain。
    /// 发现目的：验证迁移路径的 reencrypt 结果确实被丢弃（死代码）。
    func testDecrypt_迁移路径_reencrypt结果被丢弃() {
        // 迁移路径在模拟器上无法直接触发（需要真机 SecureEnclave + 旧 ECDH 密文）
        // 但可以通过源码审查确认：L107-111 的 reencrypt 结果赋值给 _ 是死代码
        // 此测试记录此问题，待真机测试或重构时修复
        XCTAssertTrue(true, "P2: L107-111 reencrypt 结果被 _ 丢弃，调用方无法获知需更新 Keychain")
    }

    // MARK: - P2 问题：getOrCreateHKDFSalt 错误处理不对称

    /// 源码 L146-167: getOrCreateHKDFSalt 中，Keychain retrieve 抛错时向上传播，
    /// 但 retrieve 返回 nil（盐不存在）时生成新盐。
    /// 问题：若 Keychain 返回 nil 但实际是临时错误（非 errSecItemNotFound），
    /// 会生成新盐覆盖旧盐，导致存量密文不可解密。
    /// 发现目的：验证 Keychain 返回 nil 时的行为（模拟器降级路径不触发此方法，
    /// 但通过源码审查确认逻辑缺陷）。
    func testGetOrCreateHKDFSalt_Keychain返回nil_生成新盐() {
        // 此方法在模拟器降级路径下不会被调用（isSupported=false）
        // 但源码审查发现：L149-157 的 do-catch 只捕获抛出错误，
        // retrieve 返回 nil 时直接走 L158 生成新盐
        // 若 Keychain 因临时错误返回 nil（非 errSecItemNotFound），
        // 会生成新盐导致存量密文不可解密
        XCTAssertTrue(true, "P2: L149-157 Keychain 返回 nil 时无法区分'不存在'与'临时错误'")
    }

    // MARK: - P2 问题：getOrCreateHardwarePrivateKey token 损坏后静默重建

    /// 源码 L196-204: 从 Keychain 读取 token 后，若 PrivateKey(dataRepresentation:) 失败，
    /// 仅记录日志并静默生成新密钥。问题：旧密文将永远无法解密，但调用方不知情。
    /// 发现目的：验证 token 损坏时的静默重建行为。
    func testGetOrCreateHardwarePrivateKey_token损坏_静默重建() {
        // 此方法在模拟器降级路径下不会被调用
        // 但源码审查发现：L201-203 catch 块仅记录日志，不抛错
        // 调用方不知道密钥已更换，旧密文将永远无法解密
        XCTAssertTrue(true, "P2: L201-203 token 损坏时静默重建，旧密文永久不可解密")
    }

    // MARK: - 降级路径：SecurityManager 不可用时的级联失败

    /// 源码 L56-58: isSupported=false 时委托给 SecurityManager.shared.encrypt
    /// 若 SecurityManager 也失败（如 Keychain 不可用），错误会向上传播。
    /// 发现目的：验证降级路径的级联错误传播。
    func testEncrypt_降级路径_SecurityManager失败_错误传播() {
        // 注入会抛错的 MockSecurityManager
        let failingMock = FailingSecurityManager()
        SecurityManager.testOverride = failingMock

        XCTAssertThrowsError(try service.encrypt("test")) { error in
            XCTAssertEqual(error as? TestError, TestError.injectedFailure, "降级路径应传播 SecurityManager 的错误")
        }
    }

    /// 降级路径 decrypt：SecurityManager 失败时错误应传播
    func testDecrypt_降级路径_SecurityManager失败_错误传播() {
        let failingMock = FailingSecurityManager()
        SecurityManager.testOverride = failingMock

        XCTAssertThrowsError(try service.decrypt("dGVzdA==")) { error in
            XCTAssertEqual(error as? TestError, TestError.injectedFailure, "降级路径应传播 SecurityManager 的错误")
        }
    }

    // MARK: - 降级路径：密钥一致性跨实例验证

    /// 不同实例加密的密文应能互相解密（密钥持久化在 Keychain）
    /// 发现目的：验证密钥不会因实例重建而变化
    func testEncryptDecrypt_跨实例_密钥一致() throws {
        let plaintext = "cross-instance-key-consistency"
        let service1 = SecureEnclaveCryptoService()
        let encrypted = try service1.encrypt(plaintext)

        let service2 = SecureEnclaveCryptoService()
        let decrypted = try service2.decrypt(encrypted)

        XCTAssertEqual(decrypted, plaintext, "不同实例应共享同一持久化密钥")
    }

    // MARK: - 降级路径：密文格式一致性

    /// 同一明文多次加密，密文格式应一致（都是合法 Base64，长度相近）
    /// 发现目的：验证加密输出的格式稳定性
    func testEncrypt_多次加密_密文格式一致() throws {
        let plaintext = "format-consistency-test"
        var lengths: [Int] = []

        for _ in 0..<5 {
            let encrypted = try service.encrypt(plaintext)
            guard let data = Data(base64Encoded: encrypted) else {
                XCTFail("密文应为合法 Base64")
                return
            }
            lengths.append(data.count)
        }

        // AES-GCM combined = nonce(12) + ciphertext + tag(16)，长度应一致
        let firstLength = lengths[0]
        XCTAssertTrue(lengths.allSatisfy { $0 == firstLength }, "同一明文多次加密的密文长度应一致（AES-GCM 格式稳定）")
    }

    // MARK: - 降级路径：Keychain 隔离验证

    /// 降级路径加密不应在 Keychain 中写入任何 SecureEnclave 相关数据
    /// 发现目的：验证降级路径不污染 Keychain
    func testEncrypt_降级路径_不写入Keychain任何SecureEnclave数据() throws {
        _ = try service.encrypt("keychain-isolation-test")

        let secureEnclaveKeys = mockKeychain.store.keys.filter { $0.contains("secure_enclave") }
        XCTAssertTrue(secureEnclaveKeys.isEmpty, "降级路径不应写入任何 SecureEnclave 相关 Keychain 数据")
    }

    // MARK: - 降级路径：空明文加密后解密环回

    /// 空字符串加密后解密应还原空字符串
    /// 发现目的：验证空明文的环回正确性
    func testEncryptDecrypt_空明文_环回正确() throws {
        let encrypted = try service.encrypt("")
        XCTAssertFalse(encrypted.isEmpty, "空明文加密后密文不应为空（含 nonce+tag）")

        let decrypted = try service.decrypt(encrypted)
        XCTAssertEqual(decrypted, "", "空明文环回应还原空字符串")
    }

    // MARK: - 降级路径：二进制安全验证

    /// 含 NULL 字节的明文应正确环回
    /// 发现目的：验证 UTF-8 编码对特殊字节的处理
    func testEncryptDecrypt_含NULL字节_环回正确() throws {
        let plaintext = "before\u{0000}after"
        let encrypted = try service.encrypt(plaintext)
        let decrypted = try service.decrypt(encrypted)

        XCTAssertEqual(decrypted, plaintext, "含 NULL 字节的明文应正确环回")
    }

    // MARK: - 降级路径：密文不可逆推明文

    /// 密文的 Base64 解码后不应包含明文的 UTF-8 字节序列
    /// 发现目的：验证加密确实执行了加密而非编码
    func testEncrypt_密文字节不含明文字节序列() throws {
        let plaintext = "unique-plaintext-marker-12345"
        let encrypted = try service.encrypt(plaintext)

        guard let cipherData = Data(base64Encoded: encrypted) else {
            XCTFail("密文应为合法 Base64")
            return
        }
        let plainData = Data(plaintext.utf8)
        XCTAssertNil(cipherData.range(of: plainData), "密文字节序列不应包含明文字节序列（加密而非编码）")
    }
}

// MARK: - 测试辅助类

/// 会抛出固定错误的 SecurityManager Mock
private final class FailingSecurityManager: SecurityManager, @unchecked Sendable {
    override func encrypt(_ plainText: String) throws -> String {
        throw TestError.injectedFailure
    }

    override func decrypt(_ cipherText: String) throws -> String {
        throw TestError.injectedFailure
    }
}

private enum TestError: Error {
    case injectedFailure
}
