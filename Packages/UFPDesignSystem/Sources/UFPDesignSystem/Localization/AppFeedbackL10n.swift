//
//  AppFeedbackL10n.swift
//  UFPDesignSystem
//
//  Created by Antigravity on 2026/10/11.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[UFPDesignSystem]
//  核心职责：UFPDesignSystem 包内自带的最小本地化资源表命名空间。
//           Feedback 系列组件（AppErrorView/AppLoadingOverlay 等）的默认文案
//           通过 Bundle.module 读取包内 Feedback.xcstrings，避免反向依赖 App 层 L10n。
//

import Foundation

/// UFPDesignSystem 包内本地化强类型访问命名空间。
/// 仅承载 Feedback 组件所需的极简默认文案，与 App 层 L10n 解耦。
public enum AppFeedbackL10n {
    /// 包内本地化表名
    static let tableName = "Feedback"

    // MARK: - 默认文案

    /// 通用错误标题（"发生错误"）
    public static var errorTitle: String { tr("errorOccurred") }
    /// 重试按钮文案（"重试"）
    public static var retryButton: String { tr("retry") }
    /// 加载中文案（"加载中..."）
    public static var loading: String { tr("loading") }

    // MARK: - 底层翻译

    /// 从包内 Feedback 表读取指定 Key 的本地化文本
    private static func tr(_ key: String) -> String {
        NSLocalizedString(key, tableName: tableName, bundle: .module, value: key, comment: "")
    }
}