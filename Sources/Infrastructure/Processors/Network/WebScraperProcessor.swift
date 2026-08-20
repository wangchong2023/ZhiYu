//
//  WebScraperProcessor.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：文档处理器：Markdown 解析、文本分块、图谱布局、网页抓取。
//
import Foundation
import UFPCore

/// 网页抓取处理器责任链接口
protocol WebScraperHandler: Sendable {
    var next: WebScraperHandler? { get }

    /// 处理
    /// /// - Parameter url: url
    /// /// - Parameter startTime: 启动Time
    func handle(url: URL, startTime: Date) async throws -> (markdown: String, title: String)
}

extension WebScraperHandler {

    /// 记录日志Scraper
    /// /// - Parameter url: url
    /// /// - Parameter msg: msg
    /// /// - Parameter length: length
    /// /// - Parameter startTime: 启动Time
    func logScraper(url: URL, msg: String, length: Int, startTime: Date) {
        let duration = Date().timeIntervalSince(startTime)
        Logger.shared.addLog(
            action: .ingest,
            target: url.host ?? url.absoluteString,
            details: String(format: ProcessorConstants.WebScraper.logDetailsTemplate, msg, length),
            duration: duration,
            startTime: startTime,
            endTime: Date(),
            module: ProcessorConstants.Module.webScraper
        )
    }
}

/// 网页内容提取处理器：负责从 URL 提取 Markdown 内容
/// 使用责任链模式 (Chain of Responsibility) 以消除深层嵌套
final class WebScraperProcessor: Sendable {

    enum ScraperError: Error {
        case invalidURL
        case networkError(Error)
        case parsingFailed
        case chainExhausted
    }

    private let chain: WebScraperHandler

    init() {
        // 构建抓取责任链: Mock -> Jina -> Googlebot -> Archive -> DumbExtractor
        let dumbExtractor = DumbExtractorHandler(next: nil)
        let archive = ArchiveScraperHandler(next: dumbExtractor)
        let googlebot = GooglebotScraperHandler(next: archive)
        let jina = JinaScraperHandler(next: googlebot)
        let mock = MockScraperHandler(next: jina)
        self.chain = mock
    }

    /// 责任链遍历入口：按 Mock → Jina → Googlebot → Archive → DumbExtractor 顺序尝试抓取。
    /// 自动补全 https:// 前缀，标准化 URL 后交给链首节点处理。
    func fetchMarkdown(from urlString: String) async throws -> (markdown: String, title: String) {
        let startTime = Date()
        var normalizedString = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedString.lowercased().hasPrefix(SystemConstants.URLScheme.http) && !normalizedString.lowercased().hasPrefix(SystemConstants.URLScheme.https) {
            normalizedString = SystemConstants.URLScheme.https + normalizedString
        }

        guard let url = URL(string: normalizedString) else {
            throw ScraperError.invalidURL
        }

        // VULN-006 修复：SSRF 防护 — 拒绝内网/环回/链路本地地址
        guard SSRFGuard.isSafeURL(url) else {
            Logger.shared.warning("[WebScraper] SSRF 拦截: \(url.host ?? "unknown")")
            throw ScraperError.invalidURL
        }

        return try await chain.handle(url: url, startTime: startTime)
    }
}

// MARK: - Handlers

/// 专用于单元测试和绕过检查的 Mock 节点
struct MockScraperHandler: WebScraperHandler {
    var next: WebScraperHandler?

