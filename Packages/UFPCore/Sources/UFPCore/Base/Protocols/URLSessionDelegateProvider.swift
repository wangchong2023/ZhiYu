//
//  URLSessionDelegateProvider.swift
//  UFPCore
//
//  系统层级：[L0] 基础设施协议
//  核心职责：URLSession 委托策略提供者协议，解耦开发调试环境与生产环境证书处理策略。
//

import Foundation

/// URLSession 委托提供者协议
public protocol URLSessionDelegateProvider: Sendable {
    func makeSessionDelegate() -> URLSessionDelegate?
}
