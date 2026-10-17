//
//  DesignTokens+Domain.swift
//  UFPDesignSystem
//
//  Created by Antigravity on 2026/05/29.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[UFPDesignSystem]
//  核心职责：领域布局令牌（About/Auth/Voice/Lint/Chat/Feedback）— 各业务领域可视化尺寸常量。
//
import CoreGraphics

extension DesignTokens.Spacing {

    // MARK: - 关于页 (About)

    /// 关于页 Logo 尺寸
    public struct About {
        /// 关于页 Logo 边长
        public static let logoSize: CGFloat = 100
    }

    // MARK: - 登录认证 (Auth)

    /// 登录认证布局令牌
    public struct Auth {
        /// 登录页 Logo 背景圆形直径
        public static let logoBackgroundSize: CGFloat = 60
        /// 登录/注册模式切换按钮宽度
        public static let modePickerWidth: CGFloat = 120
        /// 登录/注册模式切换按钮高度
        public static let modePickerHeight: CGFloat = 38
        /// 获取验证码按钮水平间距
        public static let getCodeButtonHorizontalPadding: CGFloat = 12
        /// 获取验证码按钮垂直间距
        public static let getCodeButtonVerticalPadding: CGFloat = 8
        /// 登录注册动作按钮垂直间距
        public static let actionButtonVerticalPadding: CGFloat = 14
        /// 第三方登录图标容器尺寸
        public static let thirdPartyIconContainerSize: CGFloat = 50
        /// 第三方登录图标字体大小
        public static let thirdPartyIconFontSize: CGFloat = 24
        /// 游客登录按钮顶部间距
        public static let guestButtonTopPadding: CGFloat = 10
    }

    // MARK: - 语音笔记 (Voice)

    /// 语音笔记布局令牌
    public struct Voice {
        /// 录音按钮边长
        public static let recordButtonSize: CGFloat = 80
        /// 波形缩放比例
        public static let waveScale: CGFloat = 40

        /// 录音板块子视图间距
        public static let recordingSectionSpacing: CGFloat = 14
        /// 录音权限提示垂直间距
        public static let permissionSectionSpacing: CGFloat = 12
        /// 语音状态文字垂直间距
        public static let statusTextSpacing: CGFloat = 4
        /// 状态标签水平边距
        public static let statusLabelHorizontalPadding: CGFloat = 12
        /// 状态标签垂直边距
        public static let statusLabelVerticalPadding: CGFloat = 4

        /// 波形展示高度
        public static let waveformHeight: CGFloat = 44
        /// 波形条宽度
        public static let waveBarWidth: CGFloat = 5
        /// 波形条最小高度
        public static let waveBarMinHeight: CGFloat = 4
        /// 波形条之间的间距
        public static let waveBarSpacing: CGFloat = 3

        /// 实时转写输入框最小高度
        public static let transcriptionEditorMinHeight: CGFloat = 100
        /// 实时转写输入框最大高度
        public static let transcriptionEditorMaxHeight: CGFloat = 200
    }

    // MARK: - 巡检健康 (Lint)

    /// 巡检健康布局令牌
    public struct Lint {
        /// 巡检健康圆环图直径
        public static let chartSize: CGFloat = 110
        /// 健康分数超大展示字号 (仅用于分数数字)
        public static let scoreFontSize: CGFloat = 38
        /// 健康检查空状态图标尺寸
        public static let emptyIconSize: CGFloat = 56
    }

    // MARK: - AI 对话 (AI)

    /// AI 对话布局令牌
    public struct AI {
        /// 对话气泡与头像布局令牌
        public struct Chat {
            /// 呼吸点尺寸
            public static let pulsingDotSize: CGFloat = 6
            /// 气泡图标缩放比例
            public static let bubbleIconScale: CGFloat = 1.2
            /// 头像边长
            public static let avatarSize: CGFloat = 22
            /// 气泡圆角
            public static let bubbleCornerRadius: CGFloat = 18
            /// 引用面板圆角
            public static let referencePanelCornerRadius: CGFloat = 6
            /// 气泡区块右侧最小留白 (防止遮挡头像)
            public static let bubbleTrailingPadding: CGFloat = 48
        }
    }

    // MARK: - 用户反馈 (Feedback)

    /// 用户反馈令牌
    public struct Feedback {
        /// 默认评分
        public static let defaultRating: Int = 3
        /// 最大评分
        public static let maxRating: Int = 5
    }
}