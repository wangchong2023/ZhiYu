//
//  IPAddressUtility.swift
//  UFPCore
//
//  Created by CodeFree on 2026/08/07.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 基础设施层
//  核心职责：通用 IP 地址（IPv4 / IPv6）格式校验、进制归一化、二进制解析与私有网络段判定。
//           与业务无关的基础网络工具类，供安全网关、网络客户端与配置校验器复用。
//

import Foundation
import Darwin

/// 通用 IP 地址处理工具集
public enum IPAddressUtility {

    // MARK: - IP 格式与协议判定

    /// 判断 host 是否为 IPv6 格式（含冒号或被方括号包裹）
    /// - Parameter host: 待校验的主机名或 IP 文本
    /// - Returns: 是否为 IPv6 格式
    public static func isIPv6Format(_ host: String) -> Bool {
        // 方括号包裹的 IPv6，如 [::1]
        if host.hasPrefix("[") || host.hasSuffix("]") {
            return true
        }
        // 含冒号且非端口分隔（IPv6 地址至少含 2 个冒号）
        let colonCount = host.filter { $0 == ":" }.count
        return colonCount >= 2
    }

    // MARK: - IPv4 归一化

    /// 将各种 IPv4 编码格式归一化为标准点分十进制字符串
    /// 支持：纯十进制整数（2130706433）、八进制（0177.0.0.1）、十六进制（0x7f.0.0.1）、省略格式（127.1）
    /// - Parameter host: 待归一化的主机名或 IP 文本
    /// - Returns: 标准点分十进制 IPv4 字符串；若无法解析则返回 nil
    public static func normalizeIP(_ host: String) -> String? {
        // 纯十进制整数 IP（如 2130706433 = 127.0.0.1）
        if let decimalValue = UInt32(host), host.allSatisfy(\.isNumber) {
            return ipv4FromUInt32(decimalValue)
        }

        // 点分格式，可能含八进制/十六进制段
        let parts = host.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= NetworkConstants.IPv4Octet.minCount, parts.count <= NetworkConstants.IPv4Octet.maxCount else {
            return nil
        }

        var octets: [UInt32] = []
        for part in parts {
            guard let octet = parseIPOctet(String(part)) else { return nil }
            octets.append(octet)
        }

        // 省略格式处理：1 段 = 整个 IP，2 段 = a.b → a.0.0.b，3 段 = a.b.c → a.b.0.c
        return combineOctets(octets)
    }

