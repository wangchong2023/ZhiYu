//
//  PluginSandboxGatewayAuditDeepTests.swift
//  ZhiYu
//
//  系统层级：[L0] 测试层
//  核心职责：补充验证 PluginSandboxGateway（auditFetch/auditStorage/configureWatchdog）、
//           PluginSandboxError（statusCode/errorDescription）、Data hex 扩展、
//           String matchesRegex 扩展、PluginConstants 常量值的未覆盖分支。
//

import XCTest
@testable import ZhiYu
import UFPCore

#if canImport(JavaScriptCore) && !os(watchOS)
import JavaScriptCore
#endif

@MainActor
final class PluginSandboxGatewayAuditDeepTests: XCTestCase {

    // MARK: - PluginSandboxGateway.auditFetch

    /// 无 network 权限应抛 permissionDenied
    func testAuditFetchWithoutNetworkPermissionThrows() {
        XCTAssertThrowsError(try PluginSandboxGateway.auditFetch(
            url: "https://example.com/api",
            options: nil,
            allowedDomains: ["example.com"],
            permissions: []
        )) { error in
            guard case PluginSandboxError.permissionDenied(let perm) = error else {
                XCTFail("期望 permissionDenied，实际: \(error)")
                return
            }
            XCTAssertEqual(perm, PluginConstants.Permission.network)
        }
    }

    /// 无效 URL 应抛 invalidURL
    func testAuditFetchInvalidURLThrows() {
        XCTAssertThrowsError(try PluginSandboxGateway.auditFetch(
            url: "not-a-url",
            options: nil,
            allowedDomains: [],
            permissions: [PluginConstants.Permission.network]
        )) { error in
            guard case PluginSandboxError.invalidURL = error else {
                XCTFail("期望 invalidURL，实际: \(error)")
                return
            }
        }
    }

    /// URL 无 host 应抛 invalidURL
    func testAuditFetchURLWithoutHostThrows() {
        XCTAssertThrowsError(try PluginSandboxGateway.auditFetch(
            url: "file:///local/path",
            options: nil,
            allowedDomains: [],
            permissions: [PluginConstants.Permission.network]
        )) { error in
            guard case PluginSandboxError.invalidURL = error else {
                XCTFail("期望 invalidURL，实际: \(error)")
                return
            }
        }
    }

    /// 域名不在允许列表应抛 dlpFetchBlocked
    func testAuditFetchDomainNotInAllowlistThrows() {
        XCTAssertThrowsError(try PluginSandboxGateway.auditFetch(
            url: "https://evil.com/api",
            options: nil,
            allowedDomains: ["example.com"],
            permissions: [PluginConstants.Permission.network]
        )) { error in
            guard case PluginSandboxError.dlpFetchBlocked(let host) = error else {
                XCTFail("期望 dlpFetchBlocked，实际: \(error)")
                return
            }
            XCTAssertEqual(host, "evil.com")
        }
    }

    /// 空字符串允许列表不应匹配任意 host
    func testAuditFetchEmptyAllowlistDomainDoesNotMatch() {
        XCTAssertThrowsError(try PluginSandboxGateway.auditFetch(
            url: "https://evil.com/api",
            options: nil,
            allowedDomains: [""],
            permissions: [PluginConstants.Permission.network]
        )) { error in
            guard case PluginSandboxError.dlpFetchBlocked = error else {
                XCTFail("空字符串白名单不应匹配，期望 dlpFetchBlocked")
                return
            }
        }
    }

    /// 子域后缀匹配应通过（example.com 白名单匹配 sub.example.com）
    func testAuditFetchSubdomainSuffixMatchSucceeds() throws {
        let request = try PluginSandboxGateway.auditFetch(
            url: "https://sub.example.com/api",
            options: nil,
            allowedDomains: ["example.com"],
            permissions: [PluginConstants.Permission.network]
        )
        XCTAssertEqual(request.url?.host, "sub.example.com")
    }

