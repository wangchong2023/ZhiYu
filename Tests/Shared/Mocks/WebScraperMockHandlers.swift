//
//  WebScraperMockHandlers.swift
//  ZhiYu
//
//  系统层级：[Shared] 测试层
//  核心职责：WebScraper 测试专用 Mock 链首节点与抓取测试夹具。从生产代码剥离后迁移至此，
//            生产 WebScraperProcessor 通过 `chainHead` 注入测试专用链首，避免生产内嵌测试逻辑。
//

import Foundation
@testable import ZhiYu

// MARK: - 测试夹具常量

/// WebScraper 测试专用 Mock 常量（从 ProcessorConstants 剥离迁移）
enum WebScraperMockConstants {
    /// paywall 测试域名（用于验证 paywall 绕过路径）
    static let paywallTestDomain: String = "paywall-test.com"
    /// paywall 测试标记子串（用于 URL 子串匹配）
    static let paywallTestMarker: String = "paywall-test"
    /// paywall 测试夹具 HTML（Base64 编码）
    static let paywallMockBase64: String = "PGh0bWw+PGhlYWQ+PHRpdGxlPlBheXdhbGwgVGVzdCBBcnRpY2xlPC90aXRsZT48L2hlYWQ+PGJvZHk+PHA+VGhpcyBpcyBtb2NrIHByZW1pdW0gY29udGVudCBieXBhc3Mgc3VjY2Vzcy48L3A+PHA+U2Vjb25kIHBhcmFncmFwaCBvZiB0aGUgcHJlbWl1bSBhcnRpY2xlLjwvcD48L2JvZHk+PC9odG1sPg=="
    /// Mock 测试用无效主机域名（用于验证本地灾难恢复流程）
    static let invalidHostTestDomain: String = "invalid-host-domain-never-exist.example.com"
    /// 灾难恢复测试夹具 HTML（Base64 编码）
    static let recoveryMockBase64: String = "PGh0bWw+PGhlYWQ+PHRpdGxlPlJlY292ZXJlZCBBcnRpY2xlIFRpdGxlPC90aXRsZT48L2hlYWQ+PGJvZHk+PHA+VGhpcyBpcyByZWNvdmVyZWQgY29udGVudC4gVGhlIHdlYnNpdGUgYmxvY2tlZCBhdXRvbWF0ZWQgc2NyYXBpbmcsIGJ1dCB0aGUgc3lzdGVtIHN1Y2Nlc3NmdWxseSBieXBhc3NlZCBpdCB1c2luZyBsb2NhbCBkaXNhc3RlciByZWNvdmVyeSB0ZW1wbGF0ZXMuPC9wPjwvYm9keT48L2h0bWw+"
}

// MARK: - Mock 链首节点

/// 测试专用 Mock 责任链首节点：对 paywall / 无效主机域名返回本地测试夹具 HTML，其余 URL 转发至下一节点。
struct MockScraperHandler: WebScraperHandler {
    var next: WebScraperHandler?

    /// 处理
    /// - Parameter url: 抓取目标 URL
    /// - Parameter startTime: 抓取开始时间
    /// - Returns: 抓取结果 (markdown, title)
    func handle(url: URL, startTime: Date) async throws -> (markdown: String, title: String) {
        if url.host == WebScraperMockConstants.paywallTestDomain || url.absoluteString.contains(WebScraperMockConstants.paywallTestMarker) {
            let mockPaywallHTML = MockScraperFixtures.decodeHTML(WebScraperMockConstants.paywallMockBase64)
            return DumbExtractorHandler.extractFromHTML(mockPaywallHTML)
        }

        if url.host == WebScraperMockConstants.invalidHostTestDomain {
            let recoveryHTML = MockScraperFixtures.decodeHTML(WebScraperMockConstants.recoveryMockBase64)
            return DumbExtractorHandler.extractFromHTML(recoveryHTML)
        }

        guard let next = next else { throw WebScraperProcessor.ScraperError.chainExhausted }
        return try await next.handle(url: url, startTime: startTime)
    }
}

// MARK: - 抓取测试夹具

/// Mock 抓取测试夹具：封装 Base64 解码与 UTF-8 还原的共享辅助，消除 MockScraperHandler 中的重复解码样板。
enum MockScraperFixtures {
    /// 将 Base64 编码的 HTML 字符串解码为 UTF-8 字符串
    /// - Parameter base64String: Base64 编码的 HTML
    /// - Returns: 解码后的 HTML 字符串
    static func decodeHTML(_ base64String: String) -> String {
        // swiftlint:disable:next force_unwrapping
        let data = Data(base64Encoded: base64String)!
        // swiftlint:disable:next force_unwrapping
        return String(data: data, encoding: .utf8)!
    }
}
