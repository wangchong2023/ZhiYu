//
//  CJKSpacingFormatter.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 基础设施层
//  核心职责：CJK/ANSI 混排空格优化器，实现已下沉至 UFPCore，此处为向后兼容 typealias 层。
//
import Foundation
import UFPCore

/// CJK (中日韩) 与 ANSI (英文/数字) 混排空格优化器（实现见 UFPCore）
public typealias CJKSpacingFormatter = UFPCore.CJKSpacingFormatter

/// 向后兼容类型别名
public typealias PanguFormatter = CJKSpacingFormatter
