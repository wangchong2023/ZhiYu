//
//  RemoteConfigServiceTests.swift
//  ZhiYuTests
//
//  系统层级：[L1] 基础设施层测试
//  核心职责：验证 RemoteConfigService 的远端技能拉取、离线兜底灾备、语言资源选择与字段默认值映射。
//

import XCTest
@testable import ZhiYu

// MARK: - RemoteConfigService 单元测试

final class RemoteConfigServiceTests: XCTestCase {

    // MARK: - fetchLLMManifests 离线兜底测试

    /// 验证 fetchLLMManifests 返回非空列表（直接走离线兜底）
    func testFetchLLMManifestsReturnsNonEmptyList() async throws {
        let service = RemoteConfigService()
        let manifests = try await service.fetchLLMManifests()
        XCTAssertFalse(manifests.isEmpty, "fetchLLMManifests 应返回非空列表（离线兜底）")
    }

    /// 验证 fetchLLMManifests 返回的 manifest 包含必要字段
    func testFetchLLMManifestsContainsRequiredFields() async throws {
        let service = RemoteConfigService()
        let manifests = try await service.fetchLLMManifests()
        for manifest in manifests {
            XCTAssertFalse(manifest.modelId.isEmpty, "modelId 不应为空")
            XCTAssertFalse(manifest.vendor.isEmpty, "vendor 不应为空")
            XCTAssertFalse(manifest.displayName.isEmpty, "displayName 不应为空")
        }
    }

    // MARK: - fetchAgentSkills 远端拉取与兜底测试

    /// 验证 fetchAgentSkills 在网络异常时降级返回 fallback skills
    func testFetchAgentSkillsFallsBackOnNetworkError() async throws {
        // 使用 ephemeral session + 极短超时触发网络异常
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 0.001
        config.timeoutIntervalForResource = 0.001
        let session = URLSession(configuration: config)
        let service = RemoteConfigService(session: session)

        let skills = try await service.fetchAgentSkills()
        XCTAssertFalse(skills.isEmpty, "网络异常时应降级返回 fallback skills")
        XCTAssertTrue(skills.contains { $0.skillId == CoreConstants.RemoteConfig.SkillID.chunkingFormatter }, "fallback 应包含 chunking_formatter")
    }

    /// 验证 fetchAgentSkills 在 HTTP 非 200 时降级返回 fallback skills
    func testFetchAgentSkillsFallsBackOnNon200Status() async throws {
        let session = makeMockSession(statusCode: 500, body: Data())
        let service = RemoteConfigService(session: session)

        let skills = try await service.fetchAgentSkills()
        XCTAssertFalse(skills.isEmpty, "HTTP 500 时应降级返回 fallback skills")
    }

    /// 验证 fetchAgentSkills 在业务 code 非 0 时降级返回 fallback skills
    func testFetchAgentSkillsFallsBackOnNonZeroCode() async throws {
        let body = makeApiResponseBody(code: 500, message: "error", data: NSNull())
        let session = makeMockSession(statusCode: 200, body: body)
        let service = RemoteConfigService(session: session)

        let skills = try await service.fetchAgentSkills()
        XCTAssertFalse(skills.isEmpty, "业务 code 非 0 时应降级返回 fallback skills")
    }

    /// 验证 fetchAgentSkills 在 code==0 但 data 为 nil 时降级返回 fallback skills
    func testFetchAgentSkillsFallsBackOnNilData() async throws {
        let body = makeApiResponseBody(code: 0, message: "ok", data: NSNull())
        let session = makeMockSession(statusCode: 200, body: body)
        let service = RemoteConfigService(session: session)

        let skills = try await service.fetchAgentSkills()
        XCTAssertFalse(skills.isEmpty, "data 为 nil 时应降级返回 fallback skills")
    }

    /// 验证 fetchAgentSkills 在 JSON 解码失败时降级返回 fallback skills
    func testFetchAgentSkillsFallsBackOnDecodeFailure() async throws {
        let body = Data("not json".utf8)
        let session = makeMockSession(statusCode: 200, body: body)
        let service = RemoteConfigService(session: session)

        let skills = try await service.fetchAgentSkills()
        XCTAssertFalse(skills.isEmpty, "JSON 解码失败时应降级返回 fallback skills")
    }

