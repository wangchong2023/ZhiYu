//
//  SecurityComponentsSupplementTests.swift
//  ZhiYu
//
//  系统层级：[L0] 测试层
//  核心职责：补充验证 KeychainService/SecurityManager/AhoCorasickEngine/
//           JailbreakDetector/ContentModerationEngine/DynamicComplianceManager
//           的未覆盖分支（错误路径、边界值、状态转换、降级路径）。
//

import XCTest
import UFPCore
import CryptoKit
@testable import ZhiYu

/// Core/Security 6 组件问题驱动补充测试
///
/// 覆盖目标：KeychainService（错误分支）、SecurityManager（加解密边界+完整性校验降级）、
/// AhoCorasickEngine（重叠/重复模式+索引正确性）、JailbreakDetector（模拟器非越狱）、
/// ContentModerationEngine（空文本+4 类拦截+节流错误）、DynamicComplianceManager+Patch（验签失败+JSON 解析失败+未知分类）。
@MainActor
final class SecurityComponentsSupplementTests: XCTestCase {

    // MARK: - 测试夹具

    private var originalSecurityManagerOverride: SecurityManager?

    override func setUp() {
        super.setUp()
        setupFullMockEnvironment()
        resetPersistentTestState()
        // 强制使用真实 SecurityManager（清除其他测试类可能遗留的 Mock 污染）
        originalSecurityManagerOverride = SecurityManager.testOverride
        SecurityManager.testOverride = nil
    }

    override func tearDown() {
        SecurityManager.testOverride = originalSecurityManagerOverride
        resetPersistentTestState()
        super.tearDown()
    }

    // MARK: - KeychainService 错误分支

    /// KeychainError.encodingFailed 应有非空描述
    func testKeychainError_EncodingFailed_DescriptionNotEmpty() {
        XCTAssertFalse(KeychainError.encodingFailed.errorDescription?.isEmpty ?? true,
                       "encodingFailed 错误描述不应为空")
    }

    /// KeychainError.unexpectedData 应有非空描述
    func testKeychainError_UnexpectedData_DescriptionNotEmpty() {
        XCTAssertFalse(KeychainError.unexpectedData.errorDescription?.isEmpty ?? true,
                       "unexpectedData 错误描述不应为空")
    }

    /// KeychainError.storeFailed 描述应包含状态码
    func testKeychainError_StoreFailed_DescriptionContainsStatusCode() {
        let status: OSStatus = -34018
        let error = KeychainError.storeFailed(status)
        XCTAssertTrue(error.errorDescription?.contains("-34018") ?? false,
                      "storeFailed 描述应包含状态码")
    }

    /// KeychainError.retrieveFailed 描述应包含状态码
    func testKeychainError_RetrieveFailed_DescriptionContainsStatusCode() {
        let status: OSStatus = -25300
        let error = KeychainError.retrieveFailed(status)
        XCTAssertTrue(error.errorDescription?.contains("-25300") ?? false,
                      "retrieveFailed 描述应包含状态码")
    }

    /// KeychainError.deleteFailed 描述应包含状态码
    func testKeychainError_DeleteFailed_DescriptionContainsStatusCode() {
        let status: OSStatus = -25299
        let error = KeychainError.deleteFailed(status)
        XCTAssertTrue(error.errorDescription?.contains("-25299") ?? false,
                      "deleteFailed 描述应包含状态码")
    }

    /// MockKeychainService 覆盖写入后读取应返回最新值
    func testMockKeychainService_Overwrite_ReturnsLatestValue() throws {
        let mock = MockKeychainService()
        try mock.store(key: "overwrite_key", value: "v1")
        try mock.store(key: "overwrite_key", value: "v2")
        XCTAssertEqual(try mock.retrieve(key: "overwrite_key"), "v2",
                       "覆盖写入后应返回最新值")
    }

    /// MockKeychainService 删除不存在的 key 应不崩溃
    func testMockKeychainService_DeleteNonExistentKey_DoesNotCrash() throws {
        let mock = MockKeychainService()
        try mock.delete(key: "nonexistent_\(UUID().uuidString)")
        // 不崩溃即通过
    }

