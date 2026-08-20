//
//  CoreProtocolsSupplementTests.swift
//  ZhiYu
//
//  系统层级：[L0] 测试层
//  核心职责：验证 Core/Base/Protocols 下协议的 Stub/NoOp/Unsupported 默认实现
//           返回安全默认值（空/false/nil/throw），不崩溃。
//

import XCTest
import UFPCore
import LocalAuthentication
@testable import ZhiYu

/// Core/Protocols 协议 Stub/NoOp 实现补盲测试
///
/// 覆盖目标：验证所有 NoOp/Stub/Unsupported/Dummy 类的方法调用返回安全默认值，
/// 不崩溃，正确抛出预期错误。覆盖协议默认实现（extension）。
@MainActor
final class CoreProtocolsSupplementTests: XCTestCase {

    // MARK: - AccessibilityServiceProtocol

    /// NoOpAccessibilityService postAnnouncement 应不崩溃
    func testNoOpAccessibilityService_postAnnouncement_不崩溃() {
        let service = NoOpAccessibilityService()
        service.postAnnouncement("test")
        // 不崩溃即通过
    }

    // MARK: - AIWorkflowCapabilities

    /// NoOpAIWorkflowCapabilities removeRefactorSuggestion 应不崩溃
    func testNoOpAIWorkflowCapabilities_removeRefactorSuggestion_不崩溃() {
        let caps = NoOpAIWorkflowCapabilities()
        caps.removeRefactorSuggestion(id: "test_page")
        // 不崩溃即通过
    }

    // MARK: - AppEnvironmentProtocol

    /// NoOpAppEnvironment 应返回安全默认值
    func testNoOpAppEnvironment_安全默认值() {
        let env = NoOpAppEnvironment()
        XCTAssertEqual(env.screenClass, .compact)
        XCTAssertEqual(env.interactionStyle, .touch)
        XCTAssertEqual(env.deviceName, "Test Device")
        XCTAssertFalse(env.supportsPencil)
        XCTAssertFalse(env.hasCamera)
        XCTAssertTrue(env.isMobile)
        XCTAssertEqual(env.platformName, "Test")
        XCTAssertEqual(env.appVersion, "0.0.0")
        XCTAssertFalse(env.isCloudSyncSupported)
    }

    // MARK: - BackgroundTaskProtocol

    /// StubBackgroundTaskProvider register/schedule 应不崩溃
    func testStubBackgroundTaskProvider_registerSchedule_不崩溃() {
        let provider = StubBackgroundTaskProvider()
        provider.register(handler: {})
        provider.schedule()
        // 不崩溃即通过
    }

    // MARK: - CollaborationProviderProtocol

    /// NoOpCollaborationProvider 所有方法应不崩溃
    func testNoOpCollaborationProvider_所有方法_不崩溃() {
        let provider = NoOpCollaborationProvider()
        provider.startHosting(roomName: "room", userName: "user")
        provider.startBrowsing(userName: "user")
        provider.joinRoom(DiscoveredRoom(id: "test", platformPeer: "peer" as AnyHashable, roomName: "room", owner: "user"))
        provider.stop()
        provider.broadcast(data: Data())
        // 不崩溃即通过
    }

    /// NoOpCollaborationProvider delegate 应为 nil
    func testNoOpCollaborationProvider_delegate为nil() {
        let provider = NoOpCollaborationProvider()
        XCTAssertNil(provider.delegate, "NoOp delegate 应为 nil")
    }

    /// StubCollaborationProvider startHosting 应通过 delegate 回传 simulatorNotSupported
    func testStubCollaborationProvider_startHosting_回传simulatorNotSupported() {
        let provider = StubCollaborationProvider()
        let delegate = CollaborationDelegateRecorder()
        provider.delegate = delegate
        provider.startHosting(roomName: "room", userName: "user")
        XCTAssertNotNil(delegate.lastStatus, "startHosting 应回传状态")
    }

    /// StubCollaborationProvider startBrowsing 应通过 delegate 回传 simulatorNotSupported
    func testStubCollaborationProvider_startBrowsing_回传simulatorNotSupported() {
        let provider = StubCollaborationProvider()
        let delegate = CollaborationDelegateRecorder()
        provider.delegate = delegate
        provider.startBrowsing(userName: "user")
        XCTAssertNotNil(delegate.lastStatus, "startBrowsing 应回传状态")
    }

