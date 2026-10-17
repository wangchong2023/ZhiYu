//
//  L10n+Onboarding.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 本地化层
//  核心职责：为 Onboarding 模块提供本地化强类型字符串的访问扩展。
//
import Foundation
import UFPCore

extension L10n {
    public enum Onboarding: L10nTableEntry {
        public static let tableName = "System"
        public static var t: String { tableName }
        /// 本地化翻译
        /// - Parameter key: key
        /// - Returns: 返回值
        /// 本地化格式化翻译
        /// - Parameter key: key
        /// - Parameter args: args
        /// - Returns: 返回值
        public static var subtitle: String { tr("welcome.subtitle") }
        public static var featureList: String { tr("onboarding.featureList") }
        public static var featureTitle: String { tr("onboarding.featureTitle") }

        public static var pathTitle: String { tr("onboarding.path.title") }

        public enum Path {
            public static var quickStart: String { Onboarding.tr("onboarding.path.quickStart") }
            public static var quickStartDesc: String { Onboarding.tr("onboarding.path.quickStartDesc") }
            public static var importData: String { Onboarding.tr("onboarding.path.importData") }
            public static var importDataDesc: String { Onboarding.tr("onboarding.path.importDataDesc") }
            public static var explore: String { Onboarding.tr("onboarding.path.explore") }
            public static var exploreDesc: String { Onboarding.tr("onboarding.path.exploreDesc") }
        }

        public enum Milestone {
            public static var firstPage: String { Onboarding.tr("onboarding.milestone.firstPage") }
            public static var firstChat: String { Onboarding.tr("onboarding.milestone.firstChat") }
            public static var firstGraph: String { Onboarding.tr("onboarding.milestone.firstGraph") }
            public static var firstSynthesis: String { Onboarding.tr("onboarding.milestone.firstSynthesis") }
            public static var page10: String { Onboarding.tr("onboarding.milestone.page10") }
            public static var page50: String { Onboarding.tr("onboarding.milestone.page50") }
            public static var page100: String { Onboarding.tr("onboarding.milestone.page100") }
        }

        public enum Step {
            public enum graph {
                public static var title: String { Onboarding.tr("onboarding.step.graph.title") }
                public static var desc: String { Onboarding.tr("onboarding.step.graph.desc") }
            }
            public enum aiLab {
                public static var title: String { Onboarding.tr("onboarding.step.aiLab.title") }
                public static var desc: String { Onboarding.tr("onboarding.step.aiLab.desc") }
            }
            public enum vault {
                public static var title: String { Onboarding.tr("onboarding.step.vault.title") }
                public static var desc: String { Onboarding.tr("onboarding.step.vault.desc") }
            }
        }

        public enum Action {
            public static var start: String { Onboarding.tr("onboarding.action.start") }
            public static var next: String { Onboarding.tr("onboarding.action.next") }
            public static var skip: String { Onboarding.tr("onboarding.action.skip") }
        }
    }
}
