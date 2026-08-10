//
//  PluginMarketService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：实现 PluginMarket 模块的核心业务逻辑服务，管理云端分发与下载。
//

import Foundation
import UFPCore

/// 插件市场条目模型
@MainActor
struct MarketPlugin: Codable, Identifiable {
    let id: String
    let version: String
    let author: String
    let downloads: String
    let rating: Double
    let icon: String
    let downloadURL: String?
    let minAppVersion: String?
    let requiredPermissions: [String]?
    let monetization: MonetizationInfo?
    /// 审核评价数量
    let reviewCount: Int?
    /// 插件分类
    let category: String?
    /// 来源类型：remote / local / community
    let source: String?

    let names: [String: String]
    let descriptions: [String: String]
    
    var name: String {
        return Localized.bestMatch(in: names, fallback: id)
    }

    var description: String {
        return Localized.bestMatch(in: descriptions, fallback: "")
    }

    /// 逐个成员初始构造器 (方便单元测试与本地 Fallback 构造)
    init(
        id: String,
        version: String,
        author: String,
        downloads: String,
        rating: Double,
        icon: String,
        downloadURL: String?,
        minAppVersion: String?,
        requiredPermissions: [String]?,
        monetization: MonetizationInfo?,
        reviewCount: Int?,
        category: String?,
        source: String?,
        names: [String: String] = [:],
        descriptions: [String: String] = [:]
    ) {
        self.id = id
        self.version = version
        self.author = author
        self.downloads = downloads
        self.rating = rating
        self.icon = icon
        self.downloadURL = downloadURL
        self.minAppVersion = minAppVersion
        self.requiredPermissions = requiredPermissions
        self.monetization = monetization
        self.reviewCount = reviewCount
        self.category = category
        self.source = source
        self.names = names
        self.descriptions = descriptions
    }

    /// 从 community-plugins.json 元数据条目构造插件市场条目，支持可选的多语言元数据字段。
    /// - Parameters:
    ///   - entry: 解析后的社区插件元数据条目
    ///   - downloadBase: 下载的基准 URL 地址
    init(from entry: CommunityPluginEntry, downloadBase: URL) {
        self.id = entry.id
        // 优先采纳 json 物理文件声明的动态版本字段，兜底初始版本使用 0.0.1
        self.version = entry.version ?? "0.0.1"
        self.author = entry.author
        // 初始下载计数：未开始下载时默认为 "0"
        self.downloads = "0"
        self.rating = 0
        
        // 优先采纳 json 配置文件中声明的专属图标，若无则使用自适应匹配 SF Symbol 图标，保证各示意插件展示各具特色
        if let customIcon = entry.icon, !customIcon.isEmpty {
            self.icon = customIcon
        } else {
            self.icon = downloadBase
                .appendingPathComponent(entry.id)
                .appendingPathComponent("icon.png")
                .absoluteString
        }
        
        self.downloadURL = downloadBase
            .appendingPathComponent(entry.id)
            .absoluteString
        self.minAppVersion = nil
        self.requiredPermissions = nil
        self.monetization = nil
        self.reviewCount = nil
        self.category = entry.category ?? "efficiency"
        self.source = "community"
        
        // 优先采纳 entry.names 多语言字典，若为空则自动补充默认英文名称
        var resolvedNames = entry.names ?? [:]
        if resolvedNames["en"] == nil {
            resolvedNames["en"] = entry.name
        }
        self.names = resolvedNames
        
        // 优先采纳 entry.descriptions 多语言字典，若为空则自动补充默认英文描述
        var resolvedDescs = entry.descriptions ?? [:]
        if resolvedDescs["en"] == nil {
            resolvedDescs["en"] = entry.description
        }
        self.descriptions = resolvedDescs
    }
}

/// community-plugins.json 条目（Obsidian 风格，扩展支持多语言元数据）
struct CommunityPluginEntry: Codable {
    let id: String
    let name: String
    let author: String
    let description: String
    let repo: String
    /// 自定义增加动态版本属性，由云端 json 配置文件统一调配
    let version: String?
    /// 插件自定义 SF Symbol 图标名称，允许从云端直接下发控制图标展示
    let icon: String?
    
