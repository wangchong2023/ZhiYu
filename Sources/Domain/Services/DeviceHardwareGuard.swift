//
//  DeviceHardwareGuard.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/29.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层
//  核心职责：本地物理硬件评估评估器。负责读取设备的真实物理内存，并对大模型清单进行内存拦截与置灰判定，防范端侧 OOM 强杀。
//

import Foundation

/// 硬件兼容性评估评估状态
public enum DeviceEligibility: String, Codable, Sendable, Equatable {
    /// 完美兼容，设备内存充沛
    case supported
    
    /// 边界警告，可以勉强加载，但有发生 OOM 的中高风险，应给予 UI 警告弹窗
    case warning
    
    /// 强力限制运行，设备内存极度匮乏，强行装载必被系统闪退强杀，必须在 UI 屏蔽/禁用
    case restricted
}

/// 物理硬件护栏评估评估服务
public final class DeviceHardwareGuard: Sendable {
    
    /// 线程安全的物理内存读取缓存
    private let totalPhysicalMemory: UInt64
    
    public init(physicalMemory: UInt64 = ProcessInfo.processInfo.physicalMemory) {
        self.totalPhysicalMemory = physicalMemory
    }
    
    /// 获取以 GB 为单位的设备真实物理内存大小
    public var physicalMemoryInGb: Double {
        return Double(totalPhysicalMemory) / SystemConstants.bytesPerGB
    }
    
    /// 针对特定大模型 Manifest 评定其硬件兼容性等级
    /// - Parameter manifest: 大模型 Manifest 清单结构
    /// - Returns: 兼容评估结果等级
    public func evaluateEligibility(for manifest: LLMManifest) -> DeviceEligibility {
        let availableMemoryGb = physicalMemoryInGb
        let requiredMemoryGb = manifest.minDeviceMemoryInGb
        
        // 1. 内存严重不足以加载该模型
        if availableMemoryGb < requiredMemoryGb - 1.0 {
            return .restricted
        }
        
        // 2. 内存处于临界警戒线 (相差小于 1GB)
        if availableMemoryGb >= requiredMemoryGb - 1.0 && availableMemoryGb < requiredMemoryGb + 1.0 {
            return .warning
        }
        
        // 3. 内存充裕，高枕无忧
        return .supported
    }
    
    /// 过滤并标记模型列表的硬件适配情况
    /// - Parameter manifests: 模型白名单列表
    /// - Returns: 一个包含了模型与其对应物理适配级别的字典映射表
    public func batchEvaluateEligibility(for manifests: [LLMManifest]) -> [String: DeviceEligibility] {
        var eligibilityMap: [String: DeviceEligibility] = [:]
        for manifest in manifests {
            eligibilityMap[manifest.modelId] = evaluateEligibility(for: manifest)
        }
        return eligibilityMap
    }
}
