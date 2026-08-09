//
//  AuthRegionDetector.swift
//  ZhiYu
//
//  Created by Constantine on 2026/06/21.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层 - 认证服务
//  核心职责：多优先级智能环境感知检测器，通过对 SIM 卡、系统区域以及时区等多因子探测，并配合 JSON 规则进行最优认证分区决策。
//

import Foundation

/// 登录认证划分的物理区域类型
public enum AuthRegion: String, Codable, CaseIterable, Sendable {
    /// 中国大陆认证服务区（手机号一键登录/微信等）
    case china = "CN"
    /// 国际认证服务区（通行密钥 Passkeys/Apple/Google/邮箱等）
    case international = "INTL"
}

/// 区域检测相关常量
private enum AuthRegionSpec {
    /// 区域能力配置文件名（不含扩展名）
    static let capabilitiesFileName = "region_capabilities"
    /// 区域能力配置文件扩展名
    static let capabilitiesFileExtension = "json"
    /// 中国大陆时区标识列表
    static let chinaTimeZoneIdentifiers = ["Asia/Shanghai", "Asia/Chongqing", "Asia/Harbin", "Asia/Urumqi"]
    /// 中国大陆 ISO 国家码
    static let chinaISOCode = "CN"
    /// 美国 ISO 国家码（兜底）
    static let usISOCode = "US"
    /// JSON 配置中的默认区域键
    static let defaultRegionKey = "default"
    /// JSON 配置中本地化登录页标识
    static let localizedLoginPageType = "localized"
}

/// 用户登录环境及地区探测服务类
public final class AuthRegionDetector: @unchecked Sendable {
    
    /// 单例访问点
    public static let shared = AuthRegionDetector()
    
    /// 缓存的区域能力 JSON 配置数据
    private var cachedCapabilities: RegionCapabilities?
    
    #if DEBUG
    /// 单元测试专用：手动注入区域能力配置以供环境感知测试
    public func injectCapabilities(_ capabilities: RegionCapabilities) {
        self.cachedCapabilities = capabilities
    }
    #endif
    
    private init() {
        loadCapabilities()
    }
    
    /// 载入本地打包的 region_capabilities.json 映射规则
    public func loadCapabilities() {
        guard let url = Bundle.main.url(forResource: AuthRegionSpec.capabilitiesFileName, withExtension: AuthRegionSpec.capabilitiesFileExtension) else {
            return
        }
        do {
            let data = try Data(contentsOf: url)
            self.cachedCapabilities = try JSONDecoder().decode(RegionCapabilities.self, from: data)
        } catch {
            // 发生异常时进行静默降级处理，不影响程序后续的判定流程
        }
    }
    
    /// 根据多维度设备及系统特征智能探测推荐默认的登录认证区域
    /// - Returns: 返回探测匹配后的最契合服务区类型
    public func detectDefaultRegion() -> AuthRegion {
        var isoCode: String?
        
        // 1. 第一优先级：判断 SIM 卡载波国家码 (SIM ISO)，已废弃无替代，跳过
        
        // 2. 第二优先级：若无 SIM 信息，检查设备 Locale 区域码 (如 CN、US 等)
        if isoCode == nil {
            if #available(iOS 16.0, macOS 14.0, *) {
                isoCode = Locale.current.region?.identifier.uppercased()
            } else {
                isoCode = Locale.current.regionCode?.uppercased()
            }
        }
        
        // 3. 第三优先级：检查当前时区，兜底判断是否为非中国区时区
        let timeZone = TimeZone.current
        let isChinaTimeZone = AuthRegionSpec.chinaTimeZoneIdentifiers.contains { timeZone.identifier.contains($0) }

        // 合并提取出来的检测目标 ISO 国家码，若依然不存在则根据时区关系做兜底判断
        let targetCode = isoCode ?? (isChinaTimeZone ? AuthRegionSpec.chinaISOCode : AuthRegionSpec.usISOCode)

        // 4. 读取 JSON 配置，匹配具体的区域信息
        if let capabilities = cachedCapabilities, let info = capabilities.regions[targetCode] {
            return info.loginPageType == AuthRegionSpec.localizedLoginPageType ? .china : .international
        }

        // 5. 无法直接匹配时，尝试匹配 JSON 中声明的 default 兜底项
        if let capabilities = cachedCapabilities, let defaultInfo = capabilities.regions[AuthRegionSpec.defaultRegionKey] {
            return defaultInfo.loginPageType == AuthRegionSpec.localizedLoginPageType ? .china : .international
        }
        
        // 极度异常环境下的硬编码硬兜底：为了保证现有系统零退化，默认返回中国区
        return .china
    }
}
