//
//  MultipeerSyncAndCRDTDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/02.
//  Copyright © 2026 WangChong. All rights reserved.
//

import XCTest
import SwiftUI
import UFPCore
@testable import ZhiYu

@MainActor
final class MultipeerSyncAndCRDTDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. CollaborationService Lifecycle & Hosting

    func testCollaborationServiceLifecycle() async throws {
        let service = CollaborationService()
        service.isAvailable = true
        service.startHosting(roomName: "Engineering Sync Room")
        XCTAssertTrue(service.isHosting)
        XCTAssertTrue(service.isJoined)
        XCTAssertEqual(service.roomName, "Engineering Sync Room")

        let room = DiscoveredRoom(id: "room_101", platformPeer: AnyHashable("peer_01"), roomName: "Design Room", owner: "Alice")
        service.providerDidDiscoverRoom(room)
        XCTAssertEqual(service.discoveredRooms.count, 1)

        let user = CollabUser(id: "user_202", displayName: "Bob", deviceName: "iPhone", joinedAt: Date())
        service.providerDidConnectPeer(user)
        XCTAssertEqual(service.connectedPeers.count, 1)

        service.providerDidDisconnectPeer(id: "user_202")
        XCTAssertTrue(service.connectedPeers.isEmpty)

        service.providerDidLoseRoom(id: "room_101")
        XCTAssertTrue(service.discoveredRooms.isEmpty)

        service.stop()
        XCTAssertFalse(service.isHosting)
        XCTAssertFalse(service.isJoined)
    }

    // MARK: - 2. Remote Page Sync Delegate

    func testCollaborationRemotePageSync() async throws {
        final class MockCollabDelegate: CollaborationDelegate {
            var pages: [KnowledgePage] = []
            var appliedUpdate: KnowledgePage?
            var insertedPage: KnowledgePage?

            func applyRemoteUpdate(_ page: KnowledgePage) async {
                appliedUpdate = page
            }

            func insertRemotePage(_ page: KnowledgePage) async {
                insertedPage = page
            }
        }

        let service = CollaborationService()
        let delegate = MockCollabDelegate()
        service.setDelegate(delegate)

        let newPageID = UUID()
        let payload: [String: Any] = [
            "type": FeatureConstants.CollaborationKey.pageSync,
            "page": [
                "id": newPageID.uuidString,
                "title": "Remote Architecture Notes",
                "content": "Collaborative markdown text",
                "type": PageType.concept.rawValue,
                "tags": ["Sync", "CRDT"],
                "status": PageStatus.active.rawValue,
                "updated": Date().timeIntervalSince1970
            ]
        ]

        let data = try JSONSerialization.data(withJSONObject: payload)
        service.providerDidReceiveData(data, from: "peer_alice")

        try? await Task.sleep(for: .milliseconds(50))
        XCTAssertNotNil(delegate.insertedPage)
        XCTAssertEqual(delegate.insertedPage?.title, "Remote Architecture Notes")
    }
}
