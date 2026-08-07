//
//  SSRFGuard.swift
//  ZhiYu
//
//  Created by CodeFree Security Audit on 2026/08/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：SSRF 防护兼容层 — 实际实现已迁移至 UFPCore/Security/SSRFGuard.swift
//
//  审查修复 HIGH-4/HIGH-5: IPv6 前缀误判合法域名 + IP 编码绕过（十进制/八进制/十六进制/省略格式）
//  审查修复 MED-8: 威胁模型边界 — 本实现为基础防护，不防御 DNS rebinding（TOCTOU）。
//                   若需防御 DNS rebinding，应在 isSafeURL 内解析 DNS 后锁定 IP。
//

import Foundation
import UFPCore

/// SSRF 防护网关兼容层
/// 实际实现已迁移至 `UFPCore.SSRFGuard`，业务层通过此 typealias 引用
typealias SSRFGuard = UFPCore.SSRFGuard
