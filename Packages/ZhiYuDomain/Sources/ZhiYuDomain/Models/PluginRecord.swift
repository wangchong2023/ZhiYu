//
//  PluginRecord.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/30.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层
//  核心职责：插件持久化记录模型，将插件元数据、安装状态及运行时统计映射至 SQLite。
//
import Foundation

/// 插件持久化记录：承载插件元数据、安装来源、运行状态及性能统计。
public struct PluginRecord: Codable, Sendable {
    /// 插件唯一标识符（对应 PluginManifest.id）
    public var id: String
    /// 本地化显示名称（当前 locale 解析后的值）
    public var name: String
    /// 插件版本号
    public var version: String
    /// 作者
    public var author: String
    /// 安装来源：local（本地 .zyplugin / .js）或 market（市场下载）
    public var source: String
    /// 运行状态：active / unloaded / suspended
    public var status: String
    /// 权限列表 JSON 数组字符串
    public var permissionsJSON: String
    /// 加载耗时（秒）
    public var loadDuration: Double
    /// 卸载耗时（秒）
    public var unloadDuration: Double
    /// 累计执行耗时（秒）
    public var totalExecutionTime: Double
    /// 调用次数
    public var callCount: Int
    /// 安装时间
    public var installedAt: Date
    /// 最后更新时间
    public var updatedAt: Date
    /// 原始 manifest JSON（完整备份，用于恢复插件元数据）
    public var manifestJSON: String

    public enum CodingKeys: String, CodingKey {
        case id, name, version, author, source, status
        case permissionsJSON = "permissions_json"
        case loadDuration = "load_duration"
        case unloadDuration = "unload_duration"
        case totalExecutionTime = "total_execution_time"
        case callCount = "call_count"
        case installedAt = "installed_at"
        case updatedAt = "updated_at"
        case manifestJSON = "manifest_json"
    }

    public init(id: String, name: String, version: String, author: String,
                source: String, status: String, permissionsJSON: String,
                loadDuration: Double = 0, unloadDuration: Double = 0,
                totalExecutionTime: Double = 0, callCount: Int = 0,
                installedAt: Date = Date(), updatedAt: Date = Date(),
                manifestJSON: String = "") {
        self.id = id
        self.name = name
        self.version = version
        self.author = author
        self.source = source
        self.status = status
        self.permissionsJSON = permissionsJSON
        self.loadDuration = loadDuration
        self.unloadDuration = unloadDuration
        self.totalExecutionTime = totalExecutionTime
        self.callCount = callCount
        self.installedAt = installedAt
        self.updatedAt = updatedAt
        self.manifestJSON = manifestJSON
    }
}
