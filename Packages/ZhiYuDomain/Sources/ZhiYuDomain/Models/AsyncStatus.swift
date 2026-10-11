//
//  AsyncStatus.swift
//  ZhiYuDomain
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[ZhiYuDomain]
//  核心职责：定义泛型异步状态枚举 (AsyncStatus)，统一定义 idle/loading/success/failure 四态流转模型，
//           并配套 isLoading / errorMessage 便捷访问。成功载荷 T 不强制 Equatable，
//           以支持 Void 等无值类型作为状态载荷。
//

import Foundation

/// 统一管理异步任务的状态枚举
public enum AsyncStatus<T> {
    case idle
    case loading(String) // 带有描述信息的加载中
    case success(T)
    case failure(String)

    /// 当前是否处于加载中状态
    public var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    /// 提取失败原因（非 .failure 状态返回 nil）
    public var errorMessage: String? {
        if case let .failure(message) = self { return message }
        return nil
    }
}

extension AsyncStatus: Equatable {
    public static func == (lhs: AsyncStatus<T>, rhs: AsyncStatus<T>) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case let (.loading(lhsMessage), .loading(rhsMessage)):
            return lhsMessage == rhsMessage
        case let (.success(lhsValue), .success(rhsValue)):
            return String(reflecting: lhsValue) == String(reflecting: rhsValue)
        case let (.failure(lhsMessage), .failure(rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}