//
//  ModelManagerViewSnapshots.swift
//  ZhiYu
//
//  系统层级：[Shared] 测试层
//  核心职责：大模型卡片快照测试，覆盖选中/未选中、下载状态与硬件护栏展示。
//

import XCTest
import SwiftUI
import SnapshotTesting
import UFPCore
@testable import ZhiYu

@MainActor
final class ModelManagerViewSnapshots: XCTestCase {

    /// 依据环境变量判断快照录制策略
    private static var recordMode: SnapshotTestingConfiguration.Record {
        ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] == "1" ? .all : .missing
    }

    override func invokeTest() {
        withSnapshotTesting(record: Self.recordMode) {
            super.invokeTest()
        }
    }

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 测试数据工厂

    /// 构造测试用 LLMManifest
    private func makeManifest(
        modelId: String = "gemma-2b-it",
        displayName: String = "Gemma-2-2B-IT",
        parameterCount: String = "2B",
        minDeviceMemoryInGb: Double = 6.0
    ) -> LLMManifest {
        LLMManifest(
            modelId: modelId,
            displayName: displayName,
            vendor: "Google",
            fileSizeInBytes: 1_600_000_000,
            minDeviceMemoryInGb: minDeviceMemoryInGb,
            remoteURLString: "https://example.com/model.gguf",
            sha256Checksum: "abc123",
            parameterCount: parameterCount,
            supportedTasks: ["TextSynthesis", "PageTagging"],
            description: "轻量级端侧大模型",
            defaultParameters: InferenceParameters()
        )
    }

    /// 构造 ModelCardView，注入所需环境依赖
    private func makeModelCardView(
        manifest: LLMManifest,
        alertManifest: Binding<LLMManifest?> = .constant(nil),
        expandedModelId: Binding<String?> = .constant(nil)
    ) -> some View {
        ModelCardView(
            manifest: manifest,
            modelManager: GlobalModelManager.shared,
            alertManifest: alertManifest,
            expandedModelId: expandedModelId,
            onGoToLab: {}
        )
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth)
    }

    // MARK: - ModelCardView 快照测试

    /// 测试模型卡片 — 默认折叠状态
    func testModelCardView_Collapsed() {
        let view = makeModelCardView(manifest: makeManifest())
        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: 200)))
    }

    /// 测试模型卡片 — 展开状态
    func testModelCardView_Expanded() {
        let manifest = makeManifest()
        let view = makeModelCardView(
            manifest: manifest,
            expandedModelId: .constant(manifest.modelId)
        )
        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: 500)))
    }

    /// 测试模型卡片 — 大参数模型（8B）
    func testModelCardView_LargeModel() {
        let view = makeModelCardView(manifest: makeManifest(
            modelId: "llama3-8b-instruct",
            displayName: "Llama-3-8B-Instruct",
            parameterCount: "8B",
            minDeviceMemoryInGb: 12.0
        ))
        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: 200)))
    }
}
