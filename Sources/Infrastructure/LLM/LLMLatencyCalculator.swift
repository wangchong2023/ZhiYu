//
//  LLMLatencyCalculator.swift
//  ZhiYu
//
//  Created by CodeFree on 2026/09/14.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 基础设施层
//  核心职责：LLM 延迟计算工具，实现已下沉至 UFPCore，此处为向后兼容 typealias 层。
//

import Foundation
import UFPCore

/// LLM 延迟计算工具（实现见 UFPCore）
public typealias LLMLatencyCalculator = UFPCore.LLMLatencyCalculator
