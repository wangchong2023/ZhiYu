//
//  ChatMessageDomainDTOTests.swift
//  ZhiYuDomainTests
//
//  系统层级：[ZhiYuDomainTests]
//  核心职责：验证 ChatMessageDomainDTO 的初始化默认值与 Codable 契约。
//

import XCTest
@testable import ZhiYuDomain

final class ChatMessageDomainDTOTests: XCTestCase {

    /// 默认初始化必须生成唯一 id
    func testDefaultInitGeneratesUniqueId() {
        let msg1 = ChatMessageDomainDTO(role: "user", content: "a")
        let msg2 = ChatMessageDomainDTO(role: "user", content: "b")
        XCTAssertNotEqual(msg1.id, msg2.id, "默认初始化必须生成唯一 id")
        XCTAssertFalse(msg1.id.isEmpty)
    }

    /// 显式 id 必须被保留
    func testExplicitIdPreserved() {
        let msg = ChatMessageDomainDTO(id: "custom-id", role: "assistant", content: "hi")
        XCTAssertEqual(msg.id, "custom-id")
    }

    /// role 和 content 必须正确赋值
    func testRoleContentAssignment() {
        let msg = ChatMessageDomainDTO(role: "user", content: "test content")
        XCTAssertEqual(msg.role, "user")
        XCTAssertEqual(msg.content, "test content")
    }

    /// Codable 编解码往返必须保持数据完整
    func testCodableRoundTrip() throws {
        let original = ChatMessageDomainDTO(id: "rt-1", role: "assistant", content: "round trip")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ChatMessageDomainDTO.self, from: data)

        XCTAssertEqual(original.id, decoded.id)
        XCTAssertEqual(original.role, decoded.role)
        XCTAssertEqual(original.content, decoded.content)
    }

    /// Identifiable 协议遵循（id 属性存在且类型为 String）
    func testIdentifiableConformance() {
        let msg = ChatMessageDomainDTO(role: "user", content: "x")
        XCTAssertFalse(msg.id.isEmpty, "Identifiable.id 必须非空")
    }

    /// Sendable 遵循（编译期保证，运行期验证可跨 actor 传递）
    func testSendableConformance() async {
        let msg = ChatMessageDomainDTO(role: "user", content: "sendable")
        // 跨 actor 传递验证 Sendable
        await Task {
            XCTAssertEqual(msg.content, "sendable")
        }.value
    }
}
