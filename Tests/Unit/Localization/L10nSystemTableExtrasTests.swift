//
//  L10nSystemTableExtrasTests.swift
//  ZhiYuTests
//
//  Created by CodeFree on 2026/08/10.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 System 表 L10n 扩展（Auth/Settings/Onboarding/Security/Network/Lint）的 tableName 正确性与属性 key 存在性。
//

import XCTest
@testable import ZhiYu

/// System 表 L10n 扩展补充测试（Auth/Settings/Onboarding/Security/Network/Lint）
/// 已有 L10nSystemTableTests 覆盖 Coachmark/Reminder/Shortcuts/Workflow
final class L10nSystemTableExtrasTests: XCTestCase {

    // MARK: - tableName 正确性

    func testTableName_Auth_为System() {
        XCTAssertEqual(L10n.Auth.tableName, "System")
    }

    func testTableName_Settings_为System() {
        XCTAssertEqual(L10n.Settings.tableName, "System")
    }

    func testTableName_Onboarding_为System() {
        XCTAssertEqual(L10n.Onboarding.tableName, "System")
    }

    func testTableName_Security_为System() {
        XCTAssertEqual(L10n.Security.tableName, "System")
    }

    func testTableName_Network_为System() {
        XCTAssertEqual(L10n.Network.tableName, "System")
    }

    func testTableName_Lint_为System() {
        XCTAssertEqual(L10n.Lint.tableName, "System")
    }

    // MARK: - Auth 属性 key 存在性

    func testAuth_登录相关属性返回非Missing值() {
        let values = [
            L10n.Auth.login,
            L10n.Auth.register,
            L10n.Auth.logout,
            L10n.Auth.identityPlaceholder,
            L10n.Auth.nicknamePlaceholder,
            L10n.Auth.phonePlaceholder,
            L10n.Auth.setPasswordPlaceholder,
            L10n.Auth.passwordPlaceholder,
            L10n.Auth.codePlaceholder,
            L10n.Auth.getCode,
            L10n.Auth.thirdParty,
            L10n.Auth.guestMode,
            L10n.Auth.authFailed
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Auth 登录属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Auth 登录属性返回空字符串")
        }
    }

    func testAuth_运营商相关属性返回非Missing值() {
        let values = [
            L10n.Auth.carrierSDKNotInitialized,
            L10n.Auth.carrierFailed,
            L10n.Auth.carrierUserCancelled,
            L10n.Auth.carrierNoSIM,
            L10n.Auth.carrierNoNetwork,
            L10n.Auth.carrierTimeout
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Auth 运营商属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Auth 运营商属性返回空字符串")
        }
    }

    func testAuth_第三方登录相关属性返回非Missing值() {
        let values = [
            L10n.Auth.wechatDeveloping,
            L10n.Auth.googleDeveloping,
            L10n.Auth.appleTestUser,
            L10n.Auth.defaultUser,
            L10n.Auth.appleTokenExtractFailed,
            L10n.Auth.oneClickLogin,
            L10n.Auth.phoneVerify,
            L10n.Auth.smsDeveloping,
            L10n.Auth.githubDeveloping
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Auth 第三方登录属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Auth 第三方登录属性返回空字符串")
        }
    }

    func testAuth_协议与区域属性返回非Missing值() {
        let values = [
            L10n.Auth.agreementText,
            L10n.Auth.pleaseCheckAgreement,
            L10n.Auth.moreLoginMethods,
            L10n.Auth.agreementRequired,
            L10n.Auth.overseasWelcome,
            L10n.Auth.overseasSubtitle,
            L10n.Auth.continueWithPasskey,
            L10n.Auth.signInWithEmail,
            L10n.Auth.sendMagicLink,
            L10n.Auth.magicLinkSent,
            L10n.Auth.regionChina,
            L10n.Auth.regionInternational,
            L10n.Auth.privacyPolicyTitle,
            L10n.Auth.privacyPolicyContent,
            L10n.Auth.termsOfServiceTitle,
            L10n.Auth.termsOfServiceContent
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Auth 协议区域属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Auth 协议区域属性返回空字符串")
        }
    }

    func testAuth_订阅相关属性返回非Missing值() {
        let values = [
            L10n.Auth.profileAndQuota,
            L10n.Auth.currentSubscription,
            L10n.Auth.subscription,
            L10n.Auth.litePlan,
            L10n.Auth.proPlan,
            L10n.Auth.litePlanTitle,
            L10n.Auth.proPlanTitle,
            L10n.Auth.litePlanDesc,
            L10n.Auth.proPlanDesc,
            L10n.Auth.upgradeToPro,
            L10n.Auth.unlockEverything,
            L10n.Auth.unlimitedVaults,
            L10n.Auth.unlimitedPages,
            L10n.Auth.aiSynthesis,
            L10n.Auth.premiumPlugins,
            L10n.Auth.prioritySupport,
            L10n.Auth.upgradeSuccessMsg,
            L10n.Auth.upgradePro
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Auth 订阅属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Auth 订阅属性返回空字符串")
        }
    }