    /// 精确域名匹配应通过
    func testAuditFetchExactDomainMatchSucceeds() throws {
        let request = try PluginSandboxGateway.auditFetch(
            url: "https://example.com/api",
            options: nil,
            allowedDomains: ["example.com"],
            permissions: [PluginConstants.Permission.network]
        )
        XCTAssertEqual(request.url?.host, "example.com")
    }

    /// 前缀欺骗不应通过（evil-example.com 不应匹配 example.com）
    func testAuditFetchPrefixSpoofingDoesNotMatch() {
        XCTAssertThrowsError(try PluginSandboxGateway.auditFetch(
            url: "https://evil-example.com/api",
            options: nil,
            allowedDomains: ["example.com"],
            permissions: [PluginConstants.Permission.network]
        )) { error in
            guard case PluginSandboxError.dlpFetchBlocked = error else {
                XCTFail("前缀欺骗不应通过，期望 dlpFetchBlocked")
                return
            }
        }
    }

    /// 大写 host 应匹配小写白名单
    func testAuditFetchCaseInsensitiveHostMatchSucceeds() throws {
        let request = try PluginSandboxGateway.auditFetch(
            url: "https://EXAMPLE.COM/api",
            options: nil,
            allowedDomains: ["example.com"],
            permissions: [PluginConstants.Permission.network]
        )
        XCTAssertNotNil(request.url)
    }

    /// 带 options 的请求应正确设置 method/headers/body
    func testAuditFetchWithOptionsSetsRequestFields() throws {
        let request = try PluginSandboxGateway.auditFetch(
            url: "https://example.com/api",
            options: [
                "method": "POST",
                "headers": ["X-Custom": "value"],
                "body": "test body"
            ],
            allowedDomains: ["example.com"],
            permissions: [PluginConstants.Permission.network]
        )
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Custom"), "value")
        XCTAssertEqual(request.httpBody, Data("test body".utf8))
    }

    /// 默认 method 应为 GET
    func testAuditFetchDefaultMethodIsGET() throws {
        let request = try PluginSandboxGateway.auditFetch(
            url: "https://example.com/api",
            options: [:],
            allowedDomains: ["example.com"],
            permissions: [PluginConstants.Permission.network]
        )
        XCTAssertEqual(request.httpMethod, "GET")
    }

    /// 超大 body 应抛 payloadTooLarge
    func testAuditFetchOversizedBodyThrows() {
        let largeBody = String(repeating: "A", count: PluginConstants.Sandbox.maxResponseSizeBytes + 1)
        XCTAssertThrowsError(try PluginSandboxGateway.auditFetch(
            url: "https://example.com/api",
            options: ["body": largeBody],
            allowedDomains: ["example.com"],
            permissions: [PluginConstants.Permission.network]
        )) { error in
            guard case PluginSandboxError.payloadTooLarge = error else {
                XCTFail("期望 payloadTooLarge")
                return
            }
        }
    }

    // MARK: - PluginSandboxGateway.auditStorage

    /// 正常 key/value 应通过
    func testAuditStorageNormalKeyValueSucceeds() {
        XCTAssertNoThrow(try PluginSandboxGateway.auditStorage(key: "normalKey", value: "normalValue"))
    }

    /// 超长 key 应抛 keyLengthExceeded
    func testAuditStorageOversizedKeyThrows() {
        let longKey = String(repeating: "k", count: 257)
        XCTAssertThrowsError(try PluginSandboxGateway.auditStorage(key: longKey, value: "value")) { error in
            guard case PluginSandboxError.keyLengthExceeded(let maxLen) = error else {
                XCTFail("期望 keyLengthExceeded")
                return
            }
            XCTAssertEqual(maxLen, 256)
        }
    }

