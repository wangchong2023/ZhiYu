//
//  SyncConstants.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/28.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层
//  核心职责：同步冲突解决相关的强类型常量定义。
//

import Foundation

/// 同步冲突解决（LWW）强类型常量集
public enum SyncConstants {
    /// 审计日志滑动窗口容量上限（条）
    public static let auditLogWindowLimit: Int = 200
}
