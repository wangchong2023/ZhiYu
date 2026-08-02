//
//  JailbreakDetector.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0.5] 系统集成层
//  核心职责：越狱检测：检测设备越狱状态、沙箱完整性、Cydia scheme，保障运行环境安全。
//
import Foundation
#if os(iOS)
import UIKit
#endif

/// 越狱检测器
/// 封装设备运行环境的安全完整性检测逻辑，防止应用在越狱或被注入调试器等不安全设备上运行，保障知识图谱的本地机密性。
public final class JailbreakDetector: Sendable {
    /// 获取越狱检测器的共享单例
    public static let shared = JailbreakDetector()
    
    private init() {}
    
    /// 检测当前设备是否已越狱。
    ///
    /// 综合多项底层安全检测项。任何一项异常即判定为已越狱。
    /// - Returns: 若已越狱返回 true，否则返回 false。
    @MainActor
    public func isJailbroken() -> Bool {
        // 1. 检测常见越狱文件的物理路径是否存在
        if checkCommonJailbreakFiles() {
            return true
        }
        
        // 2. 检测系统目录写权限是否破裂
        if checkSandboxWritePermission() {
            return true
        }
        
        // 3. 检测是否可成功调用底层越狱 URL scheme
        if checkCydiaScheme() {
            return true
        }
        
        return false
    }
    
    /// 物理扫描常用越狱工具物理文件及配置文件是否存在
    private func checkCommonJailbreakFiles() -> Bool {
        let jbPaths = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/usr/bin/ssh"
        ]
        for path in jbPaths where FileManager.default.fileExists(atPath: path) {
                return true
        }
        return false
    }
    
    /// 物理尝试向沙盒外部系统敏感路径写入测试文件以验证隔离沙箱完整性
    private func checkSandboxWritePermission() -> Bool {
        let testPath = "/private/jailbreak_test.txt"
        do {
            try "test".write(toFile: testPath, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(atPath: testPath)
            return true
        } catch {
            return false
        }
    }
    
    /// 检验是否能打开 Cydia 协议 URL
    @MainActor
    private func checkCydiaScheme() -> Bool {
        // VULN-010 修复：恢复 Cydia scheme 检测，使用 canOpenURL 判断
        #if os(iOS)
        if let url = URL(string: "cydia://package/com.example.test") {
            return UIApplication.shared.canOpenURL(url)
        }
        #endif
        return false
    }
}