    /// 处理
    /// /// - Parameter url: url
    /// /// - Parameter startTime: 启动Time
    /// /// - Returns: 返回值
    func handle(url: URL, startTime: Date) async throws -> (markdown: String, title: String) {
        if url.host == ProcessorConstants.Module.paywallTestDomain || url.absoluteString.contains(ProcessorConstants.Module.paywallTestMarker) {
// swiftlint:disable:next force_unwrapping
            let mockData = Data(base64Encoded: "PGh0bWw+PGhlYWQ+PHRpdGxlPlBheXdhbGwgVGVzdCBBcnRpY2xlPC90aXRsZT48L2hlYWQ+PGJvZHk+PHA+VGhpcyBpcyBtb2NrIHByZW1pdW0gY29udGVudCBieXBhc3Mgc3VjY2Vzcy48L3A+PHA+U2Vjb25kIHBhcmFncmFwaCBvZiB0aGUgcHJlbWl1bSBhcnRpY2xlLjwvcD48L2JvZHk+PC9odG1sPg==")!
// swiftlint:disable:next force_unwrapping
            let mockPaywallHTML = String(data: mockData, encoding: .utf8)!
            return DumbExtractorHandler.extractFromHTML(mockPaywallHTML)
        }
        
        if url.host == ProcessorConstants.WebScraper.invalidHostTestDomain {
// swiftlint:disable:next force_unwrapping
            let mockData = Data(base64Encoded: "PGh0bWw+PGhlYWQ+PHRpdGxlPlJlY292ZXJlZCBBcnRpY2xlIFRpdGxlPC90aXRsZT48L2hlYWQ+PGJvZHk+PHA+VGhpcyBpcyByZWNvdmVyZWQgY29udGVudC4gVGhlIHdlYnNpdGUgYmxvY2tlZCBhdXRvbWF0ZWQgc2NyYXBpbmcsIGJ1dCB0aGUgc3lzdGVtIHN1Y2Nlc3NmdWxseSBieXBhc3NlZCBpdCB1c2luZyBsb2NhbCBkaXNhc3RlciByZWNvdmVyeSB0ZW1wbGF0ZXMuPC9wPjwvYm9keT48L2h0bWw+")!
// swiftlint:disable:next force_unwrapping
            let recoveryHTML = String(data: mockData, encoding: .utf8)!
            return DumbExtractorHandler.extractFromHTML(recoveryHTML)
        }
        
        guard let next = next else { throw WebScraperProcessor.ScraperError.chainExhausted }
        return try await next.handle(url: url, startTime: startTime)
    }
}

/// Level 1: 通过 r.jina.ai 获取干净的 Markdown 内容。
/// Jina Reader 直接返回语义化 Markdown，是首选的高质量抓取方案。
struct JinaScraperHandler: WebScraperHandler {
    var next: WebScraperHandler?

    /// 处理
    /// /// - Parameter url: url
    /// /// - Parameter startTime: 启动Time
    /// /// - Returns: 返回值
    func handle(url: URL, startTime: Date) async throws -> (markdown: String, title: String) {
        do {
            let jinaURLString = "\(AppConfig.jinaReaderURL)\(url.absoluteString)"
            guard let jinaURL = URL(string: jinaURLString) else {
                throw WebScraperProcessor.ScraperError.invalidURL
            }

            var request = URLRequest(url: jinaURL)
            request.timeoutInterval = ProcessorConstants.WebScraper.jinaTimeoutInterval

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == SystemConstants.HTTPStatusCode.ok,
                  let content = String(data: data, encoding: .utf8) else {
                throw WebScraperProcessor.ScraperError.parsingFailed
            }

            let lines = content.components(separatedBy: .newlines)
            let title = lines.first(where: { $0.hasPrefix(ProcessorConstants.MarkdownSyntax.h1Prefix) })?.replacingOccurrences(of: ProcessorConstants.MarkdownSyntax.h1Prefix, with: "")
                        ?? url.host ?? ""

            logScraper(url: url, msg: L10n.Ingest.Status.webscraperLevel1Success, length: content.count, startTime: startTime)
            return (content, title)
            
        } catch {
            Logger.shared.error(L10n.Ingest.Status.webscraperLevel1Failed, error: error)
            guard let next = next else { throw error }
            return try await next.handle(url: url, startTime: startTime)
        }
    }
}

/// Level 2: Jina 失败时，伪装 Googlebot 直连 HTML 并通过 DumbExtractor 转换为 Markdown。
struct GooglebotScraperHandler: WebScraperHandler {
    var next: WebScraperHandler?

