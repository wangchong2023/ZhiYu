//
//  AuthDTOsTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证认证 DTO 的工厂方法、Encodable 编码、字段映射等与后端契约一致性。
//  注意：Request DTOs 仅遵循 Encodable（单向发送），Response DTOs 遵循 Codable（双向）。
//

import XCTest
@testable import ZhiYu

final class AuthDTOsTests: XCTestCase {

    /// 将 Encodable 编码为 JSON 字典（用于字段验证）
    private func encodeToDict<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        let any = try JSONSerialization.jsonObject(with: data)
        return (any as? [String: Any]) ?? [:]
    }

    // MARK: - SendSmsRequest

    func testSendSmsRequest_defaultScene_isLogin() throws {
        let req = SendSmsRequest(phone: "13800138000")
        XCTAssertEqual(req.scene, "login")
        XCTAssertEqual(req.phone, "13800138000")

        let dict = try encodeToDict(req)
        XCTAssertEqual(dict["phone"] as? String, "13800138000")
        XCTAssertEqual(dict["scene"] as? String, "login")
    }

    func testSendSmsRequest_customScene_preserved() throws {
        let req = SendSmsRequest(phone: "13800138000", scene: "register")
        XCTAssertEqual(req.scene, "register")
        let dict = try encodeToDict(req)
        XCTAssertEqual(dict["scene"] as? String, "register")
    }

    // MARK: - LoginRequest.password

    func testLoginRequest_password_grantTypeIsPassword() throws {
        let req = LoginRequest.password(username: "user1", password: "pass123")
        XCTAssertEqual(req.grantType, "password")
        XCTAssertEqual(req.username, "user1")
        XCTAssertEqual(req.password, "pass123")
        XCTAssertNil(req.phone)
        XCTAssertNil(req.smsCode)
        XCTAssertTrue(req.privacyConsent)

        let dict = try encodeToDict(req)
        XCTAssertEqual(dict["grantType"] as? String, "password")
        XCTAssertEqual(dict["username"] as? String, "user1")
    }

    func testLoginRequest_password_customConsent() throws {
        let req = LoginRequest.password(username: "user1", password: "pass123", consent: false)
        XCTAssertFalse(req.privacyConsent)
        let dict = try encodeToDict(req)
        XCTAssertEqual(dict["privacyConsent"] as? Bool, false)
    }

    // MARK: - LoginRequest.sms

    func testLoginRequest_sms_grantTypeIsSmsCode() throws {
        let req = LoginRequest.sms(phone: "13800138000", code: "123456")
        XCTAssertEqual(req.grantType, "sms_code")
        XCTAssertEqual(req.phone, "13800138000")
        XCTAssertEqual(req.smsCode, "123456")
        XCTAssertNil(req.username)
        XCTAssertNil(req.password)
        XCTAssertTrue(req.privacyConsent)

        let dict = try encodeToDict(req)
        XCTAssertEqual(dict["grantType"] as? String, "sms_code")
        XCTAssertEqual(dict["phone"] as? String, "13800138000")
    }

    // MARK: - GuestLoginRequest

    func testGuestLoginRequest_defaultConsent() throws {
        let req = GuestLoginRequest(deviceId: "device-abc")
        XCTAssertEqual(req.deviceId, "device-abc")
        XCTAssertTrue(req.privacyConsent)

        let dict = try encodeToDict(req)
        XCTAssertEqual(dict["deviceId"] as? String, "device-abc")
    }

    // MARK: - OAuthAppleRequest

    func testOAuthAppleRequest_encodable() throws {
        let req = OAuthAppleRequest(code: "auth_code", state: "state123", idToken: "id_token")
        let dict = try encodeToDict(req)
        XCTAssertEqual(dict["code"] as? String, "auth_code")
        XCTAssertEqual(dict["state"] as? String, "state123")
        XCTAssertEqual(dict["idToken"] as? String, "id_token")
    }

    func testOAuthAppleRequest_nilStateAndIdToken() throws {
        let req = OAuthAppleRequest(code: "auth_code", state: nil, idToken: nil)
        let dict = try encodeToDict(req)
        XCTAssertNil(dict["state"])
        XCTAssertNil(dict["idToken"])
    }

    // MARK: - OAuthWeChatRequest

    func testOAuthWeChatRequest_defaultStateNil() throws {
        let req = OAuthWeChatRequest(code: "wx_code")
        XCTAssertEqual(req.code, "wx_code")
        XCTAssertNil(req.state)
        let dict = try encodeToDict(req)
        XCTAssertEqual(dict["code"] as? String, "wx_code")
    }

    // MARK: - OAuthGoogleRequest

    func testOAuthGoogleRequest_encodable() throws {
        let req = OAuthGoogleRequest(code: "g_code", idToken: "g_token")
        let dict = try encodeToDict(req)
        XCTAssertEqual(dict["code"] as? String, "g_code")
        XCTAssertEqual(dict["idToken"] as? String, "g_token")
    }

    // MARK: - OAuthGitHubRequest

    func testOAuthGitHubRequest_defaultStateNil() throws {
        let req = OAuthGitHubRequest(code: "gh_code")
        XCTAssertEqual(req.code, "gh_code")
        XCTAssertNil(req.state)
        let dict = try encodeToDict(req)
        XCTAssertEqual(dict["code"] as? String, "gh_code")
    }

    // MARK: - CarrierAuthRequest

    func testCarrierAuthRequest_defaultConsent() throws {
        let req = CarrierAuthRequest(carrierToken: "token123", appKey: "app_key")
        XCTAssertEqual(req.carrierToken, "token123")
        XCTAssertEqual(req.appKey, "app_key")
        XCTAssertTrue(req.privacyConsent)

        let dict = try encodeToDict(req)
        XCTAssertEqual(dict["carrierToken"] as? String, "token123")
    }

    // MARK: - TokenDTO (Codable)

    func testTokenDTO_codable() throws {
        let dto = TokenDTO(accessToken: "access", refreshToken: "refresh", accessExpireAt: 3600, refreshExpireAt: 7200)
        let data = try JSONEncoder().encode(dto)
        let decoded = try JSONDecoder().decode(TokenDTO.self, from: data)
        XCTAssertEqual(decoded.accessToken, "access")
        XCTAssertEqual(decoded.refreshToken, "refresh")
        XCTAssertEqual(decoded.accessExpireAt, 3600)
        XCTAssertEqual(decoded.refreshExpireAt, 7200)
    }

    func testTokenDTO_optionalFields() throws {
        let dto = TokenDTO(accessToken: "access", refreshToken: nil, accessExpireAt: 3600, refreshExpireAt: nil)
        let data = try JSONEncoder().encode(dto)
        let decoded = try JSONDecoder().decode(TokenDTO.self, from: data)
        XCTAssertNil(decoded.refreshToken)
        XCTAssertNil(decoded.refreshExpireAt)
    }

    // MARK: - LoginResponse (Codable)

    func testLoginResponse_codable() throws {
        let resp = LoginResponse(accessToken: "at", refreshToken: "rt", expiresIn: 3600, tokenType: "Bearer", isNewUser: true, totpRequired: false)
        let data = try JSONEncoder().encode(resp)
        let decoded = try JSONDecoder().decode(LoginResponse.self, from: data)
        XCTAssertEqual(decoded.accessToken, "at")
        XCTAssertEqual(decoded.refreshToken, "rt")
        XCTAssertEqual(decoded.expiresIn, 3600)
        XCTAssertEqual(decoded.tokenType, "Bearer")
        XCTAssertEqual(decoded.isNewUser, true)
        XCTAssertEqual(decoded.totpRequired, false)
    }

    // MARK: - RefreshRequest (仅 Encodable)

    func testRefreshRequest_encodable() throws {
        let req = RefreshRequest(refreshToken: "rt_token")
        let data = try JSONEncoder().encode(req)
        XCTAssertTrue(data.count > 0)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["refreshToken"] as? String, "rt_token")
    }

    // MARK: - RefreshResponse (Codable)

    func testRefreshResponse_codable() throws {
        let resp = RefreshResponse(accessToken: "at", refreshToken: "rt", expiresIn: 3600, tokenType: "Bearer")
        let data = try JSONEncoder().encode(resp)
        let decoded = try JSONDecoder().decode(RefreshResponse.self, from: data)
        XCTAssertEqual(decoded.accessToken, "at")
        XCTAssertEqual(decoded.expiresIn, 3600)
    }

    // MARK: - UserProfileResponse (Codable)

    func testUserProfileResponse_codable() throws {
        let resp = UserProfileResponse(userId: 12345, username: "user1", nick: "User One", avatar: "http://avatar", email: "user@test.com", mobile: "13800138000", gender: 1, birthday: "1990-01-01")
        let data = try JSONEncoder().encode(resp)
        let decoded = try JSONDecoder().decode(UserProfileResponse.self, from: data)
        XCTAssertEqual(decoded.userId, 12345)
        XCTAssertEqual(decoded.username, "user1")
        XCTAssertEqual(decoded.nick, "User One")
        XCTAssertEqual(decoded.mobile, "13800138000")
    }

    func testUserProfileResponse_optionalFields_nil() throws {
        let resp = UserProfileResponse(userId: 1, username: "u", nick: "n", avatar: nil, email: nil, mobile: nil, gender: nil, birthday: nil)
        let data = try JSONEncoder().encode(resp)
        let decoded = try JSONDecoder().decode(UserProfileResponse.self, from: data)
        XCTAssertNil(decoded.avatar)
        XCTAssertNil(decoded.email)
        XCTAssertNil(decoded.mobile)
        XCTAssertNil(decoded.gender)
        XCTAssertNil(decoded.birthday)
    }
}
