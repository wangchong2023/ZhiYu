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

/// 用户订阅套餐 Key 常量（与后端通信的字符串标识）
public enum PlanKey {
    /// Lite 版（未订阅时后端返回 "free"，本地按 Lite 权益处理）
    public static let lite = "lite"
    /// Pro 专业版
    public static let pro = "pro"
    /// 后端返回的未订阅标识，本地按 Lite 权益处理
    public static let free = "free"
}

/// 用户订阅套餐等级（按权益高低排序，支持 Comparable 进行等级比较）
/// 新增套餐时只需在此枚举追加 case 并配置 rawValue 与 defaultQuotas，
/// 业务侧的 `isPro` / `isAtLeast` 等判断无需改动。
public enum PlanTier: String, Comparable, Sendable {
    /// 未订阅（后端返回 "free"，本地按 Lite 权益处理）
    case free
    /// Lite 基础版
    case lite
    /// Pro 专业版
    case pro

    /// Comparable 排序：free < lite < pro
    public static func < (lhs: PlanTier, rhs: PlanTier) -> Bool {
        lhs.rank < rhs.rank
    }

    /// 等级数值（用于比较，不暴露给业务层）
    private var rank: Int {
        switch self {
        case .free: return 0
        case .lite: return 1
        case .pro: return 2
        }
    }

    /// 该等级的默认配额（后端未返回配额时使用）
    public var defaultQuotas: User.DefaultQuotas.Quota {
        switch self {
        case .free, .lite:
            return User.DefaultQuotas.liteQuota
        case .pro:
            return User.DefaultQuotas.proQuota
        }
    }

    /// 从后端返回的 planKey 字符串解析为 PlanTier
    /// 未知字符串降级为 `.free`（按 Lite 权益处理，策安全）
    public static func from(planKey: String?) -> PlanTier {
        guard let key = planKey else { return .free }
        return PlanTier(rawValue: key) ?? .free
    }
}

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

        /// 套餐配额聚合（便于按 PlanTier 统一获取）
        public struct Quota: Sendable {
            public let maxVaults: Int
            public let maxPages: Int
            public let maxPlugins: Int
        }

        /// Lite 基础版默认配额
        public static let liteQuota = Quota(
            maxVaults: liteMaxVaults,
            maxPages: liteMaxPages,
            maxPlugins: liteMaxPlugins
        )

        /// Pro 专业版默认配额
        public static let proQuota = Quota(
            maxVaults: proMaxVaults,
            maxPages: proMaxPages,
            maxPlugins: proMaxPlugins
        )
    }

    // MARK: - 初始化

    /// 完整初始化方法
    public init(
        id: UUID = UUID(),
        name: String,
        email: String,
        phone: String? = nil,
        avatarURL: URL? = nil,
        planKey: String? = PlanKey.free,
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

    /// 当前套餐等级（从 planKey 字符串解析）
    public var planTier: PlanTier {
        PlanTier.from(planKey: planKey)
    }

    /// 是否为 Pro 专业版用户
    /// 使用等级比较，未来新增更高套餐（如 team/enterprise）时无需修改此判断
    public var isPro: Bool {
        planTier >= .pro
    }

    /// 当前套餐是否达到指定等级
    /// - Parameter tier: 门槛等级
    /// - Returns: 当前套餐等级 >= tier 时返回 true
    public func isAtLeast(_ tier: PlanTier) -> Bool {
        planTier >= tier
    }

    /// 是否具有隐私安全特性权限（Pro 或 features 中包含 privacy_security）
    public var hasPrivacySecurity: Bool {
        return features.contains(FeatureConstants.FeatureKey.privacySecurity) || isPro
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
        self.planKey = (try? container.decodeIfPresent(String.self, forKey: .planKey)) ?? PlanKey.free
        self.maxVaults = (try? container.decodeIfPresent(Int.self, forKey: .maxVaults)) ?? DefaultQuotas.liteMaxVaults
        self.maxPages = (try? container.decodeIfPresent(Int.self, forKey: .maxPages)) ?? DefaultQuotas.liteMaxPages
        self.maxPlugins = (try? container.decodeIfPresent(Int.self, forKey: .maxPlugins)) ?? DefaultQuotas.liteMaxPlugins
        self.features = (try? container.decodeIfPresent([String].self, forKey: .features)) ?? []
    }
}
