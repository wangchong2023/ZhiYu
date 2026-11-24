//
//  PluginSignatureMutationTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[测试层]
//  核心职责：对 PluginLoader 的签名校验（verifyPluginSignature）和常量时间比较
//  （constantTimeCompare）进行安全变异测试。
//  每个用例构造「若安全边界失效则 FAIL」的攻击场景。
//  任何 FAIL 代表签名绕过漏洞真实存在。
//

import XCTest
@testable import ZhiYuUnitTestHost

@MainActor
final class PluginSignatureMutationTests: XCTestCase {

    // MARK: - 辅助：构造最小合法 PluginManifest
    private func makeManifest(
        id: String,
        codeSignature: String? = nil
    ) -> PluginManifest {
        PluginManifest(
            id: id,
            version: "1.0.0",
            author: "TestAuthor",
            permissions: [],
            names: ["zh-Hans": "测试插件"],
            descriptions: ["zh-Hans": "测试描述"],
            codeSignature: codeSignature
        )
    }

    // MARK: - 变异 S1：外部 manifest 使用 local. 前缀应被拒绝
    //
    // 若此测试 FAIL → 安全漏洞：外部插件可伪造 local. 前缀绕过签名检查
    func testMutation_ExternalManifestWithLocalPrefix_IsRejected() {
        let evilManifests = [
            makeManifest(id: "local.evil-plugin"),
            makeManifest(id: "local.com.zhiyu.forged"),
            makeManifest(id: "local.", codeSignature: "abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890")
        ]

        for manifest in evilManifests {
            let result = PluginLoader.verifyPluginSignature(
                script: "console.log('evil')",
                manifest: manifest
            )
            XCTAssertFalse(
                result,
                "外部插件使用 local. 前缀 '\(manifest.id)' 应被拒绝，但通过了签名校验 → 安全漏洞！"
            )
        }
    }

    // MARK: - 变异 S2：codeSignature 为空字符串应被拒绝
    //
    // 危险点：`guard let expectedSignature = manifest.codeSignature, !expectedSignature.isEmpty`
    // 若 `!expectedSignature.isEmpty` 缺失，空字符串可绕过。
    // 若此测试 FAIL → 安全漏洞：空签名可绕过校验
    func testMutation_EmptyCodeSignature_IsRejected() {
        let manifest = makeManifest(id: "com.zhiyu.plugin.remote.test", codeSignature: "")

        let result = PluginLoader.verifyPluginSignature(
            script: "console.log('test')",
            manifest: manifest
        )
        XCTAssertFalse(result, "空字符串签名应被拒绝，但通过了校验 → 安全漏洞！")
    }

    // MARK: - 变异 S3：codeSignature 为 nil 应被拒绝
    //
    // 危险点：若 guard 被改为 `if let`（不含 else return false），nil 签名可绕过。
    func testMutation_NilCodeSignature_IsRejected() {
        let manifest = makeManifest(id: "com.zhiyu.plugin.remote.test", codeSignature: nil)

        let result = PluginLoader.verifyPluginSignature(
            script: "console.log('test')",
            manifest: manifest
        )
        XCTAssertFalse(result, "nil 签名应被拒绝，但通过了校验 → 安全漏洞！")
    }

    // MARK: - 变异 S4：非合法 hex 签名应被拒绝
    //
    // 危险点：`Data(hexString:)` 解析失败时返回 nil，
    // 若 guard 缺失（直接用 ?? Data()），会用空 Data 作比较，可能通过。
    // 若此测试 FAIL → 安全漏洞：非法 hex 签名用空 Data 绕过了比较
    func testMutation_InvalidHexSignature_IsRejected() {
        let invalidHexSignatures = [
            "not-valid-hex!",
            "GGGG",              // G 不是合法 hex 字符
            "ZZ1234",
            "12 34 56",         // 含空格
            "0x1234abcd"       // 带 0x 前缀（通常 hex 解析不接受）
        ]

        for sig in invalidHexSignatures {
            let manifest = makeManifest(id: "com.zhiyu.plugin.remote.test", codeSignature: sig)
            let result = PluginLoader.verifyPluginSignature(
                script: "console.log('test')",
                manifest: manifest
            )
            XCTAssertFalse(
                result,
                "非合法 hex 签名 '\(sig)' 应被拒绝，但通过了校验 → Data(hexString:) 解析可能有误"
            )
        }
    }

    //
    // 本地来源不再代表可信，所有缺失有效签名的本地插件都应拒绝。
    func testMutation_TrustedLocal_RejectsUnsignedLocal() {
        let manifests = [
            makeManifest(id: "local.internal-plugin", codeSignature: nil),
            makeManifest(id: "local.internal-plugin", codeSignature: ""),
            makeManifest(id: "local.internal-plugin", codeSignature: "invalid-hex")
        ]

        for manifest in manifests {
            let result = PluginLoader.verifyPluginSignature(
                script: "console.log('internal')",
                manifest: manifest
            )
            XCTAssertFalse(
                result,
                "本地插件缺少有效签名时必须返回 false，manifest.id='\(manifest.id)'"
            )
        }
    }

    // MARK: - 变异 S6：constantTimeCompare 安全性验证
    //
    // 测试两个核心安全属性：
    // a) 长度不同时必须返回 false（即使前缀相同）
    // b) 内容不同时必须返回 false（即使长度相同）
    // c) 完全相同时必须返回 true
    // 若此测试 FAIL → 安全漏洞：时序比较逻辑错误，可能允许前缀匹配绕过
    func testMutation_ConstantTimeCompare_CorrectBehavior() {
        // a) 长度不同 → 应为 false（即使前缀相同）
        XCTAssertFalse(
            PluginLoader.constantTimeCompare(Data([0x01]), b: Data([0x01, 0x02])),
            "长度不同应返回 false，前缀相同不应绕过"
        )
        XCTAssertFalse(
            PluginLoader.constantTimeCompare(Data([0x01, 0x02]), b: Data([0x01])),
            "长度不同（反向）应返回 false"
        )
        XCTAssertFalse(
            PluginLoader.constantTimeCompare(Data(), b: Data([0x00])),
            "空 Data 与单字节不同"
        )

        // b) 长度相同但内容不同 → 应为 false
        XCTAssertFalse(
            PluginLoader.constantTimeCompare(Data([0x01]), b: Data([0x02])),
            "内容不同应返回 false"
        )
        XCTAssertFalse(
            PluginLoader.constantTimeCompare(Data([0x01, 0x02, 0x03]), b: Data([0x01, 0x02, 0xFF])),
            "最后一个字节不同应返回 false"
        )

        // c) 完全相同 → 必须为 true
        XCTAssertTrue(
            PluginLoader.constantTimeCompare(Data([0x01, 0x02, 0x03]), b: Data([0x01, 0x02, 0x03])),
            "完全相同应返回 true"
        )
        XCTAssertTrue(
            PluginLoader.constantTimeCompare(Data(), b: Data()),
            "两个空 Data 应相等"
        )
    }
}
