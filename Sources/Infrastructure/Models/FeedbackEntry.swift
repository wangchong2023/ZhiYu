//
//  FeedbackEntry.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/10.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：用户反馈数据模型（GRDB ORM）

import Foundation
import UFPStorage

/// 用户反馈条目
public struct FeedbackEntry: Identifiable, Codable, FetchableRecord, MutablePersistableRecord, Sendable {
    public static let databaseTableName = AppConstants.Storage.Tables.feedbackEntries

    public var id: String
    public var title: String
    public var category: String
    public var rating: Int
    public var content: String
    public var appVersion: String
    public var osVersion: String
    public var deviceModel: String
    public var status: FeedbackStatus
    public var createdAt: Date

    public enum CodingKeys: String, CodingKey, ColumnExpression {
        case id, title, category, rating, content, status
        case appVersion = "app_version"
        case osVersion = "os_version"
        case deviceModel = "device_model"
        case createdAt = "created_at"
    }

    public init(
        id: String = UUID().uuidString,
        title: String,
        category: String,
        rating: Int,
        content: String,
        appVersion: String = "",
        osVersion: String = "",
        deviceModel: String = "",
        status: FeedbackStatus = .pending,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.rating = rating
        self.content = content
        self.appVersion = appVersion
        self.osVersion = osVersion
        self.deviceModel = deviceModel
        self.status = status
        self.createdAt = createdAt
    }
}

/// 用户反馈提交状态
public enum FeedbackStatus: String, Codable, Sendable, CaseIterable {
    case pending
    case synced
    case failed

    public var displayName: String {
        switch self {
        case .pending: return L10n.Settings.Feedback.statusPending
        case .synced: return L10n.Settings.Feedback.statusSynced
        case .failed: return L10n.Settings.Feedback.statusFailed
        }
    }
}

/// 反馈分类常量
public enum FeedbackCategory {
    public static let bug = "bug"
    public static let feature = "feature"
    public static let content = "content"
    public static let other = "other"

    public static let allCases = [bug, feature, content, other]

    public static func displayName(_ category: String) -> String {
        switch category {
        case bug: return L10n.Settings.Feedback.categoryBug
        case feature: return L10n.Settings.Feedback.categoryFeature
        case content: return L10n.Settings.Feedback.categoryContent
        case other: return L10n.Settings.Feedback.categoryOther
        default: return category
        }
    }
}
