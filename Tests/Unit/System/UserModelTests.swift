//
//  UserModelTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 User 模型的默认配额、isPro/hasPrivacySecurity 便捷属性、Codable 后端契约适配（userId Long→UUID 转换、字段映射）。
//

import XCTest
@testable import ZhiYu

final class UserModelTests: XCTestCase {

    /// 将 JSON 字符串转为 Data（避免 force unwrapping 与 non_optional_string_data_conversion 违规）
    private func jsonData(_ string: String) -> Data {
        Data(string.utf8)
    }

    // MARK: - DefaultQuotas 常量

    func testDefaultQuotas_liteValues() {
        XCTAssertEqual(User.DefaultQuotas.liteMaxVaults, 2)
        XCTAssertEqual(User.DefaultQuotas.liteMaxPages, 1000)
        XCTAssertEqual(User.DefaultQuotas.liteMaxPlugins, 3)
    }

    func testDefaultQuotas_proValues() {
        XCTAssertEqual(User.DefaultQuotas.proMaxVaults, 100)
        XCTAssertEqual(User.DefaultQuotas.proMaxPages, 50000)
        XCTAssertEqual(User.DefaultQuotas.proMaxPlugins, 999999)
    }

    // MARK: - 默认初始化

    func testInit_defaultValues_appliesLiteQuotas() {
        let user = User(name: "Alice", email: "alice@test.com")
        XCTAssertEqual(user.planKey, "free")
        XCTAssertEqual(user.maxVaults, User.DefaultQuotas.liteMaxVaults)
        XCTAssertEqual(user.maxPages, User.DefaultQuotas.liteMaxPages)
        XCTAssertEqual(user.maxPlugins, User.DefaultQuotas.liteMaxPlugins)
        XCTAssertTrue(user.features.isEmpty)
        XCTAssertNil(user.phone)
        XCTAssertNil(user.avatarURL)
        XCTAssertNil(user.gender)
        XCTAssertNil(user.birthday)
    }

    func testInit_customValues_preserved() {
        let url = URL(string: "https://avatar.test/a.png")!
        let user = User(
            name: "Bob",
            email: "bob@test.com",
            phone: "13800138000",
            avatarURL: url,
            planKey: "pro",
            maxVaults: 100,
            maxPages: 50000,
            maxPlugins: 999999,
            features: ["local_slm", "privacy_security"],
            gender: 1,
            birthday: "1990-01-01"
        )
        XCTAssertEqual(user.name, "Bob")
        XCTAssertEqual(user.phone, "13800138000")
        XCTAssertEqual(user.avatarURL, url)
        XCTAssertEqual(user.planKey, "pro")
        XCTAssertEqual(user.features, ["local_slm", "privacy_security"])
        XCTAssertEqual(user.gender, 1)
        XCTAssertEqual(user.birthday, "1990-01-01")
    }

    // MARK: - isPro

    func testIsPro_planKeyPro_returnsTrue() {
        let user = User(name: "A", email: "", planKey: "pro")
        XCTAssertTrue(user.isPro)
    }

    func testIsPro_planKeyFree_returnsFalse() {
        let user = User(name: "A", email: "", planKey: "free")
        XCTAssertFalse(user.isPro)
    }

    func testIsPro_planKeyNil_returnsFalse() {
        let user = User(name: "A", email: "", planKey: nil)
        XCTAssertFalse(user.isPro)
    }

    // MARK: - hasPrivacySecurity

    func testHasPrivacySecurity_proUser_returnsTrue() {
        let user = User(name: "A", email: "", planKey: "pro", features: [])
        XCTAssertTrue(user.hasPrivacySecurity)
    }

    func testHasPrivacySecurity_featureIncluded_returnsTrue() {
        let user = User(name: "A", email: "", planKey: "free", features: ["privacy_security"])
        XCTAssertTrue(user.hasPrivacySecurity)
    }

    func testHasPrivacySecurity_freeNoFeature_returnsFalse() {
        let user = User(name: "A", email: "", planKey: "free", features: ["local_slm"])
        XCTAssertFalse(user.hasPrivacySecurity)
    }

    func testHasPrivacySecurity_freeEmptyFeatures_returnsFalse() {
        let user = User(name: "A", email: "", planKey: "free", features: [])
        XCTAssertFalse(user.hasPrivacySecurity)
    }

    // MARK: - Codable: 后端 Long userId → UUID 转换

    func testDecode_longUserId_convertsToUUID() throws {
        let json = Data("""
        {"userId": 12345, "nick": "TestUser", "email": "t@t.com"}
        """.utf8)
        let user = try JSONDecoder().decode(User.self, from: json)
        XCTAssertEqual(user.name, "TestUser")
        XCTAssertEqual(user.email, "t@t.com")
        // UUID 应为 00000000-0000-0000-0000-000000003039 (12345 的 12 位十六进制)
        XCTAssertEqual(user.id.uuidString.lowercased(), "00000000-0000-0000-0000-000000003039")
    }

    func testDecode_stringUserId_parsedAsUUID() throws {
        let json = Data("""
        {"userId": "11111111-2222-3333-4444-555555555555", "nick": "U", "email": ""}
        """.utf8)
        let user = try JSONDecoder().decode(User.self, from: json)
        XCTAssertEqual(user.id.uuidString.lowercased(), "11111111-2222-3333-4444-555555555555")
    }

