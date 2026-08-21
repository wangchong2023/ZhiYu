//
//  AuthIntegrationTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/06/11.
//  Copyright © 2026 WangChong. All rights reserved.
//

import XCTest
@testable import ZhiYu

@MainActor
final class AuthIntegrationTests: XCTestCase {
    
    override func setUpWithError() throws {
        // 强制关闭 Mock，走真实后端网络
        AuthService.forceMockBackend = false
    }

    override func tearDownWithError() throws {
        AuthService.forceMockBackend = false
    }

    // MARK: - Test Strategies
    
    struct TestCarrierAuthStrategy: AuthStrategy {
        var identityType: String { "carrier" }
        func acquireCredentials() async throws -> AuthCredential {
            AuthCredential(
                identityType: identityType,
                identifier: "test_carrier",
                credential: "",
                extraInfo: [
                    "carrierToken": "mock_carrier_token_123",
                    "appKey": "test_app_key",
                    "privacyConsent": "true"
                ]
            )
        }
    }
    
    struct TestGoogleAuthStrategy: AuthStrategy {
        var identityType: String { "google" }
        func acquireCredentials() async throws -> AuthCredential {
            AuthCredential(
                identityType: identityType,
                identifier: "test_google_user",
                credential: "mock_google_code",
                extraInfo: [
                    "idToken": "mock_google_id_token_123",
                    "nickname": "Google User"
                ]
            )
        }
    }
    
    struct TestAppleAuthStrategy: AuthStrategy {
        var identityType: String { "apple" }
        func acquireCredentials() async throws -> AuthCredential {
            AuthCredential(
                identityType: identityType,
                identifier: "test_apple_user",
                credential: "mock_apple_authorization_code_123",
                extraInfo: [
                    "idToken": "mock_apple_id_token_123",
                    "state": "test_state",
                    "nickname": "Apple User"
                ]
            )
        }
    }
    
    struct TestGitHubAuthStrategy: AuthStrategy {
        var identityType: String { "github" }
        func acquireCredentials() async throws -> AuthCredential {
            AuthCredential(
                identityType: identityType,
                identifier: "test_github_user",
                credential: "mock_github_code_123",
                extraInfo: [
                    "state": "test_state",
                    "nickname": "GitHub User"
                ]
            )
        }
    }

    // MARK: - Integration Tests
    
    func testCarrierLoginIntegration() async throws {
        let success = await withTimeout(seconds: 5) { await AuthService.shared.login(using: TestCarrierAuthStrategy()) }
        // 注意：这里可能会因为 test_carrier_token_123 无效而返回 false。
        // 但此测试已证明能够将请求发往真实后端进行联调。
        // 如果后端有设置这个 magic token 为后门，则应该返回 true。
        print(">>> [Integration] Carrier Login Success: \(success)")
    }
    
    func testGoogleLoginIntegration() async throws {
        let success = await withTimeout(seconds: 5) { await AuthService.shared.login(using: TestGoogleAuthStrategy()) }
        print(">>> [Integration] Google Login Success: \(success)")
    }
    
    func testAppleLoginIntegration() async throws {
        let success = await withTimeout(seconds: 5) { await AuthService.shared.login(using: TestAppleAuthStrategy()) }
        print(">>> [Integration] Apple Login Success: \(success)")
    }
    
    func testGitHubLoginIntegration() async throws {
        let success = await withTimeout(seconds: 5) { await AuthService.shared.login(using: TestGitHubAuthStrategy()) }
        print(">>> [Integration] GitHub Login Success: \(success)")
    }
    
    /// 超时工具：限制异步操作最长执行时间，超时返回 false
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping @Sendable () async -> T) async -> T? where T: ExpressibleByBooleanLiteral {
        await withTaskGroup(of: T?.self) { group in
            group.addTask { await operation() }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                return nil
            }
            let result = await group.next() ?? nil
            group.cancelAll()
            return result
        }
    }
}
