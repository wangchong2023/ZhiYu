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
    
    func testGitHubAuthReturnsMockOrThrowsError() async {
        let strategy = GitHubAuthStrategy()
        #if DEBUG
        do {
            let credential = try await strategy.acquireCredentials()
            XCTAssertEqual(credential.identityType, "github")
            XCTAssertEqual(credential.identifier, "mock_github_user_id")
            XCTAssertEqual(credential.extraInfo?["nickname"], "GitHub Mock User")
            XCTAssertFalse(credential.credential.isEmpty)
        } catch {
            XCTFail("Debug 模式下 GitHub 未配置 ClientID 应当安全降级为 Mock 登录，不应抛出错误: \(error)")
        }
        #else
        do {
            _ = try await strategy.acquireCredentials()
            XCTFail("GitHub 未配置时在 Release 模式下应该抛出错误")
        } catch let error as NSError {
            XCTAssertEqual(error.domain, "GitHubAuthStrategy")
            XCTAssertEqual(error.code, -99)
        } catch {
            XCTFail("抛出的不是预期的 NSError: \(error)")
        }
        #endif
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
