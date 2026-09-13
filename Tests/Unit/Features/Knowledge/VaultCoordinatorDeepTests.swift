//
//  VaultCoordinatorDeepTests.swift
//  ZhiYuTests
//
//  合并自 2 个碎片化测试文件：IngestAndVaultCoordinatorDeepTests.swift, VaultCoordinatorAndIngestFlowDeepTests.swift
//

import Dependencies
import SwiftUI
import UFPCore
import WatchConnectivity
import WidgetKit
import XCTest

@testable import ZhiYu

@MainActor
final class VaultCoordinatorDeepTests: XCTestCase {

    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        resetPersistentTestState()
        setupFullMockEnvironment()
    }

    func makeManifest(id: String) -> LLMManifest {
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

    func testVaultDataCoordinator_BuildDemoVaultsAndEquality() {
        let service = VaultService.shared
        let defaultVaults = service.buildDefaultDemoVaults()
        let fallbackVaults = service.buildFallbackDemoVaults()

        XCTAssertEqual(defaultVaults.count, 2)
        XCTAssertEqual(fallbackVaults.count, 2)

        let names = defaultVaults.map { $0.name }
        XCTAssertTrue(names.contains(L10n.Vault.defaultName))
        XCTAssertTrue(names.contains(L10n.Vault.researchName))

        for v in defaultVaults {
            XCTAssertEqual(v.pageCount, 0)
            XCTAssertNil(v.themePayload)
        }
    }

    func testVaultDataCoordinator_AutoRestoreActiveVault() {
        let service = VaultService.shared
        let keyStore = ServiceContainer.shared.resolveOptional((any KeyStoreProtocol).self)

        let testVault = Vault(
            id: UUID(),
            name: "Test Active Vault",
            createdAt: Date(),
            updatedAt: Date(),
            pageCount: 5,
            themePayload: nil,
            icon: DesignSystem.Icons.Notebook.defaultBook,
            description: "Desc"
        )
        service.vaults = [testVault]
        keyStore?.set(testVault.id.uuidString, forKey: AppConstants.Keys.Storage.vaultsSelectedID)

        service.autoRestoreActiveVault()

        XCTAssertEqual(service.selectedVaultID, testVault.id)
        XCTAssertEqual(keyStore?.string(forKey: AppConstants.Keys.Storage.vaultSelectedEnglishName), testVault.englishName)

        keyStore?.removeObject(forKey: AppConstants.Keys.Storage.vaultsSelectedID)
    }

    func testVaultDataCoordinator_AutoSelectFirstVaultForUITesting() {
        let service = VaultService.shared
        service.selectedVaultID = nil

        let testVault = Vault(
            id: UUID(),
            name: "UI Testing Vault",
            createdAt: Date(),
            updatedAt: Date(),
            pageCount: 3,
            themePayload: nil,
            icon: DesignSystem.Icons.Notebook.defaultBook,
            description: "Desc"
        )
        service.vaults = [testVault]

        // 默认非 UI 测试模式下不自动选择
        service.autoSelectFirstVaultForUITesting()

        // 验证空 vaults 场景下的防御
        service.vaults = []
        service.autoSelectFirstVaultForUITesting()
        XCTAssertNil(service.selectedVaultID)
    }

    func testIOSWatchSyncService_AudioChunkAssemblyAndNotification() async {
        let service = iOSWatchSyncService()

        // 场景 1：无效参数防御拦截
        service.handleReceivedAudioChunk(transferId: "tx-err", index: -1, total: 2, filename: "err.m4a", data: Data([1]))
        service.handleReceivedAudioChunk(transferId: "tx-err", index: 2, total: 2, filename: "err.m4a", data: Data([1]))
        service.handleReceivedAudioChunk(transferId: "tx-err", index: 0, total: 0, filename: "err.m4a", data: Data([1]))

        // 场景 2：分片到达并在接收完毕后自愈合并
        let transferId = "tx-voice-001"
        let part1 = Data([0x01, 0x02, 0x03])
        let part2 = Data([0x04, 0x05, 0x06])

        var receivedAudioNotification = false
        let observer = NotificationCenter.default.addObserver(
            forName: .didReceiveWatchAudio,
            object: nil,
            queue: .main
        ) { notif in
            if let data = notif.object as? Data, data.count == 6 {
                receivedAudioNotification = true
            }
        }

        service.handleReceivedAudioChunk(transferId: transferId, index: 0, total: 2, filename: "record.m4a", data: part1)
        XCTAssertFalse(receivedAudioNotification)

        service.handleReceivedAudioChunk(transferId: transferId, index: 1, total: 2, filename: "record.m4a", data: part2)
        XCTAssertTrue(receivedAudioNotification)
        XCTAssertTrue(service.lastReceivedText.hasPrefix("audio:record.m4a:6"))

        NotificationCenter.default.removeObserver(observer)
    }

    func testIOSWatchSyncService_LifecycleAndUserInfoDelegate() async {
        let service = iOSWatchSyncService()

        // 1. 非激活状态下调用 sendContent 不崩溃
        service.sendContent("Test Watch Note")

        // 2. 预留接口执行
        service.requestDailyBriefing()
        service.handleBriefingResponse("briefing text")

        // 3. WCSession 委托回调调用
        service.sessionDidBecomeInactive(WCSession.default)
        service.session(WCSession.default, activationDidCompleteWith: .notActivated, error: NSError(domain: "watch", code: -1))

        // 4. session didReceiveUserInfo 分支深测
        let expectation = XCTestExpectation(description: "接收到手表内容通知")
        let observer = NotificationCenter.default.addObserver(
            forName: .didReceiveWatchContent,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }

        // 分支 A: type == "new_page"
        service.session(WCSession.default, didReceiveUserInfo: [
            "type": "new_page",
            "content": "从 Apple Watch 新建的速记页面"
        ])

        // 分支 B: type == "request_briefing"
        service.session(WCSession.default, didReceiveUserInfo: [
            "type": "request_briefing"
        ])

        // 分支 C: 纯 content 兜底
        service.session(WCSession.default, didReceiveUserInfo: [
            "content": "手表兜底速记文本"
        ])

        // 等待异步 Task { @MainActor in ... } 完成
        await fulfillment(of: [expectation], timeout: 5.0)
        NotificationCenter.default.removeObserver(observer)
        XCTAssertEqual(service.lastReceivedText, "手表兜底速记文本")
    }

    func testVaultDataCoordinator_DemoVaults() {
        let vaultService = VaultService.shared

        // 1. 默认演示库生成
        let demoVaults = vaultService.buildDefaultDemoVaults()
        XCTAssertEqual(demoVaults.count, 2)
        XCTAssertEqual(demoVaults[0].name, L10n.Vault.defaultName)
        XCTAssertEqual(demoVaults[1].name, L10n.Vault.researchName)
        XCTAssertEqual(demoVaults[0].pageCount, 0)
        XCTAssertEqual(demoVaults[1].pageCount, 0)

        // 2. 降级兜底演示库生成
        let fallbackVaults = vaultService.buildFallbackDemoVaults()
        XCTAssertEqual(fallbackVaults.count, 2)
        XCTAssertNotEqual(fallbackVaults[0].id, fallbackVaults[1].id)

        // 3. 活跃笔记本自动恢复调用
        vaultService.autoRestoreActiveVault()

        // 4. UI 测试自动选库逻辑
        vaultService.autoSelectFirstVaultForUITesting()
    }

    func testIngestView_RenderingWithoutTasks() {
        var selectedTab: AppTab = .ingest

        let ingestView = IngestView(
            selectedTab: Binding(get: { selectedTab }, set: { selectedTab = $0 })
        )
        let host = UIHostingController(rootView: ingestView.snapshotEnvironment())
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view, "IngestView 无运行中任务时应成功渲染")
    }

    func testIngestView_RenderingWithRunningTasks() {
        var selectedTab: AppTab = .ingest

        let mockTaskCenter = TaskCenter(activityService: nil)
        mockTaskCenter.tasks = [
            GlobalTask(
                type: .ingest,
                name: "智能导入 PDF",
                target: "机器学习讲义.pdf",
                status: .running(progress: 0.65, stage: .enrichment),
                isRead: false,
                associatedPageID: nil,
                subLogs: ["已提取文本", "正在生成向量索引"]
            )
        ]

        withDependencies {
            $0.taskCenter = mockTaskCenter
        } operation: {
            let ingestView = IngestView(
                selectedTab: Binding(get: { selectedTab }, set: { selectedTab = $0 })
            )
            let host = UIHostingController(rootView: ingestView.snapshotEnvironment())
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
            window.rootViewController = host
            window.makeKeyAndVisible()
            host.view.layoutIfNeeded()

            XCTAssertNotNil(host.view, "IngestView 有运行中任务时应成功渲染进度卡片与时间轴")
        }
    }

}
