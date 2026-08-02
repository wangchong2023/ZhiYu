//
//  StorageRecords.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：提供底层数据库中未被主 Domain Model 直接定义的物理表（如标签映射、重复间隔、审计日志及偏好设置）对应的 Record 实体。
//

import Foundation
import UFPStorage

// MARK: - 标签物理记录实体
/// 物理表：`tags`，负责存储全局扁平化标签词典
public struct TagRecord: Codable, FetchableRecord, MutablePersistableRecord, TableRecord, Sendable {
    
    // 绑定数据库表名
    public static let databaseTableName: String = AppConstants.Storage.Tables.tags
    
    /// 标签文本作为物理主键 ID
    public var id: String
    /// 标签名称，通常与 id 相同，支持拓展
    public var name: String
    /// 创建时间
    public var createdAt: Date
    
    /// 物理字段映射枚举，支持 GRDB 类型安全查询
    public enum CodingKeys: String, CodingKey, ColumnExpression {
        case id
        case name
        case createdAt = "created_at"
    }
    
    /// 标签记录初始化方法
    /// - Parameters:
    ///   - id: 标签主键文本
    ///   - name: 标签显示名称
    ///   - createdAt: 记录创建时间，默认为当前时间
    public init(id: String, name: String, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}

// MARK: - 页面标签关联物理记录实体
/// 物理表：`page_tags`，用于页面与标签的多对多映射关系
public struct PageTagRecord: Codable, FetchableRecord, MutablePersistableRecord, TableRecord, Sendable {
    
    // 绑定数据库表名
    public static let databaseTableName: String = AppConstants.Storage.Tables.pageTags
    
    /// 关联的知识页面 UUID 二进制数据
    public var pageID: Data
    /// 关联的标签文本主键 ID
    public var tagID: String
    
    /// 物理字段映射枚举
    public enum CodingKeys: String, CodingKey, ColumnExpression {
        case pageID = "page_id"
        case tagID = "tag_id"
    }
    
    /// 页面标签关联初始化方法
    /// - Parameters:
    ///   - pageID: 关联页面 ID 的二进制数据
    ///   - tagID: 关联的标签文本 ID
    public init(pageID: Data, tagID: String) {
        self.pageID = pageID
        self.tagID = tagID
    }
}

// MARK: - 间隔重复算法间隔元数据实体
/// 物理表：`srs_metadata`，存储卡片知识内化所需的 SRS 学习进度状态
public struct SRSMetadataRecord: Codable, FetchableRecord, MutablePersistableRecord, TableRecord, Sendable {
    
    // 绑定数据库表名
    public static let databaseTableName: String = AppConstants.Storage.Tables.srsMetadata
    
    /// 页面 ID，映射 `pages` 主键，同时作为本表主键
    public var pageID: Data
    /// 简易度因子 (Ease Factor)，影响下一次复习间隔的缩放比例
    public var easeFactor: Double
    /// 历史连续回答正确次数
    public var repetitions: Int
    /// 距离下一次复习的间隔时长 (天数)
    public var reviewInterval: Int
    /// 下一次推荐复习的物理时间
    public var nextReviewAt: Date
    /// 记录创建时间
    public var createdAt: Date
    /// 记录最后更新时间
    public var updatedAt: Date
    
    /// 物理字段映射枚举
    public enum CodingKeys: String, CodingKey, ColumnExpression {
        case pageID = "page_id"
        case easeFactor = "ease_factor"
        case repetitions
        case reviewInterval = "review_interval"
        case nextReviewAt = "next_review_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    /// 初始化方法
    /// - Parameters:
    ///   - pageID: 页面 UUID 二进制数据
    ///   - easeFactor: 简易度因子，默认值为系统配置默认值 2.5
    ///   - repetitions: 重复次数，默认为 0
    ///   - reviewInterval: 复习间隔，默认为 0
    ///   - nextReviewAt: 首次复习时间，默认当前时间
    ///   - createdAt: 创建时间，默认当前时间
    ///   - updatedAt: 修改时间，默认当前时间
    public init(
        pageID: Data,
        easeFactor: Double = AppConstants.Storage.defaultEaseFactor,
        repetitions: Int = 0,
        reviewInterval: Int = 0,
        nextReviewAt: Date = Date(),
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.pageID = pageID
        self.easeFactor = easeFactor
        self.repetitions = repetitions
        self.reviewInterval = reviewInterval
        self.nextReviewAt = nextReviewAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - 系统全局设置配置实体
/// 物理表：`global_settings`，用于系统级全局偏好设置持久化
public struct GlobalSettingRecord: Codable, FetchableRecord, MutablePersistableRecord, TableRecord, Sendable {
    
    // 绑定数据库表名
    public static let databaseTableName: String = AppConstants.Storage.Tables.globalSettings
    
    /// 配置项主键 Key
    public var key: String
    /// 配置项对应的值 Value (通常为 JSON/String 序列化格式)
    public var value: String
    /// 最后一次更新时间
    public var updatedAt: Date
    
    /// 物理字段映射枚举
    public enum CodingKeys: String, CodingKey, ColumnExpression {
        case key
        case value
        case updatedAt = "updated_at"
    }
    
    /// 全局配置项初始化方法
    /// - Parameters:
    ///   - key: 配置键
    ///   - value: 配置值
    ///   - updatedAt: 更新时间，默认为当前时间
    public init(key: String, value: String, updatedAt: Date = Date()) {
        self.key = key
        self.value = value
        self.updatedAt = updatedAt
    }
}

// MARK: - 系统安全与损耗审计日志实体
/// 物理表：`audit_logs`，审计 AI 资源调用及重要安全事件
public struct AuditLogRecord: Codable, FetchableRecord, MutablePersistableRecord, TableRecord, Sendable {
    
    // 绑定数据库表名
    public static let databaseTableName: String = AppConstants.Storage.Tables.auditLogs
    
    /// 自增主键 ID
    public var id: Int64?
    /// 审计事件的动作标识
    public var action: String
    /// 详细备注或参数 JSON Payload
    public var details: String?
    /// 日志物理生成时间
    public var createdAt: Date
    
    /// 物理字段映射枚举
    public enum CodingKeys: String, CodingKey, ColumnExpression {
        case id
        case action
        case details
        case createdAt = "created_at"
    }
    
    /// 审计日志初始化方法
    /// - Parameters:
    ///   - id: 物理自增 ID，默认为 nil
    ///   - action: 动作标示
    ///   - details: 详情负载
    ///   - createdAt: 日志创建时间，默认为当前时间
    public init(id: Int64? = nil, action: String, details: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.action = action
        self.details = details
        self.createdAt = createdAt
    }
}
