//
//  UINavigationController+PopGesture.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 平台适配层
//  核心职责：iOS 平台实现：后台任务、Widget、文件归档、Spotlight 索引。
//
#if os(iOS)
import UIKit

// MARK: - 全局手势支持
/// 解决 SwiftUI 中隐藏标准返回按钮导致侧滑返回失灵的问题
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {

    /// 视图加载完成
    override open func viewDidLoad() {
        super.viewDidLoad()
        // 将手势代理设为自身，以便在任何情况下都能拦截手势判断
        interactivePopGestureRecognizer?.delegate = self
    }

    /// 判断是否应该开始侧滑手势
    /// - Parameter gestureRecognizer: 手势识别器
    /// - Returns: 当视图控制器栈深度大于 1 时允许返回
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return viewControllers.count > 1
    }

    /// 允许与其他手势识别器同时存在
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
#endif
