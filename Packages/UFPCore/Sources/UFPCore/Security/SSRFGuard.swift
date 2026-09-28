//
//  SSRFGuard.swift
//  UFPCore
//
//  Created by CodeFree on 2026/08/07.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 基础设施层
//  核心职责：SSRF 防护 — 拦截内网地址、环回地址、链路本地地址等危险目标。
//           与业务无关的通用网络安全能力，供业务层（WebScraper/ImageExtractor 等）调用。
//
//  审查修复 HIGH-4/HIGH-5: IPv6 前缀误判合法域名 + IP 编码绕过（十进制/八进制/十六进制/省略格式）
//  审查修复 MED-8: 威胁模型边界 — 本实现为基础防护，不防御 DNS rebinding（TOCTOU）。
//                   若需防御 DNS rebinding，应在 isSafeURL 内解析 DNS 后锁定 IP。
//

import Foundation
import Darwin

/// SSRF 防护网关：校验目标 URL 是否为安全的公网地址
/// 用于 URL 导入、网页抓取、图片下载等网络出口（VULN-005/006/007 修复）
public struct SSRFGuard: Sendable {

    /// 校验 URL 是否指向安全的公网地址
    /// - Parameter url: 待校验的 URL
    /// - Returns: true 表示安全（公网地址），false 表示危险（内网/环回/链路本地）
    /// - Note: 本方法为基础防护，不防御 DNS rebinding（TOCTOU）攻击。
    ///         若威胁模型包含 DNS rebinding，需在调用方解析 DNS 后锁定 IP。
    public static func isSafeURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }

        // 1. 拒绝环回地址（IPv4 字符串精确匹配 + IPv6 归一化字节级检测）
        if host == NetworkConstants.Loopback.localhost || host == NetworkConstants.Loopback.loopbackIPv4 {
            return false
        }
        if isIPv6Loopback(host) {
            return false
        }

        // 2. 拒绝链路本地地址（AWS/GCP 元数据端点）
        if host.hasPrefix(NetworkConstants.Loopback.linkLocalPrefix) {
            return false
        }

        // 3. 审查修复 HIGH-5: 归一化 IP 编码后校验私有网络地址段
        //    将十进制/八进制/十六进制/省略格式 IP 归一化为点分十进制
        if let normalizedIP = IPAddressUtility.normalizeIP(host) {
            if IPAddressUtility.isPrivateIPv4(normalizedIP) {
                return false
            }
        }

        // 4. 审查修复 HIGH-4: IPv6 私有地址检测 — 先判断是否为 IPv6 格式
        //    仅对 IPv6 格式地址做前缀匹配，避免误判 fc/fd 开头的合法域名
        if isIPv6Format(host), isPrivateIPv6(host) {
            return false
        }

        // 5. 拒绝 .local / .internal 等本地域名
        if host.hasSuffix(NetworkConstants.LocalDomainSuffix.local) || host.hasSuffix(NetworkConstants.LocalDomainSuffix.internalSuffix) || host.hasSuffix(NetworkConstants.LocalDomainSuffix.localhost) {
            return false
        }

        // 6. 拒绝已知 DNS rebinding 服务域名
        for suffix in NetworkConstants.DNSRebinding.suffixes where host.hasSuffix(suffix) {
            return false
        }

        return true
    }

    // MARK: - IP 格式判断

    /// 判断 host 是否为 IPv6 格式（含冒号或被方括号包裹）
    static func isIPv6Format(_ host: String) -> Bool {
        // 方括号包裹的 IPv6，如 [::1]
        if host.hasPrefix("[") || host.hasSuffix("]") {
            return true
        }
        // 含冒号且非端口分隔（端口分隔在 URL.host 中已被剥离）
        // IPv6 地址至少含 2 个冒号
        let colonCount = host.filter { $0 == ":" }.count
        return colonCount >= 2
    }

    /// 判断 host 是否为 IPv6 环回地址（::1 的任何等价形式）
    /// 使用 POSIX inet_pton 归一化为 16 字节后做字节级检测，
    /// 覆盖 ::1、0:0:0:0:0:0:0:1、[::1]、[0:0:0:0:0:0:0:1] 等所有形式
    static func isIPv6Loopback(_ host: String) -> Bool {
        let cleaned = host.replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
        var address = in6_addr()
        let result = cleaned.withCString { ptr in
            inet_pton(AF_INET6, ptr, &address)
        }
        guard result == 1 else { return false }
        return isIPv6LoopbackBytes(address)
    }

    /// 校验 in6_addr 的 16 字节是否为环回地址（::1 = 前 15 字节为 0，末字节为 1）
    private static func isIPv6LoopbackBytes(_ address: in6_addr) -> Bool {
        withUnsafeBytes(of: address) { bytes in
            guard bytes.count == NetworkConstants.IPv6PrivateRange.totalBytes else { return false }
            for index in 0..<NetworkConstants.IPv6PrivateRange.lastByteIndex {
                if bytes[index] != 0 { return false }
            }
            return bytes[NetworkConstants.IPv6PrivateRange.lastByteIndex] == NetworkConstants.IPv6PrivateRange.loopbackMarker
        }
    }

    // MARK: - IPv4 归一化与私有地址段校验
    // 审查修复 HIGH-5: IP 归一化与私有段校验逻辑已统一至 IPAddressUtility，
    // 消除 SSRFGuard 与 IPAddressUtility 之间的 5 处代码重复（~243 tokens）。
    // 调用方直接使用 IPAddressUtility.normalizeIP / IPAddressUtility.isPrivateIPv4。

    /// 校验 IPv6 地址是否属于私有地址段（fc00::/7, fe80::/10）
    /// - Note: 调用前应先通过 isIPv6Format 确认 host 为 IPv6 格式
    static func isPrivateIPv6(_ host: String) -> Bool {
        // 去除方括号
        let cleaned = host.replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
            .lowercased()

        // fc00::/7 私有地址（fc, fd 开头）
        if cleaned.hasPrefix(NetworkConstants.IPv6PrivateRange.uniqueLocalPrefixFC) || cleaned.hasPrefix(NetworkConstants.IPv6PrivateRange.uniqueLocalPrefixFD) {
            return true
        }
        // fe80::/10 链路本地地址（fe8, fe9, fea, feb 开头）
        if cleaned.hasPrefix(NetworkConstants.IPv6PrivateRange.linkLocalPrefixFE8) || cleaned.hasPrefix(NetworkConstants.IPv6PrivateRange.linkLocalPrefixFE9) ||
            cleaned.hasPrefix(NetworkConstants.IPv6PrivateRange.linkLocalPrefixFEA) || cleaned.hasPrefix(NetworkConstants.IPv6PrivateRange.linkLocalPrefixFEB) {
            return true
        }
        return false
    }
}
