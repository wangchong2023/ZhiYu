//
//  WebScraperProcessor+Helpers.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/14.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：WebScraper 责任链节点的公共 HTTP 请求与错误处理辅助方法。
//
import Foundation
import UFPCore

// MARK: - WebScraper 响应安全限制常量

internal enum WebScraperResponseLimits {
    /// 单次网页抓取最大响应容量（MB）
    static let maxResponseMB: Int = 10
    /// 单次网页抓取最大响应字节数（10 MB），防止恶意超大流触发 OOM
    static let maxResponseBytes: Int = maxResponseMB * Int(SystemConstants.bytesPerMB)
}

// MARK: - WebScraper 责任链公共辅助

extension WebScraperHandler {

    /// 校验 HTTP 响应的重定向落点 SSRF 安全性与响应体大小上限
    internal static func validateScrapedResponse(_ response: URLResponse, dataByteCount: Int) throws -> HTTPURLResponse {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WebScraperProcessor.ScraperError.parsingFailed
        }
        if let finalURL = httpResponse.url, !SSRFGuard.isSafeURL(finalURL) {
            Logger.shared.warning("[WebScraper] SSRF redirect blocked: \(finalURL.host ?? ProcessorConstants.Module.webScraper)")
            throw WebScraperProcessor.ScraperError.invalidURL
        }
        guard dataByteCount <= WebScraperResponseLimits.maxResponseBytes else {
            throw WebScraperProcessor.ScraperError.parsingFailed
        }
        return httpResponse
    }

    /// 执行 HTTP 请求并校验响应状态码、重定向落点 SSRF 安全性与 UTF-8 解码
    /// - Parameters:
    ///   - request: 已配置的 URLRequest
    ///   - requireStatusCodeOk: 是否要求 HTTP 200，否则抛出 parsingFailed
    /// - Returns: 解码后的 UTF-8 字符串内容
    /// - Throws: 网络错误或 ScraperError.parsingFailed / invalidURL
    func fetchUTF8Content(for request: URLRequest, requireStatusCodeOk: Bool = true) async throws -> String {
        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = try Self.validateScrapedResponse(response, dataByteCount: data.count)

        if requireStatusCodeOk {
            guard httpResponse.statusCode == SystemConstants.HTTPStatusCode.ok,
                  let content = String(data: data, encoding: .utf8) else {
                throw WebScraperProcessor.ScraperError.parsingFailed
            }
            return content
        } else {
            let restrictedCodes = ProcessorConstants.WebScraper.restrictedStatusCodes
            if restrictedCodes.contains(httpResponse.statusCode) {
                Logger.shared.warning(L10n.Ingest.Status.webscraperPaywallDetected(httpResponse.statusCode))
                throw WebScraperProcessor.ScraperError.networkError(NSError(
                    domain: ProcessorConstants.Module.webScraper,
                    code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: ProcessorConstants.Module.paywallBlocked]
                ))
            }
            guard let content = String(data: data, encoding: .utf8) else {
                throw WebScraperProcessor.ScraperError.parsingFailed
            }
            return content
        }
    }

    /// 责任链失败兜底：记录错误日志并转交下一节点
    /// - Parameters:
    ///   - error: 捕获的错误
    ///   - url: 当前抓取 URL
    ///   - startTime: 启动时间
    ///   - failureLog: 失败日志消息
    /// - Returns: 下一节点的处理结果
    /// - Throws: 当无下一节点时抛出原错误
    func forwardToNext(
        error: Error,
        url: URL,
        startTime: Date,
        failureLog: String
    ) async throws -> (markdown: String, title: String) {
        Logger.shared.error(failureLog, error: error)
        guard let next = next else { throw error }
        return try await next.handle(url: url, startTime: startTime)
    }

    /// 统一的 HTTP 抓取 + HTML 提取 + 责任链兜底流程，消除 GooglebotScraperHandler / ArchiveScraperHandler 两处重复的 do-catch 样板。
    /// - Parameters:
    ///   - url: 抓取目标 URL（用于日志与兜底）
    ///   - request: 已配置好的 URLRequest
    ///   - successLog: 成功日志消息
    ///   - failureLog: 失败日志消息
    ///   - startTime: 抓取开始时间
    ///   - requireStatusCodeOk: 是否要求 HTTP 200
    /// - Returns: 提取后的 (markdown, title) 元组
    func fetchHTMLAndExtract(
        url: URL,
        request: URLRequest,
        successLog: String,
        failureLog: String,
        startTime: Date,
        requireStatusCodeOk: Bool = true
    ) async throws -> (markdown: String, title: String) {
        do {
            let htmlContent = try await fetchUTF8Content(for: request, requireStatusCodeOk: requireStatusCodeOk)
            return handleScraperSuccess(url: url, htmlContent: htmlContent, successLog: successLog, startTime: startTime)
        } catch {
            return try await forwardToNext(error: error, url: url, startTime: startTime, failureLog: failureLog)
        }
    }
}
