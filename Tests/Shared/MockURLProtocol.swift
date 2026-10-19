//
//  MockURLProtocol.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/10/18.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Test] 单元测试共享基础设施
//  核心职责：URLProtocol 网络请求模拟拦截器，在网络底层拦截指定 API Path 并返回预设 JSON/状态码，
//            彻底消除业务层内嵌的 `isMockBackend` 测试分支。
//

import Foundation

/// 通用网络请求 Mock 拦截协议
public final class MockURLProtocol: URLProtocol {

    /// 响应处理闭包签名
    public typealias ResponseHandler = @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)

    // MARK: - 路由表与锁（Swift 6 线程安全）

    private static let lock = NSLock()
    nonisolated(unsafe) private static var handlers: [String: ResponseHandler] = [:]

    /// 注册特定路径的动态 Mock 处理闭包
    /// - Parameters:
    ///   - pathSuffix: 匹配的 URL 路径后缀（如 `/api/v1/auth/phone/login`）
    ///   - handler: 生成响应的闭包
    public static func register(pathSuffix: String, handler: @escaping ResponseHandler) {
        lock.lock()
        defer { lock.unlock() }
        handlers[pathSuffix] = handler
    }

    /// 注册特定路径的静态 JSON 响应
    /// - Parameters:
    ///   - pathSuffix: 匹配的 URL 路径后缀
    ///   - statusCode: HTTP 状态码（默认 200）
    ///   - jsonString: 返回的 JSON 格式字符串
    public static func register(pathSuffix: String, statusCode: Int = 200, jsonString: String) {
        register(pathSuffix: pathSuffix) { request in
            guard let url = request.url else {
                throw URLError(.badURL)
            }
            let response = HTTPURLResponse(
                url: url,
                statusCode: statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: [
                    "Content-Type": "application/json",
                    "Content-Length": "\(jsonString.utf8.count)"
                ]
            ) ?? HTTPURLResponse()
            let data = jsonString.data(using: .utf8) ?? Data()
            return (response, data)
        }
    }

    /// 清空所有已注册的 Mock 规则
    public static func reset() {
        lock.lock()
        defer { lock.unlock() }
        handlers.removeAll()
    }

    /// 创建已配置好 MockURLProtocol 的 URLSessionConfiguration
    public static func makeMockConfiguration() -> URLSessionConfiguration {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return config
    }

    /// 创建已配置好 MockURLProtocol 的 URLSession 实例
    public static func makeMockSession() -> URLSession {
        URLSession(configuration: makeMockConfiguration())
    }

    // MARK: - URLProtocol 标准重写

    public override class func canInit(with request: URLRequest) -> Bool {
        guard let path = request.url?.path else { return false }
        lock.lock()
        defer { lock.unlock() }
        return handlers.keys.contains { path.hasSuffix($0) }
    }

    public override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    public override func startLoading() {
        guard let path = request.url?.path else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        let handler: ResponseHandler? = {
            Self.lock.lock()
            defer { Self.lock.unlock() }
            return Self.handlers.first { path.hasSuffix($0.key) }?.value
        }()

        guard let handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
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

    public override func stopLoading() {
        // 请求取消或完成时无需特殊处理
    }
}