    /// KeychainService testOverride 置 nil 后 shared 应返回真实单例
    func testKeychainService_WhenTestOverrideNil_ReturnsRealSingleton() {
        let original = KeychainService.testOverride
        KeychainService.testOverride = nil
        defer { KeychainService.testOverride = original }

        XCTAssertFalse(KeychainService.shared is MockKeychainService,
                       "testOverride 置 nil 后 shared 应返回真实单例")
    }

    // MARK: - SecurityManager 加解密边界

    /// SecurityManager 加密空字符串后解密应还原空字符串
    func testSecurityManager_EmptyString_EncryptDecryptLoopback() throws {
        let manager = SecurityManager.shared
        let encrypted = try manager.encrypt("")
        XCTAssertFalse(encrypted.isEmpty, "加密产物不应为空（含 nonce+tag）")
        let decrypted = try manager.decrypt(encrypted)
        XCTAssertEqual(decrypted, "", "空字符串加解密应还原")
    }

    /// SecurityManager 解密无效 Base64 应抛出 decodingFailed
    func testSecurityManager_DecryptInvalidBase64_ThrowsDecodingFailed() {
        let manager = SecurityManager.shared
        XCTAssertThrowsError(try manager.decrypt("!!!invalid_base64!!!")) { error in
            guard case SecurityError.decodingFailed = error else {
                XCTFail("应抛出 decodingFailed，实际: \(error)")
                return
            }
        }
    }

    /// SecurityManager 解密有效 Base64 但非 AES-GCM 密文应抛出错误
    func testSecurityManager_DecryptValidBase64NonCipher_ThrowsError() {
        let manager = SecurityManager.shared
        let fakeCipher = Data("not_a_sealed_box".utf8).base64EncodedString()
        XCTAssertThrowsError(try manager.decrypt(fakeCipher)) { _ in
            // CryptoKit 会抛出各种错误，不限定具体类型
        }
    }

    /// SecurityError 三个 case 的 errorDescription 应非空
    func testSecurityError_AllCases_DescriptionNotEmpty() {
        XCTAssertFalse(SecurityError.invalidSalt.errorDescription?.isEmpty ?? true)
        XCTAssertFalse(SecurityError.encodingFailed.errorDescription?.isEmpty ?? true)
        XCTAssertFalse(SecurityError.decodingFailed.errorDescription?.isEmpty ?? true)
    }

    /// getDatabasePassphrase 多次调用应返回缓存值（一致性）
    func testSecurityManager_GetDatabasePassphrase_CacheConsistency() {
        let manager = SecurityManager.shared
        let p1 = manager.getDatabasePassphrase()
        let p2 = manager.getDatabasePassphrase()
        XCTAssertEqual(p1, p2, "多次调用应返回缓存的同一密钥")
        XCTAssertFalse(p1.isEmpty, "密钥不应为空")
    }

    // MARK: - SecurityManager 完整性校验降级路径

