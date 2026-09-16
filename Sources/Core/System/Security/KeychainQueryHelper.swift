//
//  KeychainQueryHelper.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/14.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0.5] 系统集成层
//  核心职责：提供 Keychain 查询字典构造的公共辅助方法，消除 KeychainService 中重复的 query 字典构造代码块。
//
import Foundation
import Security

/// Keychain 查询字典构造辅助
/// 抽取 KeychainService.store / retrieve / delete 中重复的
/// `kSecClass` + `kSecAttrService` + `kSecAttrAccount` 基础字典构造模式。
enum KeychainQueryHelper {

    /// 构造 Keychain 基础查询字典（class=genericPassword + service + account）
    /// - Parameters:
    ///   - serviceName: Keychain 服务标识符
    ///   - key: 账户键名
    /// - Returns: 基础查询字典，调用方可追加额外字段
    static func baseQuery(serviceName: String, key: String) -> [String: Any] {
        return [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
    }
}