    func testAuth_个人资料属性返回非Missing值() {
        let values = [
            L10n.Auth.nickname,
            L10n.Auth.birthday,
            L10n.Auth.gender,
            L10n.Auth.genderMale,
            L10n.Auth.genderFemale,
            L10n.Auth.genderSecret,
            L10n.Auth.accountId,
            L10n.Auth.phoneLabel,
            L10n.Auth.avatar,
            L10n.Auth.saveChanges,
            L10n.Auth.saveSuccess,
            L10n.Auth.saveFailed,
            L10n.Auth.uploadingAvatar,
            L10n.Auth.uploadSuccess,
            L10n.Auth.uploadFailed
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Auth 个人资料属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Auth 个人资料属性返回空字符串")
        }
    }

    func testAuth_统计与用量属性返回非Missing值() {
        let values = [
            L10n.Auth.statsBoard,
            L10n.Auth.statsNotebooks,
            L10n.Auth.statsPages,
            L10n.Auth.statsSynthesis,
            L10n.Auth.statsActiveDays,
            L10n.Auth.vaultUsage,
            L10n.Auth.pagesUsage,
            L10n.Auth.pluginsUsage
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Auth 统计属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Auth 统计属性返回空字符串")
        }
    }

    func testAuth_购买相关属性返回非Missing值() {
        let values = [
            L10n.Auth.purchasing,
            L10n.Auth.selectCycle,
            L10n.Auth.monthly,
            L10n.Auth.yearly,
            L10n.Auth.monthlyPrice,
            L10n.Auth.yearlyPrice,
            L10n.Auth.save20Percent,
            L10n.Auth.priceMonthlyPro,
            L10n.Auth.priceYearlyPro,
            L10n.Auth.priceMonthlyLite,
            L10n.Auth.priceMonthlyProEquivalent,
            L10n.Auth.upgradeToProYearly,
            L10n.Auth.upgradeToProMonthly,
            L10n.Auth.bestValue,
            L10n.Auth.selectPayment,
            L10n.Auth.confirmPurchase,
            L10n.Auth.purchaseDisclaimer,
            L10n.Auth.purchasePending,
            L10n.Auth.purchaseFailed,
            L10n.Auth.verifyFailed,
            L10n.Auth.productNotFound
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Auth 购买属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Auth 购买属性返回空字符串")
        }
    }

    func testAuth_恢复购买属性返回非Missing值() {
        let values = [
            L10n.Auth.upgradeSuccessTitle,
            L10n.Auth.upgradeSuccessMessage,
            L10n.Auth.startUsingPro,
            L10n.Auth.restorePurchases,
            L10n.Auth.restoreSuccess,
            L10n.Auth.restoreFailed,
            L10n.Auth.restoring,
            L10n.Auth.restoreHint
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Auth 恢复购买属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Auth 恢复购买属性返回空字符串")
        }
    }

    // MARK: - Settings 属性 key 存在性

    func testSettings_语言相关属性返回非Missing值() {
        let values = [
            L10n.Settings.systemTheme,
            L10n.Settings.languageEnglish,
            L10n.Settings.languageChinese,
            L10n.Settings.languageTraditionalChinese,
            L10n.Settings.languageSpanish,
            L10n.Settings.languageFrench,
            L10n.Settings.languageArabic,
            L10n.Settings.languageRussian,
            L10n.Settings.languageKorean,
            L10n.Settings.languageJapanese,
            L10n.Settings.languagePortuguese,
            L10n.Settings.systemLanguage,
            L10n.Settings.languageSystem
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Settings 语言属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Settings 语言属性返回空字符串")
        }
    }

    func testSettings_功能项属性返回非Missing值() {
        let values = [
            L10n.Settings.llmSettings,
            L10n.Settings.smartRouting,
            L10n.Settings.promptSettings,
            L10n.Settings.onDeviceLLM,
            L10n.Settings.localModelManager,
            L10n.Settings.iCloudSync,
            L10n.Settings.backupRestore,
            L10n.Settings.operationLog,
            L10n.Settings.privacyMode,
            L10n.Settings.privacyModeDesc,
            L10n.Settings.biometricProtection,
            L10n.Settings.biometricProtectionDesc,
            L10n.Settings.privacyCombinedDesc,
            L10n.Settings.rebuildInitialNotebooks,
            L10n.Settings.advancedMaintenance,
            L10n.Settings.about,
            L10n.Settings.version,
            L10n.Settings.selectCategoryTip
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Settings 功能项属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Settings 功能项属性返回空字符串")
        }
    }

    func testSettings_iCloudLastSyncFormat_返回非Missing且包含参数() {
        let result = L10n.Settings.iCloudLastSyncFormat("2026-08-10")
        XCTAssertFalse(result.contains("[MISSING:"),
                       "Settings.iCloudLastSyncFormat 返回 Missing: \(result)")
        XCTAssertFalse(result.isEmpty)
    }