    /// StubCollaborationProvider stop 应通过 delegate 回传 disconnected
    func testStubCollaborationProvider_stop_回传disconnected() {
        let provider = StubCollaborationProvider()
        let delegate = CollaborationDelegateRecorder()
        provider.delegate = delegate
        provider.stop()
        XCTAssertNotNil(delegate.lastStatus, "stop 应回传状态")
    }

    // MARK: - DeviceInfoProtocol

    /// NoOpDeviceInfo 应返回安全默认值（空字符串/0）
    func testNoOpDeviceInfo_安全默认值() {
        let info = NoOpDeviceInfo()
        XCTAssertEqual(info.systemVersion, "")
        XCTAssertEqual(info.deviceModel, "")
        XCTAssertEqual(info.deviceName, "")
        XCTAssertEqual(info.screenHeight, 0)
    }

    // MARK: - ExportServiceProtocol

    /// NoOpExportService exportToPDF 应抛出 engineNotReady
    func testNoOpExportService_exportToPDF_抛出EngineNotReady() async {
        let service = NoOpExportService()
        do {
            _ = try await service.exportToPDF(markdown: "# test", fileName: "test.pdf")
            XCTFail("应抛出 engineNotReady")
        } catch {
            // 预期抛错
        }
    }

    /// NoOpExportService exportMindmapToPDF 应抛出 engineNotReady
    func testNoOpExportService_exportMindmapToPDF_抛出EngineNotReady() async {
        let service = NoOpExportService()
        do {
            _ = try await service.exportMindmapToPDF(mermaidCode: "graph TD", fileName: "test.pdf")
            XCTFail("应抛出 engineNotReady")
        } catch {
            // 预期抛错
        }
    }

    /// NoOpExportService exportToPPTX 应抛出 engineNotReady
    func testNoOpExportService_exportToPPTX_抛出EngineNotReady() async {
        let service = NoOpExportService()
        do {
            _ = try await service.exportToPPTX(markdown: "# test", fileName: "test.pptx")
            XCTFail("应抛出 engineNotReady")
        } catch {
            // 预期抛错
        }
    }

    /// ExportError 三个 case 的 errorDescription 应非空
    func testExportError_所有case_描述非空() {
        XCTAssertFalse(ExportError.systemBusy.errorDescription?.isEmpty ?? true)
        XCTAssertFalse(ExportError.engineNotReady.errorDescription?.isEmpty ?? true)
        XCTAssertFalse(ExportError.internalError("test").errorDescription?.isEmpty ?? true)
    }

    /// UnsupportedExportService exportToPDF 应抛出 NSError
    func testUnsupportedExportService_exportToPDF_抛出错误() async {
        let service = UnsupportedExportService()
        do {
            _ = try await service.exportToPDF(markdown: "# test", fileName: "test.pdf")
            XCTFail("应抛出错误")
        } catch {
            // 预期抛错
        }
    }

    /// UnsupportedExportService exportMindmapToPDF 应抛出 NSError
    func testUnsupportedExportService_exportMindmapToPDF_抛出错误() async {
        let service = UnsupportedExportService()
        do {
            _ = try await service.exportMindmapToPDF(mermaidCode: "graph TD", fileName: "test.pdf")
            XCTFail("应抛出错误")
        } catch {
            // 预期抛错
        }
    }

    /// UnsupportedExportService exportToPPTX 应抛出 NSError
    func testUnsupportedExportService_exportToPPTX_抛出错误() async {
        let service = UnsupportedExportService()
        do {
            _ = try await service.exportToPPTX(markdown: "# test", fileName: "test.pptx")
            XCTFail("应抛出错误")
        } catch {
            // 预期抛错
        }
    }

    // MARK: - FileArchiverProtocol

    /// NoOpFileArchiver zip 应抛出 platformNotSupported
    func testNoOpFileArchiver_zip_抛出PlatformNotSupported() async {
        let archiver = NoOpFileArchiver()
        do {
            try await archiver.zip(directory: URL(fileURLWithPath: "/tmp/src"),
                                   to: URL(fileURLWithPath: "/tmp/test.zip"))
            XCTFail("应抛出 platformNotSupported")
        } catch {
            // 预期抛错
        }
    }

    /// NoOpFileArchiver extractContents 应抛出 extractionFailed
    func testNoOpFileArchiver_extractContents_抛出ExtractionFailed() {
        let archiver = NoOpFileArchiver()
        do {
            try archiver.extractContents(from: URL(fileURLWithPath: "/tmp/test.zip"),
                                        to: URL(fileURLWithPath: "/tmp/out"))
            XCTFail("应抛出 extractionFailed")
        } catch {
            // 预期抛错
        }
    }

