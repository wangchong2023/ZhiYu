//
//  DatabaseManager+Testing.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/10/18.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests] 测试辅助扩展
//  核心职责：为测试套件提供 DatabaseManager 的测试专用能力，隔离于 Sources/ 生产目录。
//

import Foundation
import GRDB
@testable import ZhiYu

extension DatabaseManager {
    /// 单元测试专用：为测试管道强制注入内存/临时物理数据库连接池
    public func setupForTesting(with writer: any DatabaseWriter) throws {
        try setup(with: writer)
    }

    /// 单元测试专用：设置事务网关排空状态
    public func setDrainingForTesting(_ value: Bool) async {
        await setDraining(value)
    }
}