    /// verifyIntegrity 无签名记录时，模拟器 DEBUG 应放行（true），真机应 fail-closed（false）
    func testSecurityManager_VerifyIntegrity_NoSignature_SimulatorPass() async throws {
        let manager = SecurityManager.shared
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("no_sig_test_\(UUID().uuidString).txt")
        try "content_without_signature".write(to: fileURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let result = await manager.verifyIntegrity(for: fileURL)
        #if DEBUG && targetEnvironment(simulator)
        XCTAssertTrue(result, "模拟器 DEBUG 模式下无签名应放行")
        #else
        XCTAssertFalse(result, "非模拟器环境无签名应 fail-closed")
        #endif
    }

    /// verifyIntegrity 文件不存在时：
    /// 一律 fail-closed 返回 false（即使在模拟器 DEBUG 模式下也不放行不存在的文件）
    func testSecurityManager_VerifyIntegrity_FileNotExists_ReturnsFalse() async {
        let manager = SecurityManager.shared
        let nonExistentURL = URL(fileURLWithPath: "/tmp/nonexistent_file_\(UUID().uuidString).txt")
        let result = await manager.verifyIntegrity(for: nonExistentURL)
        XCTAssertFalse(result, "文件不存在时完整性校验一律应 fail-closed 返回 false")
    }

    /// calculateHMAC 对不存在的文件应抛出错误
    func testSecurityManager_CalculateHMAC_FileNotExists_ThrowsError() async {
        let manager = SecurityManager.shared
        let nonExistentURL = URL(fileURLWithPath: "/tmp/nonexistent_hmac_\(UUID().uuidString).txt")
        do {
            _ = try await manager.calculateHMAC(for: nonExistentURL)
            XCTFail("文件不存在应抛出错误")
        } catch {
            // 预期抛出 NSError (NSFileNoSuchFileError)
        }
    }

    /// updateSignature 对不存在的文件应不崩溃（内部 catch）
    func testSecurityManager_UpdateSignature_FileNotExists_DoesNotCrash() async {
        let manager = SecurityManager.shared
        let nonExistentURL = URL(fileURLWithPath: "/tmp/nonexistent_update_\(UUID().uuidString).txt")
        await manager.updateSignature(for: nonExistentURL)
        // 不崩溃即通过
    }

    // MARK: - AhoCorasickEngine 深度边界

    /// 重复模式应被去重（Set 去重），不影响匹配结果
    func testAhoCorasickEngine_DuplicatePatterns_MatchesNormally() {
        let patterns = ["abc", "abc", "abc", "def"]
        let engine = AhoCorasickEngine(patterns: patterns)
        let matches = engine.search(in: "abcdef")
        let uniquePatterns = Set(matches.map { $0.pattern })
        XCTAssertTrue(uniquePatterns.contains("abc"), "应匹配到 abc")
        XCTAssertTrue(uniquePatterns.contains("def"), "应匹配到 def")
    }

    /// 空字符串模式应被过滤（filter { !$0.isEmpty }），非空模式正常匹配
    func testAhoCorasickEngine_EmptyPattern_FiltersAndWorks() {
        let patterns = ["", "test", ""]
        let engine = AhoCorasickEngine(patterns: patterns)
        XCTAssertTrue(engine.containsAny(in: "test"), "空字符串模式应被过滤，test 应匹配")
        XCTAssertFalse(engine.containsAny(in: "nomatch"), "无匹配文本应返回 false")
    }

    /// search 返回的 startIndex/endIndex 应正确
    func testAhoCorasickEngine_Search_IndexCorrectness() {
        let engine = AhoCorasickEngine(patterns: ["cat"])
        let text = "the cat sat"
        let matches = engine.search(in: text)
        XCTAssertEqual(matches.count, 1, "应匹配到 1 个结果")
        if let match = matches.first {
            XCTAssertEqual(match.pattern, "cat")
            XCTAssertEqual(match.startIndex, 4, "cat 起始索引应为 4")
            XCTAssertEqual(match.endIndex, 6, "cat 结束索引应为 6")
        }
    }

    /// containsAny 空文本应返回 false
    func testAhoCorasickEngine_ContainsAny_EmptyText_ReturnsFalse() {
        let engine = AhoCorasickEngine(patterns: ["test"])
        XCTAssertFalse(engine.containsAny(in: ""), "空文本应返回 false")
    }

    /// containsAny 空模式列表应返回 false
    func testAhoCorasickEngine_ContainsAny_EmptyPatterns_ReturnsFalse() {
        let engine = AhoCorasickEngine(patterns: [])
        XCTAssertFalse(engine.containsAny(in: "any text"), "空模式列表应返回 false")
    }

    /// search 部分匹配但未完整匹配应返回空结果
    func testAhoCorasickEngine_PartialMatch_DoesNotHit() {
        let engine = AhoCorasickEngine(patterns: ["hello"])
        let matches = engine.search(in: "hel lo")
        XCTAssertTrue(matches.isEmpty, "部分匹配（中间有空格）不应命中")
    }

    /// 多个模式在同一位置重叠应全部命中
    func testAhoCorasickEngine_OverlappingPatterns_AllHit() {
        let engine = AhoCorasickEngine(patterns: ["he", "she", "her"])
        let matches = engine.search(in: "she")
        let patterns = Set(matches.map { $0.pattern })
        XCTAssertTrue(patterns.contains("she"), "应命中 she")
        XCTAssertTrue(patterns.contains("he"), "应命中 he（she 的子串）")
    }

    // MARK: - JailbreakDetector

    /// 模拟器环境越狱检测应返回 false
    func testJailbreakDetector_SimulatorEnvironment_ReturnsFalse() {
        let detector = JailbreakDetector.shared
        XCTAssertFalse(detector.isJailbroken(), "模拟器环境应检测为非越狱")
    }

    /// 独立实例也应检测为非越狱
    func testJailbreakDetector_IndependentInstance_ReturnsFalse() {
        let detector = JailbreakDetector()
        XCTAssertFalse(detector.isJailbroken(), "独立实例在模拟器应返回 false")
    }

    /// 多次调用 isJailbroken 应返回一致结果
    func testJailbreakDetector_MultipleCalls_ResultConsistent() {
        let detector = JailbreakDetector.shared
        let first = detector.isJailbroken()
        for _ in 0..<5 {
            XCTAssertEqual(detector.isJailbroken(), first, "多次调用应返回一致结果")
        }
    }

    // MARK: - ContentModerationEngine 边界

    /// 空文本应直接返回（不触发任何审核）
    func testContentModerationEngine_EmptyText_ReturnsDirectly() throws {
        let result = try ContentModerationEngine.shared.evaluateAndEnforce("")
        XCTAssertEqual(result, "", "空文本应直接返回空字符串")
    }

    /// 政治反动内容应被拦截并抛出 contentViolatesPolicy(.politicalReactionary)
    func testContentModerationEngine_PoliticalSensitive_Intercepted() {
        XCTAssertThrowsError(
            try ContentModerationEngine.shared.evaluateAndEnforce("颠覆政权反动宣言")
        ) { error in
            guard case PromptComplianceError.contentViolatesPolicy(.politicalReactionary) = error else {
                XCTFail("应抛出 politicalReactionary，实际: \(error)")
                return
            }
        }
    }

    /// 黄色色情内容应被拦截并抛出 contentViolatesPolicy(.adultNSFW)
    func testContentModerationEngine_Pornography_Intercepted() {
        XCTAssertThrowsError(
            try ContentModerationEngine.shared.evaluateAndEnforce("淫秽色情涉黄描述")
        ) { error in
            guard case PromptComplianceError.contentViolatesPolicy(.adultNSFW) = error else {
                XCTFail("应抛出 adultNSFW，实际: \(error)")
                return
            }
        }
    }

    /// 暴恐内容应被拦截并抛出 contentViolatesPolicy(.violenceTerrorism)
    func testContentModerationEngine_Terrorism_Intercepted() {
        XCTAssertThrowsError(
            try ContentModerationEngine.shared.evaluateAndEnforce("制造炸弹恐怖袭击")
        ) { error in
            guard case PromptComplianceError.contentViolatesPolicy(.violenceTerrorism) = error else {
                XCTFail("应抛出 violenceTerrorism，实际: \(error)")
                return
            }
        }
    }

    /// 赌博毒品内容应被拦截并抛出 contentViolatesPolicy(.gamblingNarcotics)
    func testContentModerationEngine_GamblingDrugs_Intercepted() {
        XCTAssertThrowsError(
            try ContentModerationEngine.shared.evaluateAndEnforce("制造冰毒配方合成冰毒")
        ) { error in
            guard case PromptComplianceError.contentViolatesPolicy(.gamblingNarcotics) = error else {
                XCTFail("应抛出 gamblingNarcotics，实际: \(error)")
                return
            }
        }
    }

    /// PromptComplianceError.accountTemporarilyThrottled 应有非空描述
    func testPromptComplianceError_AccountTemporarilyThrottled_DescriptionNotEmpty() {
        let error = PromptComplianceError.accountTemporarilyThrottled
        XCTAssertFalse(error.errorDescription?.isEmpty ?? true,
                       "accountTemporarilyThrottled 描述不应为空")
    }

    /// ComplianceCategory 应有 6 个 case 且 rawValue 非空
    func testComplianceCategory_AllSixCases_RawValueNotEmpty() {
        XCTAssertEqual(ComplianceCategory.allCases.count, 6, "应有 6 个违规分类")
        for category in ComplianceCategory.allCases {
            XCTAssertFalse(category.rawValue.isEmpty, "\(category) rawValue 不应为空")
        }
    }

    // MARK: - DynamicComplianceManager+Patch 验签失败路径

    /// 空载荷应返回 false
    func testVerifyAndApplyPatch_EmptyPayload_ReturnsFalse() {
        let manager = DynamicComplianceManager.shared
        let result = manager.verifyAndApplyPatch(
            payloadData: Data(),
            signatureBase64: "sig",
            publicKeyPEM: "key"
        )
        XCTAssertFalse(result, "空载荷应返回 false")
    }

    /// 空签名应返回 false
    func testVerifyAndApplyPatch_EmptySignature_ReturnsFalse() {
        let manager = DynamicComplianceManager.shared
        let payload = Data("{\"configVersion\":\"1\"}".utf8)
        let result = manager.verifyAndApplyPatch(
            payloadData: payload,
            signatureBase64: "",
            publicKeyPEM: "key"
        )
        XCTAssertFalse(result, "空签名应返回 false")
    }

    /// 无效 Base64 签名应返回 false（Data(base64Encoded:) 返回 nil）
    func testVerifyAndApplyPatch_InvalidBase64Signature_ReturnsFalse() {
        let manager = DynamicComplianceManager.shared
        let payload = Data("{\"configVersion\":\"1\"}".utf8)
        let result = manager.verifyAndApplyPatch(
            payloadData: payload,
            signatureBase64: "!!!not_base64!!!",
            publicKeyPEM: "VALID_TEST_PUBLIC_KEY"
        )
        XCTAssertFalse(result, "无效 Base64 签名应返回 false")
    }

    /// 测试公钥 + 空签名数据应返回 false（!signatureData.isEmpty 检查）
    func testVerifyAndApplyPatch_TestPublicKeyEmptySignature_ReturnsFalse() {
        let manager = DynamicComplianceManager.shared
        let payload = Data("{\"configVersion\":\"1\"}".utf8)
        let emptySignature = Data().base64EncodedString()
        let result = manager.verifyAndApplyPatch(
            payloadData: payload,
            signatureBase64: emptySignature,
            publicKeyPEM: "VALID_TEST_PUBLIC_KEY"
        )
        XCTAssertFalse(result, "空签名数据（base64 编码后非空字符串）应返回 false")
    }

    /// 测试公钥 + 非空签名 + 无效 JSON 应返回 false（验签通过但 JSON 解析失败）
    func testVerifyAndApplyPatch_TestPublicKeyInvalidJSON_ReturnsFalse() {
        let manager = DynamicComplianceManager.shared
        let invalidJSON = Data("not_json_at_all".utf8)
        let validSignature = Data("sig".utf8).base64EncodedString()
        let result = manager.verifyAndApplyPatch(
            payloadData: invalidJSON,
            signatureBase64: validSignature,
            publicKeyPEM: "VALID_TEST_PUBLIC_KEY"
        )
        XCTAssertFalse(result, "验签通过但 JSON 解析失败应返回 false")
    }

    /// 测试公钥 + 有效 JSON + 未知分类 key 应跳过该 key（不崩溃，返回 true）
    func testVerifyAndApplyPatch_UnknownCategoryKey_SkipsAndReturnsTrue() {
        let manager = DynamicComplianceManager.shared
        let jsonPayload = Data("""
        {
            "configVersion": "v1",
            "textOverrides": {},
            "patternOverrides": {
                "unknown_category": ["some_pattern"]
            }
        }
        """.utf8)
        let validSignature = Data("sig".utf8).base64EncodedString()
        let result = manager.verifyAndApplyPatch(
            payloadData: jsonPayload,
            signatureBase64: validSignature,
            publicKeyPEM: "VALID_TEST_PUBLIC_KEY"
        )
        XCTAssertTrue(result, "未知分类 key 应被跳过，验签+JSON 解析成功应返回 true")
    }

    /// 测试公钥 + 有效 JSON + 空覆盖应返回 true（updateRemoteComplianceConfig 接受空字典）
    func testVerifyAndApplyPatch_EmptyOverride_ReturnsTrue() {
        let manager = DynamicComplianceManager.shared
        let jsonPayload = Data("""
        {
            "configVersion": "v1",
            "textOverrides": {},
            "patternOverrides": {}
        }
        """.utf8)
        let validSignature = Data("sig".utf8).base64EncodedString()
        let result = manager.verifyAndApplyPatch(
            payloadData: jsonPayload,
            signatureBase64: validSignature,
            publicKeyPEM: "VALID_TEST_PUBLIC_KEY"
        )
        XCTAssertTrue(result, "空覆盖应返回 true")
    }

    /// 非测试公钥 + 无效 PEM 应返回 false（extractPublicKeyData 返回 nil）
    func testVerifyAndApplyPatch_NonTestPublicKeyInvalidPEM_ReturnsFalse() {
        let manager = DynamicComplianceManager.shared
        let payload = Data("{\"configVersion\":\"1\"}".utf8)
        let signature = Data("sig".utf8).base64EncodedString()
        let result = manager.verifyAndApplyPatch(
            payloadData: payload,
            signatureBase64: signature,
            publicKeyPEM: "not_a_valid_pem_key"
        )
        XCTAssertFalse(result, "非测试公钥且 PEM 无效应返回 false")
    }

    // MARK: - DynamicComplianceManager 文案与模式覆盖

    /// getComplianceMessage 无远程覆盖时应回退到 L10n
    func testDynamicComplianceManager_NoRemoteOverride_FallbackToL10n() {
        let manager = DynamicComplianceManager.shared
        // 先清空远程覆盖
        manager.updateRemoteComplianceConfig(textOverrides: [:], patternOverrides: [:])
        let message = manager.getComplianceMessage(for: .politicalReactionary)
        XCTAssertFalse(message.isEmpty, "无远程覆盖时应回退到 L10n 非空文案")
    }

    /// getPatterns 无远程覆盖时应返回 fallback
    func testDynamicComplianceManager_NoRemoteOverride_ReturnsFallback() {
        let manager = DynamicComplianceManager.shared
        manager.updateRemoteComplianceConfig(patternOverrides: [:])
        let fallback = ["fallback_pattern"]
        let patterns = manager.getPatterns(for: .adultNSFW, fallback: fallback)
        XCTAssertEqual(patterns, fallback, "无远程覆盖时应返回 fallback")
    }

    /// getPatterns 有远程覆盖时应返回远程模式
    func testDynamicComplianceManager_WithRemoteOverride_ReturnsRemotePatterns() {
        let manager = DynamicComplianceManager.shared
        let remotePatterns = ["remote_pattern_1", "remote_pattern_2"]
        manager.updateRemoteComplianceConfig(patternOverrides: [.violenceTerrorism: remotePatterns])
        let patterns = manager.getPatterns(for: .violenceTerrorism, fallback: ["fallback"])
        XCTAssertEqual(patterns, remotePatterns, "有远程覆盖时应返回远程模式")
        // 清理
        manager.updateRemoteComplianceConfig(patternOverrides: [:])
    }

    /// updateRemoteComplianceConfig 空字典不应覆盖已有远程配置
    func testDynamicComplianceManager_EmptyDictNoOverride_RetainsExistingConfig() {
        let manager = DynamicComplianceManager.shared
        let remotePatterns = ["existing_pattern"]
        manager.updateRemoteComplianceConfig(patternOverrides: [.gamblingNarcotics: remotePatterns])
        // 传入空字典不应覆盖
        manager.updateRemoteComplianceConfig(patternOverrides: [:])
        let patterns = manager.getPatterns(for: .gamblingNarcotics, fallback: ["fallback"])
        XCTAssertEqual(patterns, remotePatterns, "空字典不应覆盖已有远程配置")
        // 清理
        manager.updateRemoteComplianceConfig(patternOverrides: [:])
    }
}
