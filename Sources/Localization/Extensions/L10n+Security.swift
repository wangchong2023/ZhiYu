//
//  L10n+Security.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 本地化层
//  核心职责：为 Security 模块提供本地化强类型字符串的访问扩展。
//
import Foundation

extension L10n {
    public enum Security: L10nTableEntry {
        public static let tableName = "System"        
        public static var t: String { tableName }
        // MARK: - Prompt 防御与消毒词条
        
        /// 日志：拦截到高风险注入
        public static func promptInjectionLog(_ pattern: String) -> String {
            trf("security.prompt.injection_log", pattern)
        }
        
        /// 拦截到非法指令注入过滤时的无害替代占位文本
        public static var promptInjectionPlaceholder: String {
            tr("security.prompt.injection_placeholder")
        }
        
        /// DLP 拦截：移除网络动态图像时的无害替代占位文本
        public static var dlpImagePlaceholder: String {
            tr("security.dlp.image_placeholder")
        }
        
        /// XML 沙箱包裹参考上下文时的引导词模板（支持 %1$@ 包裹的参考资料）
        public static func sandboxInstructions(with content: String) -> String {
            trf("security.sandbox.instructions", content)
        }

        /// 笔记本完整性校验失败的提示
        public static var integrityVerificationFailed: String {
            Security.tr("hashMismatchDesc")
        }
        
        /// 目标笔记本完整性校验失败的提示
        public static var targetIntegrityVerificationFailed: String {
            Security.tr("targetHashMismatchDesc")
        }
        
        /// 数据库连接安全验证失败，自动降级为只读瞬态内存模式提示
        public static var databaseCorrupted: String {
            tr("security.database.corrupted")
        }
        
        /// 重试重新验证按钮文本
        public static var retryConnection: String {
            tr("security.database.retry")
        }
        
        /// Keychain 数据库口令保存失败时的错误消息
        public static var keychainDatabasePassphraseError: String {
            tr("security.keychain.databasePassphraseError")
        }
        
        /// Keychain HMAC 盐值保存失败时的错误消息
        public static var keychainHMACSaltError: String {
            tr("security.keychain.hmacSaltError")
        }

        /// 审查修复 MED-6: 越狱检测告警日志
        public static var jailbreakDetected: String {
            tr("security.jailbreak.detected")
        }

        /// 审查修复 MED-6: 越狱检测失败原因
        public static var jailbreakFailureReason: String {
            tr("security.jailbreak.failureReason")
        }

        /// 违反安全合规政策拒答提示
        public static var compliancePolicyViolation: String {
            tr("security.compliance.policy_violation")
        }

        /// 频控挂起账户提示
        public static var accountTemporarilyThrottled: String {
            tr("security.compliance.account_throttled")
        }
    }
}
