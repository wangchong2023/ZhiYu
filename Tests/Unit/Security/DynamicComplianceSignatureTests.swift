//
//  DynamicComplianceSignatureTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//

import XCTest
@testable import ZhiYu

final class DynamicComplianceSignatureTests: XCTestCase {

    func testVerifyAndApplyPatch_SuccessPath() throws {
        let manager = DynamicComplianceManager.shared

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

        let validSignature = Data("VALID_TEST_SIGNATURE_BASE64_BYTES".utf8).base64EncodedString()
        let testPublicKey = "-----BEGIN PUBLIC KEY-----\nVALID_TEST_PUBLIC_KEY\n-----END PUBLIC KEY-----"

        let result = manager.verifyAndApplyPatch(
            payloadData: jsonPayload,
            signatureBase64: validSignature,
            publicKeyPEM: testPublicKey
        )

        XCTAssertTrue(result, "合法公钥与有效数字签名应验签成功并施加 Delta Patch")

        let patterns = manager.getPatterns(for: .politicalReactionary, fallback: [])
        XCTAssertTrue(patterns.contains("(?i)(?:黑名单测试词)"), "应该应用 Delta Patch 中的黑名单正则词")
    }

    func testVerifyAndApplyPatch_TamperedPayloadRejection() {
        let manager = DynamicComplianceManager.shared

        let tamperedPayload = Data("""
        {
            "configVersion": "2026.08.02-v1-tampered",
            "textOverrides": {}
        }
        """.utf8)

        let emptySignature = ""
        let testPublicKey = "-----BEGIN PUBLIC KEY-----\nVALID_TEST_PUBLIC_KEY\n-----END PUBLIC KEY-----"

        let result = manager.verifyAndApplyPatch(
            payloadData: tamperedPayload,
            signatureBase64: emptySignature,
            publicKeyPEM: testPublicKey
        )

        XCTAssertFalse(result, "空签名或被中间人篡改的 Payload 应拒绝施加 Patch，保证系统安全")
    }
}
