//
//  NetworkClient+Testing.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/10/18.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests] 测试辅助扩展
//  核心职责：为单元测试提供兼容的 NetworkClient 会话拦截与并发等待辅助方法。
//

import Foundation
@testable import ZhiYu

extension NetworkClient {
    /// 单元测试专用：设置测试专用的 URLSession
    /// - Parameter session: 测试专用的 URLSession 实例
    public func setTestSession(_ session: URLSession?) {
        setCustomSession(session)
    }

    /// 单元测试专用：等待当前的 refreshTask 完成
    public func awaitRefreshTask() async {
        await awaitCurrentRefresh()
    }
}
