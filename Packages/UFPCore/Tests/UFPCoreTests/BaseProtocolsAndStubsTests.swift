//
//  BaseProtocolsAndStubsTests.swift
//  UFPCoreTests
//
//  系统层级：[UFPCoreTests]
//  核心职责：验证 APIPaths 路径规范及 BackgroundTask / ReminderService / WatchSync 协议与桩实现的默认行为。
//

import XCTest
@testable import UFPCore

final class BaseProtocolsAndStubsTests: XCTestCase {

    func testAPIPathsStartWithLeadingSlashOrHTTPS() {
        XCTAssertTrue(APIPaths.refreshPath.hasPrefix("/api/v1/"))
        XCTAssertTrue(APIPaths.phoneLoginPath.hasPrefix("/api/v1/"))
        XCTAssertTrue(APIPaths.subscriptionVerifyPath.hasPrefix("/api/v1/"))
        XCTAssertTrue(APIPaths.officialWebsite.hasPrefix("https://"))
    }

    @MainActor
    func testStubBackgroundTaskProviderIsSafeNoOp() {
        let stub = StubBackgroundTaskProvider()
        var invoked = false
        stub.register { invoked = true }
        stub.schedule()
        XCTAssertFalse(invoked, "StubBackgroundTaskProvider 不应在无后台事件时同步触发回调")
    }

    func testUnsupportedReminderServiceReturnsFalseAndDoesNotThrow() async throws {
        let service = UnsupportedReminderService()
        let granted = await service.requestAccess()
        XCTAssertFalse(granted)
        try await service.createReminder(title: "Test", notes: "Notes")
    }

    @MainActor
    func testStubWatchSyncServiceUpdatesReceivedContentAndPostsNotification() {
        let stub = StubWatchSyncService()
        XCTAssertEqual(stub.lastReceivedText, "")
        XCTAssertNil(stub.latestBriefing)
        XCTAssertFalse(stub.isBriefingLoading)

        let expectation = expectation(forNotification: .didReceiveWatchContent, object: nil) { notification in
            (notification.object as? String) == "手表速记内容"
        }
        stub.handleReceivedPageContent("手表速记内容")
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(stub.lastReceivedText, "手表速记内容")

        stub.sendContent("ping")
        stub.sendAudioData(Data(), filename: "a.m4a")
        stub.requestDailyBriefing()
        stub.handleBriefingResponse("今日简报")
    }

    func testKeychainQueryHelperIncludesDataProtectionFlagByDefault() {
        let query = KeychainQueryHelper.baseQuery(serviceName: "com.zhiyu.test", key: "token")
        XCTAssertEqual(query[kSecAttrService as String] as? String, "com.zhiyu.test")
        XCTAssertEqual(query[kSecAttrAccount as String] as? String, "token")
        XCTAssertEqual(query[kSecUseDataProtectionKeychain as String] as? Bool, true)

        let noDp = KeychainQueryHelper.baseQuery(serviceName: "com.zhiyu.test", key: "token", useDataProtection: false)
        XCTAssertNil(noDp[kSecUseDataProtectionKeychain as String])
    }

    func testLogMaskerRedactsMultiProviderAPIKeysAndBearerToken() {
        let raw = "key=sk-1234567890123456789012345678901234 and Authorization: Bearer my.jwt.token"
        let masked = LogMasker.mask(raw)
        XCTAssertTrue(masked.contains("sk-****"))
        XCTAssertTrue(masked.contains("Authorization: Bearer ****"))
        XCTAssertFalse(masked.contains("my.jwt.token"))
    }

    func testAudioSplitterSplitAndMergeRoundTrip() {
        let payload = Data((0..<1024).map { UInt8($0 % 256) })
        let chunks = AudioSplitter.split(data: payload, chunkSize: 300)
        XCTAssertEqual(chunks.count, 4)
        XCTAssertEqual(AudioSplitter.merge(chunks: chunks), payload)
        XCTAssertTrue(AudioSplitter.split(data: Data()).isEmpty)
        // 非法 chunkSize（0 或负数）不得死循环或触发 Range 越界崩溃
        XCTAssertTrue(AudioSplitter.split(data: payload, chunkSize: 0).isEmpty)
        XCTAssertTrue(AudioSplitter.split(data: payload, chunkSize: -64).isEmpty)
    }

    func testAppNotificationNamesAreStable() {
        XCTAssertEqual(Notification.Name.toggleSidebar.rawValue, "toggleSidebar")
        XCTAssertEqual(Notification.Name.vaultWillSwitch.rawValue, "vaultWillSwitch")
    }

    func testSelfSignedSessionDelegateProviderCreatesDelegate() {
        let provider = SelfSignedSessionDelegateProvider()
        let delegate = provider.makeSessionDelegate()
        XCTAssertNotNil(delegate)
        XCTAssertTrue(delegate is SelfSignedSessionDelegate)
    }
}