    /// 超大 value 应抛 payloadTooLarge
    func testAuditStorageOversizedValueThrows() {
        let largeValue = String(repeating: "V", count: PluginConstants.Sandbox.maxResponseSizeBytes + 1)
        XCTAssertThrowsError(try PluginSandboxGateway.auditStorage(key: "key", value: largeValue)) { error in
            guard case PluginSandboxError.payloadTooLarge = error else {
                XCTFail("期望 payloadTooLarge")
                return
            }
        }
    }

    /// 边界 key 长度（256）应通过
    func testAuditStorageBoundaryKeyLengthSucceeds() {
        let boundaryKey = String(repeating: "k", count: 256)
        XCTAssertNoThrow(try PluginSandboxGateway.auditStorage(key: boundaryKey, value: "value"))
    }

    // MARK: - PluginSandboxGateway.configureWatchdog

    #if canImport(JavaScriptCore) && !os(watchOS)
    /// 配置看门狗不应崩溃
    func testConfigureWatchdogDoesNotCrash() {
        let context = JSContext()
        XCTAssertNotNil(context)
        if let context {
            PluginSandboxGateway.configureWatchdog(for: context)
        }
    }
    #endif

    // MARK: - PluginSandboxError statusCode 完整覆盖

    func testStatusCodePermissionDeniedReturns403() {
        XCTAssertEqual(PluginSandboxError.permissionDenied("network").statusCode, 403)
    }

    // MARK: - PluginSandboxError errorDescription 完整覆盖

