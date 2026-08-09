//
//  L10n+Auth.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 本地化层
//  核心职责：为 Auth 模块提供本地化强类型字符串的访问扩展。
//
import Foundation

extension L10n {
    public struct Auth: L10nTableEntry {
        public static let tableName = "System"
        public static var t: String { tableName }
        /// 本地化翻译
        /// - Parameter key: key
        /// - Returns: 返回值
        public static var login: String { tr("login") }
        public static var register: String { tr("register") }
        public static var logout: String { Localized.tr("logout", table: "Common") }
        public static var identityPlaceholder: String { tr("identity.placeholder") }
        public static var nicknamePlaceholder: String { tr("auth.nicknamePlaceholder") }
        public static var phonePlaceholder: String { Localized.tr("auth.phone.placeholder", table: t) }
        public static var setPasswordPlaceholder: String { Localized.tr("auth.setPassword.placeholder", table: t) }
        public static var passwordPlaceholder: String { tr("password.placeholder") }
        public static var codePlaceholder: String { tr("code.placeholder") }
        public static var getCode: String { tr("getCode") }
        public static var thirdParty: String { tr("thirdParty") }
        public static var guestMode: String { tr("guestMode") }
        public static var authFailed: String { tr("auth.failed") }

        // MARK: - 运营商认证错误
        public static var carrierSDKNotInitialized: String { tr("auth.carrier.sdkNotInitialized") }
        public static var carrierFailed: String { tr("auth.carrier.failed") }
        public static var carrierUserCancelled: String { tr("auth.carrier.userCancelled") }
        public static var carrierNoSIM: String { tr("auth.carrier.noSIM") }
        public static var carrierNoNetwork: String { tr("auth.carrier.noNetwork") }
        public static var carrierTimeout: String { tr("auth.carrier.timeout") }
        
        /// 微信登录开发中提示文案
        public static var wechatDeveloping: String { tr("auth.wechatDeveloping") }
        
        /// Google 登录开发中提示文案
        public static var googleDeveloping: String { tr("auth.googleDeveloping") }
        
        /// Apple 登录测试用户默认昵称
        public static var appleTestUser: String { tr("auth.appleTestUser") }
        
        /// 默认普通用户昵称
        public static var defaultUser: String { tr("auth.defaultUser") }
        
        /// 无法提取 Apple ID identityToken 的错误提示
        public static var appleTokenExtractFailed: String { tr("auth.appleTokenExtractFailed") }
        
        // MARK: - 一键登录相关
        public static var oneClickLogin: String { tr("auth.oneClickLogin") }
        public static var phoneVerify: String { tr("auth.phoneVerify") }
        public static var agreementText: String { tr("auth.agreementText") }
        public static var pleaseCheckAgreement: String { tr("auth.pleaseCheckAgreement") }
        public static var moreLoginMethods: String { tr("auth.moreLoginMethods") }
        public static var smsDeveloping: String { tr("auth.smsDeveloping") }
        public static var githubDeveloping: String { tr("auth.githubDeveloping") }
        public static var agreementRequired: String { tr("auth.agreementRequired") }

        // MARK: - 海外登录与区域切换
        public static var overseasWelcome: String { tr("auth.overseas.welcome") }
        public static var overseasSubtitle: String { tr("auth.overseas.subtitle") }
        public static var continueWithPasskey: String { tr("auth.overseas.continueWithPasskey") }
        public static var signInWithEmail: String { tr("auth.overseas.signInWithEmail") }
        public static var sendMagicLink: String { tr("auth.overseas.sendMagicLink") }
        public static var magicLinkSent: String { tr("auth.overseas.magicLinkSent") }
        public static var regionChina: String { tr("auth.region.china") }
        public static var regionInternational: String { tr("auth.region.international") }


        // MARK: - 隐私政策
        public static var privacyPolicyTitle: String { tr("auth.privacyPolicy.title") }
        public static var privacyPolicyContent: String { tr("auth.privacyPolicy.content") }