    /// 验证 fetchAgentSkills 在远端成功响应时直接返回远端 list（不走 fallback）
    func testFetchAgentSkillsReturnsRemoteListOnSuccess() async throws {
        let remoteSkills: [[String: Any]] = [
            [
                "skillId": "remote_skill_1",
                "displayName": "Remote Skill 1",
                "description": "A remote skill",
                "systemPromptTemplate": "template 1",
                "tags": ["Remote"],
                "version": "2.0.0"
            ]
        ]
        let body = makeApiResponseBody(code: 0, message: "ok", data: remoteSkills)
        let session = makeMockSession(statusCode: 200, body: body)
        let service = RemoteConfigService(session: session)

        let skills = try await service.fetchAgentSkills()
        XCTAssertEqual(skills.count, 1, "远端成功响应应返回 1 个技能")
        XCTAssertEqual(skills.first?.skillId, "remote_skill_1", "应返回远端技能 ID")
        XCTAssertEqual(skills.first?.version, "2.0.0", "应返回远端技能版本")
    }

    // MARK: - getFallbackAgentSkills 内容完整性测试（通过 fetchAgentSkills 间接验证）

    /// 验证 fallback skills 包含全部 3 个技能
    func testFallbackAgentSkillsContainsAllThreeSkills() async throws {
        let session = makeMockSession(statusCode: 500, body: Data())
        let service = RemoteConfigService(session: session)

        let skills = try await service.fetchAgentSkills()
        XCTAssertEqual(skills.count, 3, "fallback 应包含 3 个技能")
        let skillIds = Set(skills.map { $0.skillId })
        XCTAssertTrue(skillIds.contains(CoreConstants.RemoteConfig.SkillID.chunkingFormatter), "应包含 chunking_formatter")
        XCTAssertTrue(skillIds.contains(CoreConstants.RemoteConfig.SkillID.presentationGenerator), "应包含 presentation_generator")
        XCTAssertTrue(skillIds.contains(CoreConstants.RemoteConfig.SkillID.linkDiscovery), "应包含 link_discovery")
    }

    /// 验证 fallback presentationGenerator 技能的内容
    func testFallbackPresentationGeneratorSkillContent() async throws {
        let session = makeMockSession(statusCode: 500, body: Data())
        let service = RemoteConfigService(session: session)

        let skills = try await service.fetchAgentSkills()
        let presentation = skills.first { $0.skillId == CoreConstants.RemoteConfig.SkillID.presentationGenerator }
        XCTAssertNotNil(presentation, "应存在 presentation_generator 技能")
        XCTAssertEqual(presentation?.tags, [CoreConstants.RemoteConfig.SkillTag.synthesis, CoreConstants.RemoteConfig.SkillTag.edgeCloud], "presentation_generator 标签应正确")
        XCTAssertNotNil(presentation?.customParameters, "presentation_generator 应有 customParameters")
    }

    /// 验证 fallback linkDiscovery 技能的内容
    func testFallbackLinkDiscoverySkillContent() async throws {
        let session = makeMockSession(statusCode: 500, body: Data())
        let service = RemoteConfigService(session: session)

        let skills = try await service.fetchAgentSkills()
        let linkDiscovery = skills.first { $0.skillId == CoreConstants.RemoteConfig.SkillID.linkDiscovery }
        XCTAssertNotNil(linkDiscovery, "应存在 link_discovery 技能")
        XCTAssertEqual(linkDiscovery?.tags, [CoreConstants.RemoteConfig.SkillTag.graph, CoreConstants.RemoteConfig.SkillTag.offline], "link_discovery 标签应正确")
        XCTAssertNotNil(linkDiscovery?.customParameters, "link_discovery 应有 customParameters")
    }

    // MARK: - init 默认参数测试

    /// 验证 init() 默认参数使用 .shared session（不崩溃即可）
    func testInitWithDefaultSession() {
        let service = RemoteConfigService()
        XCTAssertNotNil(service, "init() 默认参数应成功创建实例")
    }

    // MARK: - 辅助方法

    /// 构造 Mock URLSession，拦截所有请求并返回固定 statusCode + body
    private func makeMockSession(statusCode: Int, body: Data) -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [RemoteConfigMockURLProtocol.self]
        RemoteConfigMockURLProtocol.responseBody = body
        RemoteConfigMockURLProtocol.statusCode = statusCode
        return URLSession(configuration: config)
    }

    /// 构造 ApiResponse JSON body
    private func makeApiResponseBody(code: Int, message: String, data: Any) -> Data {
        let body: [String: Any] = [
            "code": code,
            "message": message,
            "data": data,
            "requestId": "req-test-\(UUID().uuidString.prefix(8))",
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: body) else {
            return Data()
        }
        return data
    }
}

// MARK: - RemoteConfigService Mock URLProtocol

final class RemoteConfigMockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var responseBody: Data = Data()
    nonisolated(unsafe) static var statusCode: Int = 200

    static func reset() {
        responseBody = Data()
        statusCode = 200
    }

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        let response = HTTPURLResponse(
            url: url,
            statusCode: RemoteConfigMockURLProtocol.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )
        client?.urlProtocol(self, didReceive: response ?? HTTPURLResponse(), cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: RemoteConfigMockURLProtocol.responseBody)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
