//
//  TokenManager.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：Token 生命周期管理 — 自动登录恢复 / 登录态持久化 / 刷新 / 注销清理 / 用户资料同步。
//

import Foundation
import UFPCore

extension AuthService {

    // MARK: - 自动登录恢复

    /// 自动静默登录验证，利用 Keychain 本地缓存的 token 进行登录态恢复
    /// - Returns: 是否登录恢复成功
    public func tryAutoLogin() async -> Bool {
        #if DEBUG
        if isMockBackend {
            // Mock 模式：检测到 Mock 环境则直接构造并注入假登录用户态
            let mockUser = User(
                id: UUID(),
                name: "Mock Autologin User",
                email: "mock_autologin@example.com",
                phone: "13800000000",
                avatarURL: nil
            )
            AuthSession.shared.update(user: mockUser)
            saveState()
            return true
        }
        #endif

        // 1. 尝试从安全区 Keychain 提取现存的 Token
        guard (try? KeychainService.shared.retrieve(key: AppConstants.Network.jwtTokenKey)) != nil else {
            return false
        }

        do {
            // 2. 发起 GET 请求拉取服务器上用户的最新 Profile 资料
            let response: UserProfileResponse = try await NetworkClient.shared.request(
                path: AppConstants.Network.userProfilePath,
                method: AppConstants.Network.methodGET,
                requiresAuth: true
            )

            // 3. 构造本地 User 模型并更新状态树
            let user = User(
                id: UUID(uuidString: String(response.userId)) ?? UUID(),
                name: response.nick,
                email: response.email ?? "",
                phone: response.mobile,
                avatarURL: response.avatar.flatMap { URL(string: $0) }
            )
            AuthSession.shared.update(user: user)
            saveState()
            return true
        } catch {
            Logger.shared.error("[AuthService] 自动静默登录拉取 Profile 失败: ", error: error)
            return false
        }
    }

    // MARK: - 登录成功处理

    /// 登录成功后统一处理：存储 Token → 拉取用户资料 → 更新本地状态
    /// - Parameters:
    ///   - response: 后端返回的登录响应（含 JWT）
    ///   - identity: 用户标识（用于 Mock 模式构造 User）
    /// - Returns: 是否处理成功
    @MainActor
    internal func handleSuccessfulLogin(response: LoginResponse, identity: String) async -> Bool {
        do {
            // 写入本地安全区
            try KeychainService.shared.store(key: AppConstants.Network.jwtTokenKey, value: response.accessToken)
            if let refresh = response.refreshToken {
                try KeychainService.shared.store(key: "refresh_token", value: refresh)
            }
        } catch {
            Logger.shared.error("[AuthService] Token storage failed", error: error)
            #if DEBUG
            if isMockBackend {
                Logger.shared.warning("[AuthService] Mock Keychain write skipped")
            } else {
                return false
            }
            #else
            return false
            #endif
        }

        #if DEBUG
        if isMockBackend {
            let mockUser = User(
                id: UUID(),
                name: identity,
                email: "",
                phone: nil,
                avatarURL: nil
            )
            AuthSession.shared.update(user: mockUser)
            saveState()
            return true
        }
        #endif

        do {
            let profileResponse: UserProfileResponse = try await NetworkClient.shared.request(
                path: AppConstants.Network.userProfilePath,
                method: AppConstants.Network.methodGET,
                requiresAuth: true
            )

            let user = User(
                id: UUID(uuidString: String(profileResponse.userId)) ?? UUID(),
                name: profileResponse.nick,
                email: profileResponse.email ?? "",
                phone: profileResponse.mobile,
                avatarURL: profileResponse.avatar.flatMap { URL(string: $0) }
            )
            AuthSession.shared.update(user: user)
            saveState()
            return true
        } catch {
            Logger.shared.error("[AuthService] 拉取用户配置失败: ", error: error)
            return false
        }
    }

    // MARK: - KeyStore

