//
//  AhoCorasickEngine.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 基础设施层
//  核心职责：兼容层 — AhoCorasickEngine 已下沉至 UFPCore，本文件保留 typealias 以兼容 App 层既有引用。
//
import Foundation
import UFPCore

/// 兼容层：AC 自动机匹配结果（实现见 UFPCore.AhoMatch）
public typealias AhoMatch = UFPCore.AhoMatch

/// 兼容层：AC 自动机多模式匹配引擎（实现见 UFPCore.AhoCorasickEngine）
public typealias AhoCorasickEngine = UFPCore.AhoCorasickEngine
