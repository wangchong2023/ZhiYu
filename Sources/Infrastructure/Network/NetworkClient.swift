//
//  NetworkClient.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/28.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：全局 HTTP 网络客户端，支持自动注入 Bearer Token 以及 401 无感刷新双重拦截。
//

import Foundation
import UFPCore

#if DEBUG
/// 仅用于开发环境的自签名证书信任代理
final class TrustAllSessionDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // 开发环境下无条件信任所有证书（包括自签名）
        if let serverTrust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
#endif

public actor NetworkClient {
    public static let shared = NetworkClient()
    
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    
    #if DEBUG
    /// 单元测试专用：测试专用的 URLSession，允许拦截和 Mock HTTP 请求
    private var testSession: URLSession?
    
    /// 单元测试专用：设置测试专用的 URLSession
    /// - Parameter session: 测试专用的 URLSession 实例
    public func setTestSession(_ session: URLSession?) {
        self.testSession = session
    }
    
    /// 单元测试专用：等待当前的 refreshTask 彻底完成
    public func awaitRefreshTask() async {
        if let task = refreshTask {
            _ = await task.value
        }
    }
    #endif
    
    /// 当前活跃的 URLSession 实例
    private var activeSession: URLSession {
        #if DEBUG
        return testSession ?? session
        #else
        return session
        #endif
    }
    
    // 无感刷新防并发控制
    private var isRefreshing = false
    private var refreshTask: Task<Result<String, Error>, Never>?
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = AppConstants.Network.requestTimeout
        config.timeoutIntervalForResource = AppConstants.Network.resourceTimeout
        
        #if DEBUG
        // DEBUG 模式下允许自签名 HTTPS 证书
        let delegate = TrustAllSessionDelegate()
        self.session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        #else
        self.session = URLSession(configuration: config)
        #endif
        
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }
    
    /// 发起带有数据载荷的请求 (POST, PUT 等)
    public func request<T: Codable, Body: Encodable>(
        path: String,
        method: String = "POST",
        body: Body? = nil,
        requiresAuth: Bool = true
    ) async throws -> T {
        return try await performRequest(path: path, method: method, body: body, requiresAuth: requiresAuth, isRetry: false)
    }
    
    /// 发起无数据载荷的请求 (GET 等)
    public func request<T: Codable>(
        path: String,
        method: String = "GET",
        requiresAuth: Bool = true
    ) async throws -> T {
        let dummyBody: EmptyData? = nil
        return try await performRequest(path: path, method: method, body: dummyBody, requiresAuth: requiresAuth, isRetry: false)
    }
    
    // MARK: - Multipart 文件上传

    /// 发起 multipart/form-data 文件上传请求，返回后端回传的资源字符串（通常为文件 URL）
    /// - Parameters:
    ///   - path: 请求路径
    ///   - fileData: 文件二进制数据
    ///   - fileName: 文件名（含扩展名）
    ///   - mimeType: MIME 类型，推荐使用 AppConstants.Network.mimeTypePNG / mimeTypeJPEG
    ///   - requiresAuth: 是否需要携带 Bearer Token
    public func uploadFile(
        path: String,
        fileData: Data,
        fileName: String,
        mimeType: String,
        requiresAuth: Bool = true
    ) async throws -> String {
        guard let url = URL(string: AppConfig.backendBaseURL + path) else {
            throw NetworkError.invalidURL
        }

        // 生成唯一 boundary 分隔符
        let boundary = AppConstants.Network.multipartBoundaryPrefix + UUID().uuidString
        let crlf = AppConstants.Network.crlf

        var request = URLRequest(url: url)
        request.httpMethod = AppConstants.Network.methodPOST
        request.addValue(
            AppConstants.Network.contentTypeMultipartPrefix + boundary,
            forHTTPHeaderField: AppConstants.Network.headerContentType
        )
        if requiresAuth, let token = try? KeychainService.shared.retrieve(key: AppConstants.Network.jwtTokenKey) {
            request.addValue(
                AppConstants.Network.bearerPrefix + token,
                forHTTPHeaderField: AppConstants.Network.headerAuthorization
            )
        }

        // 构造 multipart body
        var body = Data()
        // swiftlint:disable:next force_unwrapping
        body.append(("--\(boundary)" + crlf).data(using: .utf8)!)
        // swiftlint:disable:next force_unwrapping
        body.append(("Content-Disposition: form-data; name=\"\(AppConstants.Network.multipartFieldName)\"; filename=\"\(fileName)\"" + crlf).data(using: .utf8)!)
        // swiftlint:disable:next force_unwrapping
        body.append(("Content-Type: \(mimeType)" + crlf + crlf).data(using: .utf8)!)
        body.append(fileData)
        // swiftlint:disable:next force_unwrapping
        body.append((crlf + "--\(boundary)--" + crlf).data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await activeSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, SystemConstants.HTTPStatusCode.isSuccess(httpResponse.statusCode) else {
            throw NetworkError.invalidHTTPResponse
        }
        let apiResponse: ApiResponse<String> = try decodeResponse(data)
        if apiResponse.isSuccess {
            return try extractPayload(apiResponse)
        }
        throw NetworkError.serverError(apiResponse.code, apiResponse.message)
    }

    // MARK: - 内部请求与拦截逻辑
    
    private func performRequest<T: Codable, Body: Encodable>(
        path: String,
        method: String,
        body: Body?,
        requiresAuth: Bool,
        isRetry: Bool
    ) async throws -> T {
        await waitForTokenRefreshIfNeeded(requiresAuth: requiresAuth, isRetry: isRetry)
        let request = try buildURLRequest(path: path, method: method, body: body, requiresAuth: requiresAuth)
        let (data, response) = try await activeSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidHTTPResponse
        }
        // 5xx 服务器错误直接拒绝（不解析 body，防止误判）
        // 4xx 客户端错误仍解析 body，因为后端可能用业务 code 表示具体错误（如 40101 token 过期）
        if httpResponse.statusCode >= SystemConstants.HTTPStatusCode.internalServerError {
            throw NetworkError.serverError(httpResponse.statusCode, "HTTP \(httpResponse.statusCode)")
        }
        let apiResponse: ApiResponse<T> = try decodeResponse(data)
        if apiResponse.isSuccess {
            return try extractPayload(apiResponse)
        }
        if apiResponse.code == AppConstants.Network.BusinessCode.tokenExpired && requiresAuth && !isRetry {
            return try await handleTokenRefreshAndRetry(path: path, method: method, body: body)
        }
        throw NetworkError.serverError(apiResponse.code, apiResponse.message)
    }

    private func waitForTokenRefreshIfNeeded(requiresAuth: Bool, isRetry: Bool) async {
        guard requiresAuth && isRefreshing && !isRetry else { return }
        if let refreshTask = self.refreshTask {
            _ = await refreshTask.value
        }
    }

    private func buildURLRequest<Body: Encodable>(path: String, method: String, body: Body?, requiresAuth: Bool) throws -> URLRequest {
        guard let url = URL(string: AppConfig.backendBaseURL + path) else {
            throw NetworkError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.addValue(AppConstants.Network.contentTypeJSON, forHTTPHeaderField: AppConstants.Network.headerContentType)
        if requiresAuth, let token = try? KeychainService.shared.retrieve(key: AppConstants.Network.jwtTokenKey) {
            request.addValue(AppConstants.Network.bearerPrefix + token, forHTTPHeaderField: AppConstants.Network.headerAuthorization)
        }
        if let body = body {
            request.httpBody = try encoder.encode(body)
        }
        return request
    }

    private func decodeResponse<T: Codable>(_ data: Data) throws -> ApiResponse<T> {
        do {
            return try decoder.decode(ApiResponse<T>.self, from: data)
        } catch {
            throw NetworkError.decodeFailed(error)
        }
    }

    private func extractPayload<T: Codable>(_ apiResponse: ApiResponse<T>) throws -> T {
        if let payload = apiResponse.data { return payload }
        if T.self == EmptyData.self {
            // swiftlint:disable:next force_cast
            return EmptyData() as! T
        }
        throw NetworkError.missingDataPayload
    }
    
    // MARK: - 无感刷新逻辑 (Refresh Token)
    
    private func handleTokenRefreshAndRetry<T: Codable, Body: Encodable>(
        path: String,
        method: String,
        body: Body?
    ) async throws -> T {
        // 防止多个并发请求同时触发刷新
        if isRefreshing, let existingTask = refreshTask {
            let result = await existingTask.value
            switch result {
            case .success:
                return try await performRequest(path: path, method: method, body: body, requiresAuth: true, isRetry: true)
            case .failure(let error):
                throw error
            }
        }
        
        isRefreshing = true
        let task = Task<Result<String, Error>, Never> {
            defer {
                self.isRefreshing = false
                self.refreshTask = nil
            }
            
            // 拿到长效 Refresh Token
            guard let refreshToken = try? KeychainService.shared.retrieve(key: AppConstants.Network.refreshTokenKey) else {
                NotificationCenter.default.post(name: .userAuthExpired, object: nil)
                return .failure(NetworkError.missingRefreshToken)
            }
            
            // 发起刷新请求
            let req = RefreshRequest(refreshToken: refreshToken)
            let refreshURL = AppConfig.backendBaseURL + APIPaths.refreshPath
            guard let refreshEndpoint = URL(string: refreshURL) else {
                return .failure(NetworkError.invalidURL)
            }
            var request = URLRequest(url: refreshEndpoint)
            request.httpMethod = AppConstants.Network.methodPOST
            request.addValue(AppConstants.Network.contentTypeJSON, forHTTPHeaderField: AppConstants.Network.headerContentType)
            
            do {
                request.httpBody = try encoder.encode(req)
                let (data, _) = try await activeSession.data(for: request)
                let response = try decoder.decode(ApiResponse<LoginResponse>.self, from: data)
                
                if response.isSuccess, let loginData = response.data {
                    Logger.shared.debug("[NetworkClient] Token refresh succeeded, updating Keychain...")
                    // 更新 Keychain
                    try KeychainService.shared.store(key: AppConstants.Network.jwtTokenKey, value: loginData.accessToken)
                    if let newRefresh = loginData.refreshToken {
                        try KeychainService.shared.store(key: AppConstants.Network.refreshTokenKey, value: newRefresh)
                    }
                    return .success(loginData.accessToken)
                } else {
                    Logger.shared.debug("[NetworkClient] Token refresh failed, code=\(response.code)")
                    // 刷新失败（如重放攻击 40103，或者已过期），强制退登
                    try? KeychainService.shared.delete(key: AppConstants.Network.jwtTokenKey)
                    try? KeychainService.shared.delete(key: AppConstants.Network.refreshTokenKey)
                    NotificationCenter.default.post(name: .userAuthExpired, object: nil)
                    return .failure(NetworkError.sessionInvalidated)
                }
            } catch {
                return .failure(error)
            }
        }
        refreshTask = task
        
        // 等待刷新完成并重试原请求
// swiftlint:disable:next force_unwrapping
        let result = await refreshTask!.value
        switch result {
        case .success:
            return try await performRequest(path: path, method: method, body: body, requiresAuth: true, isRetry: true)
        case .failure(let error):
            throw error
        }
    }
}

public extension Notification.Name {
    /// 广播：用户认证信息已完全过期失效，UI 应该跳转回登录页
    static let userAuthExpired = Notification.Name("com.zhiyu.app.userAuthExpired")
}
