//
//  APIPaths.swift
//  ZhiYu
//
//  系统层级：[L0] 基础设施层
//  核心职责：后端 API 路径与外部服务 URL 常量集（认证/用户/订阅/OAuth/LLM 提供商等）。
//

import UFPCore

/// 后端 API 路径与外部服务 URL 常量集
public enum APIPaths {

    // MARK: - 认证相关 API 路径

    /// Token 刷新接口路径
    public static let refreshPath = "/api/v1/auth/refresh"
    /// 登出接口路径
    public static let logoutPath = "/api/v1/auth/logout"
    /// 手机号登录接口路径
    public static let phoneLoginPath = "/api/v1/auth/login"
    /// 发送短信验证码接口路径
    public static let smsSendPath = "/api/v1/auth/sms/send"
    /// Apple OAuth 登录接口路径
    public static let oauthApplePath = "/api/v1/auth/oauth/apple"
    /// WeChat OAuth 登录接口路径
    public static let oauthWeChatPath = "/api/v1/auth/oauth/wechat"
    /// Google OAuth 登录接口路径
    public static let oauthGooglePath = "/api/v1/auth/oauth/google"
    /// GitHub OAuth 登录接口路径
    public static let oauthGitHubPath = "/api/v1/auth/oauth/github"
    /// 运营商认证登录接口路径
    public static let carrierAuthPath = "/api/v1/auth/carrier"

    // MARK: - 用户相关 API 路径

    /// 用户资料接口路径
    public static let userProfilePath = "/api/v1/user/profile"
    /// 用户资料头像上传接口路径
    public static let avatarUploadPath = "/api/v1/user/profile/avatar"

    // MARK: - 订阅相关 API 路径

    /// Apple 订阅验证接口路径
    public static let subscriptionAppleVerifyPath = "/api/v1/subscriptions/apple/verify"
    /// 当前用户订阅信息接口路径
    public static let subscriptionsMePath = "/api/v1/subscriptions/me"

    // MARK: - 外部服务 URL

    /// 应用官网
    public static let officialWebsite = "https://www.izhiyu.top"
    /// MultiAvatar 头像生成 API
    public static let multiAvatarAPI = "https://api.multiavatar.com"
    /// GitHub OAuth 授权页 URL
    public static let gitHubOAuthAuthorize = "https://github.com/login/oauth/authorize"

    // MARK: - LLM 提供商 API URL

    /// 智谱 AI API URL
    public static let llmProviderZhipu = "https://open.bigmodel.cn/api/paas/v4"
    /// MiniMax API URL
    public static let llmProviderMinimax = "https://api.minimax.chat/v1"
    /// 通义千问 API URL
    public static let llmProviderQwen = "https://dashscope.aliyuncs.com/compatible-mode/v1"
    /// DeepSeek API URL
    public static let llmProviderDeepSeek = "https://api.deepseek.com/v1"
    /// Kimi (Moonshot) API URL
    public static let llmProviderKimi = "https://api.moonshot.cn/v1"
    /// SiliconFlow API URL
    public static let llmProviderSiliconFlow = "https://api.siliconflow.cn/v1"

    // MARK: - 插件市场 URL

    /// 社区插件列表 JSON URL
    public static let communityPluginsJSON = "https://raw.githubusercontent.com/wangchong2023/zhiyu-releases/master/community-plugins.json"

    // MARK: - 模型下载 CDN URL

    /// Gemma 2B 模型下载 URL
    public static let cdnModelGemma = "https://cdn.zhiyu.app/models/gemma-2b-it-q4.bin"
    /// Llama 3 8B 模型下载 URL
    public static let cdnModelLlama = "https://cdn.zhiyu.app/models/llama-3-8b-q4.bin"
    /// Phi-3 Mini 模型下载 URL
    public static let cdnModelPhi = "https://cdn.zhiyu.app/models/phi-3-mini-q4.bin"

    // MARK: - Web 存档与示例链接

    /// Web Archive 前缀
    public static let webArchivePrefix = "https://web.archive.org/web/2/"
    /// 示例链接：Karpathy LLM.c
    public static let exampleKarpathyLLM = "https://github.com/karpathy/llm.c"
    /// 示例链接：咖啡产业
    public static let exampleCoffeeIndustry = "https://finance.sina.com.cn/coffee-industry"

    // MARK: - 本地开发

    /// 本地开发默认地址
    public static let localhostDefault = "http://localhost:8000"
}
