//
//  NetworkConstants.swift
//  UFPCore
//
//  Created by CodeFree on 2026/08/07.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 基础设施层
//  核心职责：与业务无关的网络协议常量集（IPv4/IPv6 地址段、octet 校验范围、
//           位运算移位量等），避免代码中出现裸数字 10/172/192/127/169 等魔鬼数字。
//           依据 RFC 1918 / RFC 3927 / RFC 6598 / RFC 5735 / RFC 4291 等标准定义。
//

import Foundation

/// 与业务无关的网络协议常量集
public enum NetworkConstants {

    // MARK: - IPv4 私有地址段 (RFC 1918 / RFC 5735)

    /// IPv4 私有地址段定义（RFC 1918 / RFC 3927 / RFC 6598 / RFC 5735）
    public enum IPv4PrivateRange {
        // MARK: RFC 1918 私有段

        /// 10.0.0.0/8 — RFC 1918 Class A 私有段
        public static let classAFirstOctet: UInt32 = 10
        /// 172.16.0.0/12 — RFC 1918 Class B 私有段
        public static let classBFirstOctet: UInt32 = 172
        /// 172.16.0.0/12 — Class B 私有段第二 octet 范围起始
        public static let classBSecondOctetStart: UInt32 = 16
        /// 172.16.0.0/12 — Class B 私有段第二 octet 范围结束
        public static let classBSecondOctetEnd: UInt32 = 31
        /// 192.168.0.0/16 — RFC 1918 Class C 私有段第一 octet
        public static let classCFirstOctet: UInt32 = 192
        /// 192.168.0.0/16 — RFC 1918 Class C 私有段第二 octet
        public static let classCSecondOctet: UInt32 = 168

        // MARK: RFC 5735 特殊用途段

        /// 0.0.0.0/8 — RFC 5735 本网络段（this-network）
        public static let thisNetworkOctet: UInt32 = 0
        /// 127.0.0.0/8 — RFC 5735 环回段（loopback）
        public static let loopbackOctet: UInt32 = 127

        // MARK: RFC 6598 CGNAT 段

        /// 100.64.0.0/10 — RFC 6598 CGNAT 段第一 octet
        public static let cgnatFirstOctet: UInt32 = 100
        /// 100.64.0.0/10 — CGNAT 段第二 octet 范围起始
        public static let cgnatSecondOctetStart: UInt32 = 64
        /// 100.64.0.0/10 — CGNAT 段第二 octet 范围结束
        public static let cgnatSecondOctetEnd: UInt32 = 127

        // MARK: RFC 3927 链路本地段

        /// 169.254.0.0/16 — RFC 3927 链路本地段第一 octet
        public static let linkLocalFirstOctet: UInt32 = 169
        /// 169.254.0.0/16 — RFC 3927 链路本地段第二 octet
        public static let linkLocalSecondOctet: UInt32 = 254
    }

    // MARK: - IPv4 Octet 校验 (Octet Validation)

    /// IPv4 octet 校验范围与段数限制
    public enum IPv4Octet {
        /// octet 最大值（255）
        public static let maxValue: UInt32 = 255
        /// 完整 IPv4 地址的 octet 数量
        public static let fullCount: Int = 4
        /// 省略格式最小 octet 数量
        public static let minCount: Int = 1
        /// 省略格式最大 octet 数量
        public static let maxCount: Int = 4
    }

    // MARK: - IPv4 位运算移位量 (Bit Shift)

    /// IPv4 省略格式组合时的位运算移位量
    public enum IPv4BitShift {
        /// 第一 octet 左移位数（24 位）
        public static let octet1: UInt32 = 24
        /// 第二 octet 左移位数（16 位）
        public static let octet2: UInt32 = 16
        /// 第三 octet 左移位数（8 位）
        public static let octet3: UInt32 = 8
        /// octet 位掩码（0xFF）
        public static let octetMask: UInt32 = 0xFF
    }

    // MARK: - IPv6 私有地址段 (RFC 4291)

