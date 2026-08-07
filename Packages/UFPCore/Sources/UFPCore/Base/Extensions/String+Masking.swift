//
//  String+Masking.swift
//  UFPCore
//
//  Created by CodeFree on 2026/08/07.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 基础设施层
//  核心职责：通用字符串掩码扩展，与业务无关。
//

import Foundation

extension String {
    /// 将手机号中间四位替换为星号掩码
    /// - Returns: 掩码后的字符串（如 `138****1234`）；若长度不足 7 位则原样返回
    public var maskedPhoneNumber: String {
        guard count >= 7 else { return self }
        let start = startIndex
        let middleStart = index(start, offsetBy: 3)
        let middleEnd = index(start, offsetBy: 7)
        let prefix = self[start..<middleStart]
        let suffix = self[middleEnd..<endIndex]
        return "\(prefix)****\(suffix)"
    }
}