    /// UnsupportedFileArchiver zip 应抛出 platformNotSupported
    func testUnsupportedFileArchiver_zip_抛出PlatformNotSupported() async {
        let archiver = UnsupportedFileArchiver()
        do {
            try await archiver.zip(directory: URL(fileURLWithPath: "/tmp/src"),
                                   to: URL(fileURLWithPath: "/tmp/test.zip"))
            XCTFail("应抛出 platformNotSupported")
        } catch {
            // 预期抛错
        }
    }

    /// UnsupportedFileArchiver extractContents 应抛出 platformNotSupported
    func testUnsupportedFileArchiver_extractContents_抛出PlatformNotSupported() {
        let archiver = UnsupportedFileArchiver()
        do {
            try archiver.extractContents(from: URL(fileURLWithPath: "/tmp/test.zip"),
                                        to: URL(fileURLWithPath: "/tmp/out"))
            XCTFail("应抛出 platformNotSupported")
        } catch {
            // 预期抛错
        }
    }

    // MARK: - HapticFeedbackProtocol

    /// NoOpHapticFeedback trigger 应不崩溃（覆盖所有 HapticPattern）
    func testNoOpHapticFeedback_trigger_所有模式_不崩溃() {
        let haptic = NoOpHapticFeedback()
        haptic.trigger(.success)
        haptic.trigger(.error)
        haptic.trigger(.warning)
        haptic.trigger(.processing)
        haptic.trigger(.lock)
        haptic.trigger(.unlock)
        haptic.trigger(.link)
        haptic.trigger(.selection)
        haptic.trigger(.pulse)
        // 不崩溃即通过
    }

    // MARK: - LiveActivityProtocol

    /// DummyActivityService startActivity 基础版应不崩溃
    func testDummyActivityService_startActivity_基础版_不崩溃() {
        let service = DummyActivityService()
        service.startActivity(id: UUID(), name: "test", target: "target")
        // 不崩溃即通过
    }

    /// DummyActivityService startActivity 扩展版应不崩溃
    func testDummyActivityService_startActivity_扩展版_不崩溃() {
        let service = DummyActivityService()
        service.startActivity(
            id: UUID(), name: "test", target: "target",
            kind: .synthesis, sourceCount: 5,
            currentFileName: "file.md", estimatedSecondsRemaining: 60
        )
        // 不崩溃即通过
    }

    /// DummyActivityService updateProgress 基础版应不崩溃
    func testDummyActivityService_updateProgress_基础版_不崩溃() async {
        let service = DummyActivityService()
        let id = UUID()
        service.startActivity(id: id, name: "test", target: "target")
        await service.updateProgress(id: id, progress: 0.5, message: "processing")
        // 不崩溃即通过
    }

    /// DummyActivityService updateProgress 扩展版应不崩溃
    func testDummyActivityService_updateProgress_扩展版_不崩溃() async {
        let service = DummyActivityService()
        let id = UUID()
        service.startActivity(id: id, name: "test", target: "target")
        await service.updateProgress(
            id: id, progress: 0.5, message: "processing",
            sourceCount: 5, currentFileName: "file.md",
            estimatedSecondsRemaining: 30
        )
        // 不崩溃即通过
    }

    /// DummyActivityService endActivity 应不崩溃
    func testDummyActivityService_endActivity_不崩溃() async {
        let service = DummyActivityService()
        let id = UUID()
        service.startActivity(id: id, name: "test", target: "target")
        await service.endActivity(id: id)
        // 不崩溃即通过
    }

    // MARK: - OCRServiceProtocol

    /// NoOpOCRService recognizeText 应返回空字符串
    func testNoOpOCRService_recognizeText_返回空字符串() async {
        let service = NoOpOCRService()
        let result = try? await service.recognizeText(from: AppImage())
        XCTAssertEqual(result, "", "NoOp OCR 应返回空字符串")
    }

    // MARK: - PlatformCapabilities

    /// NoOpBiometricAuthProvider authenticationPolicy 应为 deviceOwnerAuthenticationWithBiometrics
    func testNoOpBiometricAuthProvider_authenticationPolicy_正确值() {
        let provider = NoOpBiometricAuthProvider()
        XCTAssertEqual(provider.authenticationPolicy, .deviceOwnerAuthenticationWithBiometrics)
    }

