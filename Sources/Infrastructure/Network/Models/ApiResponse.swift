//
//  ApiResponse.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/28.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：App 层兼容层，将 ApiResponse/EmptyData/NetworkError 转引自 UFPCore 通用底座，
//           使既有调用点（OAuthService/PhoneAuthService/AuthService/PluginMarketService/NetworkClient/RemoteConfigService）无需改动。
//

import Foundation
import UFPCore

/// 后端全局统一 JSON 响应封装（转引自 UFPCore）
public typealias ApiResponse<T: Codable & Sendable> = UFPCore.ApiResponse<T>

/// 当接口响应中 data 为 null 时的占位类型（转引自 UFPCore）
public typealias EmptyData = UFPCore.EmptyData

/// 后端网络通信自定义错误（转引自 UFPCore）
public typealias NetworkError = UFPCore.NetworkError
