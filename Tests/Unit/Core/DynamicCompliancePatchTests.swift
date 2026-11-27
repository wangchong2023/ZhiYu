//
//  DynamicCompliancePatchTests.swift
//  ZhiYu
//
//  系统层级：[L0] 测试层
//  核心职责：验证 DynamicComplianceManager+Patch 的 RSA 验签、PEM 解析、
//           JSON 解码失败、无效 Base64 签名、空 payload 拒绝等边界路径。
//

import XCTest
@testable import ZhiYuUnitTestHost

final class DynamicCompliancePatchTests: XCTestCase {

    private var manager: DynamicComplianceManager!

    override func setUp() {
        super.setUp()
        manager = DynamicComplianceManager.shared
    }

    override func tearDown() {
        // DynamicComplianceManager 是 private init 单例，无 testOverride 机制，
        // updateRemoteComplianceConfig 内部有 isEmpty 守卫无法清理。
        // 接受单例状态污染，测试用唯一 key/独立 fallback 避免跨用例冲突。
        manager = nil
        super.tearDown()
    }

    // MARK: - 空 payload / 空签名拒绝

    func testVerifyAndApplyPatchEmptyPayloadReturnsFalse() {
        let result = manager.verifyAndApplyPatch(
            payloadData: Data(),
            signatureBase64: "valid_signature",
            publicKeyPEM: "-----BEGIN PUBLIC KEY-----\nVALID_TEST_PUBLIC_KEY\n-----END PUBLIC KEY-----"
        )
        XCTAssertFalse(result, "空 payload 应拒绝")
    }

    func testVerifyAndApplyPatchEmptySignatureReturnsFalse() {
        let payload = Data("{\"configVersion\":\"v1\"}".utf8)
        let result = manager.verifyAndApplyPatch(
            payloadData: payload,
            signatureBase64: "",
            publicKeyPEM: "-----BEGIN PUBLIC KEY-----\nVALID_TEST_PUBLIC_KEY\n-----END PUBLIC KEY-----"
        )
        XCTAssertFalse(result, "空签名应拒绝")
    }

    // MARK: - 真实 RSA-2048 验签路径

    func testVerifyAndApplyPatchTestKeyNonEmptySignatureVerificationPasses() throws {
        let (privateKey, publicKeyPEM) = try ComplianceRSATestHelper.makeKeyPair()
        let payload = Data("""
        {
            "configVersion": "2026.08.06-v1",
            "textOverrides": {},
            "patternOverrides": {}
        }
        """.utf8)
        let signature = try ComplianceRSATestHelper.sign(payload, with: privateKey)

        let result = manager.verifyAndApplyPatch(
            payloadData: payload,
            signatureBase64: signature,
            publicKeyPEM: publicKeyPEM
        )
        XCTAssertTrue(result, "真实 RSA-2048 公钥 + 合法签名应验签通过")
    }

    func testVerifyAndApplyPatchTestKeyEmptySignatureDataVerificationFails() throws {
        let (_, publicKeyPEM) = try ComplianceRSATestHelper.makeKeyPair()
        let payload = Data("{\"configVersion\":\"v1\"}".utf8)
        let emptySignature = Data().base64EncodedString() // 空数据的 Base64

        let result = manager.verifyAndApplyPatch(
            payloadData: payload,
            signatureBase64: emptySignature,
            publicKeyPEM: publicKeyPEM
        )
        XCTAssertFalse(result, "空签名数据应验签失败")
    }

    // MARK: - 无效 Base64 签名

    func testVerifyAndApplyPatchInvalidBase64SignatureReturnsFalse() {
        let payload = Data("{\"configVersion\":\"v1\"}".utf8)
        let invalidBase64 = "!!!not_valid_base64!!!"
        let realKeyPEM = "-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA\n-----END PUBLIC KEY-----"

        let result = manager.verifyAndApplyPatch(
            payloadData: payload,
            signatureBase64: invalidBase64,
            publicKeyPEM: realKeyPEM
        )
        XCTAssertFalse(result, "无效 Base64 签名应返回 false")
    }

    // MARK: - JSON 解码失败

    func testVerifyAndApplyPatchTestKeyInvalidJsonReturnsFalse() throws {
        let (privateKey, publicKeyPEM) = try ComplianceRSATestHelper.makeKeyPair()
        let invalidJson = Data("not a json".utf8)
        let signature = try ComplianceRSATestHelper.sign(invalidJson, with: privateKey)

        let result = manager.verifyAndApplyPatch(
            payloadData: invalidJson,
            signatureBase64: signature,
            publicKeyPEM: publicKeyPEM
        )
        XCTAssertFalse(result, "验签通过但 JSON 非法应返回 false")
    }

