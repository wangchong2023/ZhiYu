//
//  AuthService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：身份认证服务协调器 — 组合 OAuth / PhoneAuth / TokenManager 三大子模块。
//

import Foundation
import UFPCore
import Observation

/// 身份认证服务
/// 负责管理应用的访问权限，支持多种登录方式及游客模式。
@Observable
@MainActor
public final class AuthService: AuthServiceProtocol {
    
    // MARK: - 状态属性
    
    /// 是否已通过身份认证 (登录成功)
    public var isAuthenticated: Bool {
        AuthSession.shared.isLoggedIn
    }
    
    /// 是否处于游客模式
    public var isGuest: Bool {
        AuthSession.shared.isGuest
    }
    
    /// 当前登录用户 (可选)
    public var currentUser: User? {
        AuthSession.shared.currentUser
    }
    
    // MARK: - 单例与初始化
    
    public static let shared = AuthService()
    
    private init() {}

    // MARK: - 测试辅助

    #if DEBUG
    /// 单元测试用：强制启用 mock backend 模式，无需设置 ProcessInfo 启动参数
    public static var forceMockBackend = false
    #endif

    var isMockBackend: Bool {
        #if DEBUG
        // 优先检查强制 mock 标志（供单元测试使用）
        if Self.forceMockBackend { return true }
        // 其次检查 UI 测试启动参数（与 AppEnvironment 内存数据库 mock 保持一致）
        return TestModeDetector.isMockDataMode
        #else
        return false
        #endif
    }

    /// 是否处于 Mock 模式下（供视图层与其它服务判定）
    public var isMockMode: Bool {
        isMockBackend
    }

    // MARK: - 核心操作
    
    /// 以游客身份进入系统
    public func continueAsGuest() {
        AuthSession.shared.update(user: nil)
        AuthSession.shared.isGuest = true
        saveState()
    }
    
    /// 用于测试的后台注销任务追踪
    public var testLogoutTask: Task<Void, Never>?
    
    /// 用于测试的后台注销任务追踪列表，防止早期被 XCTest 释放导致崩溃
    public var testLogoutTasks: [Task<Void, Never>] = []
    
    /// 退出登录
    @MainActor
    public func logout() {
        Logger.shared.debug("[AuthService] logout() called")
        AuthSession.shared.logout()
        VaultService.shared.exitVault()
        saveState()
        
        if testLogoutTask != nil {
            Logger.shared.debug("[AuthService] Cancelling existing testLogoutTask")
            testLogoutTask?.cancel()
        }
        
        let task = Task {
            Logger.shared.debug("[AuthService] Logout Task started")
            // 尝试通知后端登出并吊销 RefreshToken
            if let refreshToken = try? KeychainService.shared.retrieve(key: AppConstants.Network.refreshTokenKey) {
                Logger.shared.debug("[AuthService] Revoking token on backend...")
                let req = RefreshRequest(refreshToken: refreshToken)
                let result: EmptyData? = try? await NetworkClient.shared.request(
                    path: APIPaths.logoutPath,
                    method: SystemConstants.HTTPMethod.post,
                    body: req,
                    requiresAuth: true
                )
                Logger.shared.debug("[AuthService] Backend revoke result: \(result != nil ? "success" : "failed/nil")")
            } else {
                Logger.shared.debug("[AuthService] No refresh token found to revoke")
            }
            
            // 清理本地状态
            Logger.shared.debug("[AuthService] Deleting tokens from Keychain...")
            try? KeychainService.shared.delete(key: AppConstants.Network.jwtTokenKey)
            try? KeychainService.shared.delete(key: AppConstants.Network.refreshTokenKey)
            Logger.shared.debug("[AuthService] Logout Task completed")
        }
        
        testLogoutTask = task
        testLogoutTasks.append(task)
    }
    
    // MARK: - 个人信息修改与支付校验
    