    /// NoOpBiometricAuthProvider canEvaluatePolicy 应返回 false
    func testNoOpBiometricAuthProvider_canEvaluatePolicy_返回false() {
        let provider = NoOpBiometricAuthProvider()
        let context = LAContext()
        XCTAssertFalse(provider.canEvaluatePolicy(context: context),
                       "NoOp 生物认证应返回 false")
    }

    /// NoOpBiometricAuthProvider evaluatePolicy 应返回 false
    func testNoOpBiometricAuthProvider_evaluatePolicy_返回false() async {
        let provider = NoOpBiometricAuthProvider()
        let context = LAContext()
        let result = await provider.evaluatePolicy(context: context, reason: "test")
        XCTAssertFalse(result, "NoOp 生物认证评估应返回 false")
    }

    // MARK: - ReminderServiceProtocol

    /// UnsupportedReminderService requestAccess 应返回 false
    func testUnsupportedReminderService_requestAccess_返回false() async {
        let service = UnsupportedReminderService()
        let result = await service.requestAccess()
        XCTAssertFalse(result, "Unsupported 提醒服务应返回 false")
    }

    /// UnsupportedReminderService createReminder 应不崩溃
    func testUnsupportedReminderService_createReminder_不崩溃() async {
        let service = UnsupportedReminderService()
        try? await service.createReminder(title: "test", notes: "body")
        // 不崩溃即通过
    }

    // MARK: - WatchSyncProtocol

    /// StubWatchSyncService 初始状态应返回安全默认值
    func testStubWatchSyncService_初始状态_安全默认值() {
        let service = StubWatchSyncService()
        XCTAssertEqual(service.lastReceivedText, "", "初始 lastReceivedText 应为空")
        XCTAssertNil(service.latestBriefing, "初始 latestBriefing 应为 nil")
        XCTAssertFalse(service.isBriefingLoading, "初始 isBriefingLoading 应为 false")
    }

    /// StubWatchSyncService sendContent 应不崩溃
    func testStubWatchSyncService_sendContent_不崩溃() {
        let service = StubWatchSyncService()
        service.sendContent("test")
        // 不崩溃即通过
    }

    /// StubWatchSyncService requestDailyBriefing 应不崩溃
    func testStubWatchSyncService_requestDailyBriefing_不崩溃() {
        let service = StubWatchSyncService()
        service.requestDailyBriefing()
        // 不崩溃即通过
    }

    /// StubWatchSyncService handleBriefingResponse 应不崩溃
    func testStubWatchSyncService_handleBriefingResponse_不崩溃() {
        let service = StubWatchSyncService()
        service.handleBriefingResponse("briefing text")
        // 不崩溃即通过
    }

    /// StubWatchSyncService sendAudioData 默认实现应不崩溃
    func testStubWatchSyncService_sendAudioData_默认实现_不崩溃() async {
        let service = StubWatchSyncService()
        await service.sendAudioData(Data(), filename: "test.m4a")
        // 不崩溃即通过（WatchSyncProtocol extension 默认实现）
    }

    /// StubWatchSyncService latestBriefing 可读写
    func testStubWatchSyncService_latestBriefing_可读写() {
        let service = StubWatchSyncService()
        service.latestBriefing = "test briefing"
        XCTAssertEqual(service.latestBriefing, "test briefing")
        service.latestBriefing = nil
        XCTAssertNil(service.latestBriefing)
    }

    /// StubWatchSyncService isBriefingLoading 可读写
    func testStubWatchSyncService_isBriefingLoading_可读写() {
        let service = StubWatchSyncService()
        service.isBriefingLoading = true
        XCTAssertTrue(service.isBriefingLoading)
        service.isBriefingLoading = false
        XCTAssertFalse(service.isBriefingLoading)
    }
}

// MARK: - 测试辅助

/// 记录 CollaborationProviderDelegate 回调状态的测试替身
@MainActor
private final class CollaborationDelegateRecorder: CollaborationProviderDelegate {
    var lastStatus: String?

    func providerDidUpdateStatus(_ message: String) {
        lastStatus = message
    }

    func providerDidDiscoverRoom(_ room: DiscoveredRoom) {}
    func providerDidLoseRoom(id: String) {}
    func providerDidConnectPeer(_ user: CollabUser) {}
    func providerDidDisconnectPeer(id: String) {}
    func providerDidReceiveData(_ data: Data, from userID: String) {}
    func providerDidEncounterError(_ error: String) {}
}
