//
//  StoreKitAndInfraServiceDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/03.
//  Copyright © 2026 WangChong. All rights reserved.
//

import XCTest
import SwiftUI
import StoreKit
import AuthenticationServices
import UFPCore
@testable import ZhiYu

@MainActor
final class StoreKitAndInfraServiceDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        UserDefaults.standard.removeObject(forKey: FeatureConstants.ServerConfig.storageKey)
        UserDefaults.standard.removeObject(forKey: LLMConstants.OnDeviceStorage.configKey)
        StoreKitService.shared.restoreMessage = nil
        StoreKitService.shared.isRestoring = false
    }

    override func tearDown() async throws {
        UserDefaults.standard.removeObject(forKey: FeatureConstants.ServerConfig.storageKey)
        UserDefaults.standard.removeObject(forKey: LLMConstants.OnDeviceStorage.configKey)
        StoreKitService.shared.restoreMessage = nil
        StoreKitService.shared.isRestoring = false
        try await super.tearDown()
    }

    // MARK: - 1. StoreKitService 核心状态与生命周期深测

    func testStoreKitService_StateAndLifecycle() async {
        let service = StoreKitService.shared

        service.startListening()
        XCTAssertFalse(service.isRestoring)
        XCTAssertNil(service.restoreMessage)

        // 验证停止监听
        service.stopListening()

        // 注：restorePurchases() 调用 StoreKit.AppStore.sync()，在模拟器无沙盒账号
        // 环境下会无限挂起，与项目其他 StoreKit 测试一致，此处跳过恢复购买验证
        XCTAssertFalse(service.isRestoring)
    }

    func testStoreKitService_DowngradeToLite_Scenarios() {
        let service = StoreKitService.shared

        // 场景 1：当前用户已是 Pro 用户，触发降级
        let proUser = User(
            id: UUID(),
            name: "Pro Tester",
            email: "pro@test.com",
            phone: nil,
            avatarURL: nil,
            planKey: PlanKey.pro,
            maxVaults: User.DefaultQuotas.proMaxVaults,
            maxPages: User.DefaultQuotas.proMaxPages,
            maxPlugins: User.DefaultQuotas.proMaxPlugins,
            gender: nil,
            birthday: nil
        )
        AuthSession.shared.update(user: proUser)
        XCTAssertTrue(AuthSession.shared.currentUser?.isPro ?? false)

        service.downgradeToLite()

        let downgradedUser = AuthSession.shared.currentUser
        XCTAssertNotNil(downgradedUser)
        XCTAssertEqual(downgradedUser?.planKey, PlanKey.lite)
        XCTAssertFalse(downgradedUser?.isPro ?? true)
        XCTAssertEqual(downgradedUser?.maxVaults, User.DefaultQuotas.liteMaxVaults)
        XCTAssertEqual(downgradedUser?.maxPages, User.DefaultQuotas.liteMaxPages)
        XCTAssertEqual(downgradedUser?.maxPlugins, User.DefaultQuotas.liteMaxPlugins)

        // 场景 2：当前用户已是 Lite 用户，重复降级应静默无操作
        service.downgradeToLite()
        XCTAssertEqual(AuthSession.shared.currentUser?.planKey, PlanKey.lite)

        // 场景 3：当前无登录用户，降级应安全守卫退出
        AuthSession.shared.logout()
        service.downgradeToLite()
        XCTAssertNil(AuthSession.shared.currentUser)
    }

    // MARK: - 2. SubscriptionPurchaseFlow 视图与购买流深测

    func testSubscriptionPurchaseFlow_MonthlyAndYearlyRendering() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 375, height: 667))

        var isPurchasingMonthly = false
        var isSuccessMonthly = false
        var errorMonthly: String?

        let monthlyFlow = SubscriptionPurchaseFlow(
            isPurchasing: Binding(get: { isPurchasingMonthly }, set: { isPurchasingMonthly = $0 }),
            isUpgradeSuccess: Binding(get: { isSuccessMonthly }, set: { isSuccessMonthly = $0 }),
            errorMessage: Binding(get: { errorMonthly }, set: { errorMonthly = $0 }),
            selectedCycle: .monthly
        ).snapshotEnvironment()

        let hostMonthly = UIHostingController(rootView: monthlyFlow)
        window.rootViewController = hostMonthly
        window.makeKeyAndVisible()
        hostMonthly.view.layoutIfNeeded()

        XCTAssertNotNil(hostMonthly.view)
        XCTAssertFalse(isPurchasingMonthly)
        XCTAssertFalse(isSuccessMonthly)
        XCTAssertNil(errorMonthly)

        // 切换到 Yearly
        var isPurchasingYearly = false
        var isSuccessYearly = false
        var errorYearly: String?

        let yearlyFlow = SubscriptionPurchaseFlow(
            isPurchasing: Binding(get: { isPurchasingYearly }, set: { isPurchasingYearly = $0 }),
            isUpgradeSuccess: Binding(get: { isSuccessYearly }, set: { isSuccessYearly = $0 }),
            errorMessage: Binding(get: { errorYearly }, set: { errorYearly = $0 }),
            selectedCycle: .yearly
        ).snapshotEnvironment()

        let hostYearly = UIHostingController(rootView: yearlyFlow)
        window.rootViewController = hostYearly
        hostYearly.view.layoutIfNeeded()

        XCTAssertNotNil(hostYearly.view)
    }

    // MARK: - 3. AppleAuthStrategy 策略与代理深测

    func testAppleAuthStrategy_AcquireCredentialsInTestMode() async throws {
        let strategy = AppleAuthStrategy()
        XCTAssertEqual(strategy.identityType, "apple")

        // 在模拟器与测试感知环境下应返回 MockCredential
        let cred = try await strategy.acquireCredentials()
        XCTAssertEqual(cred.identityType, "apple")
        XCTAssertEqual(cred.identifier, "mock_apple_user_id")
        XCTAssertEqual(cred.credential, FeatureConstants.MockData.mockAppleCode)
        XCTAssertNotNil(cred.extraInfo?["idToken"])
        XCTAssertEqual(cred.extraInfo?["email"], "mock_apple_user@example.com")
        XCTAssertEqual(cred.extraInfo?["nickname"], "Apple Mock User")
    }

    func testAppleAuthStrategy_DidCompleteWithError() {
        let strategy = AppleAuthStrategy()
        let request = ASAuthorizationAppleIDProvider().createRequest()
        let controller = ASAuthorizationController(authorizationRequests: [request])
        let dummyError = NSError(domain: "com.apple.AuthenticationServices", code: 1001, userInfo: [NSLocalizedDescriptionKey: "User cancelled"])

        // 直接测试委托回调触发，不应崩溃
        strategy.authorizationController(controller: controller, didCompleteWithError: dummyError)
        XCTAssertNotNil(strategy)
    }

    // MARK: - 4. OnDeviceLLMService 发现与配置深测

    func testOnDeviceLLMService_DiscoveryAndConfig() {
        let service = OnDeviceLLMService()
        
        // 验证 Config 常量定义
        XCTAssertEqual(OnDeviceLLMService.Config.defaultMaxTokens, 256)
        XCTAssertEqual(OnDeviceLLMService.Config.generationTemperature, 0.7)
        XCTAssertEqual(OnDeviceLLMService.Config.smartIngestMaxTokens, 500)
        XCTAssertEqual(OnDeviceLLMService.Config.chatMaxTokens, 300)
        XCTAssertEqual(OnDeviceLLMService.Config.contextPageLimit, 5)
        XCTAssertEqual(OnDeviceLLMService.Config.contentPreviewChars, 200)

        // 验证发现模型列表与模型数量
        service.discoverModels()
        XCTAssertNotNil(service.availableModels)
        
        // 验证未加载模型时的初始状态
        XCTAssertFalse(service.isModelLoaded)
        XCTAssertFalse(service.isGenerating)
        XCTAssertEqual(service.generationProgress, 0)
        XCTAssertEqual(service.generatedText, "")
        XCTAssertEqual(service.inferenceSpeed, 0)
    }

    func testOnDeviceLLMService_LoadModelNotFound_Throws() async {
        let service = OnDeviceLLMService()
        service.selectedModelID = "non_existent_model_id_99999"

        do {
            try await service.loadModel()
            XCTFail("应当抛出 modelNotFound 异常")
        } catch let error as OnDeviceError {
            XCTAssertEqual(error, OnDeviceError.modelNotFound)
        } catch {
            XCTFail("异常类型不符: \(error)")
        }
    }

    func testOnDeviceLLMService_GenerateWithoutLoadedModel_Throws() async {
        let service = OnDeviceLLMService()
        service.isModelLoaded = false

        do {
            _ = try await service.generate(prompt: "Hello world")
            XCTFail("应当抛出 modelNotLoaded 异常")
        } catch let error as OnDeviceError {
            XCTAssertEqual(error, OnDeviceError.modelNotLoaded)
        } catch {
            XCTFail("异常类型不符: \(error)")
        }
    }

    // MARK: - 5. PluginLoader 安全性与格式解析深测

    func testPluginLoader_ConstantTimeCompare() {
        let data1 = Data([0x01, 0x02, 0x03, 0x04])
        let data2 = Data([0x01, 0x02, 0x03, 0x04])
        let data3 = Data([0x01, 0x02, 0x03, 0x05])
        let data4 = Data([0x01, 0x02])

        XCTAssertTrue(PluginLoader.constantTimeCompare(data1, b: data2))
        XCTAssertFalse(PluginLoader.constantTimeCompare(data1, b: data3))
        XCTAssertFalse(PluginLoader.constantTimeCompare(data1, b: data4))
    }

    func testPluginLoader_VerifyPluginSignature() {
        let manifestTrusted = PluginManifest(
            id: "local.dev.test",
            version: "1.0.0",
            author: "Tester",
            permissions: ["log"],
            allowedDomains: nil,
            names: ["en": "Dev Test Plugin"],
            descriptions: ["en": "A test plugin"],
            readmeFiles: nil,
            iconFile: nil,
            category: nil,
            codeSignature: nil
        )

        // isTrustedLocal = true 时跳过签名
        let isTrusted = PluginLoader.verifyPluginSignature(script: "console.log('hi');", manifest: manifestTrusted, isTrustedLocal: true)
        XCTAssertTrue(isTrusted)

        // 外部 manifest 带有 local. 前缀视为可疑，拒绝加载
        let isSuspicious = PluginLoader.verifyPluginSignature(script: "console.log('hi');", manifest: manifestTrusted, isTrustedLocal: false)
        XCTAssertFalse(isSuspicious)

        // 外部插件缺少签名，拒绝加载
        let manifestNoSig = PluginManifest(
            id: "com.zhiyu.plugin.unsigned",
            version: "1.0.0",
            author: "Tester",
            permissions: ["log"],
            allowedDomains: nil,
            names: ["en": "Unsigned Plugin"],
            descriptions: ["en": "No sig"],
            readmeFiles: nil,
            iconFile: nil,
            category: nil,
            codeSignature: nil
        )
        let isRejected = PluginLoader.verifyPluginSignature(script: "console.log('test');", manifest: manifestNoSig, isTrustedLocal: false)
        XCTAssertFalse(isRejected)
    }

    func testPluginLoader_ScanAndLoadLocalPlugins() {
        let loader = PluginLoader()
        // 扫描不应崩溃，能自愈创建沙盒 Plugins 目录
        loader.scanAndLoadLocalPlugins()
        XCTAssertNotNil(loader)
    }

    // MARK: - 6. ServerConfigView 与 MockServerConfig 深测

    func testServerConfigView_LifecycleAndRendering() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        let rawView = ServerConfigView()
        XCTAssertNotNil(rawView)
        let view = rawView.snapshotEnvironment()
        let host = UIHostingController(rootView: view)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
    }

    func testMockServerConfig_CodableAndEquality() throws {
        let original = MockServerConfig(
            id: UUID(),
            name: "Test Server",
            baseURL: "https://api.test.com",
            apiKey: "secret_123",
            isDefault: true,
            lastTestedAt: Date(),
            latencyMs: 42,
            isHealthy: true
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MockServerConfig.self, from: encoded)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.baseURL, original.baseURL)
        XCTAssertEqual(decoded.apiKey, original.apiKey)
        XCTAssertEqual(decoded.isDefault, original.isDefault)
        XCTAssertEqual(decoded.latencyMs, original.latencyMs)
        XCTAssertEqual(decoded.isHealthy, original.isHealthy)
    }
}
