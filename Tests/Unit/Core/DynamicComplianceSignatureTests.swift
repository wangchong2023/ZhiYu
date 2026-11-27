//
//  DynamicComplianceSignatureTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//

import XCTest
import Security
@testable import ZhiYuUnitTestHost

/// 测试专用 RSA-2048 密钥对签发辅助（零生产后门，验证真实密码学验签）
enum ComplianceRSATestHelper {
    static func makeKeyPair() throws -> (privateKey: SecKey, publicKeyPEM: String) {
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: 2048
        ]
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error),
              let publicKey = SecKeyCopyPublicKey(privateKey),
              let externalData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            throw error?.takeRetainedValue() as Error? ?? NSError(domain: "ComplianceRSATestHelper", code: -1)
        }
        let pem = "-----BEGIN PUBLIC KEY-----\n\(externalData.base64EncodedString())\n-----END PUBLIC KEY-----"
        return (privateKey, pem)
    }

    static func sign(_ payload: Data, with privateKey: SecKey) throws -> String {
        var error: Unmanaged<CFError>?
        guard let sigData = SecKeyCreateSignature(
            privateKey,
            .rsaSignatureMessagePKCS1v15SHA256,
            payload as CFData,
            &error
        ) as Data? else {
            throw error?.takeRetainedValue() as Error? ?? NSError(domain: "ComplianceRSATestHelper", code: -2)
        }
        return sigData.base64EncodedString()
    }
}

final class DynamicComplianceSignatureTests: XCTestCase {

    func testVerifyAndApplyPatch_SuccessPath() throws {
        let manager = DynamicComplianceManager.shared
        let (privateKey, publicKeyPEM) = try ComplianceRSATestHelper.makeKeyPair()

        let jsonPayload = Data("""
        {
            "configVersion": "2026.08.02-v1",
            "textOverrides": {
                "zh-Hans": {
                    "political_reactionary": "系统检测到违规，已安全拒答"
                }
            },
            "patternOverrides": {
                "political_reactionary": ["(?i)(?:黑名单测试词)"]
            }
        }
        """.utf8)

        let validSignature = try ComplianceRSATestHelper.sign(jsonPayload, with: privateKey)

        let result = manager.verifyAndApplyPatch(
            payloadData: jsonPayload,
            signatureBase64: validSignature,
            publicKeyPEM: publicKeyPEM
        )

        XCTAssertTrue(result, "合法 RSA-2048 公钥与真实数字签名应验签成功并施加 Delta Patch")

        let patterns = manager.getPatterns(for: .politicalReactionary, fallback: [])
        XCTAssertTrue(patterns.contains("(?i)(?:黑名单测试词)"), "应该应用 Delta Patch 中的黑名单正则词")
    }

    /// 缺陷 #234 回归：篡改 Payload、空签名以及历史 VALID_TEST_PUBLIC_KEY 后门标识均必须被严格拒绝
    func testVerifyAndApplyPatch_TamperedPayloadAndLegacyBackdoorRejected() throws {
        let manager = DynamicComplianceManager.shared
        let (privateKey, publicKeyPEM) = try ComplianceRSATestHelper.makeKeyPair()

        let originalPayload = Data("""
        {
            "configVersion": "2026.08.02-v1",
            "textOverrides": {}
        }
        """.utf8)
        let tamperedPayload = Data("""
        {
            "configVersion": "2026.08.02-v1-tampered",
            "textOverrides": {}
        }
        """.utf8)

        let validSigForOriginal = try ComplianceRSATestHelper.sign(originalPayload, with: privateKey)
        XCTAssertFalse(
            manager.verifyAndApplyPatch(payloadData: tamperedPayload, signatureBase64: validSigForOriginal, publicKeyPEM: publicKeyPEM),
            "被中间人篡改的 Payload 必须验签失败"
        )
        XCTAssertFalse(
            manager.verifyAndApplyPatch(payloadData: tamperedPayload, signatureBase64: "", publicKeyPEM: publicKeyPEM),
            "空签名必须拒绝"
        )
        XCTAssertFalse(
            manager.verifyAndApplyPatch(
                payloadData: originalPayload,
                signatureBase64: Data("fake_sig".utf8).base64EncodedString(),
                publicKeyPEM: "-----BEGIN PUBLIC KEY-----\nVALID_TEST_PUBLIC_KEY\n-----END PUBLIC KEY-----"
            ),
            "生产代码不得存在 VALID_TEST_PUBLIC_KEY 验签绕过后门"
        )
    }
}
