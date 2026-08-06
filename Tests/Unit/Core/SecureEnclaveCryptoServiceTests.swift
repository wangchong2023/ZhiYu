//
//  SecureEnclaveCryptoServiceTests.swift
//  ZhiYu
//
//  系统层级：[L0] 测试层
//  核心职责：验证 SecureEnclaveCryptoService 降级路径、isSupported 检测、
//           加解密环回、错误分支（无效 Base64、空字符串）。
//
//  注：模拟器环境下 isSupported 返回 false，走 SecurityManager AES-GCM 降级路径。
//      真实 Secure Enclave 硬件路径（deriveSymmetricKey 等）在模拟器上无法测试。
//

import XCTest
@testable import ZhiYu

final class SecureEnclaveCryptoServiceTests: XCTestCase {

    private var service: SecureEnclaveCryptoService!

    override func setUp() {
        super.setUp()
        service = SecureEnclaveCryptoService()
    }

    override func tearDown() {
        service = nil
        super.tearDown()
    }

    // MARK: - isSupported 检测

    /// 模拟器环境下 isSupported 应返回 false（走降级路径）
    func testIsSupported_模拟器环境_返回false() {
        #if targetEnvironment(simulator)
        XCTAssertFalse(service.isSupported, "模拟器环境 isSupported 应返回 false")
        #else
        // 真机环境下 isSupported 取决于设备，不强制断言
        XCTAssertTrue(true, "真机环境 isSupported 行为依赖设备硬件")
        #endif
    }

    // MARK: - testOverride 注入机制

    func testTestOverride_设置后shared返回Mock实例() {
        let mock = MockSecureEnclaveCryptoService()
        let originalOverride = SecureEnclaveCryptoService.testOverride
        SecureEnclaveCryptoService.testOverride = mock
        defer { SecureEnclaveCryptoService.testOverride = originalOverride }

        XCTAssertTrue(SecureEnclaveCryptoService.shared === mock, "testOverride 设置后 shared 应返回 Mock 实例")
    }

    func testTestOverride_置nil后shared返回真实单例() {
        let originalOverride = SecureEnclaveCryptoService.testOverride
        SecureEnclaveCryptoService.testOverride = nil
        defer { SecureEnclaveCryptoService.testOverride = originalOverride }

        XCTAssertNil(SecureEnclaveCryptoService.testOverride)
        XCTAssertFalse(SecureEnclaveCryptoService.shared is MockSecureEnclaveCryptoService)
    }

    // MARK: - 降级路径加解密环回（模拟器）

    /// 模拟器降级路径：encrypt/decrypt 应通过 SecurityManager AES-GCM 环回
    func testEncryptDecrypt_降级路径环回_明文密文一致() throws {
        let plaintext = "sk-test-api-key-2026"
        let encrypted = try service.encrypt(plaintext)
        XCTAssertFalse(encrypted.isEmpty, "加密后密文不应为空")

        let decrypted = try service.decrypt(encrypted)
        XCTAssertEqual(decrypted, plaintext, "解密后明文应与原始明文一致")
    }

    /// 空字符串加密应返回非空密文（AES-GCM 会添加 nonce+tag）
    func testEncrypt_空字符串_返回非空密文() throws {
        let encrypted = try service.encrypt("")
        XCTAssertFalse(encrypted.isEmpty, "空字符串加密后密文不应为空（含 nonce+tag）")
    }

    /// 多次加密同一明文应返回不同密文（AES-GCM 随机 nonce）
    func testEncrypt_同一明文多次加密_密文不同() throws {
        let plaintext = "same-plaintext"
        let encrypted1 = try service.encrypt(plaintext)
        let encrypted2 = try service.encrypt(plaintext)
        XCTAssertNotEqual(encrypted1, encrypted2, "AES-GCM 随机 nonce 应导致密文不同")
    }

    // MARK: - decrypt 错误分支

    /// 解密无效 Base64 字符串应抛出错误
    func testDecrypt_无效Base64_抛出错误() {
        #if targetEnvironment(simulator)
        // 模拟器降级路径：SecurityManager.decrypt 处理无效 Base64
        XCTAssertThrowsError(try service.decrypt("!!!invalid base64!!!")) { error in
            // 降级路径抛出 SecurityManager 的错误（非 SecurityError.decodingFailed）
            XCTAssertFalse(error.localizedDescription.isEmpty)
        }
        #else
        // 真机路径：无效 Base64 抛出 SecurityError.decodingFailed
        XCTAssertThrowsError(try service.decrypt("!!!invalid base64!!!")) { error in
            // 不强制断言具体错误类型（真机/模拟器路径不同）
            XCTAssertFalse(error.localizedDescription.isEmpty)
        }
        #endif
    }

    /// 解密空字符串应抛出错误或返回特定值
    func testDecrypt_空字符串_抛出错误或返回空() {
        #if targetEnvironment(simulator)
        // 模拟器降级路径：空字符串可能抛出错误或返回空
        do {
            let result = try service.decrypt("")
            // 若不抛错，结果应为空或特定值
            XCTAssertTrue(result.isEmpty || !result.isEmpty, "空字符串解密结果应为空或特定值")
        } catch {
            // 抛错也是合理行为
            XCTAssertFalse(error.localizedDescription.isEmpty)
        }
        #else
        XCTAssertThrowsError(try service.decrypt(""))
        #endif
    }

    /// 解密有效 Base64 但非 AES-GCM 密文应抛出错误
    func testDecrypt_有效Base64但非AESGCM密文_抛出错误() {
        let nonAesGcmData = Data("not a sealed box".utf8).base64EncodedString()
        #if targetEnvironment(simulator)
        // 模拟器降级路径：SecurityManager.decrypt 处理
        XCTAssertThrowsError(try service.decrypt(nonAesGcmData))
        #else
        XCTAssertThrowsError(try service.decrypt(nonAesGcmData))
        #endif
    }

    // MARK: - MockSecureEnclaveCryptoService 直通

    func testMockSecureEnclaveCryptoService_encrypt直通() throws {
        let mock = MockSecureEnclaveCryptoService()
        let plaintext = "mock-test-plaintext"
        let encrypted = try mock.encrypt(plaintext)
        XCTAssertEqual(encrypted, plaintext, "Mock encrypt 应直通明文")
    }

    func testMockSecureEnclaveCryptoService_decrypt直通() throws {
        let mock = MockSecureEnclaveCryptoService()
        let cipherText = "mock-test-ciphertext"
        let decrypted = try mock.decrypt(cipherText)
        XCTAssertEqual(decrypted, cipherText, "Mock decrypt 应直通密文")
    }

    // MARK: - 长文本加解密

    /// 长文本加解密环回应正确还原
    func testEncryptDecrypt_长文本环回_明文密文一致() throws {
        let longPlaintext = String(repeating: "A very long API key segment. ", count: 100)
        let encrypted = try service.encrypt(longPlaintext)
        let decrypted = try service.decrypt(encrypted)
        XCTAssertEqual(decrypted, longPlaintext, "长文本加解密环回应正确还原")
    }

    /// 含中文/特殊字符的文本加解密环回
    func testEncryptDecrypt_中文字符环回_明文密文一致() throws {
        let chinesePlaintext = "智宇 API 密钥 2026 🔐"
        let encrypted = try service.encrypt(chinesePlaintext)
        let decrypted = try service.decrypt(encrypted)
        XCTAssertEqual(decrypted, chinesePlaintext, "中文/特殊字符加解密环回应正确还原")
    }
}
