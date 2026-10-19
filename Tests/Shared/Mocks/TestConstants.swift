//
//  TestConstants.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/10/18.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests] 测试层常量
//  核心职责：集中定义单元测试与 Mock 所需的测试凭据与字面量，避免污染 Sources/ 生产代码。
//

import Foundation
@testable import ZhiYu

/// 测试套件统一常量定义
public enum TestConstants {
    /// 身份认证测试常量
    public enum Auth {
        public static let mockJwtToken = "mock_jwt_token"
        public static let mockGoogleCode = "mock_google_code"
        public static let mockAppleCode = "mock_apple_authorization_code"
        public static let mockJwtAccess = "mock_jwt_access_token"
        public static let mockJwtRefresh = "mock_jwt_refresh_token"
        public static let mockSub123 = "mock_sub_123"
        public static let mockAutologinUser = "Mock Autologin User"
        public static let mockAutologinEmail = "mock_autologin@example.com"
        public static let mockAutologinPhone = "13800000000"
        public static let weChatMockUser = "WeChat Mock User"
        public static let gitHubMockUser = "GitHub Mock User"
        public static let googleMockUser = "Google Mock User"
    }
}

extension FeatureConstants {
    public typealias MockData = FeatureConstants.DefaultValue
    public typealias MockText = FeatureConstants.LabDemoText
    public typealias MockColorName = FeatureConstants.DemoColorName
}
