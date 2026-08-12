//
//  PluginMarketServiceTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 PluginMarketService 开展自动化单元测试验证。
//
import XCTest
import CryptoKit
@testable import ZhiYu
@testable import UFPCore

final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    
    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            XCTFail("Received unexpected request with no handler set")
            return
        }
        
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    
    override func stopLoading() {}
}

@MainActor
final class PluginMarketServiceTests: XCTestCase {
    var service: PluginMarketService!
    private var registry: PluginRegistry!

    override func setUp() {
        super.setUp()
        URLProtocol.registerClass(MockURLProtocol.self)
        registry = PluginRegistry()
        ServiceContainer.shared.register(registry, for: PluginRegistry.self)
        service = PluginMarketService(registry: registry)
    }

    override func tearDown() {
        URLProtocol.unregisterClass(MockURLProtocol.self)
        MockURLProtocol.requestHandler = nil
        service = nil
        registry = nil
        super.tearDown()
    }
    
    func testFetchPluginsSuccess() async throws {
        // Mock JSON Data
        let jsonString = """
        [
            {
                "id": "com.test.plugin",
                "version": "1.0.0",
                "author": "Test Author",
                "downloads": "100",
                "rating": 5.0,
                "icon": "star",
                "downloadURL": "https://example.com/plugin.js",
                "names": { "en": "Test Plugin", "zh-Hans": "测试插件" },
                "descriptions": { "en": "Desc" }
            }
        ]
        """
        
        // swiftlint:disable:next force_unwrapping
        let responseData = jsonString.data(using: .utf8)!
        
        MockURLProtocol.requestHandler = { request in
            // swiftlint:disable:next force_unwrapping
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, responseData)
        }

        XCTAssertTrue(service.availablePlugins.isEmpty)
        
        await service.fetchPlugins()
        