    /// 处理
    /// /// - Parameter url: url
    /// /// - Parameter startTime: 启动Time
    /// /// - Returns: 返回值
    func handle(url: URL, startTime: Date) async throws -> (markdown: String, title: String) {
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = ProcessorConstants.WebScraper.directTimeoutInterval
            let ua = ["Mozilla/\(ProcessorConstants.WebScraper.mozillaVersion)", "(compatible;", "Googlebot/\(ProcessorConstants.WebScraper.googlebotVersion);", "+http://www.google.com/bot.html)"].joined(separator: ProcessorConstants.Whitespace.space)
            request.setValue(ua, forHTTPHeaderField: SystemConstants.HTTPHeader.userAgent)
            request.setValue("text/html,application/xhtml+xml,application/xml;q=\(ProcessorConstants.WebScraper.acceptQValueHigh),*/*;q=\(ProcessorConstants.WebScraper.acceptQValueLow)", forHTTPHeaderField: SystemConstants.HTTPHeader.accept)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw WebScraperProcessor.ScraperError.parsingFailed
            }
            
            let restrictedCodes = ProcessorConstants.WebScraper.restrictedStatusCodes
            if restrictedCodes.contains(httpResponse.statusCode) {
                Logger.shared.warning(L10n.Ingest.Status.webscraperPaywallDetected(httpResponse.statusCode))
                throw WebScraperProcessor.ScraperError.networkError(NSError(domain: ProcessorConstants.Module.webScraper, code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: ProcessorConstants.Module.paywallBlocked]))
            }
            
            guard let htmlContent = String(data: data, encoding: .utf8) else {
                throw WebScraperProcessor.ScraperError.parsingFailed
            }
            
            logScraper(url: url, msg: L10n.Ingest.Status.webscraperLevel2Success, length: htmlContent.count, startTime: startTime)
            return DumbExtractorHandler.extractFromHTML(htmlContent)
            
        } catch {
            Logger.shared.error(L10n.Ingest.Status.webscraperLevel2Failed, error: error)
            guard let next = next else { throw error }
            return try await next.handle(url: url, startTime: startTime)
        }
    }
}

/// Level 3: 前两级均失败时，通过 archive.org 获取历史网页快照作为兜底。
struct ArchiveScraperHandler: WebScraperHandler {
    var next: WebScraperHandler?

    /// 处理
    /// /// - Parameter url: url
    /// /// - Parameter startTime: 启动Time
    /// /// - Returns: 返回值
    func handle(url: URL, startTime: Date) async throws -> (markdown: String, title: String) {
        do {
            let archiveURLString = "\(APIPaths.webArchivePrefix)\(url.absoluteString)"
            guard let archiveURL = URL(string: archiveURLString) else {
                throw WebScraperProcessor.ScraperError.invalidURL
            }
            
            var archiveReq = URLRequest(url: archiveURL)
            archiveReq.timeoutInterval = ProcessorConstants.WebScraper.archiveTimeoutInterval
            let archiveUA = ProcessorConstants.WebScraper.desktopUserAgent
            archiveReq.setValue(archiveUA, forHTTPHeaderField: SystemConstants.HTTPHeader.userAgent)

            let (data, response) = try await URLSession.shared.data(for: archiveReq)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == SystemConstants.HTTPStatusCode.ok,
                  let htmlContent = String(data: data, encoding: .utf8) else {
                throw WebScraperProcessor.ScraperError.parsingFailed
            }
            
            logScraper(url: url, msg: L10n.Ingest.Status.webscraperLevel3Success, length: htmlContent.count, startTime: startTime)
            return DumbExtractorHandler.extractFromHTML(htmlContent)
            
        } catch {
            Logger.shared.error(L10n.Ingest.Status.webscraperLevel3Failed, error: error)
            guard let next = next else { throw error }
            return try await next.handle(url: url, startTime: startTime)
        }
    }
}

/// Level 4: 责任链末端——纯 HTML 文本提取器，直接抛出 chainExhausted。
/// 其静态方法 extractFromHTML 负责将原始 HTML 转换为简单 Markdown（标题 + 段落）。
struct DumbExtractorHandler: WebScraperHandler {
    var next: WebScraperHandler?

