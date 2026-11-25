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
}
