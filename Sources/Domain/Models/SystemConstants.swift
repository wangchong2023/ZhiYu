//
//  SystemConstants.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/05.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层
//  核心职责：领域业务阈值常量集。
//           系统级换算常量（时间/字节/HTTP）定义在 UFPCore.SystemConstants，
//           上层直接引用 UFPCore.SystemConstants.xxx，不在本文件重复定义或转接。
//

import Foundation

/// 领域业务阈值常量集
public enum SystemConstants {

    // MARK: - 知识页面 (KnowledgePage) 业务阈值
    public struct KnowledgePageThresholds {
        /// 存根页面（内容过少）的字数阈值
        public static let stubPageWordCount: Int = 100
    }
}
