//
//  WatchAppEnvironment.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 应用层
//  核心职责：平台环境适配实现，桥接 AppEnvironmentProtocol 与具体平台 API。
//
#if os(watchOS)
import WatchKit

/// watchOS 环境能力实现
final class WatchAppEnvironment: AppEnvironmentProtocol {
    var screenClass: ScreenClass { return .compact }
    
    var interactionStyle: InteractionStyle { return .crown }
    
    var supportsPencil: Bool { return false }
    
    var hasCamera: Bool { return false }
    
    var isMobile: Bool { return true }
    
    var platformName: String { return "watchOS" }
    
    var deviceName: String {
        return WKInterfaceDevice.current().name
    }
    
    var isCloudSyncSupported: Bool { return false }
}
#endif
