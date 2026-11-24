//
//  AuthRealBackendUITests.swift
//  ZhiYuUITests
//
//  系统层级：[Tests] UI 联调
//  核心职责：验证独立测试应用的真实会话恢复、后端昵称与订阅数据，缺少凭据明确跳过。
//
import XCTest

@MainActor
final class AuthRealBackendUITests: BaseUITestCase {
    private enum Configuration {
        static let token = "ZHIYU_UI_TEST_ACCESS_TOKEN"
        static let nickname = "ZHIYU_UI_TEST_EXPECTED_NICKNAME"
        static let backendURL = "ZHIYU_UI_TEST_BACKEND_URL"
        static let plan = "ZHIYU_UI_TEST_EXPECTED_PLAN"
        static let subscriptionPath = "api/v1/subscriptions/me"
        static let waitTimeout: TimeInterval = 30
        static let httpOK = 200
        static let businessOK = 0
    }

    override func setUp() async throws {
        // 不使用占位手机号或模拟认证，避免未发生真实请求却报告联调通过。
        injectedAccessToken = try requiredEnvironment(Configuration.token)
        try await super.setUp()
    }

    /// Token 只能通过真实 profile 请求恢复会话，测试宿主不会注入游客身份。
    func testRealBackendConnectivitySmoke() {
        XCTAssertTrue(app.buttons["userProfileMenuButton"].waitForExistence(timeout: Configuration.waitTimeout), "真实 Token 未能恢复会话，请检查后端、证书和凭据")
    }

    /// 昵称必须与测试环境中预先确认的账户资料一致。
    func testProfileLoadedFromRealBackend() throws {
        let expected = try requiredEnvironment(Configuration.nickname)
        let profile = app.buttons["userProfileMenuButton"]
        XCTAssertTrue(profile.waitForExistence(timeout: Configuration.waitTimeout))
        profile.tap()
        let nickname = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", expected)).firstMatch
        XCTAssertTrue(nickname.waitForExistence(timeout: Configuration.waitTimeout), "应显示后端返回的账户昵称")
    }

    /// 对同一凭据验证真实订阅响应，不允许用离线 Free 配额替代接口断言。
    func testSubscriptionQuotaLoadedFromRealBackend() async throws {
        let baseURL = try requiredEnvironment(Configuration.backendURL)
        let expectedPlan = try requiredEnvironment(Configuration.plan)
        let token = try XCTUnwrap(injectedAccessToken)
        let rootURL = try XCTUnwrap(URL(string: baseURL))
        var request = URLRequest(url: rootURL.appendingPathComponent(Configuration.subscriptionPath))
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, Configuration.httpOK)
        let payload = try JSONDecoder().decode(SubscriptionEnvelope.self, from: data)
        XCTAssertEqual(payload.code, Configuration.businessOK)
        XCTAssertEqual(payload.data?.planKey, expectedPlan)
    }

    private func requiredEnvironment(_ key: String) throws -> String {
        guard let value = ProcessInfo.processInfo.environment[key], !value.isEmpty else {
            throw XCTSkip("真实后端验收缺少环境配置：\(key)，本次未完成该项验收")
        }
        return value
    }

    private struct SubscriptionEnvelope: Decodable {
        let code: Int
        let data: SubscriptionPayload?
    }

    private struct SubscriptionPayload: Decodable {
        let planKey: String?
    }
}