        // MARK: - 服务条款
        public static var termsOfServiceTitle: String { tr("auth.termsOfService.title") }
        public static var termsOfServiceContent: String { tr("auth.termsOfService.content") }

        // MARK: - 个人资料与套餐页面
        public static var profileAndQuota: String { tr("auth.profileAndQuota") }
        public static var currentSubscription: String { tr("auth.currentSubscription") }
        public static var subscription: String { tr("auth.subscription") }
        public static var litePlan: String { tr("auth.litePlan") }
        public static var proPlan: String { tr("auth.proPlan") }
        public static var litePlanTitle: String { tr("auth.litePlanTitle") }
        public static var proPlanTitle: String { tr("auth.proPlanTitle") }
        public static var litePlanDesc: String { tr("auth.litePlanDesc") }
        public static var proPlanDesc: String { tr("auth.proPlanDesc") }
        public static var upgradeToPro: String { tr("auth.upgradeToPro") }
        public static var unlockEverything: String { tr("auth.unlockEverything") }
        public static var unlimitedVaults: String { tr("auth.unlimitedVaults") }
        public static var unlimitedPages: String { tr("auth.unlimitedPages") }
        public static var aiSynthesis: String { tr("auth.aiSynthesis") }
        public static var premiumPlugins: String { tr("auth.premiumPlugins") }
        public static var prioritySupport: String { tr("auth.prioritySupport") }
        public static var upgradeSuccessMsg: String { tr("auth.upgradeSuccessMsg") }
        public static var upgradePro: String { tr("auth.upgradePro") }
        public static var nickname: String { tr("auth.nickname") }
        public static var birthday: String { tr("auth.birthday") }
        public static var gender: String { tr("auth.gender") }
        public static var genderMale: String { tr("auth.genderMale") }
        public static var genderFemale: String { tr("auth.genderFemale") }
        public static var genderSecret: String { tr("auth.genderSecret") }
        public static var accountId: String { tr("auth.accountId") }
        public static var phoneLabel: String { tr("auth.phoneLabel") }
        public static var avatar: String { tr("auth.avatar") }
        public static var saveChanges: String { tr("auth.saveChanges") }
        public static var saveSuccess: String { tr("auth.saveSuccess") }
        public static var saveFailed: String { tr("auth.saveFailed") }
        public static var uploadingAvatar: String { tr("auth.uploadingAvatar") }
        public static var uploadSuccess: String { tr("auth.uploadSuccess") }
        public static var uploadFailed: String { tr("auth.uploadFailed") }

        // MARK: - 活跃度与大盘统计
        public static var statsBoard: String { tr("auth.statsBoard") }
        public static var statsNotebooks: String { tr("auth.statsNotebooks") }
        public static var statsPages: String { tr("auth.statsPages") }
        public static var statsSynthesis: String { tr("auth.statsSynthesis") }
        public static var statsActiveDays: String { tr("auth.statsActiveDays") }

        // MARK: - 配额展示
        public static var vaultUsage: String { tr("auth.quota.vaultUsage") }
        public static var pagesUsage: String { tr("auth.quota.pagesUsage") }
        public static var pluginsUsage: String { tr("auth.quota.pluginsUsage") }

