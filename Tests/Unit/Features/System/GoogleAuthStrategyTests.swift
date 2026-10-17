//
//  GoogleAuthStrategyTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/29.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 GoogleAuthStrategy 开展自动化单元测试验证。
//  覆盖范围：
//    - identityType 常量校验
//    - resolveConfiguredClientID 探针纯函数（Info.plist 优先 / SDK 兜底 / 缺失 / 占位与空值）
//    - 未配置 clientID 时的降级分支（Debug 返回 Mock，Release 抛未配置错误）
//    - 已配置 clientID 时真实 signIn 分支（凭证透传、idToken 为空抛错、无根控制器抛错）
//

import XCTest
@testable import ZhiYu

/// 可注入的 GoogleSignIn 登录能力 Mock
@MainActor
private final class MockGoogleSignInProvider: GoogleSignInProviding {

    var result: Result<GoogleSignInCredentialData, Error>
    var presentedController: UIViewController?

    init(result: Result<GoogleSignInCredentialData, Error>) {
        self.result = result
    }

    func signIn(presenting: UIViewController) async throws -> GoogleSignInCredentialData {
        presentedController = presenting
        return try result.get()
    }
}

@MainActor
final class GoogleAuthStrategyTests: XCTestCase {

    /// 便捷构造：默认注入有效 clientID、假根控制器与固定 provider 结果
    private func makeStrategy(
        result: Result<GoogleSignInCredentialData, Error> = .success(
            .init(idToken: "token", userID: "uid", email: "a@b.com", name: "Alice")
        ),
        clientID: String? = "valid-client-id",
        rootVC: UIViewController? = UIViewController()
    ) -> GoogleAuthStrategy {
        GoogleAuthStrategy(
            signInProvider: MockGoogleSignInProvider(result: result),
            clientIDResolver: { clientID },
            rootViewControllerProvider: { rootVC }
        )
    }

    // MARK: - identityType 基础校验

    /// 验证 Google 策略的 identityType 固定为 "google"
    func testGoogleAuthIdentityType() {
        XCTAssertEqual(GoogleAuthStrategy().identityType, "google", "Google 认证策略的 identityType 应当固定为 google")
    }

    // MARK: - resolveConfiguredClientID 探针纯函数

    /// Info.plist 中的 clientID 优先于 SDK 侧配置
    func testResolveConfiguredClientID_PrefersInfoPlistOverSDK() {
        let info = [FeatureConstants.GoogleConfig.clientIDKey: "ios-client"]
        XCTAssertEqual(
            GoogleAuthStrategy.resolveConfiguredClientID(infoPlist: info, sdkClientID: "sdk-client"),
            "ios-client",
            "Info.plist 的 GIDClientID 应优先于 SDK configuration"
        )
    }

    /// Info.plist 缺失时回退到 SDK 侧 clientID
    func testResolveConfiguredClientID_FallsBackToSDKClientID() {
        XCTAssertEqual(
            GoogleAuthStrategy.resolveConfiguredClientID(infoPlist: [:], sdkClientID: "sdk-client"),
            "sdk-client",
            "Info.plist 无 GIDClientID 时应回退到 SDK configuration"
        )
    }

    /// 两处都缺失时视为未配置
    func testResolveConfiguredClientID_NilWhenMissingEverywhere() {
        XCTAssertNil(GoogleAuthStrategy.resolveConfiguredClientID(infoPlist: [:], sdkClientID: nil))
        XCTAssertNil(GoogleAuthStrategy.resolveConfiguredClientID(infoPlist: nil, sdkClientID: nil))
    }

    /// 占位值或空字符串均视为未配置
    func testResolveConfiguredClientID_PlaceholderOrEmptyTreatedAsUnconfigured() {
        XCTAssertNil(GoogleAuthStrategy.resolveConfiguredClientID(
            infoPlist: [FeatureConstants.GoogleConfig.clientIDKey: FeatureConstants.GoogleConfig.placeholderClientID],
            sdkClientID: nil
        ), "占位 clientID 应视为未配置")
        XCTAssertNil(GoogleAuthStrategy.resolveConfiguredClientID(
            infoPlist: [FeatureConstants.GoogleConfig.clientIDKey: ""],
            sdkClientID: nil
        ), "空 clientID 应视为未配置")
    }

