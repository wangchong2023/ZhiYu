//
//  ApplicationStorageLocation.swift
//  ZhiYu
//
//  系统层级：[L0] 基础设施层
//  核心职责：为独立应用环境提供可注入的文件存储根目录。
//
import Foundation
import UFPCore

/// 存储位置由应用组装层选择，业务层不判断运行环境。
struct ApplicationStorageLocation: Sendable {
    let root: URL

    static var applicationSupport: URL {
        // inject_exempt: 可选应用级存储位置，未配置时沿用现有系统目录
        if let location = ServiceContainer.shared.resolveOptional(ApplicationStorageLocation.self) {
            return location.root
        }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
    }
}