    /// IPv6 私有地址段前缀（RFC 4291）
    public enum IPv6PrivateRange {
        /// fc00::/7 — 唯一本地地址前缀起始（fc）
        public static let uniqueLocalPrefixFC: String = "fc"
        /// fd00::/7 — 唯一本地地址前缀起始（fd）
        public static let uniqueLocalPrefixFD: String = "fd"
        /// fe80::/10 — 链路本地地址前缀起始（fe8）
        public static let linkLocalPrefixFE8: String = "fe8"
        /// fe80::/10 — 链路本地地址前缀起始（fe9）
        public static let linkLocalPrefixFE9: String = "fe9"
        /// fe80::/10 — 链路本地地址前缀起始（fea）
        public static let linkLocalPrefixFEA: String = "fea"
        /// fe80::/10 — 链路本地地址前缀起始（feb）
        public static let linkLocalPrefixFEB: String = "feb"
        /// IPv6 地址总字节数
        public static let totalBytes: Int = 16
        /// 环回地址最后字节索引
        public static let lastByteIndex: Int = 15
        /// 环回地址标记字节
        public static let loopbackMarker: UInt8 = 0x01
        /// IPv4 映射地址零前缀字节数
        public static let v4MappedZeroPrefixCount: Int = 10
        /// IPv4 映射地址前导标记索引 1
        public static let v4MappedIndex1: Int = 10
        /// IPv4 映射地址前导标记索引 2
        public static let v4MappedIndex2: Int = 11
        /// IPv4 映射地址前导标记值
        public static let v4MappedMarker: UInt8 = 0xFF
        /// IPv4 映射地址八位组索引 0
        public static let v4MappedOctetIndex0: Int = 12
        /// IPv4 映射地址八位组索引 1
        public static let v4MappedOctetIndex1: Int = 13
        /// IPv4 映射地址八位组索引 2
        public static let v4MappedOctetIndex2: Int = 14
        /// IPv4 映射地址八位组索引 3
        public static let v4MappedOctetIndex3: Int = 15
        /// 唯一本地地址掩码
        public static let uniqueLocalMask: UInt8 = 0xFE
        /// 唯一本地地址期望值
        public static let uniqueLocalExpected: UInt8 = 0xFC
        /// 链路本地地址首字节
        public static let linkLocalFirstByte: UInt8 = 0xFE
        /// 链路本地地址次字节掩码
        public static let linkLocalSecondByteMask: UInt8 = 0xC0
        /// 链路本地地址次字节期望值
        public static let linkLocalSecondByteExpected: UInt8 = 0x80
    }

    // MARK: - IP 编码前缀 (IP Encoding Prefix)

    /// IP 段十六进制编码前缀
    public enum IPEncoding {
        /// 十六进制段小写前缀
        public static let hexPrefixLower: String = "0x"
        /// 十六进制段大写前缀
        public static let hexPrefixUpper: String = "0X"
        /// 八进制段前缀
        public static let octalPrefix: String = "0"
    }

    // MARK: - 环回与本地地址 (Loopback & Local Addresses)

    /// 环回地址与本地域名常量
    public enum Loopback {
        /// localhost 主机名
        public static let localhost: String = "localhost"
        /// IPv4 环回地址
        public static let loopbackIPv4: String = "127.0.0.1"
        /// IPv6 环回地址
        public static let loopbackIPv6: String = "::1"
        /// IPv6 环回地址（带方括号）
        public static let loopbackIPv6Bracketed: String = "[::1]"
        /// 链路本地地址前缀（AWS/GCP 元数据端点）
        public static let linkLocalPrefix: String = "169.254."
    }

    // MARK: - 本地域名后缀 (Local Domain Suffixes)

    /// 本地域名后缀集合
    public enum LocalDomainSuffix {
        /// .local 后缀
        public static let local: String = ".local"
        /// .internal 后缀
        public static let internalSuffix: String = ".internal"
        /// .localhost 后缀
        public static let localhost: String = ".localhost"
    }

    // MARK: - DNS Rebinding 服务后缀 (DNS Rebinding Suffixes)

    /// DNS rebinding 服务后缀集合（用于检测 DNS rebinding 攻击）
    public enum DNSRebinding {
        /// 已知 DNS rebinding 服务后缀列表
        public static let suffixes: [String] = [".nip.io", ".sslip.io", ".localtest.me", ".xip.io"]
    }

    // MARK: - URL Scheme 白名单 (URL Scheme Whitelist)

    /// URL scheme 白名单常量 — 仅允许 http/https 协议发起网络请求，
    /// 拦截 ftp/file/ftp/gopher 等非 HTTP scheme 导致的潜在 SSRF 与超时挂起
    public enum URLScheme {
        /// HTTP 协议 scheme
        public static let http: String = "http"
        /// HTTPS 协议 scheme
        public static let https: String = "https"
        /// 允许的 scheme 白名单集合
        public static let allowed: Set<String> = [http, https]
    }
}
