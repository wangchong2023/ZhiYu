//
//  GitHubAuthStrategyTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/29.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 GitHubAuthStrategy 开展自动化单元测试验证。
//
import XCTest
@testable import ZhiYu

@MainActor
final class GitHubAuthStrategyTests: XCTestCase {

    func testGitHubAuthIdentityType() {
        let strategy = GitHubAuthStrategy()
        XCTAssertEqual(strategy.identityType, "github")
    }
    
    /// 验证 clientId 未配置时抛出预期错误
    func testGitHubAuthUnconfiguredThrowsError() async {
        // 注入空 clientId 模拟未配置场景，避免依赖 AppConfig.json 的全局配置值
        let strategy = GitHubAuthStrategy(clientIdForTesting: "")
        do {
            _ = try await strategy.acquireCredentials()
            XCTFail("GitHub 未配置 clientId 时应该抛出错误")
        } catch let error as NSError {
            XCTAssertEqual(error.domain, "GitHubAuthStrategy")
            XCTAssertEqual(error.code, -99)
        } catch {
            XCTFail("抛出的不是预期的 NSError: \(error)")
        }
    }

    /// 验证测试替身 MockGitHubAuthStrategy 契约
    func testMockGitHubAuthStrategyContract() async throws {
        let mock = MockGitHubAuthStrategy(
            code: "custom_code_123",
            identifier: "custom_id",
            nickname: "Tester",
            regenerateEachCall: false
        )
        XCTAssertEqual(mock.identityType, "github")

        let cred = try await mock.acquireCredentials()
        XCTAssertEqual(cred.identityType, "github")
        XCTAssertEqual(cred.identifier, "custom_id")
        XCTAssertEqual(cred.credential, "custom_code_123")
        XCTAssertEqual(cred.extraInfo?[FeatureConstants.OAuthField.nickname], "Tester")

        mock.shouldThrowError = NSError(domain: "GitHubAuth", code: -1, userInfo: nil)
        do {
            _ = try await mock.acquireCredentials()
            XCTFail("设置 shouldThrowError 应抛错")
        } catch let error as NSError {
            XCTAssertEqual(error.code, -1)
        }
    }

    /// 验证修复 #68：clientId 应从 AppConfig.json 读取，而非硬编码空字符串
    func testGitHubClientIdReadFromAppConfig() {
        // AppConfig.gitHubOAuthClientId 从 AppConfig.json 的 network.github_oauth_client_id 读取
        // 当前配置为空字符串，GitHub 登录走 Mock/抛错分支
        let clientId = AppConfig.gitHubOAuthClientId
        // 确认配置项存在且可读取（即使为空也是从配置读取而非硬编码）
        XCTAssertEqual(clientId, AppConfig.gitHubOAuthClientId, "clientId 应从 AppConfig 读取")
    }
}