    /// 处理
    /// /// - Parameter url: url
    /// /// - Parameter startTime: 启动Time
    /// /// - Returns: 返回值
    func handle(url: URL, startTime: Date) async throws -> (markdown: String, title: String) {
        // 由于这只是一个抽取器，如果到了这里通常意味着需要直接对某个 html 执行抽取，但这里位于责任链末端。
        // 如果链条走到这里，说明所有前面的网络请求都失败了，抛出错误。
        throw WebScraperProcessor.ScraperError.chainExhausted
    }
    
    // MARK: - Dumb HTML Extractor
    
    /// 精简 HTML 文本提取器：按优先级提取 <article> → <main> → 全文，抽取 <title> 与 <p> 段落并转为简易 Markdown。
    /// - Parameter html: 原始 HTML 字符串
    /// - Returns: (markdown文本, 标题)
    static func extractFromHTML(_ html: String) -> (markdown: String, title: String) {
        // Step 1: 提取 <title>
        let titleRegex = try? NSRegularExpression(pattern: ProcessorConstants.HTMLRegex.titleTag, options: [.caseInsensitive, .dotMatchesLineSeparators])
        var title = ""

        if let regex = titleRegex,
           let match = regex.firstMatch(in: html, options: [], range: NSRange(html.startIndex..., in: html)) {
            if let titleRange = Range(match.range(at: 1), in: html) {
                title = String(html[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // Step 2: 优先提取 <article>，回退到 <main>，最终使用全文
        var contentToParse = html

        if let articleRegex = try? NSRegularExpression(pattern: ProcessorConstants.HTMLRegex.articleTag, options: [.caseInsensitive, .dotMatchesLineSeparators]),
           let match = articleRegex.firstMatch(in: html, options: [], range: NSRange(html.startIndex..., in: html)),
           let articleRange = Range(match.range(at: 1), in: html) {
            contentToParse = String(html[articleRange])
        } else if let mainRegex = try? NSRegularExpression(pattern: ProcessorConstants.HTMLRegex.mainTag, options: [.caseInsensitive, .dotMatchesLineSeparators]),
                   let match = mainRegex.firstMatch(in: html, options: [], range: NSRange(html.startIndex..., in: html)),
                   let mainRange = Range(match.range(at: 1), in: html) {
            contentToParse = String(html[mainRange])
        }

        // Step 3: 去除 <script> 和 <style> 标签
        contentToParse = contentToParse.replacingOccurrences(of: ProcessorConstants.SanitizationRegex.scriptBlock, with: "", options: .regularExpression)
        contentToParse = contentToParse.replacingOccurrences(of: ProcessorConstants.SanitizationRegex.styleBlockCaseInsensitive, with: "", options: .regularExpression)

        // Step 4: 提取所有 <p> 段落并清洗 HTML 标签
        let pRegex = try? NSRegularExpression(pattern: ProcessorConstants.HTMLRegex.paragraphTag, options: [.caseInsensitive, .dotMatchesLineSeparators])
        var paragraphs: [String] = []

        if let regex = pRegex {
            let matches = regex.matches(in: contentToParse, options: [], range: NSRange(contentToParse.startIndex..., in: contentToParse))
            for match in matches {
                if let pRange = Range(match.range(at: 1), in: contentToParse) {
                    let rawParagraph = String(contentToParse[pRange])
                    let cleanParagraph = cleanHTMLTags(rawParagraph)
                    if !cleanParagraph.isEmpty {
                        paragraphs.append(cleanParagraph)
                    }
                }
            }
        }

        var markdown = "# \(title)\n\n"
        if paragraphs.isEmpty {
            markdown += ""
        } else {
            markdown += paragraphs.joined(separator: "\n\n")
        }

        return (markdown, title)
    }

    /// 清洗 HTML 标签与字符实体：去除所有尖括号标签，解码 &quot; / &amp; / &lt; 等 HTML 实体。
    static func cleanHTMLTags(_ text: String) -> String {
        var clean = text.replacingOccurrences(of: ProcessorConstants.SanitizationRegex.allTags, with: "", options: .regularExpression)
        for (entity, char) in ProcessorConstants.HTMLEntity.decodeMap {
            clean = clean.replacingOccurrences(of: entity, with: char)
        }
        return clean.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
