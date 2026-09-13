//
//  DeviceHardwareGuardTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/29.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 DeviceHardwareGuard 开展自动化单元测试验证。
//
import XCTest
@testable import ZhiYu

final class DeviceHardwareGuardTests: XCTestCase {
    
    // 物理内存常量规约 (以字节为单位)
    private let sixGbBytes: UInt64 = 6 * 1024 * 1024 * 1024
    private let eightGbBytes: UInt64 = 8 * 1024 * 1024 * 1024
    private let twelveGbBytes: UInt64 = 12 * 1024 * 1024 * 1024
    private let sixteenGbBytes: UInt64 = 16 * 1024 * 1024 * 1024
    
    // 示例模型清单 (Gemma-2B: 要求 6GB | Llama-3-8B: 要求 12GB)
    private var gemmaManifest: LLMManifest!
    private var llamaManifest: LLMManifest!
    
    override func setUp() {
        super.setUp()
        
        let dummyParams = InferenceParameters()
        
        gemmaManifest = LLMManifest(
            modelId: "gemma-2b-it",
            displayName: "Gemma-2B",
            vendor: "Google",
            fileSizeInBytes: 1530000000,
            minDeviceMemoryInGb: 6.0, // 要求最低 6.0 GB 运存
            remoteURLString: "https://cdn.test.com/gemma.bin",
            sha256Checksum: "checksum_gemma",
            parameterCount: "2B",
            description: "Test Gemma",
            defaultParameters: dummyParams
        )
        
        llamaManifest = LLMManifest(
            modelId: "llama3-8b-instruct",
            displayName: "Llama-3-8B",
            vendor: "Meta",
            fileSizeInBytes: 4610000000,
            minDeviceMemoryInGb: 12.0, // 要求最低 12.0 GB 运存
            remoteURLString: "https://cdn.test.com/llama.bin",
            sha256Checksum: "checksum_llama",
            parameterCount: "8B",
            description: "Test Llama",
            defaultParameters: dummyParams
        )
    }
    
    override func tearDown() {
        gemmaManifest = nil
        llamaManifest = nil
        super.tearDown()
    }
    
    // MARK: - 1. 测试 Gemma-2B (要求 6GB) 兼容等级
    
    /// 当设备内存处于 8GB 充裕状态下，Gemma-2B 应被判定为 supported (完美支持)
    func testGemmaOnEightGbDeviceShouldBeSupported() {
        let guardEvaluator = DeviceHardwareGuard(physicalMemory: eightGbBytes)
        let eligibility = guardEvaluator.evaluateEligibility(for: gemmaManifest)
        
        XCTAssertEqual(eligibility, .supported, "在 8GB 运存设备上运行 Gemma-2B，判定结果应为 supported。")
    }
    
    /// 当设备内存处于临界 6GB 状态下 (临界区)，Gemma-2B 应被判定为 warning (警戒警告)
    func testGemmaOnSixGbDeviceShouldBeWarning() {
        let guardEvaluator = DeviceHardwareGuard(physicalMemory: sixGbBytes)
        let eligibility = guardEvaluator.evaluateEligibility(for: gemmaManifest)
        
        XCTAssertEqual(eligibility, .warning, "在 6GB 运存设备上运行 Gemma-2B，因刚好处于临界线，应判定为 warning。")
    }
    
    // MARK: - 2. 测试 Llama-3-8B (要求 12GB) 兼容等级
    
    /// 当设备运存仅为 8GB 时 (远低于所需的 12GB 内存硬限)，Llama-3-8B 应被判定为 restricted (强力强限制禁用)
    func testLlamaOnEightGbDeviceShouldBeRestricted() {
        let guardEvaluator = DeviceHardwareGuard(physicalMemory: eightGbBytes)
        let eligibility = guardEvaluator.evaluateEligibility(for: llamaManifest)
        
        XCTAssertEqual(eligibility, .restricted, "在 8GB 运存设备上强行加载要求 12GB 的 Llama-8B，应直接触发 restricted 物理阻断。")
    }
    
    /// 当设备运存为 12GB 临界状态下，Llama-3-8B 应判定为 warning
    func testLlamaOnTwelveGbDeviceShouldBeWarning() {
        let guardEvaluator = DeviceHardwareGuard(physicalMemory: twelveGbBytes)
        let eligibility = guardEvaluator.evaluateEligibility(for: llamaManifest)
        
        XCTAssertEqual(eligibility, .warning, "在 12GB 运存设备上运行 Llama-8B，因刚好压线，应判定为 warning。")
    }
    
    /// 当设备运存充沛至 16GB (Mac / M系列)，Llama-3-8B 应被判定为 supported
    func testLlamaOnSixteenGbDeviceShouldBeSupported() {
        let guardEvaluator = DeviceHardwareGuard(physicalMemory: sixteenGbBytes)
        let eligibility = guardEvaluator.evaluateEligibility(for: llamaManifest)
        
        XCTAssertEqual(eligibility, .supported, "在 16GB 高内存设备上运行 Llama-8B，物理内存极度宽裕，应判定为 supported。")
    }
    
    // MARK: - 3. 批量兼容判定评估测试
    
    /// 测试对模型白名单列表进行批量匹配计算
    func testBatchEligibilityEvaluation() {
        let guardEvaluator = DeviceHardwareGuard(physicalMemory: eightGbBytes)
        // swiftlint:disable:next force_unwrapping
        let batchManifests = [gemmaManifest!, llamaManifest!]
        
        let batchResult = guardEvaluator.batchEvaluateEligibility(for: batchManifests)
        
        XCTAssertEqual(batchResult["gemma-2b-it"], .supported)
        XCTAssertEqual(batchResult["llama3-8b-instruct"], .restricted)
    }
}
