//
//  PromptTemplateEngineTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/29.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 PromptTemplateEngine 开展自动化单元测试验证。
//
import XCTest
@testable import ZhiYu

final class PromptTemplateEngineTests: XCTestCase {
    
    private var promptEngine: PromptTemplateEngine!
    private var mockSession: URLSession!
    
    // MARK: - Mock 网络协议组件
    
    private class MockURLProtocol: URLProtocol {
        static var mockData: Data?
        static var mockResponse: URLResponse?
        static var mockError: Error?
        
        override class func canInit(with request: URLRequest) -> Bool {
            return true
        }
        
        override class func canonicalRequest(for request: URLRequest) -> URLRequest {
            return request
        }
        
        override func startLoading() {
            if let error = Self.mockError {
                client?.urlProtocol(self, didFailWithError: error)
            } else {
                if let response = Self.mockResponse {
                    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                }
                if let data = Self.mockData {
                    client?.urlProtocol(self, didLoad: data)
                }
                client?.urlProtocolDidFinishLoading(self)
            }
        }
        
        override func stopLoading() {}
    }
    
    override func setUp() {
        super.setUp()
        // 配置自定义 URLProtocol 拦截网络请求
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        mockSession = URLSession(configuration: config)
        
        promptEngine = PromptTemplateEngine(session: mockSession)
        
        // 重置 Mock 数据
        MockURLProtocol.mockData = nil
        MockURLProtocol.mockResponse = nil
        MockURLProtocol.mockError = nil
    }
    
    override func tearDown() async throws {
        await promptEngine.clearCache()
        promptEngine = nil
        mockSession = nil
        try await super.tearDown()
    }
    
    // MARK: - 1. 测试同步占位符参数插值 (parse)
    
    /// 测试单参数和多参数的占位符解析
    func testPromptVariablesInterpolation() {
        let template = "你是一个{{role}}。请根据背景：{{context}}，回答用户输入：{{input}}"
        let variables = [
            "role": "资深架构师",
            "context": "ZhiYu项目遵循垂直化切片架构",
            "input": "依赖注入是如何工作的？"
        ]
        
        let result = promptEngine.parse(template: template, with: variables)
        
        XCTAssertTrue(result.contains("你是一个资深架构师"), "解析结果应正确插值 role 参数。")
        XCTAssertTrue(result.contains("ZhiYu项目遵循垂直化切片架构"), "解析结果应正确插值 context 参数。")
        XCTAssertTrue(result.contains("依赖注入是如何工作的？"), "解析结果应正确插值 input 参数。")
    }
    
    /// 当传入参数字典中缺失模板所需键时，未配对的占位符应保留原样，避免强制擦除导致调试信息丢失
    func testPromptInterpolationWithMissingKeys() {
        let template = "你好，{{name}}！您的运存状况是：{{memory}}GB"
        let variables = ["name": "Constantine"] // 缺少 memory
        
        let result = promptEngine.parse(template: template, with: variables)
        
        XCTAssertTrue(result.contains("你好，Constantine！"), "已提供的参数应顺利替换。")
        XCTAssertTrue(result.contains("{{memory}}"), "未提供对应替换值的占位符应保持现状以备审计。")
    }
    
    // MARK: - 2. 测试 renderPrompt 渲染控制流与降级
    
    /// 场景 A：当智能体技能未配置 remotePromptURLString 时，应 100% 采用本地 systemPromptTemplate 进行插值
    func testRenderPromptDirectlyUsingLocalTemplate() async {
        let skill = AgentSkill(
            skillId: "test_local_skill",
            displayName: "本地测试技能",
            description: "No remote url",
            systemPromptTemplate: "本地模板：{{query}}",
            version: "1.0.0"
        )
        
        let variables = ["query": "本地直接解析测试"]
        let rendered = await promptEngine.renderPrompt(for: skill, with: variables)
        
        XCTAssertEqual(rendered, "本地模板：本地直接解析测试", "无远端链接时，必须直达本地模板。")
    }
    
    /// 场景 B/C：当有远程 URL 且本地无缓存时，静默拉取并写入沙盒缓存。下一次调用直接命中缓存（网络发生异常时亦不中断）
    func testRenderPromptRemoteDownloadAndVersionedCaching() async throws {
        let skill = AgentSkill(
            skillId: "test_remote_skill",
            displayName: "远程测试技能",
            description: "Has remote url",
            systemPromptTemplate: "本地预置兜底：{{query}}",
            remotePromptURLString: "https://cdn.zhiyu.ai/prompts/test_remote_prompt.md",
            version: "2.1.0"
        )
        
        // 1. 设置 Mock 网络数据
        let remotePromptText = "这是拉取到的远程高级提示词内容，输入为：{{query}}"
        MockURLProtocol.mockData = remotePromptText.data(using: .utf8)
        MockURLProtocol.mockResponse = HTTPURLResponse(
            // swiftlint:disable:next force_unwrapping
            url: URL(string: skill.remotePromptURLString!)!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        // 2. 第一次拉取：此时无本地缓存，应触发网络请求
        let variables = ["query": "并发安全测试"]
        let renderedFirst = await promptEngine.renderPrompt(for: skill, with: variables)
        
        XCTAssertEqual(renderedFirst, "这是拉取到的远程高级提示词内容，输入为：并发安全测试", "首次无缓存，应完美渲染拉取到的网络提示词。")
        
        // 3. 此时已写入本地沙盒缓存。我们将网络设置为“崩溃断网”状态（mockError）
        MockURLProtocol.mockData = nil
        MockURLProtocol.mockResponse = nil
        MockURLProtocol.mockError = NSError(domain: "NSURLErrorDomain", code: -1009, userInfo: nil) // 模拟离线
        
        // 4. 第二次拉取：断网状态下由于缓存命中，应该完美不受网络影响，继续返回远程配置
        let renderedSecond = await promptEngine.renderPrompt(for: skill, with: variables)
        XCTAssertEqual(renderedSecond, "这是拉取到的远程高级提示词内容，输入为：并发安全测试", "本地存在版本匹配的缓存时，必须零耗时直接命中，不受网络闪断影响。")
    }
    
    /// 场景 D：存在远程 URL 且无缓存，若网络突发损毁异常，应 100% 优雅降级为本地预置兜底模板
    func testRenderPromptFallbackToLocalTemplateWhenNetworkFailed() async {
        let skill = AgentSkill(
            skillId: "test_fallback_skill",
            displayName: "灾备兜底技能",
            description: "Test fallback",
            systemPromptTemplate: "本地兜底保活：{{query}}",
            remotePromptURLString: "https://cdn.zhiyu.ai/prompts/fallback.md",
            version: "1.0.5"
        )
        
        // 模拟网络请求彻底失败（服务器 500 崩溃）
        MockURLProtocol.mockError = NSError(domain: "NSURLErrorDomain", code: -1004, userInfo: nil)
        
        let variables = ["query": "容灾测试"]
        let rendered = await promptEngine.renderPrompt(for: skill, with: variables)
        
        XCTAssertEqual(rendered, "本地兜底保活：容灾测试", "当网络完全挂毁且无本地缓存时，系统必须平滑兜底，绝对不抛异常或崩溃。")
    }
}
