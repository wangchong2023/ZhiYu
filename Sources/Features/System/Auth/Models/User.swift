//
//  User.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：用户认证模型：包含基本信息与订阅套餐配额字段。
//
import Foundation

/// 用户信息模型
/// 包含基本身份信息以及当前订阅套餐的配额限制字段。
public struct User: Codable, Identifiable, Sendable {
    // MARK: - 基本身份信息

    /// 唯一标识符
    public let id: UUID
    /// 用户昵称/显示名
    public let name: String
    /// 电子邮箱
    public let email: String
    /// 手机号（通过短信登录时存在）
    public let phone: String?
    /// 头像远端 URL（可选）
    public var avatarURL: URL?
    /// 性别（0:未知, 1:男, 2:女）
    public var gender: Int?
    /// 生日（YYYY-MM-DD格式）
    public var birthday: String?

    // MARK: - 订阅套餐信息

    /// 当前套餐标识：free（Lite 基础版）或 pro（Pro 专业版）
    public var planKey: String?
    /// 套餐允许的最大笔记本数量
    public var maxVaults: Int
    /// 套餐允许的最大知识页面数量
    public var maxPages: Int
    /// 套餐允许的最大插件安装数量
    public var maxPlugins: Int
    /// 当前套餐包含的特性列表 (例如: "local_slm", "privacy_security" 等)
    public var features: [String]

    public struct DefaultQuotas {
        public static let liteMaxVaults = 2
        public static let liteMaxPages = 1000
        public static let liteMaxPlugins = 3
        
        public static let proMaxVaults = 100
        public static let proMaxPages = 50000
        public static let proMaxPlugins = 999999
    }

    // MARK: - 初始化

    /// 完整初始化方法
    public init(
        id: UUID = UUID(),
        name: String,
        email: String,
        phone: String? = nil,
        avatarURL: URL? = nil,
        planKey: String? = "free",
        maxVaults: Int = DefaultQuotas.liteMaxVaults,
        maxPages: Int = DefaultQuotas.liteMaxPages,
        maxPlugins: Int = DefaultQuotas.liteMaxPlugins,
        features: [String] = [],
        gender: Int? = nil,
        birthday: String? = nil
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.phone = phone
        self.avatarURL = avatarURL
        self.planKey = planKey
        self.maxVaults = maxVaults
        self.maxPages = maxPages
        self.maxPlugins = maxPlugins
        self.features = features
        self.gender = gender
        self.birthday = birthday
    }

    // MARK: - 便捷属性

    /// 是否为 Pro 专业版用户
    public var isPro: Bool {
        planKey == "pro"
    }
    
    /// 是否具有隐私安全特性权限（Pro 或 features 中包含 privacy_security）
    public var hasPrivacySecurity: Bool {
        return features.contains("privacy_security") || isPro
    }

    // MARK: - Codable 适配后端 UserProfileResp
    
    private enum CodingKeys: String, CodingKey {
        case id = "userId"
        case name = "nick"
        case email
        case phone = "mobile"
        case avatarURL = "avatar"
        case gender
        case birthday
        case planKey = "plan_key"
        case maxVaults = "max_vaults"
        case maxPages = "max_pages"
        case maxPlugins = "max_plugins"
        case features
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // 解析 ID (后端返回的是 Long 的 userId)
        if let idLong = try? container.decode(Int64.self, forKey: .id) {
            let uuidString = String(format: "00000000-0000-0000-0000-%012x", idLong)
            self.id = UUID(uuidString: uuidString) ?? UUID()
        } else if let idString = try? container.decode(String.self, forKey: .id), let parsedId = UUID(uuidString: idString) {
            self.id = parsedId
        } else {
            self.id = UUID()
        }
        
        enum AlternateKeys: String, CodingKey {
            case username
        }
        let altContainer = try? decoder.container(keyedBy: AlternateKeys.self)
        
        self.name = (try? container.decodeIfPresent(String.self, forKey: .name)) ??
                    (try? altContainer?.decodeIfPresent(String.self, forKey: .username)) ?? "Guest"
        
        self.email = (try? container.decodeIfPresent(String.self, forKey: .email)) ?? ""
        self.phone = try? container.decodeIfPresent(String.self, forKey: .phone)
        
        if let avatarStr = try? container.decodeIfPresent(String.self, forKey: .avatarURL) {
            self.avatarURL = URL(string: avatarStr)
        } else {
            self.avatarURL = nil
        }
        
        self.gender = try? container.decodeIfPresent(Int.self, forKey: .gender)
        self.birthday = try? container.decodeIfPresent(String.self, forKey: .birthday)
        
        // 赋予默认套餐属性（因为后端目前暂无此字段）
        self.planKey = (try? container.decodeIfPresent(String.self, forKey: .planKey)) ?? "free"
        self.maxVaults = (try? container.decodeIfPresent(Int.self, forKey: .maxVaults)) ?? DefaultQuotas.liteMaxVaults
        self.maxPages = (try? container.decodeIfPresent(Int.self, forKey: .maxPages)) ?? DefaultQuotas.liteMaxPages
        self.maxPlugins = (try? container.decodeIfPresent(Int.self, forKey: .maxPlugins)) ?? DefaultQuotas.liteMaxPlugins
        self.features = (try? container.decodeIfPresent([String].self, forKey: .features)) ?? []
    }
}
