//
//  L10n+Settings.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 本地化层
//  核心职责：为 Settings 模块提供本地化强类型字符串的访问扩展。
//
import Foundation

extension L10n {
    public struct Settings: L10nTableEntry {
        public static let tableName = "System"
        public static var t: String { tableName }
        /// 本地化翻译
        /// - Parameter key: key
        /// - Returns: 返回值
        /// 本地化格式化翻译
        /// - Parameter key: key
        /// - Parameter args: args
        /// - Returns: 返回值
        /// 获取插件权限提示文案
        /// - Parameter name: 插件名称
        /// - Returns: 本地化格式化文案
        public static func pluginPermissionMessage(_ name: String) -> String { Settings.trf("plugin.permission.message", name) }

        /// 获取端侧模型加载失败错误文案
        /// - Parameter code: 错误代码
        /// - Returns: 本地化格式化文案
        public static func onDeviceErrorFormat(_ code: String) -> String { L10n.Common.trf("ondevice.errorFormat", code) }

        /// 获取iCloud最后同步时间文案
        /// - Parameter date: 同步时间字符串
        /// - Returns: 本地化格式化文案
        public static func iCloudLastSyncFormat(_ date: String) -> String { Settings.trf("icloud.lastSyncFormat", date) }

            public static var title: String { Localized.tr("settings.resetOnboarding.title", table: t) }
        public static var systemTheme: String { tr("settings.systemTheme") }
        public static var languageEnglish: String { tr("language.english") }
        public static var languageChinese: String { tr("language.chinese") }
        public static var languageTraditionalChinese: String { tr("language.traditionalChinese") }
        public static var languageSpanish: String { tr("language.spanish") }
        public static var languageFrench: String { tr("language.french") }
        public static var languageArabic: String { tr("language.arabic") }
        public static var languageRussian: String { tr("language.russian") }
        public static var languageKorean: String { tr("language.korean") }
        public static var languageJapanese: String { tr("language.japanese") }
        public static var languagePortuguese: String { tr("language.portuguese") }
        public static var systemLanguage: String { tr("settings.systemLanguage") }
        public static var languageSystem: String { tr("language.system") }
        public static var llmSettings: String { tr("llmSettings") }
        public static var smartRouting: String { tr("settings.smartRouting") }
        public static var promptSettings: String { tr("settings.promptSettings") }
        public static var onDeviceLLM: String { tr("settings.onDeviceLLM") }
        public static var localModelManager: String { tr("settings.localModelManager") }
        public static var iCloudSync: String { Localized.tr("settings.iCloudSync", table: t) }
        public static var backupRestore: String { Localized.tr("backup.restore", table: "Transfer") }
        public static var operationLog: String { Localized.tr("settings.operationLog", table: t) }
        public static var privacyMode: String { tr("privacyMode") }
        public static var privacyModeDesc: String { Localized.tr("settings.privacyMode.desc", table: t) }
        public static var biometricProtection: String { tr("biometricProtection") }
        public static var biometricProtectionDesc: String { Localized.tr("settings.biometricProtection.desc", table: t) }
        /// 隐私与生物识别合并后的描述文案
        public static var privacyCombinedDesc: String { Localized.tr("settings.privacyCombined.desc", table: t) }
        public static var rebuildInitialNotebooks: String { Localized.tr("settings.rebuildInitialNotebooks", table: t) }
        public static var advancedMaintenance: String { Localized.tr("settings.advancedMaintenance", table: t) }
        public static var about: String { tr("aboutApp") }
        public static var version: String { tr("version") }
        /// 选择设置大类的占位提示文本
        public static var selectCategoryTip: String { tr("settings.selectCategoryTip") }

        public struct resetOnboarding {
            public static var title: String { Localized.tr("settings.resetOnboarding", table: t) }
            public static var message: String { Localized.tr("settings.resetOnboarding.message", table: t) }
            public static var label: String { Localized.tr("settings.resetOnboarding", table: t) }
        }

