//
//  CollaborationModelsTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证协作模型：CollabUser.displayLabel、CollabRole.displayName/icon、DiscoveredRoom Hashable/Equatable、Codable 往返。
//

import XCTest
@testable import ZhiYu

final class CollabModelsBatch3Tests: XCTestCase {

    // MARK: - CollabUser

    func testCollabUser_displayLabel_format() {
        let user = CollabUser(
            id: "u1",
            displayName: "Alice",
            deviceName: "iPhone",
            joinedAt: Date()
        )
        XCTAssertEqual(user.displayLabel, "Alice (iPhone)")
    }

    func testCollabUser_codableRoundTrip() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let user = CollabUser(id: "u1", displayName: "Bob", deviceName: "Mac", joinedAt: date)
        let data = try JSONEncoder().encode(user)
        let decoded = try JSONDecoder().decode(CollabUser.self, from: data)
        XCTAssertEqual(user, decoded)
    }

    func testCollabUser_hashable() {
        let user1 = CollabUser(id: "u1", displayName: "A", deviceName: "D", joinedAt: Date())
        let user2 = CollabUser(id: "u1", displayName: "A", deviceName: "D", joinedAt: Date())
        let set: Set<CollabUser> = [user1, user2]
        XCTAssertEqual(set.count, 1, "相同字段的 CollabUser 应去重")
    }

    func testCollabUser_identifiable() {
        let user = CollabUser(id: "u1", displayName: "A", deviceName: "D", joinedAt: Date())
        XCTAssertEqual(user.id, "u1")
    }

    // MARK: - CollabEdit

    func testCollabEdit_codableRoundTrip() throws {
        let pageID = UUID()
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let edit = CollabEdit(
            id: "e1",
            userID: "u1",
            pageID: pageID,
            field: "title",
            oldValue: "Old",
            newValue: "New",
            timestamp: date
        )
        let data = try JSONEncoder().encode(edit)
        let decoded = try JSONDecoder().decode(CollabEdit.self, from: data)
        XCTAssertEqual(decoded.id, "e1")
        XCTAssertEqual(decoded.userID, "u1")
        XCTAssertEqual(decoded.pageID, pageID)
        XCTAssertEqual(decoded.field, "title")
        XCTAssertEqual(decoded.oldValue, "Old")
        XCTAssertEqual(decoded.newValue, "New")
        XCTAssertEqual(decoded.timestamp, date)
    }

    func testCollabEdit_identifiable() {
        let edit = CollabEdit(
            id: "e1", userID: "u", pageID: UUID(),
            field: "f", oldValue: "a", newValue: "b", timestamp: Date()
        )
        XCTAssertEqual(edit.id, "e1")
    }

    private let allRoles: [CollabRole] = [.owner, .editor, .viewer]

    // MARK: - CollabRole

    func testCollabRole_allCases_containsThreeRoles() {
        XCTAssertEqual(allRoles.count, 3)
        XCTAssertTrue(allRoles.contains(.owner))
        XCTAssertTrue(allRoles.contains(.editor))
        XCTAssertTrue(allRoles.contains(.viewer))
    }

    func testCollabRole_displayName_nonEmpty() {
        for role in allRoles {
            XCTAssertFalse(role.displayName.isEmpty, "角色显示名不应为空")
        }
    }

    func testCollabRole_displayName_distinct() {
        let names = allRoles.map { $0.displayName }
        XCTAssertEqual(names.count, Set(names).count, "角色显示名应唯一")
    }

    func testCollabRole_icon_owner_isCrown() {
        XCTAssertEqual(CollabRole.owner.icon, "crown.fill")
    }

    func testCollabRole_icon_editor_isPencil() {
        XCTAssertEqual(CollabRole.editor.icon, "pencil.circle.fill")
    }

    func testCollabRole_icon_viewer_isEye() {
        XCTAssertEqual(CollabRole.viewer.icon, "eye.fill")
    }

    func testCollabRole_icon_allNonEmpty() {
        for role in allRoles {
            XCTAssertFalse(role.icon.isEmpty, "角色图标不应为空")
        }
    }

    func testCollabRole_codableRoundTrip() throws {
        for role in allRoles {
            let data = try JSONEncoder().encode(role)
            let decoded = try JSONDecoder().decode(CollabRole.self, from: data)
            XCTAssertEqual(decoded, role)
        }
    }

    func testCollabRole_rawValue() {
        XCTAssertEqual(CollabRole.owner.rawValue, "owner")
        XCTAssertEqual(CollabRole.editor.rawValue, "editor")
        XCTAssertEqual(CollabRole.viewer.rawValue, "viewer")
    }

    // MARK: - DiscoveredRoom

    func testDiscoveredRoom_equatable_byId() {
        let room1 = DiscoveredRoom(id: "r1", platformPeer: "peer1", roomName: "Room", owner: "Alice")
        let room2 = DiscoveredRoom(id: "r1", platformPeer: "peer2", roomName: "Different", owner: "Bob")
        XCTAssertEqual(room1, room2, "DiscoveredRoom 判等应只比较 id")
    }

    func testDiscoveredRoom_notEqual_differentId() {
        let room1 = DiscoveredRoom(id: "r1", platformPeer: "p", roomName: "R", owner: "O")
        let room2 = DiscoveredRoom(id: "r2", platformPeer: "p", roomName: "R", owner: "O")
        XCTAssertNotEqual(room1, room2)
    }

    func testDiscoveredRoom_hashable_byId() {
        let room1 = DiscoveredRoom(id: "r1", platformPeer: "peer1", roomName: "A", owner: "X")
        let room2 = DiscoveredRoom(id: "r1", platformPeer: "peer2", roomName: "B", owner: "Y")
        let set: Set<DiscoveredRoom> = [room1, room2]
        XCTAssertEqual(set.count, 1, "相同 id 的 DiscoveredRoom 应去重")
    }

    func testDiscoveredRoom_hashable_differentIds() {
        let room1 = DiscoveredRoom(id: "r1", platformPeer: "p", roomName: "A", owner: "X")
        let room2 = DiscoveredRoom(id: "r2", platformPeer: "p", roomName: "A", owner: "X")
        let set: Set<DiscoveredRoom> = [room1, room2]
        XCTAssertEqual(set.count, 2)
    }

    func testDiscoveredRoom_identifiable() {
        let room = DiscoveredRoom(id: "r1", platformPeer: "p", roomName: "R", owner: "O")
        XCTAssertEqual(room.id, "r1")
    }

    func testDiscoveredRoom_properties() {
        let room = DiscoveredRoom(id: "r1", platformPeer: "peer", roomName: "MyRoom", owner: "Alice")
        XCTAssertEqual(room.roomName, "MyRoom")
        XCTAssertEqual(room.owner, "Alice")
    }
}