        // MARK: - 升级收银台
        public static var purchasing: String { tr("auth.purchasing") }
        public static var selectCycle: String { tr("auth.selectCycle") }
        public static var monthly: String { tr("auth.monthly") }
        public static var yearly: String { tr("auth.yearly") }
        public static var monthlyPrice: String { tr("auth.monthlyPrice") }
        public static var yearlyPrice: String { tr("auth.yearlyPrice") }
        public static var save20Percent: String { tr("auth.save20Percent") }
        public static var priceMonthlyPro: String { tr("auth.priceMonthlyPro") }
        public static var priceYearlyPro: String { tr("auth.priceYearlyPro") }
        public static var priceMonthlyLite: String { tr("auth.priceMonthlyLite") }
        public static var priceMonthlyProEquivalent: String { tr("auth.priceMonthlyProEquivalent") }
        public static var upgradeToProYearly: String { tr("auth.upgradeToProYearly") }
        public static var upgradeToProMonthly: String { tr("auth.upgradeToProMonthly") }
        public static var bestValue: String { tr("auth.bestValue") }
        public static var selectPayment: String { tr("auth.selectPayment") }
        public static var confirmPurchase: String { tr("auth.confirmPurchase") }
        public static var purchaseDisclaimer: String { tr("auth.purchaseDisclaimer") }
        public static var purchasePending: String { tr("auth.purchasePending") }
        public static var purchaseFailed: String { tr("auth.purchaseFailed") }
        public static var verifyFailed: String { tr("auth.verifyFailed") }
        public static var productNotFound: String { tr("auth.productNotFound") }
        public static var upgradeSuccessTitle: String { tr("auth.upgradeSuccessTitle") }
        public static var upgradeSuccessMessage: String { tr("auth.upgradeSuccessMessage") }
        public static var startUsingPro: String { tr("auth.startUsingPro") }
        
        // MARK: - 恢复购买（App Store 审核强制要求）
        /// 「恢复购买」按钮文案
        public static var restorePurchases: String { tr("auth.restorePurchases") }
        /// 恢复购买成功提示
        public static var restoreSuccess: String { tr("auth.restoreSuccess") }
        /// 恢复购买失败提示
        public static var restoreFailed: String { tr("auth.restoreFailed") }
        /// 恢复中 Loading 提示
        public static var restoring: String { tr("auth.restoring") }
        /// 恢复购买的作用机制注解
        public static var restoreHint: String { tr("auth.restoreHint") }


        // MARK: - 套餐权益对比子结构
        public struct Feature {
            public static var vaults: String { Localized.tr("auth.feature.vaults", table: Auth.t) }
            public static var pages: String { Localized.tr("auth.feature.pages", table: Auth.t) }
            public static var plugins: String { Localized.tr("auth.feature.plugins", table: Auth.t) }
            public static var aiSynth: String { Localized.tr("auth.feature.aiSynth", table: Auth.t) }
            public static var privacySecurity: String { Localized.tr("auth.feature.privacySecurity", table: Auth.t) }
            public static var vaultsLiteValue: String { Localized.tr("auth.feature.vaultsLiteValue", table: Auth.t) }
            public static var vaultsProValue: String { Localized.tr("auth.feature.vaultsProValue", table: Auth.t) }
            public static var pagesLiteValue: String { Localized.tr("auth.feature.pagesLiteValue", table: Auth.t) }
            public static var pagesProValue: String { Localized.tr("auth.feature.pagesProValue", table: Auth.t) }
            public static var pluginsLiteValue: String { Localized.tr("auth.feature.pluginsLiteValue", table: Auth.t) }
            public static var pluginsProValue: String { Localized.tr("auth.feature.pluginsProValue", table: Auth.t) }
            public static var aiSynthLiteValue: String { Localized.tr("auth.feature.aiSynthLiteValue", table: Auth.t) }
            public static var aiSynthProValue: String { Localized.tr("auth.feature.aiSynthProValue", table: Auth.t) }
            public static var privacySecurityLiteValue: String { Localized.tr("auth.feature.privacySecurityLiteValue", table: Auth.t) }
            public static var privacySecurityProValue: String { Localized.tr("auth.feature.privacySecurityProValue", table: Auth.t) }
        }

        // MARK: - 支付渠道子结构
        public struct Payment {
            public static var apple: String { Localized.tr("auth.payment.apple", table: Auth.t) }
            public static var wechat: String { Localized.tr("auth.payment.wechat", table: Auth.t) }
            public static var alipay: String { Localized.tr("auth.payment.alipay", table: Auth.t) }
        }
    }
}