    /// 更新个人资料
    /// - Parameters:
    ///   - nickname: 昵称
    ///   - avatar: 头像地址（URL字符串）
    ///   - gender: 性别
    ///   - birthday: 生日
    /// - Returns: 是否更新成功
    public func updateUserProfile(nickname: String, avatar: String?, gender: Int? = nil, birthday: String? = nil) async -> Bool {
        #if DEBUG
        if isMockBackend {
            // Mock 模式：直接更新本地缓存，不调用网络
            if let user = AuthSession.shared.currentUser {
                let updated = User(
                    id: user.id,
                    name: nickname,
                    email: user.email,
                    phone: user.phone,
                    avatarURL: avatar.flatMap { URL(string: $0) } ?? user.avatarURL,
                    planKey: user.planKey,
                    maxVaults: user.maxVaults,
                    maxPages: user.maxPages,
                    maxPlugins: user.maxPlugins,
                    features: user.features,
                    gender: gender ?? user.gender,
                    birthday: birthday ?? user.birthday
                )
                AuthSession.shared.update(user: updated)
                return true
            }
            return false
        }
        #endif
        
        // 实际请求后端 PUT /api/v1/user/profile 更新昵称和头像
        struct ProfileUpdateRequest: Codable {
            let nick: String
            let avatar: String?
            let gender: Int?
            let birthday: String?
        }
        
        let req = ProfileUpdateRequest(nick: nickname, avatar: avatar, gender: gender, birthday: birthday)
        do {
            let response: UserProfileResponse = try await NetworkClient.shared.request(
                path: APIPaths.userProfilePath,
                method: SystemConstants.HTTPMethod.put,
                body: req,
                requiresAuth: true
            )
            
            // 更新本地用户信息
            if let user = AuthSession.shared.currentUser {
                let updated = User(
                    id: user.id,
                    name: response.nick,
                    email: response.email ?? user.email,
                    phone: response.mobile ?? user.phone,
                    avatarURL: response.avatar.flatMap { URL(string: $0) } ?? user.avatarURL,
                    planKey: user.planKey,
                    maxVaults: user.maxVaults,
                    maxPages: user.maxPages,
                    maxPlugins: user.maxPlugins,
                    gender: response.gender ?? user.gender,
                    birthday: response.birthday ?? user.birthday
                )
                AuthSession.shared.update(user: updated)
            }
            return true
        } catch {
            Logger.shared.error("[AuthService] 更新个人资料失败: ", error: error)
            return false
        }
    }
    
    /// 上传头像图片到后端 OSS
    /// - Parameter imageData: 图片的二进制数据（PNG/JPEG）
    /// - Returns: 上传成功后返回的头像 URL 字符串，失败返回 nil
    public func uploadAvatar(imageData: Data) async -> String? {
        #if DEBUG
        if isMockBackend {
            // Mock 模式：返回随机头像 URL
            return "\(APIPaths.multiAvatarAPI)/\(UUID().uuidString).png"
        }
        #endif
        
        do {
            // 调用 NetworkClient 的 multipart 上传接口
            let avatarUrl: String = try await NetworkClient.shared.uploadFile(
                path: APIPaths.avatarUploadPath,
                fileData: imageData,
                fileName: AppConstants.Network.avatarFileName,
                mimeType: AppConstants.Network.avatarMimeType,
                requiresAuth: true
            )
            return avatarUrl
        } catch {
            Logger.shared.error("[AuthService] 上传头像失败: ", error: error)
            return nil
        }
    }
    
    /// 向后端验证 Apple 内购收据并激活 Pro 权益
    /// - Parameters:
    ///   - productId: App Store 商品 ID
    ///   - receiptData: StoreKit 返回的 Base64 编码收据
    ///   - orderNo: 发起购买前系统生成的订单号（可选）
    /// - Returns: 验证并激活成功返回 true
    public func verifyApplePurchase(productId: String, receiptData: String, orderNo: String?) async -> Bool {
        #if DEBUG
        if isMockBackend {
            // Mock 模式：直接本地激活 Pro
            if let user = AuthSession.shared.currentUser {
                let updated = User(
                    id: user.id,
                    name: user.name,
                    email: user.email,
                    avatarURL: user.avatarURL,
                    planKey: PlanKey.pro,
                    maxVaults: User.DefaultQuotas.proMaxVaults,
                    maxPages: User.DefaultQuotas.proMaxPages,
                    maxPlugins: User.DefaultQuotas.proMaxPlugins
                )
                AuthSession.shared.update(user: updated)
                return true
            }
            return false
        }
        #endif
        
        struct VerifyRequest: Codable {
            let productId: String
            let receiptData: String
            let orderNo: String?
        }
        
        struct VerifyResponse: Codable {
            let orderNo: String
            let status: String
            let planKey: String?
        }
        
        let body = VerifyRequest(productId: productId, receiptData: receiptData, orderNo: orderNo)
        do {
            let _: VerifyResponse = try await NetworkClient.shared.request(
                path: APIPaths.subscriptionAppleVerifyPath,
                method: SystemConstants.HTTPMethod.post,
                body: body,
                requiresAuth: true
            )
            // 校验成功后，重新拉取最新用户资料（含套餐限额）
            try await refreshUserProfile()
            return true
        } catch {
            Logger.shared.error("[AuthService] 验证苹果支付凭证失败: ", error: error)
            return false
        }
    }
}

// MARK: - 数据模型
// User 已移动至 Sources/Features/Auth/Models/User.swift