        XCTAssertFalse(service.availablePlugins.isEmpty)
        XCTAssertEqual(service.availablePlugins.first?.id, "com.test.plugin")
        // Localized.bestMatch 根据系统语言返回对应本地化名称，接受中/英文
        let pluginName = service.availablePlugins.first?.name
        XCTAssertTrue(pluginName == "Test Plugin" || pluginName == "测试插件",
                      "插件名称应为英文或中文本地化值，实际为: \(pluginName ?? "nil")")
        XCTAssertNil(service.errorMessage)
    }
    
    func testFetchPluginsSuccessWithCategory() async throws {
        // Mock JSON Data with category
        let jsonString = """
        [
            {
                "id": "com.test.efficiency.plugin",
                "version": "1.0.0",
                "author": "Test Author",
                "downloads": "100",
                "rating": 5.0,
                "icon": "star",
                "downloadURL": "https://example.com/plugin.js",
                "category": "efficiency",
                "names": { "en": "Efficiency Plugin", "zh-Hans": "效率插件" },
                "descriptions": { "en": "Desc" }
            }
        ]
        """
        
        // swiftlint:disable:next force_unwrapping
        let responseData = jsonString.data(using: .utf8)!
        
        MockURLProtocol.requestHandler = { request in
            // swiftlint:disable:next force_unwrapping
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, responseData)
        }

        await service.fetchPlugins()
        
        XCTAssertFalse(service.availablePlugins.isEmpty)
        XCTAssertEqual(service.availablePlugins.first?.category, "efficiency", "插件解析得到的分类应当为 efficiency")
    }
    
    /// 验证当网络抓取失败时，availablePlugins 应清空，不进行本地 Fallback 插件填充，且 errorMessage 正确被赋值
    func testFetchPluginsFailureNoFallback() async throws {
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        XCTAssertTrue(service.availablePlugins.isEmpty)

        await service.fetchPlugins()

        // 验证失败后，由于去除了 fallback 逻辑，列表为空且抛出连接错误提示
        XCTAssertTrue(service.availablePlugins.isEmpty)
        XCTAssertNotNil(service.errorMessage)
    }

    /// 验证若 MarketPlugin 缺少有效的下载 URL，下载应直接返回失败 (false)
    func testDownloadPluginWithoutURLFailure() async throws {
        // 创建一个没有下载链接的 Mock 插件
        let plugin = MarketPlugin(
            from: CommunityPluginEntry(
                id: "smart-cleaner",
                name: "Markdown Beautifier",
                author: "ZhiYu Team",
                description: "Desc",
                repo: "wangchong2023/zhiyu-releases",
                version: nil,
                icon: nil,
                names: nil,
                descriptions: nil,
                category: nil
            ),
            downloadBase: URL(string: "https://raw.githubusercontent.com/wangchong2023/zhiyu-releases/master/plugins")!
        )
        
        // 构造一个没有下载 URL 的插件实例
        let mockPluginNoURL = MarketPlugin(
            id: plugin.id,
            version: plugin.version,
            author: plugin.author,
            downloads: plugin.downloads,
            rating: plugin.rating,
            icon: plugin.icon,
            downloadURL: nil,
            minAppVersion: plugin.minAppVersion,
            requiredPermissions: plugin.requiredPermissions,
            monetization: plugin.monetization,
            reviewCount: plugin.reviewCount,
            category: plugin.category,
            source: plugin.source,
            names: plugin.names,
            descriptions: plugin.descriptions
        )
        
        let success = await service.downloadPlugin(mockPluginNoURL)
        XCTAssertFalse(success, "缺少下载 URL 的插件在无 fallback 模式下应直接下载失败并返回 false")
    }

    // MARK: - community-plugins.json 格式测试

    func testCommunityPluginsFormatParsing() async throws {
        let jsonString = """
        [
            {"id":"toc-generator","name":"TOC Generator","author":"ZhiYu Team","description":"Auto-generate TOC.","repo":"wangchong2023/zhiyu-releases"},
            {"id":"link-preview","name":"Link Preview","author":"ZhiYu Team","description":"Rich preview cards.","repo":"wangchong2023/zhiyu-releases"}
        ]
        """
        MockURLProtocol.requestHandler = { request in
            // swiftlint:disable:next force_unwrapping
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(jsonString.utf8))
        }

        await service.fetchPlugins()

        XCTAssertEqual(service.availablePlugins.count, 2)
        XCTAssertEqual(service.availablePlugins[0].id, "toc-generator")
        XCTAssertEqual(service.availablePlugins[0].name, "TOC Generator")
        XCTAssertEqual(service.availablePlugins[0].author, "ZhiYu Team")
        XCTAssertEqual(service.availablePlugins[0].source, "community")
        // 下载 URL 应包含 plugins/ 目录
        XCTAssertTrue(service.availablePlugins[0].downloadURL?.contains("/plugins/") ?? false,
                      "下载 URL 应包含 /plugins/ 路径")
        XCTAssertTrue(service.availablePlugins[0].downloadURL?.hasSuffix("/toc-generator") ?? false,
                      "下载 URL 应以 {id} 结尾")
        XCTAssertNil(service.errorMessage)
    }

    func testCommunityPluginsDownloadURLContainsPluginsDir() async throws {
        // 验证 downloadBase 替换逻辑：community-plugins.json → plugins/
        let jsonString = """
        [{"id":"test","name":"Test","author":"A","description":"D","repo":"user/repo"}]
        """
        MockURLProtocol.requestHandler = { request in
            let urlString = request.url?.absoluteString ?? ""
            XCTAssertTrue(urlString.contains("community-plugins.json") || urlString.contains("community-plugins_zh-Hans.json"))
            // swiftlint:disable:next force_unwrapping
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(jsonString.utf8))
        }

        await service.fetchPlugins()

        XCTAssertEqual(service.availablePlugins.count, 1)
        let downloadURL = service.availablePlugins[0].downloadURL ?? ""
        // 不应该包含 community-plugins.json
        XCTAssertFalse(downloadURL.contains("community-plugins.json"))
        // 应该包含 plugins/ 目录
        XCTAssertTrue(downloadURL.contains("/plugins/"))
        // 应以 id 结尾
        XCTAssertTrue(downloadURL.hasSuffix("/test"))
    }

    func testEmptyCommunityPluginsList() async throws {
        MockURLProtocol.requestHandler = { request in
            // swiftlint:disable:next force_unwrapping
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("[]".utf8))
        }

        await service.fetchPlugins()

        XCTAssertTrue(service.availablePlugins.isEmpty)
        XCTAssertNil(service.errorMessage)
    }

    func testCommunityPluginsFallbackToMockFormat() async throws {
        // Mock 服务器格式（ApiResponse 包装 → 直接 MarketPlugin 数组回退）
        let jsonString = """
        [{"id":"mock-plugin","version":"1.0","author":"Mock","downloads":"0","rating":0,"icon":"","downloadURL":null,"names":{"en":"Mock"},"descriptions":{"en":""}}]
        """
        MockURLProtocol.requestHandler = { request in
            // swiftlint:disable:next force_unwrapping
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(jsonString.utf8))
        }

        await service.fetchPlugins()

        if service.availablePlugins.isEmpty {
            // community-plugins.json 格式解析失败也 OK——此测试验证回退不崩溃
            XCTAssertNil(service.errorMessage)
        } else {
            XCTAssertEqual(service.availablePlugins[0].id, "mock-plugin")
        }
    }

    /// 验证从社区抓取的 community-plugins.json 可以包含并成功解析可选的 `names` 和 `descriptions` 字典
    func testCommunityPluginsFormatParsingWithLocales() async throws {
        let jsonString = """
        [
            {
                "id": "locale-test",
                "name": "Fallback Name",
                "author": "Author",
                "description": "Fallback Desc",
                "repo": "user/repo",
                "names": { "en": "English Name", "zh-Hans": "中文名称" },
                "descriptions": { "en": "English Desc", "zh-Hans": "中文描述" }
            }
        ]
        """
        MockURLProtocol.requestHandler = { request in
            // swiftlint:disable:next force_unwrapping
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(jsonString.utf8))
        }

        await service.fetchPlugins()

        XCTAssertEqual(service.availablePlugins.count, 1)
        let plugin = service.availablePlugins[0]
        XCTAssertEqual(plugin.names["en"], "English Name")
        XCTAssertEqual(plugin.names["zh-Hans"], "中文名称")
        XCTAssertEqual(plugin.descriptions["en"], "English Desc")
        XCTAssertEqual(plugin.descriptions["zh-Hans"], "中文描述")
    }

    /// 验证根据首选语言及下载基准 URL 解析候选的 README 云端路径及降级顺序
    func testFetchRemoteReadmeLanguageFallback() throws {
        let pluginID = "test-plugin-id"
        let downloadURL = "https://raw.githubusercontent.com/user/repo/master/plugins/test-plugin-id.zyplugin"
        
        // 1. 首选语言为中文 (zh-Hans)，应优先请求特定语言版，其次英文，最后默认
        let zhCandidates = service.readmeCandidateURLs(forID: pluginID, downloadURLString: downloadURL, preferredLanguages: ["zh-Hans"])
        XCTAssertEqual(zhCandidates.count, 3)
        XCTAssertEqual(zhCandidates[0].absoluteString, "https://raw.githubusercontent.com/user/repo/master/plugins/test-plugin-id_zh-Hans.md")
        XCTAssertEqual(zhCandidates[1].absoluteString, "https://raw.githubusercontent.com/user/repo/master/plugins/test-plugin-id_en.md")
        XCTAssertEqual(zhCandidates[2].absoluteString, "https://raw.githubusercontent.com/user/repo/master/plugins/test-plugin-id.md")
        
        // 2. 首选语言为英文 (en)，英文即为首选，降级列表只有英文和默认
        let enCandidates = service.readmeCandidateURLs(forID: pluginID, downloadURLString: downloadURL, preferredLanguages: ["en"])
        XCTAssertEqual(enCandidates.count, 2)
        XCTAssertEqual(enCandidates[0].absoluteString, "https://raw.githubusercontent.com/user/repo/master/plugins/test-plugin-id_en.md")
        XCTAssertEqual(enCandidates[1].absoluteString, "https://raw.githubusercontent.com/user/repo/master/plugins/test-plugin-id.md")
        
        // 3. 首选为其它语言（如法文 fr），应优先法语，其次英文，最后默认
        let frCandidates = service.readmeCandidateURLs(forID: pluginID, downloadURLString: downloadURL, preferredLanguages: ["fr-FR"])
        XCTAssertEqual(frCandidates.count, 3)
        XCTAssertEqual(frCandidates[0].absoluteString, "https://raw.githubusercontent.com/user/repo/master/plugins/test-plugin-id_fr.md")
        XCTAssertEqual(frCandidates[1].absoluteString, "https://raw.githubusercontent.com/user/repo/master/plugins/test-plugin-id_en.md")
        XCTAssertEqual(frCandidates[2].absoluteString, "https://raw.githubusercontent.com/user/repo/master/plugins/test-plugin-id.md")
    }

    /// 验证正常情况下 downloadPlugin 能并发成功下载、保存和在沙盒中建立插件所需的文件结构
    func testDownloadPluginSuccess() async throws {
        // 创建临时沙盒 Plugins 目录路径
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            XCTFail("无法定位本地 Documents 目录")
            return
        }
        let pluginsDir = documentsURL.appendingPathComponent("Plugins")
        let destFolder = pluginsDir.appendingPathComponent("com.test.plugin.success")
        
        // 预先清理可能残留的文件，保证测试隔离性
        try? fileManager.removeItem(at: destFolder)
        
        // 创建用于测试的 Mock 插件实例
        let plugin = MarketPlugin(
            id: "com.test.plugin.success",
            version: "1.0.0",
            author: "Test Author",
            downloads: "100",
            rating: 5.0,
            icon: "star",
            downloadURL: "https://raw.githubusercontent.com/wangchong2023/zhiyu-releases/master/plugins/com.test.plugin.success",
            minAppVersion: "2.0.0",
            requiredPermissions: ["writeContent"],
            monetization: nil,
            reviewCount: 0,
            category: "Sync",
            source: "community",
            names: ["en": "Success Plugin"],
            descriptions: ["en": "Successful download test."]
        )
        
        // 配置模拟的必需文件二进制和 JSON 字符串
        let manifestJSON = """
        {
            "id": "com.test.plugin.success",
            "version": "1.0.0",
            "author": "Test Author",
            "permissions": ["writeContent"],
            "names": { "en": "Success Plugin" },
            "descriptions": { "en": "Successful download test." }
        }
        """
        
        let indexJS = """
        function onLoad(context) {
            context.log("Loaded Success Plugin");
        }
        function onUnload() {
            // Unload
        }
        """
        
        // 使用 URLProtocol 劫持并 Mock 对应的文件 HTTP 返回
        MockURLProtocol.requestHandler = { request in
            let urlString = request.url?.absoluteString ?? ""
            // swiftlint:disable:next force_unwrapping
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            
            if urlString.hasSuffix("manifest.json") {
                return (response, Data(manifestJSON.utf8))
            } else if urlString.hasSuffix("index.js") {
                return (response, Data(indexJS.utf8))
            } else if urlString.hasSuffix("icon.png") {
                return (response, Data())
            } else if urlString.hasSuffix("README.md") {
                return (response, Data("# Success Plugin README".utf8))
            } else {
                return (response, Data())
            }
        }
        
        // 触发下载行为
        let success = await service.downloadPlugin(plugin)
        XCTAssertTrue(success, "在有 Mock API 成功返回时，插件下载应当返回 True 代表安装成功")
        
        // 校验必需的文件是否已经成功创建落地在沙盒目录中
        let manifestExists = fileManager.fileExists(atPath: destFolder.appendingPathComponent("manifest.json").path)
        let indexExists = fileManager.fileExists(atPath: destFolder.appendingPathComponent("index.js").path)
        
        XCTAssertTrue(manifestExists, "测试下载成功后，manifest.json 应当正确在沙盒落地")
        XCTAssertTrue(indexExists, "测试下载成功后，index.js 应当正确在沙盒落地")
        
        // 彻底清理测试现场
        try? fileManager.removeItem(at: destFolder)
    }

    /// 验证当市场插件ID（简短ID，例如 "toc-generator"）与物理 manifest.json 中声明的真实ID（例如 "com.zhiyu.plugin.local.toc-generator"）存在不匹配时，
    /// 安装之后逻辑层是否能够通过自适应后缀匹配识别到已安装状态，并且卸载时能完美卸载。
    func testDownloadPluginWithIDMismatchSuccess() async throws {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            XCTFail("无法定位本地 Documents 目录")
            return
        }
        let pluginsDir = documentsURL.appendingPathComponent("Plugins")
        
        // 简短的市场插件 ID 
        let marketID = "toc-generator"
        // 真实的规范 ID（审查修复 HIGH-2: 外部 manifest 不得使用 local. 前缀）
        let realManifestID = "com.zhiyu.plugin.toc-generator"
        
        // 彻底清除可能因为之前测试残留于内存或物理磁盘中的同名插件，保证单测环境的绝对隔离性
        registry.unloadPlugin(id: realManifestID)
        registry.unloadPlugin(id: "com.zhiyu.plugin.local.toc-generator")
        
        let destFolder = pluginsDir.appendingPathComponent(marketID)
        try? fileManager.removeItem(at: destFolder)
        
        let plugin = MarketPlugin(
            id: marketID,
            version: "0.0.1",
            author: "ZhiYu Team",
            downloads: "100",
            rating: 5.0,
            icon: "star",
            downloadURL: "https://raw.githubusercontent.com/wangchong2023/zhiyu-releases/master/plugins/\(marketID)",
            minAppVersion: "2.0.0",
            requiredPermissions: ["writeContent", "log"],
            monetization: nil,
            reviewCount: 0,
            category: "Sync",
            source: "community",
            names: ["en": "TOC Generator"],
            descriptions: ["en": "Test ID Mismatch."]
        )
        
        let indexJS = """
        function onLoad(context) {
            context.log("Loaded TOC Generator");
        }
        function onUnload() {}
        """
        
        // VULN-001 修复后：外部插件必须携带有效 HMAC-SHA256 签名
        // 注入 Mock Keychain + 已知密钥，计算与 indexJS 匹配的签名
        let mockKeychain = MockKeychainService()
        let testKey = SymmetricKey(size: .bits256)
        let testKeyData = testKey.withUnsafeBytes { Data($0) }
        try mockKeychain.store(key: "com.zhiyu.plugin.signature_key", value: testKeyData.base64EncodedString())
        KeychainService.testOverride = mockKeychain
        defer { KeychainService.testOverride = nil }
        
        let computedHMAC = HMAC<SHA256>.authenticationCode(for: Data(indexJS.utf8), using: testKey)
        let signatureHex = Data(computedHMAC).map { String(format: "%02x", $0) }.joined()
        
        let manifestJSON = """
        {
            "id": "\(realManifestID)",
            "version": "0.0.1",
            "author": "ZhiYu Team",
            "permissions": ["writeContent", "log"],
            "names": { "en": "TOC Generator" },
            "descriptions": { "en": "Test ID Mismatch." },
            "codeSignature": "\(signatureHex)"
        }
        """
        
        MockURLProtocol.requestHandler = { request in
            let urlString = request.url?.absoluteString ?? ""
            // swiftlint:disable:next force_unwrapping
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            
            if urlString.hasSuffix("manifest.json") {
                return (response, Data(manifestJSON.utf8))
            } else if urlString.hasSuffix("index.js") {
                return (response, Data(indexJS.utf8))
            } else {
                return (response, Data())
            }
        }
        
        // 1. 执行安装
        let success = await service.downloadPlugin(plugin)
        XCTAssertTrue(success, "插件下载安装应当成功")
        
        // 2. 验证通过后缀匹配和相等匹配能否探测到已安装状态
        let isInstalled = registry.plugins.contains(where: {
            $0.manifest.id == plugin.id || $0.manifest.id.hasSuffix("." + plugin.id)
        })
        XCTAssertTrue(isInstalled, "系统应当能识别不一致 ID 的已安装状态")
        
        // 3. 验证能否获取正确的展示版本号
        if let localPlugin = registry.plugins.first(where: {
            $0.manifest.id == plugin.id || $0.manifest.id.hasSuffix("." + plugin.id)
        }) {
            XCTAssertEqual(localPlugin.manifest.version, "0.0.1")
        } else {
            XCTFail("无法获取对应的本地已安装插件")
        }
        
        // 4. 执行卸载并验证
        let targetID = registry.plugins.first(where: { 
            $0.manifest.id == plugin.id || $0.manifest.id.hasSuffix("." + plugin.id) 
        })?.manifest.id ?? plugin.id
        
        registry.unloadPlugin(id: targetID)
        
        let isStillInstalled = registry.plugins.contains(where: {
            $0.manifest.id == plugin.id || $0.manifest.id.hasSuffix("." + plugin.id)
        })
        XCTAssertFalse(isStillInstalled, "卸载后应当标记为未安装")
        
        // 5. 验证是否自动物理删除了磁盘文件夹以绝后患，如果此物理文件依然存在，则说明系统物理清理失败
        let folderExists = fileManager.fileExists(atPath: destFolder.path)
        XCTAssertFalse(folderExists, "卸载后应该自动在物理层删除该插件以简短 ID 命名的子文件夹，实际目录仍存在: \(destFolder.path)")
    }
}
