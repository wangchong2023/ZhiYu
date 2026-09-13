//
//  SubscriptionQuotaConstants.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/05.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层
//  核心职责：会员与套餐配额强类型常量集。
//

import Foundation

/// 会员与套餐配额强类型常量
public enum SubscriptionQuotaConstants {
    /// Lite 基础免费版配额基线
    public enum Lite {
        public static let maxKnowledgePages: Int = 1000
        public static let maxVaultsCount: Int = 2
        public static let maxFileSizeMb: Int = 10
    }

    /// Pro 专业版配额基线
    public enum Pro {
        public static let maxKnowledgePages: Int = 50000
        public static let maxVaultsCount: Int = 100
        public static let maxFileSizeMb: Int = 50
    }
}
