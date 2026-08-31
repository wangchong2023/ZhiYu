//
//  MedalConstants.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/26.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：奖章模块强类型常量集（ID、L10n key、SF Symbol、颜色 hex）。
//

import Foundation

/// 奖章模块常量集
enum MedalConstants {

    // MARK: - 奖章 ID (Medal ID)
    enum MedalID {
        static let firstPage = "first_page"
        static let nodes5 = "nodes_5"
        static let nodes10 = "nodes_10"
        static let nodes100 = "nodes_100"
        static let links5 = "links_5"
        static let links10 = "links_10"
        static let links100 = "links_100"
    }

    // MARK: - 本地化 Key (L10n Key)
    enum L10nKey {
        static let firstPageTitle = "medal.first_page.title"
        static let firstPageDesc = "medal.first_page.desc"
        static let nodes5Title = "medal.nodes_5.title"
        static let nodes5Desc = "medal.nodes_5.desc"
        static let nodes10Title = "medal.nodes_10.title"
        static let nodes10Desc = "medal.nodes_10.desc"
        static let nodes100Title = "medal.nodes_100.title"
        static let nodes100Desc = "medal.nodes_100.desc"
        static let links5Title = "medal.links_5.title"
        static let links5Desc = "medal.links_5.desc"
        static let links10Title = "medal.links_10.title"
        static let links10Desc = "medal.links_10.desc"
        static let links100Title = "medal.links_100.title"
        static let links100Desc = "medal.links_100.desc"
    }

    // MARK: - 颜色 Hex (Color Hex)
    enum ColorHex {
        static let gold = "#FFD700"
        static let skyBlue = "#4FACFE"
        static let cyan = "#00F2FE"
        static let mint = "#A8EDEA"
        static let pink = "#F093FB"
        static let coral = "#F5576C"
        static let periwinkle = "#8EC5FC"
    }
}