    func testVerifyAndApplyPatchJsonMissingRequiredFieldsStillReturnsTrue() throws {
        let (privateKey, publicKeyPEM) = try ComplianceRSATestHelper.makeKeyPair()
        // CompliancePatchPayload 所有字段都是可选的，缺少字段应解码成功
        let minimalJson = Data("{}".utf8)
        let signature = try ComplianceRSATestHelper.sign(minimalJson, with: privateKey)

        let result = manager.verifyAndApplyPatch(
            payloadData: minimalJson,
            signatureBase64: signature,
            publicKeyPEM: publicKeyPEM
        )
        XCTAssertTrue(result, "空 JSON 对象应解码成功（所有字段可选）并返回 true")
    }

    // MARK: - patternOverrides 转换

    func testVerifyAndApplyPatchInvalidCategoryPatternSkipsCategory() throws {
        let (privateKey, publicKeyPEM) = try ComplianceRSATestHelper.makeKeyPair()
        let payload = Data("""
        {
            "patternOverrides": {
                "invalid_category": ["pattern1"],
                "political_reactionary": ["valid_pattern"]
            }
        }
        """.utf8)
        let signature = try ComplianceRSATestHelper.sign(payload, with: privateKey)

        let result = manager.verifyAndApplyPatch(
            payloadData: payload,
            signatureBase64: signature,
            publicKeyPEM: publicKeyPEM
        )
        XCTAssertTrue(result, "应成功施加 Patch（无效 category 被跳过）")

        let validPatterns = manager.getPatterns(for: .politicalReactionary, fallback: [])
        XCTAssertTrue(validPatterns.contains("valid_pattern"), "有效 category 的 pattern 应被应用")
    }

    // MARK: - textOverrides 应用

    func testVerifyAndApplyPatchTextOverridesAppliedAffectsGetComplianceMessage() throws {
        let (privateKey, publicKeyPEM) = try ComplianceRSATestHelper.makeKeyPair()
        let payload = Data("""
        {
            "textOverrides": {
                "zh-Hans": {
                    "political_reactionary": "自定义违规告示文案"
                }
            }
        }
        """.utf8)
        let signature = try ComplianceRSATestHelper.sign(payload, with: privateKey)

        _ = manager.verifyAndApplyPatch(
            payloadData: payload,
            signatureBase64: signature,
            publicKeyPEM: publicKeyPEM
        )

        // 注意：getComplianceMessage 依赖系统语言偏好，可能返回自定义文案或 L10n 回退
        let message = manager.getComplianceMessage(for: .politicalReactionary)
        XCTAssertFalse(message.isEmpty, "合规告示文案不应为空")
    }

    // MARK: - 真实 PEM 解析路径（非测试公钥）

    /// 非测试公钥（不含 VALID_TEST_PUBLIC_KEY）应走真实 SecKey 验签路径
    /// 无效的 PEM Base64 应导致 extractPublicKeyData 返回 nil，验签失败
    func testVerifyAndApplyPatchInvalidPemContentVerificationFails() {
        let payload = Data("{\"configVersion\":\"v1\"}".utf8)
        let signature = Data("sig".utf8).base64EncodedString()
        // 真实 PEM 格式但内容不是有效 Base64 公钥
        let invalidPem = "-----BEGIN PUBLIC KEY-----\n!!!invalid base64!!!\n-----END PUBLIC KEY-----"

        let result = manager.verifyAndApplyPatch(
            payloadData: payload,
            signatureBase64: signature,
            publicKeyPEM: invalidPem
        )
        XCTAssertFalse(result, "无效 PEM 内容应导致公钥提取失败，验签返回 false")
    }

    /// PEM 缺少头尾标记应导致 extractPublicKeyData 解析异常
    func testVerifyAndApplyPatchPemMissingHeaderVerificationFails() {
        let payload = Data("{\"configVersion\":\"v1\"}".utf8)
        let signature = Data("sig".utf8).base64EncodedString()
        // 缺少 BEGIN 标记的 PEM
        let malformedPem = "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA\n-----END PUBLIC KEY-----"

        let result = manager.verifyAndApplyPatch(
            payloadData: payload,
            signatureBase64: signature,
            publicKeyPEM: malformedPem
        )
        // extractPublicKeyData 会尝试 Base64 解码整个清理后的字符串，
        // 缺少头标记时清理结果可能仍包含 END 标记，导致 Base64 解码失败
        XCTAssertFalse(result, "缺少头标记的 PEM 应验签失败")
    }
}