    /// 解析单个 IP 段（支持十进制、八进制 0xxx、十六进制 0xXX）
    /// - Parameter trimmed: 单段文本
    /// - Returns: 解析后的 32 位无符号整数；格式非法时返回 nil
    public static func parseIPOctet(_ trimmed: String) -> UInt32? {
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
    /// - Parameter octets: 各段数值数组
    /// - Returns: 点分十进制字符串；段数不符合规范或越界时返回 nil
    public static func combineOctets(_ octets: [UInt32]) -> String? {
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
    /// 使用 POSIX `inet_ntop` 系统库函数处理标准转换，避免手写位运算误差
    /// - Parameter value: 主机字节序的 32 位整数
    /// - Returns: 点分十进制字符串；转换失败返回 nil
    public static func ipv4FromUInt32(_ value: UInt32) -> String? {
        // inet_ntop 要求网络字节序（大端），需将主机字节序转换
        let networkOrder = value.bigEndian
        var address = in_addr(s_addr: networkOrder)
        var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        let result = inet_ntop(AF_INET, &address, &buffer, socklen_t(INET_ADDRSTRLEN))
        guard result != nil else { return nil }
        return String(decoding: buffer.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    // MARK: - 私有地址段校验

    /// 校验点分十进制 IPv4 是否属于私有网络段（RFC 1918 / RFC 5735 / RFC 6598 / RFC 3927）
    /// - Parameter ip: 点分十进制 IPv4 字符串
    /// - Returns: 是否为私有/环回/链路本地地址
    public static func isPrivateIPv4(_ ip: String) -> Bool {
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

    /// 校验 IPv6 地址是否属于私有地址段（fc00::/7, fe80::/10, 环回, 映射）
    /// - Parameter host: 待校验的 IPv6 主机名（支持方括号包裹与压缩形式）
    /// - Returns: 是否为私有/环回/链路本地地址
    /// - Note: 调用前应先通过 isIPv6Format 确认 host 为 IPv6 格式
    public static func isPrivateIPv6(_ host: String) -> Bool {
        // 去除方括号
        let cleaned = host.replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
            .lowercased()

        // 优先通过 POSIX inet_pton 解析 128 位二进制 IPv6 地址，免疫各类字符串压缩/全零表示绕过
        var sin6 = in6_addr()
        if inet_pton(AF_INET6, cleaned, &sin6) == 1 {
            let isLoopback = withUnsafeBytes(of: &sin6) { raw in
                for idx in 0..<NetworkConstants.IPv6PrivateRange.lastByteIndex where raw[idx] != 0 {
                    return false
                }
                return raw[NetworkConstants.IPv6PrivateRange.lastByteIndex] == NetworkConstants.IPv6PrivateRange.loopbackMarker
            }
            if isLoopback { return true }

            let isUnspecified = withUnsafeBytes(of: &sin6) { raw in
                for idx in 0..<NetworkConstants.IPv6PrivateRange.totalBytes where raw[idx] != 0 {
                    return false
                }
                return true
            }
            if isUnspecified { return true }

            let isV4Mapped = withUnsafeBytes(of: &sin6) { raw in
                for idx in 0..<NetworkConstants.IPv6PrivateRange.v4MappedZeroPrefixCount where raw[idx] != 0 {
                    return false
                }
                return raw[NetworkConstants.IPv6PrivateRange.v4MappedIndex1] == NetworkConstants.IPv6PrivateRange.v4MappedMarker &&
                       raw[NetworkConstants.IPv6PrivateRange.v4MappedIndex2] == NetworkConstants.IPv6PrivateRange.v4MappedMarker
            }
            if isV4Mapped {
                let v4Octets = withUnsafeBytes(of: &sin6) { raw in
                    "\(raw[NetworkConstants.IPv6PrivateRange.v4MappedOctetIndex0])." +
                    "\(raw[NetworkConstants.IPv6PrivateRange.v4MappedOctetIndex1])." +
                    "\(raw[NetworkConstants.IPv6PrivateRange.v4MappedOctetIndex2])." +
                    "\(raw[NetworkConstants.IPv6PrivateRange.v4MappedOctetIndex3])"
                }
                if isPrivateIPv4(v4Octets) { return true }
            }

            let firstByte = withUnsafeBytes(of: &sin6) { $0[0] }
            if (firstByte & NetworkConstants.IPv6PrivateRange.uniqueLocalMask) == NetworkConstants.IPv6PrivateRange.uniqueLocalExpected {
                return true
            }

            let secondByte = withUnsafeBytes(of: &sin6) { $0[1] }
            if firstByte == NetworkConstants.IPv6PrivateRange.linkLocalFirstByte &&
               (secondByte & NetworkConstants.IPv6PrivateRange.linkLocalSecondByteMask) == NetworkConstants.IPv6PrivateRange.linkLocalSecondByteExpected {
                return true
            }
        }

        // 字符串前缀保底 fallback
        if cleaned.hasPrefix(NetworkConstants.IPv6PrivateRange.uniqueLocalPrefixFC) || cleaned.hasPrefix(NetworkConstants.IPv6PrivateRange.uniqueLocalPrefixFD) {
            return true
        }
        if cleaned.hasPrefix(NetworkConstants.IPv6PrivateRange.linkLocalPrefixFE8) || cleaned.hasPrefix(NetworkConstants.IPv6PrivateRange.linkLocalPrefixFE9) ||
            cleaned.hasPrefix(NetworkConstants.IPv6PrivateRange.linkLocalPrefixFEA) || cleaned.hasPrefix(NetworkConstants.IPv6PrivateRange.linkLocalPrefixFEB) {
            return true
        }
        return false
    }
}
