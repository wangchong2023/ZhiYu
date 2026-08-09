//
//  PhoneAuthService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：手机号认证流程 — 密码登录 / 短信验证码发送 / 验证码注册登录。
//

import Foundation

extension AuthService {

    // MARK: - 密码登录

    /// 统一密码登录操作
    /// - Parameters:
    ///   - identity: 用户标识（用户名/手机号）
    ///   - password: 密码
    /// - Returns: 是否登录成功
    @MainActor
    public func login(identity: String, password: String) async -> Bool {
        #if DEBUG
        if isMockBackend {
            let response = LoginResponse(
                accessToken: "mock_jwt_access_token",
                refreshToken: "mock_jwt_refresh_token",
                expiresIn: 3600,
                tokenType: "Bearer",
                isNewUser: false,
                totpRequired: false
            )
            return await handleSuccessfulLogin(response: response, identity: identity)
        }
        #endif
        let req = LoginRequest.password(username: identity, password: password)
        do {
            let response: LoginResponse = try await NetworkClient.shared.request(
                path: APIPaths.phoneLoginPath,
                method: "POST",
                body: req,
                requiresAuth: false
            )

            return await handleSuccessfulLogin(response: response, identity: identity)
        } catch {
            Logger.shared.error("[AuthService] Password login failed", error: error)
            return false
        }
    }

    // MARK: - 短信验证码

    /// 发送注册/登录验证码
    /// - Parameters:
    ///   - phone: 手机号
    ///   - scene: 场景标识（login / register）
    /// - Returns: 是否发送成功
    @MainActor
    public func sendSmsCode(phone: String, scene: String) async -> Bool {
        let req = SendSmsRequest(phone: phone, scene: scene)
        do {
            let _: EmptyData = try await NetworkClient.shared.request(
                path: APIPaths.smsSendPath,
                method: "POST",
                body: req,
                requiresAuth: false
            )
            return true
        } catch {
            Logger.shared.error("[AuthService] SMS send failed", error: error)
            return false
        }
    }

    // MARK: - 验证码注册/登录

    /// 手机号+验证码登录/注册操作
    /// - Parameters:
    ///   - phone: 手机号
    ///   - code: 短信验证码
    ///   - password: 密码（可选，注册时设置）
    /// - Returns: 是否成功
    @MainActor
    public func register(phone: String, code: String, password: String) async -> Bool {
        let req = LoginRequest.sms(phone: phone, code: code)
        do {
            let response: LoginResponse = try await NetworkClient.shared.request(
                path: APIPaths.phoneLoginPath,
                method: "POST",
                body: req,
                requiresAuth: false
            )

            return await handleSuccessfulLogin(response: response, identity: phone)
        } catch {
            Logger.shared.error("[AuthService] SMS login/register failed", error: error)
            return false
        }
    }
}
