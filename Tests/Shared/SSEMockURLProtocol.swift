//
//  SSEMockURLProtocol.swift
//  ZhiYuTests
//
//  系统层级：[Test] 单元测试
//  核心职责：URLProtocol mock，用于构造 SSE 流式响应字节流（sse.mock.local），
//            供 App 层测试 LLM 流式请求解析复用。
//            注：UFPCore 测试各自持有一份私有副本（跨 SPM 包无法共享）。
//

import Foundation

/// SSE 流式响应 Mock URLProtocol（App 层测试共享资源）
final class SSEMockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var responseBody: String = ""

    static func reset() {
        responseBody = ""
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "sse.mock.local"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let body = Self.responseBody.data(using: .utf8) ?? Data()
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": "text/event-stream",
                "Content-Length": "\(body.count)",
                "Connection": "close"
            ]
        )
        guard let httpResponse = response else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {
        // 无需清理
    }
}