        public struct clearAll {
            public static var action: String { Localized.tr("settings.clearAll.action", table: t) }
            public static var confirmTitle: String { Localized.tr("settings.clearAll.confirmTitle", table: t) }
            public static var message: String { Localized.tr("settings.clearAll.message", table: t) }
            public static var label: String { Localized.tr("settings.clearAll", table: t) }
        }

        public struct injectConfirm {
            public static var title: String { Localized.tr("settings.injectConfirm.title", table: t) }
            public static var message: String { Localized.tr("settings.injectConfirm.message", table: t) }
        }

        public struct developer {
            public struct section {
                public static var data: String { Localized.tr("settings.developer.section.data", table: t) }
                public static var dataReset: String { Localized.tr("settings.developer.section.dataReset", table: t) }
                public static var operationInfo: String { Localized.tr("settings.developer.section.operationInfo", table: t) }
                public static var performance_test: String { Localized.tr("settings.developer.section.performance_test", table: t) }
                public static var onboarding: String { L10n.Common.tr("demo.welcome.tag1") }
            }

            public static var resetOnboardingDone: String { Localized.tr("settings.developer.resetOnboardingDone", table: t) }
            public static var showGuidePage: String { Localized.tr("settings.developer.showGuidePage", table: t) }
            public static var showWelcomeBanner: String { Localized.tr("settings.developer.showWelcomeBanner", table: t) }

            public struct stressTest {
                public static var count: String { Localized.tr("settings.developer.stressTest.count", table: t) }
                public static var run: String { Localized.tr("settings.developer.stressTest.run", table: t) }
                public static func nodes(_ n: Int) -> String { Localized.trf("settings.developer.stressTest.nodes", table: t, n) }
                public static var confirmTitle: String { Localized.tr("settings.developer.stressTest.confirmTitle", table: t) }
                public static var confirmMessage: String { Localized.tr("settings.developer.stressTest.confirmMessage", table: t) }
                public static var sliderLabel: String { Localized.tr("settings.developer.stressTest.sliderLabel", table: t) }

                /// success
                /// - Parameter n: n
                /// - Returns: 字符串
                public static func success(_ n: Int) -> String { Localized.trf("settings.developer.stressTest.success", table: t, n) }

                /// confirmAction
                /// - Parameter n: n
                /// - Returns: 字符串
                public static func confirmAction(_ n: Int) -> String { Localized.trf("settings.developer.stressTest.confirmAction", table: t, n) }

                /// noDataInjected: 压力测试未注入任何数据
                public static var noDataInjected: String { Localized.tr("settings.developer.stressTest.noDataInjected", table: t) }
            }
        }

        public struct Section {
            public static var appearance: String { Settings.tr("section.appearance") }
            public static var ai: String { Settings.tr("section.ai") }
            public static var data: String { Settings.tr("section.data") }
            public static var security: String { Settings.tr("section.security") }
            public static var maintenance: String { Settings.tr("section.maintenance") }
            public static var about: String { Settings.tr("section.about") }
            public static var developer: String { Settings.tr("section.developer") }
            public static var plugins: String { Settings.tr("section.plugins") }
            public static var tabData: String { Localized.tr("settings.developer.section.tabData", table: t) }
            public static var tabQuality: String { Localized.tr("settings.developer.section.tabQuality", table: t) }
        }

        public struct InjectDemo {

            /// successMessage
            /// - Parameter n: n
            /// - Returns: 字符串
            public static func successMessage(_ n: Int) -> String { Localized.trf("settings.injectDemo.successMessage", table: t, n) }
            public static var errorMessage: String { Localized.tr("settings.injectDemo.errorMessage", table: t) }
            /// 含每个笔记本详情
            public static func successDetail(_ vaultCount: Int, _ details: String) -> String { Localized.trf("settings.injectDemo.successDetail", table: t, vaultCount, details) }
            public static func vaultDetail(_ name: String, _ count: Int) -> String { Localized.trf("settings.injectDemo.vaultDetail", table: t, name, count) }
            /// 简单字符串片段
            public static var injectedNotebooks: String { Localized.tr("settings.injectDemo.injectedNotebooks", table: t) }
            public static var pageUnit: String { Localized.tr("settings.injectDemo.pageUnit", table: t) }
            public static var itemsSeparator: String { Localized.tr("settings.injectDemo.itemsSeparator", table: t) }
        }