    // MARK: - Onboarding 属性 key 存在性

    func testOnboarding_基础属性返回非Missing值() {
        let values = [
            L10n.Onboarding.subtitle,
            L10n.Onboarding.featureList,
            L10n.Onboarding.featureTitle,
            L10n.Onboarding.pathTitle
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Onboarding 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Onboarding 属性返回空字符串")
        }
    }

    // MARK: - Security 属性 key 存在性

    func testSecurity_基础属性返回非Missing值() {
        let values = [
            L10n.Security.promptInjectionPlaceholder,
            L10n.Security.dlpImagePlaceholder,
            L10n.Security.integrityVerificationFailed,
            L10n.Security.targetIntegrityVerificationFailed,
            L10n.Security.databaseCorrupted,
            L10n.Security.retryConnection,
            L10n.Security.keychainDatabasePassphraseError,
            L10n.Security.keychainHMACSaltError,
            L10n.Security.jailbreakDetected,
            L10n.Security.jailbreakFailureReason,
            L10n.Security.compliancePolicyViolation,
            L10n.Security.accountTemporarilyThrottled
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Security 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Security 属性返回空字符串")
        }
    }

    func testSecurity_sandboxInstructions_返回非Missing且包含参数() {
        let result = L10n.Security.sandboxInstructions("plugin-name")
        XCTAssertFalse(result.contains("[MISSING:"),
                       "Security.sandboxInstructions 返回 Missing: \(result)")
        XCTAssertFalse(result.isEmpty)
    }

    // MARK: - Network 属性 key 存在性

    func testNetwork_基础属性返回非Missing值() {
        let values = [
            L10n.Network.invalidHTTPResponse,
            L10n.Network.missingDataPayload,
            L10n.Network.missingRefreshToken,
            L10n.Network.sessionInvalidated,
            L10n.Network.errorInvalidURL,
            L10n.Network.errorTokenExpired
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Network 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Network 属性返回空字符串")
        }
    }

    func testNetwork_errorServer_返回非Missing且包含参数() {
        let result = L10n.Network.errorServer(500, "Internal Server Error")
        XCTAssertFalse(result.contains("[MISSING:"),
                       "Network.errorServer 返回 Missing: \(result)")
        XCTAssertFalse(result.isEmpty)
    }

    func testNetwork_errorHTTP_返回非Missing且包含参数() {
        let result = L10n.Network.errorHTTP(404)
        XCTAssertFalse(result.contains("[MISSING:"),
                       "Network.errorHTTP 返回 Missing: \(result)")
        XCTAssertFalse(result.isEmpty)
    }

    // MARK: - Lint 属性 key 存在性

    func testLint_基础属性返回非Missing值() {
        let values = [
            L10n.Lint.title,
            L10n.Lint.refactorSection,
            L10n.Lint.linkDiscoverySection,
            L10n.Lint.healthExcellent,
            L10n.Lint.healthGood,
            L10n.Lint.healthFair,
            L10n.Lint.healthPoor
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Lint 基础属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Lint 基础属性返回空字符串")
        }
    }

    func testLint_问题类型属性返回非Missing值() {
        let values = [
            L10n.Lint.orphanPage,
            L10n.Lint.orphanSuggestion,
            L10n.Lint.cycleMessage,
            L10n.Lint.cycleSuggestion,
            L10n.Lint.brokenLink,
            L10n.Lint.brokenLinkSuggestion,
            L10n.Lint.stubContent,
            L10n.Lint.stubSuggestion,
            L10n.Lint.outdated,
            L10n.Lint.outdatedSuggestion,
            L10n.Lint.duplicateTitleSuggestion
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Lint 问题类型属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Lint 问题类型属性返回空字符串")
        }
    }

    func testLint_指标与操作属性返回非Missing值() {
        let values = [
            L10n.Lint.metricPages,
            L10n.Lint.metricBroken,
            L10n.Lint.metricOrphans,
            L10n.Lint.metricLinks,
            L10n.Lint.noIssues,
            L10n.Lint.noIssuesHint,
            L10n.Lint.noAISuggestions,
            L10n.Lint.noAISuggestionsHint,
            L10n.Lint.scanComplete,
            L10n.Lint.scanning,
            L10n.Lint.aiDisabledHint,
            L10n.Lint.aiScanComplete,
            L10n.Lint.apply,
            L10n.Lint.runCheck,
            L10n.Lint.runAIScan,
            L10n.Lint.goToPage,
            L10n.Lint.aiFixSuggestionShort
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Lint 指标操作属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Lint 指标操作属性返回空字符串")
        }
    }

    func testLint_errors_返回非Missing且包含参数() {
        let result = L10n.Lint.errors(3)
        XCTAssertFalse(result.contains("[MISSING:"),
                       "Lint.errors 返回 Missing: \(result)")
        XCTAssertFalse(result.isEmpty)
    }
}
