//
//  XCUIElement+SafeTap.swift
//  ZhiYuUITests
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests] UI 自动化测试扩展
//  核心职责：封装 XCUIElement 隐式谓词安全等待与点击，消除模拟器硬件动画延时与时序竞争问题。
//

import XCTest

extension XCUIElement {
    
    /// 隐式谓词安全点击：等待元素同时满足存在 (exists) 且可点击 (isHittable) 后才执行 tap()
    /// - Parameters:
    ///   - timeout: 超时时间（默认 8.0 秒）
    ///   - file: 调用位置文件
    ///   - line: 调用位置行号
    /// - Returns: 是否点击成功
    @discardableResult
    public func waitAndTap(timeout: TimeInterval = 8.0, file: StaticString = #file, line: UInt = #line) -> Bool {
        let predicate = NSPredicate(format: "exists == true AND isHittable == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        if result == .completed {
            self.tap()
            return true
        } else {
            // 如果超时仍未能点击，记录调试提示但返回 false 避免未捕获崩盘
            print("⚠️ [waitAndTap] 元素在 \(timeout)s 内未达到 isHittable 状态: \(self)")
            return false
        }
    }
    
    /// 等待元素满足存在且可交互状态
    /// - Parameter timeout: 超时时间（秒）
    /// - Returns: 是否就绪
    public func waitForExistenceAndHittable(timeout: TimeInterval = 8.0) -> Bool {
        let predicate = NSPredicate(format: "exists == true AND isHittable == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
