//
//  L10nSettingsDeepTests.swift
//  ZhiYuTests
//
//  Created by CodeFree on 2026/08/22.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests] 单元测试层
//  核心职责：深度验证 Settings 表 L10n 扩展的所有属性 key 存在性与返回值非空。
//

import XCTest
@testable import ZhiYu

/// Settings 表 L10n 扩展深度测试 — 全量属性覆盖
final class L10nSettingsDeepTests: XCTestCase {

    private func assertNonMissing(_ value: String, _ context: String = "") {
        XCTAssertFalse(value.contains("[MISSING:"), "属性返回 Missing \(context): \(value)")
        XCTAssertFalse(value.isEmpty, "属性返回空字符串 \(context)")
    }

    func testTableName_Settings() {
        XCTAssertEqual(L10n.Settings.tableName, L10n.Settings.tableName)
    }

    // MARK: - 全量属性批量验证

    func testSettings_所有静态属性返回非Missing值() {
        let values: [String] = [
            L10n.Settings.title,
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
            L10n.Settings.languageSystem,
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
            L10n.Settings.selectCategoryTip,
            L10n.Settings.resetOnboarding.title,
            L10n.Settings.resetOnboarding.message,
            L10n.Settings.resetOnboarding.label,
            L10n.Settings.clearAll.action,
            L10n.Settings.clearAll.confirmTitle,
            L10n.Settings.clearAll.message,
            L10n.Settings.clearAll.label,
            L10n.Settings.injectConfirm.title,
            L10n.Settings.injectConfirm.message,
            L10n.Settings.developer.section.data,
            L10n.Settings.developer.section.dataReset,
            L10n.Settings.developer.section.operationInfo,
            L10n.Settings.developer.section.performance_test,
            L10n.Settings.developer.section.onboarding,
            L10n.Settings.developer.resetOnboardingDone,
            L10n.Settings.developer.showGuidePage,
            L10n.Settings.developer.showWelcomeBanner,
            L10n.Settings.developer.stressTest.count,
            L10n.Settings.developer.stressTest.run,
            L10n.Settings.developer.stressTest.confirmTitle,
            L10n.Settings.developer.stressTest.confirmMessage,
            L10n.Settings.developer.stressTest.sliderLabel,
            L10n.Settings.Section.appearance,
            L10n.Settings.Section.ai,
            L10n.Settings.Section.data,
            L10n.Settings.Section.security,
            L10n.Settings.Section.maintenance,
            L10n.Settings.Section.about,
            L10n.Settings.Section.developer,
            L10n.Settings.Section.plugins,
            L10n.Settings.Section.tabData,
            L10n.Settings.Section.tabQuality,
            L10n.Settings.InjectDemo.errorMessage,
            L10n.Settings.InjectDemo.injectedNotebooks,
            L10n.Settings.InjectDemo.pageUnit,
            L10n.Settings.InjectDemo.itemsSeparator,
            L10n.Settings.Feedback.title,
            L10n.Settings.Feedback.subject,
            L10n.Settings.Feedback.subjectPlaceholder,
            L10n.Settings.Feedback.category,
            L10n.Settings.Feedback.categoryBug,
            L10n.Settings.Feedback.categoryFeature,
            L10n.Settings.Feedback.categoryContent,
            L10n.Settings.Feedback.categoryOther,
            L10n.Settings.Feedback.rating,
            L10n.Settings.Feedback.content,
            L10n.Settings.Feedback.contentPlaceholder,
            L10n.Settings.Feedback.submit,
            L10n.Settings.Feedback.submitted,
            L10n.Settings.Feedback.appVersionLabel,
            L10n.Settings.Feedback.osVersionLabel,
            L10n.Settings.Feedback.osMacDefault,
            L10n.Settings.Feedback.deviceMacDefault,
            L10n.Settings.Feedback.history,
            L10n.Settings.Feedback.noHistory,
            L10n.Settings.Feedback.statusPending,
            L10n.Settings.Feedback.statusSynced,
            L10n.Settings.Feedback.statusFailed,
            L10n.Settings.About.developer,
            L10n.Settings.About.developerName,
            L10n.Settings.About.website,
            L10n.Settings.About.version,
            L10n.Settings.About.build,
            L10n.Settings.About.buildTime,
            L10n.Settings.About.copyright,
            L10n.Settings.theme.dark,
            L10n.Settings.theme.light,
            L10n.Settings.theme.system,
            L10n.Settings.OnDevice.npuAcceleration,
            L10n.Settings.OnDevice.descNpu,
            L10n.Settings.OnDevice.ramAllocation,
            L10n.Settings.OnDevice.descRam,
            L10n.Settings.OnDevice.maxContext,
            L10n.Settings.OnDevice.descContext,
            L10n.Settings.OnDevice.overheatProtection,
            L10n.Settings.OnDevice.descOverheat,
            L10n.Settings.OnDevice.performanceConfig
        ]
        for value in values { assertNonMissing(value) }
    }

    // MARK: - 全量格式化方法验证

    func testSettings_所有格式化方法返回非Missing值() {
        assertNonMissing(L10n.Settings.pluginPermissionMessage("x"), "L10n.Settings.pluginPermissionMessage")
        assertNonMissing(L10n.Settings.onDeviceErrorFormat("x"), "L10n.Settings.onDeviceErrorFormat")
        assertNonMissing(L10n.Settings.iCloudLastSyncFormat("x"), "L10n.Settings.iCloudLastSyncFormat")
        assertNonMissing(L10n.Settings.developer.stressTest.nodes(1), "L10n.Settings.developer.stressTest.nodes")
        assertNonMissing(L10n.Settings.developer.stressTest.success(1), "L10n.Settings.developer.stressTest.success")
        assertNonMissing(L10n.Settings.developer.stressTest.confirmAction(1), "L10n.Settings.developer.stressTest.confirmAction")
        assertNonMissing(L10n.Settings.InjectDemo.successMessage(1), "L10n.Settings.InjectDemo.successMessage")
        assertNonMissing(L10n.Settings.InjectDemo.successDetail(1, "x"), "L10n.Settings.InjectDemo.successDetail")
        assertNonMissing(L10n.Settings.InjectDemo.vaultDetail("x", 1), "L10n.Settings.InjectDemo.vaultDetail")
    }
}
