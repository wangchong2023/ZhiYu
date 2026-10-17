//
//  IntentRateLimiter.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/03.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 基础设施层
//  核心职责：兼容层 — IntentRateLimiter 已下沉至 UFPCore，本文件保留 typealias 以兼容 App 层既有引用。
//
import Foundation
import UFPCore

/// 兼容层：10Hz 滑动窗口限流器（实现见 UFPCore.IntentRateLimiter）
public typealias IntentRateLimiter = UFPCore.IntentRateLimiter
