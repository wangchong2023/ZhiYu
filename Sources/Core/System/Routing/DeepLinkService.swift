//
//  DeepLinkService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0.5] 系统集成层
//  核心职责：实现 DeepLink 模块的核心业务逻辑服务。
//
import Foundation
import UFPCore
#if canImport(CoreSpotlight)
import CoreSpotlight
#endif

// MARK: - Deep Link Service
/// Handles deep links, universal links, and Spotlight indexing for Knowledge Base pages.
final class DeepLinkService: ObservableObject {
    @Published var pendingDeepLink: DeepLink?
    
    enum DeepLink {
        case openPage(id: UUID)
        case openPageByTitle(String)
        case search(String)
        case create // 桌面小组件快捷新建卡片动作
        case ingest
        case graph
        case chat
    }
    
    /// 支持的 DeepLink Host 常量（大小写不敏感匹配）
    private enum Host {
        static let page = "page"
        static let create = "create"
        static let search = "search"
        static let ingest = "ingest"
        static let voice = "voice"
        static let ocr = "ocr"
        static let graph = "graph"
        static let chat = "chat"
    }

    /// DeepLink 查询参数与 UserActivity 键常量
    private enum QueryKey {
        static let id = "id"
        static let title = "title"
        static let query = "q"
        static let pageID = "pageID"
    }

    /// DeepLink 输入边界保护常量
    private enum Limits {
        static let maxSearchQueryLength = 256
        static let maxTitleLength = 256
    }

    /// 清洗外部链接文本参数：剥离控制字符与换行、裁剪首尾空白并限制最大长度
    private func sanitizeTextParameter(_ raw: String, maxLength: Int) -> String {
        let disallowed = CharacterSet.controlCharacters.union(.newlines)
        let cleanedScalars = raw.unicodeScalars.filter { !disallowed.contains($0) }
        let trimmed = String(String.UnicodeScalarView(cleanedScalars))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(maxLength))
    }

    // MARK: - URL Scheme Handling
    /// 处理应用特有的 URL Scheme 深度路由分发
    /// - Parameter url: 传入的原始 URL 实例
    /// - Returns: 是否为系统可识别且处理成功的路由动作
    func handleURL(_ url: URL) -> Bool {
        // 先校验 Scheme 归属本应用再扣除限流配额，防止外部无关 URL 恶意耗尽令牌桶
        guard url.scheme?.lowercased() == CoreConstants.DeepLink.scheme.lowercased() else { return false }
        guard IntentRateLimiter.shared.request() else {
            Logger.shared.warning(" [DeepLinkService]" + " Rate limit" + " exceeded! Dropping" + " request: \(url.absoluteString)")
            return false
        }
        return handleKnownHost(url.host, url: url)
    }

    private func handleKnownHost(_ host: String?, url: URL) -> Bool {
        switch host?.lowercased() {
        case Host.page: return handlePageDeepLink(url: url)
        case Host.create: pendingDeepLink = .create; return true
        case Host.search:
            let sanitized = sanitizeTextParameter(
                url.queryParameters[QueryKey.query] ?? "",
                maxLength: Limits.maxSearchQueryLength
            )
            pendingDeepLink = .search(sanitized)
            return true
        case Host.ingest, Host.voice, Host.ocr: pendingDeepLink = .ingest; return true
        case Host.graph: pendingDeepLink = .graph; return true
        case Host.chat: pendingDeepLink = .chat; return true
        default: return false
        }
    }

    private func handlePageDeepLink(url: URL) -> Bool {
        if let rawID = url.queryParameters[QueryKey.id]?.trimmingCharacters(in: .whitespacesAndNewlines),
           let id = UUID(uuidString: rawID) {
            pendingDeepLink = .openPage(id: id)
            return true
        }
        if let rawTitle = url.queryParameters[QueryKey.title] {
            let sanitizedTitle = sanitizeTextParameter(rawTitle, maxLength: Limits.maxTitleLength)
            if !sanitizedTitle.isEmpty {
                pendingDeepLink = .openPageByTitle(sanitizedTitle)
                return true
            }
        }
        return false
    }
    
    // MARK: - Spotlight Query Handling
    /// 处理 Spotlight Activity（同时兼容系统原生 CoreSpotlight 回调与内部自定义 openPage 活动）
    /// - Parameter userActivity: userActivity
    /// - Returns: 是否成功
    func handleSpotlightActivity(_ userActivity: NSUserActivity) -> Bool {
        guard let userInfo = userActivity.userInfo else { return false }

        let isRecognizedActivity: Bool
        let rawIdentifier: String?
        #if canImport(CoreSpotlight)
        if userActivity.activityType == CSSearchableItemActionType {
            isRecognizedActivity = true
            rawIdentifier = (userInfo[CSSearchableItemActivityIdentifier] as? String)
                ?? (userInfo[QueryKey.pageID] as? String)
        } else if userActivity.activityType == CoreConstants.DeepLink.spotlightActivityType {
            isRecognizedActivity = true
            rawIdentifier = (userInfo[QueryKey.pageID] as? String)
                ?? (userInfo[CSSearchableItemActivityIdentifier] as? String)
        } else {
            isRecognizedActivity = false
            rawIdentifier = nil
        }
        #else
        isRecognizedActivity = (userActivity.activityType == CoreConstants.DeepLink.spotlightActivityType)
        rawIdentifier = userInfo[QueryKey.pageID] as? String
        #endif

        guard isRecognizedActivity,
              let idString = rawIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines),
              let id = UUID(uuidString: idString) else {
            return false
        }
        pendingDeepLink = .openPage(id: id)
        return true
    }
    
    /// consumeDeep链接
    /// - Returns: 可选值
    func consumeDeepLink() -> DeepLink? {
        let link = pendingDeepLink
        pendingDeepLink = nil
        return link
    }
}

// MARK: - URL Query Parameters Extension
extension URL {
    var queryParameters: [String: String] {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else { return [:] }
        let pairs: [(String, String)] = queryItems.compactMap { item in
            guard let value = item.value else { return nil }
            return (item.name, value)
        }
        return Dictionary(pairs, uniquingKeysWith: { _, latest in latest })
    }
}