    /// 键值存储抽象（extension 不支持 @Inject，使用 computed property 安全解析）
    private var keyStore: (any KeyStoreProtocol)? {
        ServiceContainer.shared.resolveOptional((any KeyStoreProtocol).self)
    }

    // MARK: - 状态持久化

    /// 将当前认证状态写入 KeyStore（供 App 启动恢复用）
    internal func saveState() {
        keyStore?.set(isAuthenticated, forKey: AppConstants.Keys.Storage.authIsAuthenticated)
        keyStore?.set(isGuest, forKey: AppConstants.Keys.Storage.authIsGuest)
    }

    // MARK: - 用户资料刷新

    /// 从后端拉取最新个人资料并更新本地 User 缓存
    /// 在登录成功或支付激活后调用，保证本地数据与后端同步
    public func refreshUserProfile() async throws {
        let profile: RefreshProfileResponse = try await NetworkClient.shared.request(
            path: "/api/v1/user/profile",
            method: "GET",
            requiresAuth: true
        )

        var currentPlanKey: String? = "free"
        var parsedQuotas: RefreshPlanQuotas?
        var parsedFeatures: [String] = []

        do {
            let sub: RefreshSubscriptionResponse = try await NetworkClient.shared.request(
                path: "/api/v1/subscriptions/me",
                method: "GET",
                requiresAuth: true
            )
            currentPlanKey = sub.planKey ?? "free"

            if let quotasStr = sub.quotasJson, let data = quotasStr.data(using: .utf8) {
                parsedQuotas = try? JSONDecoder().decode(RefreshPlanQuotas.self, from: data)
            }

            if let featuresStr = sub.featuresJson, let data = featuresStr.data(using: .utf8) {
                if let decodedFeatures = try? JSONDecoder().decode([String].self, from: data) {
                    parsedFeatures = decodedFeatures
                }
            }
        } catch {
            Logger.shared.warning("[AuthService] 获取当前订阅信息失败，将使用默认配置: \(error)")
        }

        // 3. 合并更新本地 User 对象
        if let user = AuthSession.shared.currentUser {
            // 如果后端未返回或解析失败，默认给与 Lite (free) 的限制以策安全
            let defaultLiteQuotas = RefreshPlanQuotas(
                maxVaults: User.DefaultQuotas.liteMaxVaults,
                maxPages: User.DefaultQuotas.liteMaxPages,
                maxPlugins: User.DefaultQuotas.liteMaxPlugins
            )
            let quotasToUse = parsedQuotas ?? defaultLiteQuotas

            let updated = User(
                id: user.id,
                name: profile.nick,
                email: profile.email.flatMap { $0.isEmpty ? nil : $0 } ?? user.email,
                phone: profile.mobile.flatMap { $0.isEmpty ? nil : $0 } ?? user.phone,
                avatarURL: profile.avatar.flatMap { URL(string: $0) },
                planKey: currentPlanKey,
                maxVaults: quotasToUse.maxVaults,
                maxPages: quotasToUse.maxPages,
                maxPlugins: quotasToUse.maxPlugins,
                features: parsedFeatures
            )
            AuthSession.shared.update(user: updated)
        }
    }
}

// MARK: - 私有 DTO 结构体

/// 用户基本信息响应体
private struct RefreshProfileResponse: Codable {
    let userId: Int64
    let username: String
    let nick: String
    let avatar: String?
    let email: String?
    let mobile: String?
}

/// 用户订阅套餐信息响应体
private struct RefreshSubscriptionResponse: Codable {
    let planKey: String?
    let quotasJson: String?
    let featuresJson: String?
}

/// 用户订阅配置限额详情
private struct RefreshPlanQuotas: Codable {
    let maxVaults: Int
    let maxPages: Int
    let maxPlugins: Int

    enum CodingKeys: String, CodingKey {
        case maxVaults = "max_vaults"
        case maxPages = "max_pages"
        case maxPlugins = "max_plugins"
    }
}
