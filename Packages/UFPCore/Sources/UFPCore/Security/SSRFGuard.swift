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

        // 1. 拒绝环回地址
        if host == NetworkConstants.Loopback.localhost || host == NetworkConstants.Loopback.loopbackIPv4 || host == NetworkConstants.Loopback.loopbackIPv6 || host == NetworkConstants.Loopback.loopbackIPv6Bracketed {
            return false
        }

        // 2. 拒绝链路本地地址（AWS/GCP 元数据端点）
        if host.hasPrefix(NetworkConstants.Loopback.linkLocalPrefix) {
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

    // MARK: - IPv4 归一化（审查修复 HIGH-5）

    /// 将各种 IP 编码格式归一化为点分十进制
    /// 支持：十进制整数（2130706433）、八进制（0177.0.0.1）、十六进制（0x7f.0.0.1）、省略格式（127.1）
    static func normalizeIP(_ host: String) -> String? {
        // 纯十进制整数 IP（如 2130706433 = 127.0.0.1）
        if let decimalValue = UInt32(host), host.allSatisfy(\.isNumber) {
            return ipv4FromUInt32(decimalValue)
        }

        // 点分格式，可能含八进制/十六进制段
        let parts = host.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= NetworkConstants.IPv4Octet.minCount, parts.count <= NetworkConstants.IPv4Octet.maxCount else { return nil }

        var octets: [UInt32] = []
        for part in parts {
            guard let octet = parseIPOctet(String(part)) else { return nil }
            octets.append(octet)
        }

        // 省略格式处理：1 段 = 整个 IP，2 段 = a.b → a.0.0.b，3 段 = a.b.c → a.b.0.c
        return combineOctets(octets)
    }

    /// 解析单个 IP 段（支持十进制、八进制 0xxx、十六进制 0xXX）
    static func parseIPOctet(_ trimmed: String) -> UInt32? {
        if trimmed.hasPrefix(NetworkConstants.IPEncoding.hexPrefixLower) || trimmed.hasPrefix(NetworkConstants.IPEncoding.hexPrefixUpper) {
            // 十六进制段
            return UInt32(trimmed.dropFirst(2), radix: 16)
        } else if trimmed.hasPrefix(NetworkConstants.IPEncoding.octalPrefix) && trimmed.count > 1 {
            // 八进制段
            return UInt32(trimmed.dropFirst(), radix: 8)
        } else {
            // 十进制段
            return UInt32(trimmed)
        }
    }

    /// 将 octets 数组组合为点分十进制 IPv4 字符串（处理省略格式）
    static func combineOctets(_ octets: [UInt32]) -> String? {
        switch octets.count {
        case NetworkConstants.IPv4Octet.minCount:
            return ipv4FromUInt32(octets[0])
        case 2:
            let combined = (octets[0] << NetworkConstants.IPv4BitShift.octet1) | octets[1]
            return ipv4FromUInt32(combined)
        case 3:
            let combined = (octets[0] << NetworkConstants.IPv4BitShift.octet1) | (octets[1] << NetworkConstants.IPv4BitShift.octet2) | octets[2]
            return ipv4FromUInt32(combined)
        case NetworkConstants.IPv4Octet.fullCount:
            // 检查每段是否在 0-255 范围
            guard octets.allSatisfy({ $0 <= NetworkConstants.IPv4Octet.maxValue }) else { return nil }
            return "\(octets[0]).\(octets[1]).\(octets[2]).\(octets[3])"
        default:
            return nil
        }
    }

    /// 将 UInt32 转为点分十进制 IPv4（网络字节序）
    /// 使用 POSIX `inet_ntop` 系统库函数处理标准转换，避免自研位运算
    static func ipv4FromUInt32(_ value: UInt32) -> String? {
        // inet_ntop 要求网络字节序（大端），需将主机字节序转换
        let networkOrder = value.bigEndian
        var address = in_addr(s_addr: networkOrder)
        var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        let result = inet_ntop(AF_INET, &address, &buffer, socklen_t(INET_ADDRSTRLEN))
        guard result != nil else { return nil }
        return String(cString: buffer)
    }

    // MARK: - 私有地址段校验

    /// 校验点分十进制 IPv4 是否属于私有网络段
    static func isPrivateIPv4(_ ip: String) -> Bool {
        let parts = ip.split(separator: ".").compactMap { UInt32($0) }
        guard parts.count == NetworkConstants.IPv4Octet.fullCount else { return false }

        // 10.0.0.0/8 — RFC 1918 Class A 私有段
        if parts[0] == NetworkConstants.IPv4PrivateRange.classAFirstOctet { return true }
        // 172.16.0.0/12 — RFC 1918 Class B 私有段
        if parts[0] == NetworkConstants.IPv4PrivateRange.classBFirstOctet,
           parts[1] >= NetworkConstants.IPv4PrivateRange.classBSecondOctetStart,
           parts[1] <= NetworkConstants.IPv4PrivateRange.classBSecondOctetEnd { return true }
        // 192.168.0.0/16 — RFC 1918 Class C 私有段
        if parts[0] == NetworkConstants.IPv4PrivateRange.classCFirstOctet,
           parts[1] == NetworkConstants.IPv4PrivateRange.classCSecondOctet { return true }
        // 0.0.0.0/8 — RFC 5735 本网络段
        if parts[0] == NetworkConstants.IPv4PrivateRange.thisNetworkOctet { return true }
        // 100.64.0.0/10 — RFC 6598 CGNAT 段
        if parts[0] == NetworkConstants.IPv4PrivateRange.cgnatFirstOctet,
           parts[1] >= NetworkConstants.IPv4PrivateRange.cgnatSecondOctetStart,
           parts[1] <= NetworkConstants.IPv4PrivateRange.cgnatSecondOctetEnd { return true }
        // 127.0.0.0/8 — RFC 5735 环回段
        if parts[0] == NetworkConstants.IPv4PrivateRange.loopbackOctet { return true }
        // 169.254.0.0/16 — RFC 3927 链路本地段
        if parts[0] == NetworkConstants.IPv4PrivateRange.linkLocalFirstOctet,
           parts[1] == NetworkConstants.IPv4PrivateRange.linkLocalSecondOctet { return true }

        return false
    }

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