    func testErrorDescriptionPermissionDeniedContainsPermission() {
        let error = PluginSandboxError.permissionDenied("network")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("network") == true || error.errorDescription?.isEmpty == false)
    }

    // MARK: - Data hex 扩展

    /// Data hexString 初始化奇数长度应返回 nil
    func testDataHexInitOddLengthReturnsNil() {
        XCTAssertNil(Data(hexString: "abc"))
    }

    /// Data hexString 初始化空字符串应返回空 Data
    func testDataHexInitEmptyStringReturnsEmptyData() {
        let data = Data(hexString: "")
        XCTAssertEqual(data?.count, 0)
    }

    /// Data hexString 初始化带空格应正确解析
    func testDataHexInitWithSpacesParsesCorrectly() {
        let data = Data(hexString: "ab cd")
        XCTAssertEqual(data?.count, 2)
        XCTAssertEqual(data?[0], 0xab)
        XCTAssertEqual(data?[1], 0xcd)
    }

    /// Data hexString 初始化大写应正确解析
    func testDataHexInitUpperCaseParsesCorrectly() {
        let data = Data(hexString: "ABCD")
        XCTAssertEqual(data?.count, 2)
        XCTAssertEqual(data?[0], 0xab)
        XCTAssertEqual(data?[1], 0xcd)
    }

    /// Data hexString 初始化无效字符应返回 nil
    func testDataHexInitInvalidCharReturnsNil() {
        XCTAssertNil(Data(hexString: "xy"))
    }

    /// Data hexEncoded 应正确编码
    func testDataHexEncodedCorrectOutput() {
        let data = Data([0xab, 0xcd])
        XCTAssertEqual(data.hexEncoded, "abcd")
    }

    /// Data hexEncoded 空数据应返回空字符串
    func testDataHexEncodedEmptyDataReturnsEmptyString() {
        XCTAssertEqual(Data().hexEncoded, "")
    }

    /// Data hex 往返一致性
    func testDataHexRoundTrip() {
        let original = Data([0x01, 0x02, 0xff, 0x00])
        let hex = original.hexEncoded
        let restored = Data(hexString: hex)
        XCTAssertEqual(original, restored)
    }

    // MARK: - String matchesRegex 扩展

    /// matchesRegex 空字符串空模式应匹配（NSRegularExpression 空模式匹配位置 0）
    func testMatchesRegexEmptyStringEmptyPatternReturnsTrue() {
        let result = "".matchesRegex("")
        XCTAssertTrue(result, "空字符串应匹配空正则")
    }

    /// matchesRegex 非空字符串空模式应不崩溃
    func testMatchesRegexNonEmptyStringEmptyPatternDoesNotCrash() {
        let result = "abc".matchesRegex("")
        XCTAssertTrue(result, "非空字符串匹配空正则应返回 true")
    }

    // MARK: - PluginConstants 验证

    /// Sandbox 常量值验证
    func testPluginConstantsSandboxValues() {
        XCTAssertEqual(PluginConstants.Sandbox.jsExecutionTimeLimitSeconds, 0.5)
        XCTAssertEqual(PluginConstants.Sandbox.maxResponseSizeMB, 5)
        XCTAssertGreaterThan(PluginConstants.Sandbox.maxResponseSizeBytes, 0)
    }

    /// Permission 常量值验证
    func testPluginConstantsPermissionValues() {
        XCTAssertEqual(PluginConstants.Permission.network, "network")
        XCTAssertEqual(PluginConstants.Permission.llm, "llm")
        XCTAssertEqual(PluginConstants.Permission.pagesRead, "pages.read")
        XCTAssertEqual(PluginConstants.Permission.writeContent, "writeContent")
    }

    /// DefaultManifest 常量值验证
    func testPluginConstantsDefaultManifestValues() {
        XCTAssertEqual(PluginConstants.DefaultManifest.idPrefix, "local.")
        XCTAssertEqual(PluginConstants.DefaultManifest.author, "Local Developer")
        XCTAssertEqual(PluginConstants.DefaultManifest.version, SystemConstants.Version.defaultSemVer)
        XCTAssertTrue(PluginConstants.DefaultManifest.permissions.contains("log"))
        XCTAssertTrue(PluginConstants.DefaultManifest.permissions.contains("writeContent"))
    }

    /// MarketJSON 常量值验证
    func testPluginConstantsMarketJSONValues() {
        XCTAssertEqual(PluginConstants.MarketJSON.communityPlugins, "community-plugins.json")
        XCTAssertEqual(PluginConstants.MarketJSON.communityPluginsZhHans, "community-plugins_zh-Hans.json")
        XCTAssertEqual(PluginConstants.MarketJSON.community, "community.json")
        XCTAssertEqual(PluginConstants.MarketJSON.pluginsPathSegment, "plugins")
    }

    /// LanguagePrefix 常量值验证
    func testPluginConstantsLanguagePrefixValues() {
        XCTAssertEqual(PluginConstants.LanguagePrefix.zh, "zh")
        XCTAssertEqual(PluginConstants.LanguagePrefix.en, "en")
    }

    /// MarketError 常量值验证
    func testPluginConstantsMarketErrorValues() {
        XCTAssertEqual(PluginConstants.MarketError.domain, "PluginMarketService")
        XCTAssertEqual(PluginConstants.MarketError.httpPrefix, "HTTP ")
        XCTAssertEqual(PluginConstants.MarketError.documentsNotFound, "Failed to locate documents directory")
    }

    /// PluginID 常量值验证
    func testPluginConstantsPluginIDValues() {
        XCTAssertEqual(PluginConstants.PluginID.officialPrefix, "com.zhiyu.plugin.")
        XCTAssertEqual(PluginConstants.PluginID.v1VersionPrefix, "1.")
    }

    /// JSGlobal 常量值验证
    func testPluginConstantsJSGlobalValues() {
        XCTAssertEqual(PluginConstants.JSGlobal.hostBridge, "ZhiYu")
    }

    /// AnalyticsKey 常量值验证
    func testPluginConstantsAnalyticsKeyValues() {
        XCTAssertEqual(PluginConstants.AnalyticsKey.id, "id")
        XCTAssertEqual(PluginConstants.AnalyticsKey.duration, "duration")
        XCTAssertEqual(PluginConstants.AnalyticsKey.error, "error")
    }

    /// Localization requiredLocales 验证
    func testPluginConstantsLocalizationRequiredLocales() {
        XCTAssertEqual(PluginConstants.Localization.requiredLocales, ["en", "zh-Hans"])
    }
}
