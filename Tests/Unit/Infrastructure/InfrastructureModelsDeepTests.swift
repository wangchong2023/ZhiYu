//
//  InfrastructureModelsDeepTests.swift
//  ZhiYuTests
//
//  系统层级：[L1] 基础设施层测试
//  核心职责：验证 Infrastructure 层纯数据模型的完整性，覆盖 RegionCapabilities /
//           SpeechModels 的 init 默认值、CodingKeys 映射、Codable 编解码往返。
//

import XCTest
@testable import ZhiYu

// MARK: - RegionCapabilities 模型测试

final class RegionCapabilitiesDeepTests: XCTestCase {

    /// 验证 RegionInfo init
    func testRegionInfoInit() {
        let info = RegionCapabilities.RegionInfo(
            loginPageType: "localized",
            pluginMarketUrl: "https://example.com/plugins"
        )
        XCTAssertEqual(info.loginPageType, "localized")
        XCTAssertEqual(info.pluginMarketUrl, "https://example.com/plugins")
    }

    /// 验证 RegionCapabilities init
    func testRegionCapabilitiesInit() {
        let info = RegionCapabilities.RegionInfo(
            loginPageType: "international",
            pluginMarketUrl: "https://overseas.example.com"
        )
        let caps = RegionCapabilities(regions: ["US": info])
        XCTAssertEqual(caps.regions.count, 1)
        XCTAssertEqual(caps.regions["US"]?.loginPageType, "international")
    }

    /// 验证 RegionInfo Codable 往返（snake_case 映射）
    func testRegionInfoCodableRoundTrip() throws {
        let original = RegionCapabilities.RegionInfo(
            loginPageType: "localized",
            pluginMarketUrl: "https://cn.example.com"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RegionCapabilities.RegionInfo.self, from: data)
        XCTAssertEqual(decoded.loginPageType, original.loginPageType)
        XCTAssertEqual(decoded.pluginMarketUrl, original.pluginMarketUrl)
    }

    /// 验证 RegionInfo 从 snake_case JSON 解码
    func testRegionInfoDecodeFromSnakeCaseJSON() throws {
        let json = """
        {
            "login_page_type": "international",
            "plugin_market_url": "https://us.example.com"
        }
        """
        guard let jsonData = json.data(using: .utf8) else {
            XCTFail("JSON 字符串转 Data 失败")
            return
        }
        let decoded = try JSONDecoder().decode(RegionCapabilities.RegionInfo.self, from: jsonData)
        XCTAssertEqual(decoded.loginPageType, "international")
        XCTAssertEqual(decoded.pluginMarketUrl, "https://us.example.com")
    }

    /// 验证 RegionCapabilities Codable 往返
    func testRegionCapabilitiesCodableRoundTrip() throws {
        let cnInfo = RegionCapabilities.RegionInfo(
            loginPageType: "localized",
            pluginMarketUrl: "https://cn.example.com"
        )
        let usInfo = RegionCapabilities.RegionInfo(
            loginPageType: "international",
            pluginMarketUrl: "https://us.example.com"
        )
        let original = RegionCapabilities(regions: ["CN": cnInfo, "US": usInfo])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RegionCapabilities.self, from: data)
        XCTAssertEqual(decoded.regions.count, 2)
        XCTAssertEqual(decoded.regions["CN"]?.loginPageType, "localized")
        XCTAssertEqual(decoded.regions["US"]?.loginPageType, "international")
    }
}

// MARK: - SpeechModels 测试

final class SpeechModelsDeepTests: XCTestCase {

    /// 验证 VoiceRecording init 含默认值
    func testVoiceRecordingInitWithDefaults() {
        let recording = VoiceRecording(title: "测试", text: "内容", language: "zh", duration: 10.0)
        XCTAssertNotNil(recording.id)
        XCTAssertEqual(recording.title, "测试")
        XCTAssertEqual(recording.text, "内容")
        XCTAssertEqual(recording.language, "zh")
        XCTAssertEqual(recording.duration, 10.0)
        XCTAssertNotNil(recording.createdAt)
    }

    /// 验证 VoiceRecording init 含全部参数
    func testVoiceRecordingInitWithAllParameters() {
        let id = UUID()
        let date = Date()
        let recording = VoiceRecording(
            id: id,
            title: "标题",
            text: "文本",
            language: "en",
            duration: 30.0,
            createdAt: date
        )
        XCTAssertEqual(recording.id, id)
        XCTAssertEqual(recording.createdAt, date)
    }

    /// 验证 VoiceRecording Codable 往返
    func testVoiceRecordingCodableRoundTrip() throws {
        let original = VoiceRecording(title: "录音", text: "转写", language: "zh", duration: 5.5)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(VoiceRecording.self, from: data)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.text, original.text)
        XCTAssertEqual(decoded.language, original.language)
        XCTAssertEqual(decoded.duration, original.duration)
    }

    /// 验证 VoiceRecording Identifiable
    func testVoiceRecordingIdentifiable() {
        let recording = VoiceRecording(title: "x", text: "", language: "en", duration: 1.0)
        XCTAssertFalse(recording.id.uuidString.isEmpty)
    }

    /// 验证 SpeechError 所有 case
    func testSpeechErrorAllCases() {
        let errors: [SpeechError] = [.localeNotSupported, .notAuthorized, .audioEngineError]
        XCTAssertEqual(errors.count, 3)
    }

    /// 验证 SpeechError errorDescription 非空
    func testSpeechErrorDescriptions() {
        XCTAssertNotNil(SpeechError.localeNotSupported.errorDescription)
        XCTAssertNotNil(SpeechError.notAuthorized.errorDescription)
        XCTAssertNotNil(SpeechError.audioEngineError.errorDescription)
    }
}