        public enum Feedback {
            public static var title: String { Settings.tr("settings.feedback.title") }
            public static var subject: String { Settings.tr("settings.feedback.subject") }
            public static var subjectPlaceholder: String { Settings.tr("settings.feedback.subjectPlaceholder") }
            public static var category: String { Settings.tr("settings.feedback.category") }
            public static var categoryBug: String { Settings.tr("settings.feedback.categoryBug") }
            public static var categoryFeature: String { Settings.tr("settings.feedback.categoryFeature") }
            public static var categoryContent: String { Settings.tr("settings.feedback.categoryContent") }
            public static var categoryOther: String { Settings.tr("settings.feedback.categoryOther") }
            public static var rating: String { Settings.tr("settings.feedback.rating") }
            public static var content: String { Settings.tr("settings.feedback.content") }
            public static var contentPlaceholder: String { Settings.tr("settings.feedback.contentPlaceholder") }
            public static var submit: String { Settings.tr("settings.feedback.submit") }
            public static var submitted: String { Settings.tr("settings.feedback.submitted") }
            public static var appVersionLabel: String { Settings.tr("settings.feedback.appVersionLabel") }
            public static var osVersionLabel: String { L10n.Common.tr("sidebar.system") }
            public static var osMacDefault: String { Settings.tr("settings.feedback.osMacDefault") }
            public static var deviceMacDefault: String { Settings.tr("settings.feedback.deviceMacDefault") }
            public static var history: String { Settings.tr("settings.feedback.history") }
            public static var noHistory: String { Settings.tr("settings.feedback.noHistory") }
            public static var statusPending: String { Settings.tr("settings.feedback.statusPending") }
            public static var statusSynced: String { Settings.tr("settings.feedback.statusSynced") }
            public static var statusFailed: String { Settings.tr("settings.feedback.statusFailed") }
        }

        public struct About {
            public static var developer: String { Localized.tr("settings.about.developer", table: t) }
            public static var developerName: String { Localized.tr("settings.about.developerName", table: t) }
            public static var website: String { Localized.tr("settings.about.website", table: t) }
            public static var version: String { Localized.tr("settings.about.version", table: t) }
            public static var build: String { Localized.tr("settings.about.build", table: t) }
            public static var buildTime: String { Localized.tr("settings.about.buildTime", table: t) }
            public static var copyright: String { Localized.tr("settings.about.copyright", table: t) }
        }

        public struct theme {
            public static var dark: String { Localized.tr("settings.theme.dark", table: t) }
            public static var light: String { Localized.tr("settings.theme.light", table: t) }
            public static var system: String { Localized.tr("settings.theme.system", table: t) }
        }

        public struct OnDevice {
            public static var npuAcceleration: String { Localized.tr("settings.ondevice.npu", table: t) }
            public static var descNpu: String { Localized.tr("settings.ondevice.descNpu", table: t) }
            public static var ramAllocation: String { Localized.tr("settings.ondevice.ram", table: t) }
            public static var descRam: String { Localized.tr("settings.ondevice.descRam", table: t) }
            public static var maxContext: String { Localized.tr("settings.ondevice.context", table: t) }
            public static var descContext: String { Localized.tr("settings.ondevice.descContext", table: t) }
            public static var overheatProtection: String { Localized.tr("settings.ondevice.overheat", table: t) }
            public static var descOverheat: String { Localized.tr("settings.ondevice.descOverheat", table: t) }
            public static var performanceConfig: String { Localized.tr("settings.ondevice.perfConfig", table: t) }
        }
    }
}
