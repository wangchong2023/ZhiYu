//
//  AppErrorFactory.swift
//  UFPCore
//
//  Created by CodeFree on 2026/08/07.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 基础设施层
//  核心职责：通用的 NSError 工厂，消除重复的 NSError(domain:code:userInfo:) 样板代码。
//           与业务无关，业务层通过 AppError 便捷方法封装业务域常量后调用。
//

import Foundation

/// 通用错误工厂
/// 提供与业务无关的 NSError 构造能力，业务层应通过自身便捷方法封装业务域后转发调用。
public enum AppErrorFactory {

    /// 创建带本地化描述的 NSError
    /// - Parameters:
    ///   - domain: 错误域（如模块名）
    ///   - code: 错误码，默认 `SystemConstants.ErrorCode.default`
    ///   - description: 用户可读的错误描述
    /// - Returns: NSError 实例
    public static func make(domain: String, code: Int = SystemConstants.ErrorCode.default, description: String) -> NSError {
        NSError(domain: domain, code: code, userInfo: [NSLocalizedDescriptionKey: description])
    }
}
