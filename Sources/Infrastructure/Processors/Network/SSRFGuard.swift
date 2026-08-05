//
//  SSRFGuard.swift
//  ZhiYu
//
//  Created by CodeFree Security Audit on 2026/08/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：SSRF 防护 — 拦截内网地址、环回地址、链路本地地址等危险目标。
//
//  审查修复 HIGH-4/HIGH-5: IPv6 前缀误判合法域名 + IP 编码绕过（十进制/八进制/十六进制/省略格式）
//  审查修复 MED-8: 威胁模型边界 — 本实现为基础防护，不防御 DNS rebinding（TOCTOU）。
//                   若需防御 DNS rebinding，应在 isSafeURL 内解析 DNS 后锁定 IP。
//

import Foundation

/// SSRF 防护网关：校验目标 URL 是否为安全的公网地址
/// 用于 URL 导入、网页抓取、图片下载等网络出口（VULN-005/006/007 修复）
struct SSRFGuard: Sendable {

    /// 校验 URL 是否指向安全的公网地址
    /// - Parameter url: 待校验的 URL
    /// - Returns: true 表示安全（公网地址），false 表示危险（内网/环回/链路本地）
    /// - Note: 本方法为基础防护，不防御 DNS rebinding（TOCTOU）攻击。
    ///         若威胁模型包含 DNS rebinding，需在调用方解析 DNS 后锁定 IP。
    static func isSafeURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }

        // 1. 拒绝环回地址
        if host == ProcessorConstants.SSRFGuard.localhost || host == ProcessorConstants.SSRFGuard.loopbackIPv4 || host == ProcessorConstants.SSRFGuard.loopbackIPv6 || host == ProcessorConstants.SSRFGuard.loopbackIPv6Bracketed {
            return false
        }

        // 2. 拒绝链路本地地址（AWS/GCP 元数据端点）
        if host.hasPrefix(ProcessorConstants.SSRFGuard.linkLocalPrefix) {
            return false
        }

        // 3. 审查修复 HIGH-5: 归一化 IP 编码后校验私有网络地址段
        //    将十进制/八进制/十六进制/省略格式 IP 归一化为点分十进制
        if let normalizedIP = normalizeIP(host) {
            if isPrivateIPv4(normalizedIP) {
                return false
            }
        }

        // 4. 审查修复 HIGH-4: IPv6 私有地址检测 — 先判断是否为 IPv6 格式
        //    仅对 IPv6 格式地址做前缀匹配，避免误判 fc/fd 开头的合法域名
        if isIPv6Format(host), isPrivateIPv6(host) {
            return false
        }

        // 5. 拒绝 .local / .internal 等本地域名
        if host.hasSuffix(ProcessorConstants.SSRFGuard.localDomainSuffix) || host.hasSuffix(ProcessorConstants.SSRFGuard.internalDomainSuffix) || host.hasSuffix(ProcessorConstants.SSRFGuard.localhostDomainSuffix) {
            return false
        }

        // 6. 拒绝已知 DNS rebinding 服务域名
        let rebindingSuffixes = [".nip.io", ".sslip.io", ".localtest.me", ".xip.io"]
        for suffix in rebindingSuffixes where host.hasSuffix(suffix) {
            return false
        }

        return true
    }

    // MARK: - IP 格式判断

    /// 判断 host 是否为 IPv6 格式（含冒号或被方括号包裹）
    private static func isIPv6Format(_ host: String) -> Bool {
        // 方括号包裹的 IPv6，如 [::1]
        if host.hasPrefix("[") || host.hasSuffix("]") {
            return true
        }
        // 含冒号且非端口分隔（端口分隔在 URL.host 中已被剥离）
        // IPv6 地址至少含 2 个冒号
        let colonCount = host.filter { $0 == ":" }.count
        return colonCount >= 2
    }

    // MARK: - IPv4 归一化（审查修复 HIGH-5）

    /// 将各种 IP 编码格式归一化为点分十进制
    /// 支持：十进制整数（2130706433）、八进制（0177.0.0.1）、十六进制（0x7f.0.0.1）、省略格式（127.1）
    private static func normalizeIP(_ host: String) -> String? {
        // 纯十进制整数 IP（如 2130706433 = 127.0.0.1）
        if let decimalValue = UInt32(host), host.allSatisfy(\.isNumber) {
            return ipv4FromUInt32(decimalValue)
        }

        // 点分格式，可能含八进制/十六进制段
        let parts = host.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 1, parts.count <= 4 else { return nil }

        var octets: [UInt32] = []
        for part in parts {
            guard let octet = parseIPOctet(String(part)) else { return nil }
            octets.append(octet)
        }

        // 省略格式处理：1 段 = 整个 IP，2 段 = a.b → a.0.0.b，3 段 = a.b.c → a.b.0.c
        return combineOctets(octets)
    }

    /// 解析单个 IP 段（支持十进制、八进制 0xxx、十六进制 0xXX）
    private static func parseIPOctet(_ trimmed: String) -> UInt32? {
        if trimmed.hasPrefix(ProcessorConstants.SSRFGuard.hexPrefixLower) || trimmed.hasPrefix(ProcessorConstants.SSRFGuard.hexPrefixUpper) {
            // 十六进制段
            return UInt32(trimmed.dropFirst(2), radix: 16)
        } else if trimmed.hasPrefix("0") && trimmed.count > 1 {
            // 八进制段
            return UInt32(trimmed.dropFirst(), radix: 8)
        } else {
            // 十进制段
            return UInt32(trimmed)
        }
    }

    /// 将 octets 数组组合为点分十进制 IPv4 字符串（处理省略格式）
    private static func combineOctets(_ octets: [UInt32]) -> String? {
        switch octets.count {
        case 1:
            return ipv4FromUInt32(octets[0])
        case 2:
            let combined = (octets[0] << 24) | octets[1]
            return ipv4FromUInt32(combined)
        case 3:
            let combined = (octets[0] << 24) | (octets[1] << 16) | octets[2]
            return ipv4FromUInt32(combined)
        case 4:
            // 检查每段是否在 0-255 范围
            guard octets.allSatisfy({ $0 <= 255 }) else { return nil }
            return "\(octets[0]).\(octets[1]).\(octets[2]).\(octets[3])"
        default:
            return nil
        }
    }

    /// 将 UInt32 转为点分十进制 IPv4
    private static func ipv4FromUInt32(_ value: UInt32) -> String {
        let octet1 = (value >> 24) & 0xFF
        let octet2 = (value >> 16) & 0xFF
        let octet3 = (value >> 8) & 0xFF
        let octet4 = value & 0xFF
        return "\(octet1).\(octet2).\(octet3).\(octet4)"
    }

    // MARK: - 私有地址段校验

    /// 校验点分十进制 IPv4 是否属于私有网络段
    private static func isPrivateIPv4(_ ip: String) -> Bool {
        let parts = ip.split(separator: ".").compactMap { UInt32($0) }
        guard parts.count == 4 else { return false }

        // 10.0.0.0/8
        if parts[0] == 10 { return true }
        // 172.16.0.0/12
        if parts[0] == 172, parts[1] >= 16, parts[1] <= 31 { return true }
        // 192.168.0.0/16
        if parts[0] == 192, parts[1] == 168 { return true }
        // 0.0.0.0/8
        if parts[0] == 0 { return true }
        // 100.64.0.0/10 CGNAT
        if parts[0] == 100, parts[1] >= 64, parts[1] <= 127 { return true }
        // 127.0.0.0/8 环回（补充校验）
        if parts[0] == 127 { return true }
        // 169.254.0.0/16 链路本地（补充校验）
        if parts[0] == 169, parts[1] == 254 { return true }

        return false
    }

    /// 校验 IPv6 地址是否属于私有地址段（fc00::/7, fe80::/10）
    /// - Note: 调用前应先通过 isIPv6Format 确认 host 为 IPv6 格式
    private static func isPrivateIPv6(_ host: String) -> Bool {
        // 去除方括号
        let cleaned = host.replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
            .lowercased()

        // fc00::/7 私有地址（fc, fd 开头）
        if cleaned.hasPrefix(ProcessorConstants.SSRFGuard.ipv6UniqueLocalPrefixFC) || cleaned.hasPrefix(ProcessorConstants.SSRFGuard.ipv6UniqueLocalPrefixFD) {
            return true
        }
        // fe80::/10 链路本地地址（fe8, fe9, fea, feb 开头）
        if cleaned.hasPrefix(ProcessorConstants.SSRFGuard.ipv6LinkLocalPrefixFE8) || cleaned.hasPrefix(ProcessorConstants.SSRFGuard.ipv6LinkLocalPrefixFE9) ||
            cleaned.hasPrefix(ProcessorConstants.SSRFGuard.ipv6LinkLocalPrefixFEA) || cleaned.hasPrefix(ProcessorConstants.SSRFGuard.ipv6LinkLocalPrefixFEB) {
            return true
        }
        return false
    }
}