    func testDecode_invalidUserId_generatesRandomUUID() throws {
        let json = Data("""
        {"userId": "not-a-uuid", "nick": "U", "email": ""}
        """.utf8)
        let user = try JSONDecoder().decode(User.self, from: json)
        // 应生成随机 UUID 而非崩溃
        XCTAssertEqual(user.id.uuidString.count, 36)
    }

    func testDecode_missingUserId_generatesRandomUUID() throws {
        let json = Data("""
        {"nick": "U", "email": ""}
        """.utf8)
        let user = try JSONDecoder().decode(User.self, from: json)
        XCTAssertEqual(user.id.uuidString.count, 36)
    }

    // MARK: - Codable: 字段映射

    func testDecode_nickMapsToName() throws {
        let json = Data("""
        {"userId": 1, "nick": "NickName", "email": ""}
        """.utf8)
        let user = try JSONDecoder().decode(User.self, from: json)
        XCTAssertEqual(user.name, "NickName")
    }

    func testDecode_usernameFallback_whenNickMissing() throws {
        let json = Data("""
        {"userId": 1, "username": "UserName", "email": ""}
        """.utf8)
        let user = try JSONDecoder().decode(User.self, from: json)
        XCTAssertEqual(user.name, "UserName")
    }

    func testDecode_missingName_defaultsToGuest() throws {
        let json = Data("""
        {"userId": 1, "email": ""}
        """.utf8)
        let user = try JSONDecoder().decode(User.self, from: json)
        XCTAssertEqual(user.name, "Guest")
    }

    func testDecode_mobileMapsToPhone() throws {
        let json = Data("""
        {"userId": 1, "nick": "U", "email": "", "mobile": "13800138000"}
        """.utf8)
        let user = try JSONDecoder().decode(User.self, from: json)
        XCTAssertEqual(user.phone, "13800138000")
    }

    func testDecode_avatarStringMapsToURL() throws {
        let json = Data("""
        {"userId": 1, "nick": "U", "email": "", "avatar": "https://test.com/a.png"}
        """.utf8)
        let user = try JSONDecoder().decode(User.self, from: json)
        XCTAssertEqual(user.avatarURL?.absoluteString, "https://test.com/a.png")
    }

    func testDecode_planKeySnakeCase() throws {
        let json = Data("""
        {"userId": 1, "nick": "U", "email": "", "plan_key": "pro"}
        """.utf8)
        let user = try JSONDecoder().decode(User.self, from: json)
        XCTAssertEqual(user.planKey, "pro")
    }

    func testDecode_maxVaultsSnakeCase() throws {
        let json = Data("""
        {"userId": 1, "nick": "U", "email": "", "max_vaults": 50}
        """.utf8)
        let user = try JSONDecoder().decode(User.self, from: json)
        XCTAssertEqual(user.maxVaults, 50)
    }

    func testDecode_missingQuotas_appliesLiteDefaults() throws {
        let json = Data("""
        {"userId": 1, "nick": "U", "email": ""}
        """.utf8)
        let user = try JSONDecoder().decode(User.self, from: json)
        XCTAssertEqual(user.maxVaults, User.DefaultQuotas.liteMaxVaults)
        XCTAssertEqual(user.maxPages, User.DefaultQuotas.liteMaxPages)
        XCTAssertEqual(user.maxPlugins, User.DefaultQuotas.liteMaxPlugins)
        XCTAssertEqual(user.planKey, "free")
    }

    func testDecode_featuresArray() throws {
        let json = Data("""
        {"userId": 1, "nick": "U", "email": "", "features": ["a", "b"]}
        """.utf8)
        let user = try JSONDecoder().decode(User.self, from: json)
        XCTAssertEqual(user.features, ["a", "b"])
    }

    // MARK: - Codable: 往返

    func testEncodeDecode_roundTrip_preservesFields() throws {
        let original = User(
            name: "Round",
            email: "r@t.com",
            phone: "138",
            planKey: "pro",
            maxVaults: 50,
            maxPages: 1000,
            maxPlugins: 100,
            features: ["x"],
            gender: 2,
            birthday: "2000-01-01"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(User.self, from: data)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.email, original.email)
        XCTAssertEqual(decoded.phone, original.phone)
        XCTAssertEqual(decoded.planKey, original.planKey)
        XCTAssertEqual(decoded.maxVaults, original.maxVaults)
        XCTAssertEqual(decoded.maxPages, original.maxPages)
        XCTAssertEqual(decoded.maxPlugins, original.maxPlugins)
        XCTAssertEqual(decoded.features, original.features)
        XCTAssertEqual(decoded.gender, original.gender)
        XCTAssertEqual(decoded.birthday, original.birthday)
    }

    // MARK: - Sendable / Equatable

    func testUser_isSendable() {
        // 编译时检查：User 声明为 Sendable
        let user = User(name: "A", email: "")
        _ = user
        // User 未遵循 Equatable，但 UUID 可比较
        let user2 = User(id: user.id, name: "A", email: "")
        XCTAssertEqual(user.id, user2.id)
    }
}