    // MARK: - 未配置 clientID 的降级分支

    /// Debug 模式下未配置 clientID 应安全降级为 Mock 登录
    func testAcquire_NotConfigured_DebugReturnsMock() async {
        #if DEBUG
        let strategy = makeStrategy(clientID: nil)
        do {
            let credential = try await strategy.acquireCredentials()
            XCTAssertEqual(credential.identityType, "google")
            XCTAssertEqual(credential.identifier, "mock_google_user_id")
            XCTAssertFalse((credential.extraInfo?["idToken"] ?? "").isEmpty, "Mock 凭证应包含非空 idToken")
        } catch {
            XCTFail("Debug 未配置 clientID 应安全降级为 Mock 登录，不应抛错: \(error)")
        }
        #endif
    }

    /// Release 模式下未配置 clientID 应抛出未配置错误
    func testAcquire_NotConfigured_ThrowsInRelease() async {
        #if !DEBUG
        let strategy = makeStrategy(clientID: nil)
        do {
            _ = try await strategy.acquireCredentials()
            XCTFail("未配置 clientID 时应抛出未配置错误")
        } catch let error as NSError {
            XCTAssertEqual(error.code, -99, "错误码应为 -99（SDK 未配置）")
        } catch {
            XCTFail("抛出的不是预期的 NSError: \(error)")
        }
        #endif
    }

    // MARK: - 已配置 clientID 的 signIn 分支

    /// 已配置 clientID 时，应调用 provider 并用其返回值组装凭证
    func testAcquire_Configured_ReturnsCredentialFromProvider() async throws {
        let provider = MockGoogleSignInProvider(result: .success(.init(
            idToken: "token-abc", userID: "user-123", email: "a@b.com", name: "Alice B"
        )))
        let strategy = GoogleAuthStrategy(
            signInProvider: provider,
            clientIDResolver: { "valid" },
            rootViewControllerProvider: { UIViewController() }
        )

        let credential = try await strategy.acquireCredentials()

        XCTAssertEqual(credential.identityType, "google")
        XCTAssertEqual(credential.identifier, "user-123", "identifier 应来自 provider 的 userID")
        XCTAssertEqual(credential.extraInfo?["idToken"], "token-abc", "idToken 应透传后端验证")
        XCTAssertEqual(credential.extraInfo?["email"], "a@b.com")
        XCTAssertEqual(credential.extraInfo?["nickname"], "Alice B")
        XCTAssertEqual(credential.credential, FeatureConstants.MockData.mockGoogleCode)
        XCTAssertNotNil(provider.presentedController, "signIn 分支应传入根控制器")
    }

    /// provider 返回空 idToken 时应抛出 token 错误
    func testAcquire_Configured_EmptyIdToken_ThrowsTokenError() async {
        let strategy = makeStrategy(result: .success(.init(idToken: "", userID: "uid", email: nil, name: nil)))
        do {
            _ = try await strategy.acquireCredentials()
            XCTFail("idToken 为空时应抛出 token 错误")
        } catch let error as NSError {
            XCTAssertEqual(error.code, -2, "错误码应为 -2（idToken 获取失败）")
        } catch {
            XCTFail("抛出的不是预期的 NSError: \(error)")
        }
    }

    /// 无前台根控制器时应抛出窗口错误
    func testAcquire_Configured_NoRootViewController_ThrowsWindowError() async {
        let strategy = makeStrategy(rootVC: nil)
        do {
            _ = try await strategy.acquireCredentials()
            XCTFail("无前台根控制器时应抛出窗口错误")
        } catch let error as NSError {
            XCTAssertEqual(error.code, -1, "错误码应为 -1（无窗口）")
        } catch {
            XCTFail("抛出的不是预期的 NSError: \(error)")
        }
    }
}
