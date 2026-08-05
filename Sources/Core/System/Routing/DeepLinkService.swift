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
    
    // MARK: - URL Scheme Handling
    /// 处理应用特有的 URL Scheme 深度路由分发
    /// - Parameter url: 传入的原始 URL 实例
    /// - Returns: 是否为系统可识别且处理成功的路由动作
    func handleURL(_ url: URL) -> Bool {
        guard IntentRateLimiter.shared.request() else {
            Logger.shared.warning(" [DeepLinkService]" + " Rate limit" + " exceeded! Dropping" + " request: \(url.absoluteString)")
            return false
        }
        guard url.scheme == CoreConstants.DeepLink.scheme else { return false }
        return handleKnownHost(url.host, url: url)
    }

    private func handleKnownHost(_ host: String?, url: URL) -> Bool {
        switch host {
        case "page": return handlePageDeepLink(url: url)
        case "create": pendingDeepLink = .create; return true
        case "search": pendingDeepLink = .search(url.queryParameters["q"] ?? ""); return true
        case "ingest": pendingDeepLink = .ingest; return true
        case "graph": pendingDeepLink = .graph; return true
        case "chat": pendingDeepLink = .chat; return true
        default: return false
        }
    }

    private func handlePageDeepLink(url: URL) -> Bool {
        if let idString = url.queryParameters["id"],
           let id = UUID(uuidString: idString) {
            pendingDeepLink = .openPage(id: id)
            return true
        }
        if let title = url.queryParameters["title"] {
            pendingDeepLink = .openPageByTitle(title)
            return true
        }
        return false
    }
    
    // MARK: - Spotlight Query Handling
    /// 处理SpotlightActivity
    /// - Parameter userActivity: userActivity
    /// - Returns: 是否成功
    func handleSpotlightActivity(_ userActivity: NSUserActivity) -> Bool {
        guard userActivity.activityType == CoreConstants.DeepLink.spotlightActivityType,
              let userInfo = userActivity.userInfo,
              let idString = userInfo["pageID"] as? String,
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
        return Dictionary(uniqueKeysWithValues: queryItems.compactMap { item in
            guard let value = item.value else { return nil }
            return (item.name, value)
        })
    }
}
