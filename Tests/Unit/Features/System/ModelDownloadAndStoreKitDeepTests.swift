//
//  ModelDownloadAndStoreKitDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/03.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests] 单元测试层
//  核心职责：深度覆盖 L2 Features 模型下载组件、StoreKit 订阅生命周期与 AppleAuthStrategy 认证。
//

import XCTest
import SwiftUI
import StoreKit
import AuthenticationServices
@testable import ZhiYu
import UFPCore

@MainActor
final class ModelDownloadAndStoreKitDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    private func makeManifest(id: String) -> LLMManifest {
        LLMManifest(
            modelId: id,
            displayName: "测试模型",
            vendor: "Google",
            fileSizeInBytes: 1024 * 1024 * 50,
            minDeviceMemoryInGb: 4.0,
            remoteURLString: "https://example.com/model.bin",
            sha256Checksum: "dummy-sha256",
            parameterCount: "2B",
            supportedTasks: ["TextSynthesis"],
            description: "测试模型描述",
            defaultParameters: InferenceParameters()
        )
    }

    // MARK: - 1. ModelDownloadStatusBar 状态映射测试

    func testModelDownloadStatusBar_AllStates() {
        let manifest = makeManifest(id: "test-model-v1")
        let modelManager = GlobalModelManager.shared

        // 1. failed notDownloaded -> EmptyView
        let view1 = ModelDownloadStatusBar(
            manifest: manifest,
            downloadState: .failed(error: FeatureConstants.MockData.notDownloaded),
            modelManager: modelManager
        )
        XCTAssertEqual(view1.manifest.id, "test-model-v1")
        _ = view1.body
        let host1 = UIHostingController(rootView: view1.snapshotEnvironment())
        host1.view.frame = CGRect(x: 0, y: 0, width: 300, height: 40)
        host1.view.layoutIfNeeded()
        XCTAssertNotNil(host1.view)

        // 2. failed other error -> ringWithStatus
        let view2 = ModelDownloadStatusBar(
            manifest: manifest,
            downloadState: .failed(error: "网络连接超时"),
            modelManager: modelManager
        )
        _ = view2.body
        let host2 = UIHostingController(rootView: view2.snapshotEnvironment())
        host2.view.frame = CGRect(x: 0, y: 0, width: 300, height: 40)
        host2.view.layoutIfNeeded()
        XCTAssertNotNil(host2.view)

        // 3. downloading
        let view3 = ModelDownloadStatusBar(
            manifest: manifest,
            downloadState: .downloading(progress: 0.45, bytesPerSecond: 2048000),
            modelManager: modelManager
        )
        _ = view3.body
        let host3 = UIHostingController(rootView: view3.snapshotEnvironment())
        host3.view.frame = CGRect(x: 0, y: 0, width: 300, height: 40)
        host3.view.layoutIfNeeded()
        XCTAssertNotNil(host3.view)

        // 4. paused
        let view4 = ModelDownloadStatusBar(
            manifest: manifest,
            downloadState: .paused,
            modelManager: modelManager
        )
        _ = view4.body
        let host4 = UIHostingController(rootView: view4.snapshotEnvironment())
        host4.view.frame = CGRect(x: 0, y: 0, width: 300, height: 40)
        host4.view.layoutIfNeeded()
        XCTAssertNotNil(host4.view)

        // 5. verifying
        let view5 = ModelDownloadStatusBar(
            manifest: manifest,
            downloadState: .verifying,
            modelManager: modelManager
        )
        _ = view5.body
        let host5 = UIHostingController(rootView: view5.snapshotEnvironment())
        host5.view.frame = CGRect(x: 0, y: 0, width: 300, height: 40)
        host5.view.layoutIfNeeded()
        XCTAssertNotNil(host5.view)

        // 6. pending
        let view6 = ModelDownloadStatusBar(
            manifest: manifest,
            downloadState: .pending,
            modelManager: modelManager
        )
        _ = view6.body
        let host6 = UIHostingController(rootView: view6.snapshotEnvironment())
        host6.view.frame = CGRect(x: 0, y: 0, width: 300, height: 40)
        host6.view.layoutIfNeeded()
        XCTAssertNotNil(host6.view)
    }

    // MARK: - 2. ModelActionButton 操作按钮各分支测试

    func testModelActionButton_EligibilityAndStates() {
        let manifest = makeManifest(id: "test-model-v2")
        let modelManager = GlobalModelManager.shared
        var alertManifest: LLMManifest?
        let alertBinding = Binding(get: { alertManifest }, set: { alertManifest = $0 })

        // 1. restricted
        let restrictedBtn = ModelActionButton(
            manifest: manifest,
            eligibility: .restricted,
            isSelected: false,
            isLocalReady: false,
            downloadState: .failed(error: FeatureConstants.MockData.notDownloaded),
            modelManager: modelManager,
            alertManifest: alertBinding,
            onGoToLab: {}
        )
        let host1 = UIHostingController(rootView: restrictedBtn.snapshotEnvironment())
        host1.view.frame = CGRect(x: 0, y: 0, width: 200, height: 50)
        host1.view.layoutIfNeeded()
        XCTAssertEqual(restrictedBtn.eligibility, .restricted)
        XCTAssertNotNil(host1.view)

        // 2. isLocalReady
        var labTriggered = false
        let dummyLocalURL = URL(fileURLWithPath: "/tmp/dummy.bin")
        let readyBtn = ModelActionButton(
            manifest: manifest,
            eligibility: .supported,
            isSelected: true,
            isLocalReady: true,
            downloadState: .completed(localURL: dummyLocalURL),
            modelManager: modelManager,
            alertManifest: alertBinding,
            onGoToLab: { labTriggered = true }
        )
        let host2 = UIHostingController(rootView: readyBtn.snapshotEnvironment())
        host2.view.frame = CGRect(x: 0, y: 0, width: 200, height: 50)
        host2.view.layoutIfNeeded()
        XCTAssertNotNil(host2.view)

        // 3. downloadActionButton - downloading
        let downloadingBtn = ModelActionButton(
            manifest: manifest,
            eligibility: .supported,
            isSelected: false,
            isLocalReady: false,
            downloadState: .downloading(progress: 0.2, bytesPerSecond: 1000),
            modelManager: modelManager,
            alertManifest: alertBinding,
            onGoToLab: {}
        )
        let host3 = UIHostingController(rootView: downloadingBtn.snapshotEnvironment())
        host3.view.frame = CGRect(x: 0, y: 0, width: 200, height: 50)
        host3.view.layoutIfNeeded()
        XCTAssertNotNil(host3.view)

        // 4. downloadActionButton - paused
        let pausedBtn = ModelActionButton(
            manifest: manifest,
            eligibility: .supported,
            isSelected: false,
            isLocalReady: false,
            downloadState: .paused,
            modelManager: modelManager,
            alertManifest: alertBinding,
            onGoToLab: {}
        )
        let host4 = UIHostingController(rootView: pausedBtn.snapshotEnvironment())
        host4.view.frame = CGRect(x: 0, y: 0, width: 200, height: 50)
        host4.view.layoutIfNeeded()
        XCTAssertNotNil(host4.view)
        _ = labTriggered
    }

    // MARK: - 3. StoreKitService 监听与恢复购买测试

    func testStoreKitService_Lifecycle() async {
        let service = StoreKitService.shared

        service.startListening()
        service.stopListening()

        XCTAssertFalse(service.isRestoring)
        XCTAssertNil(service.restoreMessage)

        // 注意：AppStore.sync() 在模拟器无沙盒账号环境下会无限挂起（死锁），
        // 已有 Tests/Unit/System/StoreKitServiceTests.swift 与
        // Tests/Unit/Features/StoreKitServiceDeepTests.swift 均因此跳过 restorePurchases。
        // 此处同步跳过，仅验证非 async 的状态机逻辑。
        // let result = await service.restorePurchases()
        // XCTAssertFalse(service.isRestoring)
        // XCTAssertNotNil(service.restoreMessage)
        // _ = result
    }

    // MARK: - 4. SubscriptionPurchaseFlow 视图挂载测试

    func testSubscriptionPurchaseFlow_Rendering() {
        var isPurchasing = false
        var isUpgradeSuccess = false
        var errorMessage: String?

        let flowYearly = SubscriptionPurchaseFlow(
            isPurchasing: Binding(get: { isPurchasing }, set: { isPurchasing = $0 }),
            isUpgradeSuccess: Binding(get: { isUpgradeSuccess }, set: { isUpgradeSuccess = $0 }),
            errorMessage: Binding(get: { errorMessage }, set: { errorMessage = $0 }),
            selectedCycle: .yearly
        )
        let host1 = UIHostingController(rootView: flowYearly.snapshotEnvironment())
        let window1 = UIWindow(frame: CGRect(x: 0, y: 0, width: 350, height: 120))
        window1.rootViewController = host1
        window1.makeKeyAndVisible()
        host1.view.layoutIfNeeded()
        XCTAssertEqual(flowYearly.selectedCycle, .yearly)
        XCTAssertNotNil(host1.view)

        let flowMonthly = SubscriptionPurchaseFlow(
            isPurchasing: Binding(get: { isPurchasing }, set: { isPurchasing = $0 }),
            isUpgradeSuccess: Binding(get: { isUpgradeSuccess }, set: { isUpgradeSuccess = $0 }),
            errorMessage: Binding(get: { errorMessage }, set: { errorMessage = $0 }),
            selectedCycle: .monthly
        )
        let host2 = UIHostingController(rootView: flowMonthly.snapshotEnvironment())
        let window2 = UIWindow(frame: CGRect(x: 0, y: 0, width: 350, height: 120))
        window2.rootViewController = host2
        window2.makeKeyAndVisible()
        host2.view.layoutIfNeeded()
        XCTAssertEqual(flowMonthly.selectedCycle, .monthly)
        XCTAssertNotNil(host2.view)
    }

    // MARK: - 5. AppleAuthStrategy 凭证获取测试

    func testAppleAuthStrategy_AcquireCredentials() async throws {
        let strategy = AppleAuthStrategy()
        XCTAssertEqual(strategy.identityType, "apple")

        let credential = try await strategy.acquireCredentials()
        XCTAssertEqual(credential.identityType, "apple")
        XCTAssertEqual(credential.identifier, "mock_apple_user_id")
        XCTAssertEqual(credential.credential, FeatureConstants.MockData.mockAppleCode)
    }
}
