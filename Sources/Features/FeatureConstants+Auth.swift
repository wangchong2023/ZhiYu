//
//  FeatureConstants+Auth.swift
//  ZhiYu
//
//  系统层级：[L2] 业务功能层
//  核心职责：Features 模块认证、OAuth、订阅相关强类型常量。
//

import Foundation
import UFPCore

// MARK: - 认证相关常量
extension FeatureConstants {

    // MARK: - OAuth 提供商 (OAuth Provider)
    /// 第三方登录提供商标识字符串键
    enum OAuthProvider {
        static let apple: String = "apple"
        static let wechat: String = "wechat"
        static let google: String = "google"
        static let github: String = "github"
        static let carrier: String = "carrier"
    }

    // MARK: - OAuth 提供商 ID (OAuth Provider ID)
    /// 第三方登录按钮标识
    enum OAuthProviderId {
        static let apple: String = "auth.thirdparty.apple"
        static let google: String = "auth.thirdparty.google"
        static let github: String = "auth.thirdparty.github"
    }

    // MARK: - OAuth 授权类型 (OAuth Grant Type)
    /// OAuth 登录授权类型字面量
    enum GrantType {
        static let pwd = "password"
        static let sms = "sms_code"
    }

    // MARK: - OAuth 字段名 (OAuth Field Name)
    /// OAuth 凭证 extraInfo 字典 key
    enum OAuthField {
        static let nickname = "nickname"
        static let state = "state"
        static let code = "code"
        static let idToken = "idToken"
    }

    // MARK: - Google 配置 (Google Config)
    /// Google SDK 配置键与占位符
    enum GoogleConfig {
        static let clientIDKey = "GIDClientID"
        static let placeholderClientID = "YOUR_GOOGLE_CLIENT_ID"
    }

    // MARK: - 插件权限名 (Permission Name)
    /// 插件权限标识字符串键，用于 switch case 匹配
    enum PermissionName {
        static let readContent: String = "readContent"
        static let writeContent: String = "writeContent"
        static let network: String = "network"
        static let aiAccess: String = "aiAccess"
        static let log: String = "log"
    }

    // MARK: - 功能 Key (Feature Key)
    /// 用户 features 列表中的功能标识
    enum FeatureKey {
        static let privacySecurity = "privacy_security"
    }

    // MARK: - URL Scheme 名 (URL Scheme Name)
    /// 协议链接 scheme 与 host 标识
    enum URLSchemeName {
        static let privacy = "privacy"
        static let terms = "terms"
    }

    // MARK: - 协作 Key (Collaboration Key)
    /// 协作消息字典 key
    enum CollaborationKey {
        static let type = "type"
        static let pageSync = "pageSync"
    }

    // MARK: - 资产名 (Asset Name)
    /// Asset Catalog 资产名
    enum AssetName {
        static let githubLogo = "GithubLogo"
    }

    // MARK: - 区域标识 (Locale Identifier)
    /// 区域与语言标识符
    enum LocaleIdentifier {
        static let cn = "CN"
        static let zhHans = "zh-Hans"
        static let zhHansCN = "_CN"
    }

    // MARK: - 错误描述 (Error Description)
    /// AppError / NSError 描述文本
    enum ErrorDescription {
        static let weChatSDKNotConfigured = "WeChat SDK not configured"
        static let githubURLError = "GitHub URL Error"
        static let githubCallbackError = "GitHub Callback Error"
        static let githubStateMismatch = "GitHub State Mismatch"
        static let watchOSNotSupported = "WatchOS not supported"
    }

    // MARK: - Mock 凭证 (Mock Credential)
    /// Mock 认证凭证字面量
    enum MockCredential {
        static let mockJwtToken = "mock_jwt_token"
    }

    // MARK: - Mock 凭证 JSON Key (Mock Credential JSON Key)
    /// OAuth mock userInfo 字典 key
    enum MockCredentialKey {
        static let nickname = "nickname"
    }

    // MARK: - 认证翻转动效 (Auth Flip Animation)
    /// 认证区域 3D 翻转动效角度
    enum AuthFlip {
        static let rotationDegrees: Double = 180
    }

    // MARK: - 订阅配额 (Subscription Quota)
    /// 订阅配额卡片危险阈值
    enum SubscriptionQuota {
        static let dangerRatioThreshold: Double = 0.9
        /// 免费用户默认最大保险库数
        static let defaultMaxVaults: Int = 2
        /// 免费用户默认最大页面数
        static let defaultMaxPages: Int = 1000
        /// 免费用户默认最大插件数
        static let defaultMaxPlugins: Int = 3
        /// 无限额度显示符号
        static let unlimitedSymbol: String = "∞"
    }
}