    let names: [String: String]?
    let descriptions: [String: String]?
    let category: String?
}

/// 插件市场服务 (Architect 视角：实现云端分发体系)
@MainActor
final class PluginMarketService: ObservableObject {
    @Published var availablePlugins: [MarketPlugin] = []
    @Published var isLoading = false
    @Published var downloadingPluginID: String?
    @Published var errorMessage: String?

    // 生产环境 (GitHub)
    private let registryGitHub: URL = {
        guard let url = URL(string: APIPaths.communityPluginsJSON) else {
            preconditionFailure("Invalid GitHub registry URL")
        }
        return url
    }()

    /// 插件市场目标请求 URL 地址，统一为 GitHub 生产环境发布地址
    private var targetURL: URL {
        return registryGitHub
    }

    /// 从云端抓取插件元数据并更新可用的插件列表
    func fetchPlugins() async {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }

        let urlsToTry = self.buildPluginURLs()
        let fetchSuccess = await tryFetchAny(from: urlsToTry)

        if !fetchSuccess {
            await MainActor.run {
                self.availablePlugins = []
                self.errorMessage = L10n.Plugin.market.connectionError
                self.isLoading = false
            }
        }
    }

    /// 构建要尝试请求的插件市场 URL 地址列表（支持按首选语言加载）
    private func buildPluginURLs() -> [URL] {
        let preferredLanguage = Localized.currentLanguage
        var urls: [URL] = []
        
        // 优先将对应语言的本地化 community-plugins_zh-Hans.json 加入抓取队列中以优先尝试
        if preferredLanguage.hasPrefix(PluginConstants.LanguagePrefix.zh) {
            let zhURL = registryGitHub.deletingLastPathComponent().appendingPathComponent("community-plugins_zh-Hans.json")
            urls.append(zhURL)
        }
        
        // 其次加入通用的默认 community-plugins.json 作为最终兜底
        urls.append(registryGitHub)
        return urls
    }

    /// 并发依次尝试拉取请求列表中的第一个可用插件元数据
    private func tryFetchAny(from urls: [URL]) async -> Bool {
        for url in urls {
            let hasFetched = await tryFetch(from: url)
            if hasFetched {
                return true
            }
        }
        return false
    }

    /// 尝试从单个 URL 抓取插件元数据
    private func tryFetch(from url: URL) async -> Bool {
        do {
            Logger.shared.info("[PluginMarket] 正在尝试从以下地址拉取插件市场: \(url.absoluteString)")
            let (data, response) = try await URLSession.shared.data(from: url)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

            guard statusCode == SystemConstants.HTTPStatusCode.ok else {
                throw NSError(domain: PluginConstants.MarketError.domain, code: statusCode, userInfo: [NSLocalizedDescriptionKey: "\(PluginConstants.MarketError.httpPrefix)\(statusCode)"])
            }

            Logger.shared.info("[PluginMarket] 成功拉取插件元数据，大小: \(data.count) 字节")
            return await processPluginResponse(data: data)
        } catch {
            Logger.shared.warning("[PluginMarket] 从云端 \(url.absoluteString) 拉取插件市场元数据失败: \(error.localizedDescription)")
            return false
        }
    }

    /// 解析服务器返回的插件市场元数据 JSON 并转换为 MarketPlugin 结构
    private func processPluginResponse(data: Data) async -> Bool {
        let decoder = JSONDecoder()

        if let communityPlugins = try? decoder.decode([CommunityPluginEntry].self, from: data) {
            let currentTargetURL = targetURL
            let rawURLString: String
            if currentTargetURL.absoluteString.contains(PluginConstants.MarketJSON.communityPlugins) {
                rawURLString = currentTargetURL.absoluteString.replacingOccurrences(of: PluginConstants.MarketJSON.communityPlugins, with: PluginConstants.MarketJSON.pluginsPathSegment)
            } else if currentTargetURL.absoluteString.contains(PluginConstants.MarketJSON.communityPluginsZhHans) {
                rawURLString = currentTargetURL.absoluteString.replacingOccurrences(of: PluginConstants.MarketJSON.communityPluginsZhHans, with: PluginConstants.MarketJSON.pluginsPathSegment)
            } else if currentTargetURL.absoluteString.contains(PluginConstants.MarketJSON.community) {
                rawURLString = currentTargetURL.absoluteString.replacingOccurrences(of: PluginConstants.MarketJSON.community, with: PluginConstants.MarketJSON.pluginsPathSegment)
            } else {
                rawURLString = currentTargetURL.deletingLastPathComponent().appendingPathComponent("plugins").absoluteString
            }
            
            if let downloadBase = URL(string: rawURLString) {
                let plugins = await MainActor.run {
                    communityPlugins.map { MarketPlugin(from: $0, downloadBase: downloadBase) }
                }
                await MainActor.run {
                    self.availablePlugins = plugins
                    self.isLoading = false
                }
                return true
            }
        }

        if let apiResponse = try? decoder.decode(ApiResponse<[MarketPlugin]>.self, from: data),
           let plugins = apiResponse.data {
            await MainActor.run {
                self.availablePlugins = plugins
                self.isLoading = false
            }
            return true
        }

        if let decodedPlugins = try? decoder.decode([MarketPlugin].self, from: data) {
            await MainActor.run {
                self.availablePlugins = decodedPlugins
                self.isLoading = false
            }
            return true
        }

        return false
    }

    /// 下载指定的插件并将其保存到本地沙盒存储目录中
    func downloadPlugin(_ plugin: MarketPlugin) async -> Bool {
        guard let urlString = plugin.downloadURL, let baseURL = URL(string: urlString) else {
            Logger.shared.warning("[PluginMarket] 插件 \(plugin.name) 下载链接无效或缺失。")
            return false
        }

        await MainActor.run { 
            downloadingPluginID = plugin.id
            errorMessage = nil 
        }
        
        defer { 
            Task { @MainActor in downloadingPluginID = nil }
        }
        
        let fileManager = FileManager.default

        do {
            Logger.shared.info("[PluginMarket] 开始从明文目录并发下载插件: \(plugin.name)")
            let destinationFolderURL = try prepareDestinationFolder(for: plugin.id, fileManager: fileManager)
            let tasks = buildDownloadTasks(baseURL: baseURL, destinationFolderURL: destinationFolderURL)
            
            try await executeDownloadTasks(tasks)
            
            await MainActor.run {
                Logger.shared.info(" [PluginMarket] 插件下载并安装成功: \(plugin.name)")
            }
            
            // 扫描并重新加载插件以供系统挂载
            PluginRegistry.shared.scanAndLoadLocalPlugins()
            return true
        } catch {
            performDownloadRollback(for: plugin.id, fileManager: fileManager)
            await MainActor.run {
                Logger.shared.error(" [PluginMarket] 插件明文并发下载安装失败: \(plugin.name)", error: error)
                self.errorMessage = error.localizedDescription
            }
            return false
        }
    }

    /// 为指定插件准备物理沙盒目标文件夹，清理老旧缓存
    private func prepareDestinationFolder(for pluginID: String, fileManager: FileManager) throws -> URL {
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw NSError(
                domain: PluginConstants.MarketError.domain,
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: PluginConstants.MarketError.documentsNotFound]
            )
        }
        let pluginsDirectory = documentsURL.appendingPathComponent("Plugins")
        let destinationFolderURL = pluginsDirectory.appendingPathComponent(pluginID)
        
        if fileManager.fileExists(atPath: destinationFolderURL.path) {
            try fileManager.removeItem(at: destinationFolderURL)
        }
        try fileManager.createDirectory(at: destinationFolderURL, withIntermediateDirectories: true, attributes: nil)
        return destinationFolderURL
    }

    /// 构造所要下载的文件清单任务列表
    private func buildDownloadTasks(baseURL: URL, destinationFolderURL: URL) -> [FileDownloadTask] {
        return [
            FileDownloadTask(
                remoteURL: baseURL.appendingPathComponent(SystemConstants.FileName.manifestJSON),
                localURL: destinationFolderURL.appendingPathComponent(SystemConstants.FileName.manifestJSON),
                isRequired: true
            ),
            FileDownloadTask(
                remoteURL: baseURL.appendingPathComponent("index.js"),
                localURL: destinationFolderURL.appendingPathComponent("index.js"),
                isRequired: true
            ),
            FileDownloadTask(
                remoteURL: baseURL.appendingPathComponent("icon.png"),
                localURL: destinationFolderURL.appendingPathComponent("icon.png"),
                isRequired: false
            ),
            FileDownloadTask(
                remoteURL: baseURL.appendingPathComponent("README.md"),
                localURL: destinationFolderURL.appendingPathComponent("README.md"),
                isRequired: false
            ),
            FileDownloadTask(
                remoteURL: baseURL.appendingPathComponent("README.zh-Hans.md"),
                localURL: destinationFolderURL.appendingPathComponent("README.zh-Hans.md"),
                isRequired: false
            )
        ]
    }

    /// 并发吞吐执行网络拉取文件任务组，控制错误传递
    private func executeDownloadTasks(_ tasks: [FileDownloadTask]) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for task in tasks {
                group.addTask {
                    do {
                        let (tempURL, response) = try await URLSession.shared.download(from: task.remoteURL)
                        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                        guard statusCode == SystemConstants.HTTPStatusCode.ok else {
                            throw NSError(
                                domain: PluginConstants.MarketError.domain,
                                code: statusCode,
                                userInfo: [NSLocalizedDescriptionKey: "\(PluginConstants.MarketError.httpPrefix)\(statusCode)"]
                            )
                        }
                        
                        if FileManager.default.fileExists(atPath: task.localURL.path) {
                            try FileManager.default.removeItem(at: task.localURL)
                        }
                        try FileManager.default.moveItem(at: tempURL, to: task.localURL)
                        Logger.shared.info("[PluginMarket] 成功下载明文文件: \(task.remoteURL.lastPathComponent)")
                    } catch {
                        if task.isRequired {
                            throw error
                        } else {
                            Logger.shared.warning(
                                "[PluginMarket] 辅助资源拉取跳过: \(task.remoteURL.lastPathComponent), error: \(error.localizedDescription)"
                            )
                        }
                    }
                }
            }
            try await group.waitForAll()
        }
    }

    /// 发生异常时的下载清理回滚动作
    private func performDownloadRollback(for pluginID: String, fileManager: FileManager) {
        if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let destinationFolderURL = documentsURL.appendingPathComponent("Plugins").appendingPathComponent(pluginID)
            if fileManager.fileExists(atPath: destinationFolderURL.path) {
                try? fileManager.removeItem(at: destinationFolderURL)
            }
        }
    }

    /// 获取云端 README.md 拉取时的候选 URL 降级路径数组
    public func readmeCandidateURLs(
        forID pluginID: String,
        downloadURLString: String,
        preferredLanguages: [String] = [Localized.currentLanguage]
    ) -> [URL] {
        guard let downloadURL = URL(string: downloadURLString) else { return [] }
        let base = downloadURL.deletingLastPathComponent()
        let preferredLanguage = preferredLanguages.first ?? PluginConstants.LanguagePrefix.en
        
        var urlsToTry: [URL] = []
        if preferredLanguage.hasPrefix(PluginConstants.LanguagePrefix.zh) {
            urlsToTry.append(base.appendingPathComponent("\(pluginID)_zh-Hans.md"))
        } else if preferredLanguage.hasPrefix(PluginConstants.LanguagePrefix.en) {
            urlsToTry.append(base.appendingPathComponent("\(pluginID)_en.md"))
        } else {
            let cleanLang = preferredLanguage.components(separatedBy: "-").first ?? preferredLanguage
            urlsToTry.append(base.appendingPathComponent("\(pluginID)_\(cleanLang).md"))
        }
        
        if !preferredLanguage.hasPrefix(PluginConstants.LanguagePrefix.en) {
            urlsToTry.append(base.appendingPathComponent("\(pluginID)_en.md"))
        }
        
        urlsToTry.append(base.appendingPathComponent("\(pluginID).md"))
        return urlsToTry
    }
}

/// 文件下载清单描述结构
private struct FileDownloadTask: Sendable {
    let remoteURL: URL
    let localURL: URL
    let isRequired: Bool
}
