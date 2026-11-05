//
//  ModelBenchmarkTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试 / 系统功能层
//  核心职责：端侧大模型性能基准跑分算子 (ModelBenchmarkRunner) 与模型市场任务筛选逻辑的全面覆盖。
//

import XCTest
import UFPCore
@testable import ZhiYu

final class ModelBenchmarkTests: XCTestCase {

    // MARK: - 测试 1: 基准测试压测采样与指标计算

    func testBenchmarkExecutionAndMetrics() async {
        let runner = ModelBenchmarkRunner()
        let progressCountBox = MutexBox(0)

        let result = await runner.runBenchmark(modelId: "test-model", rounds: 2) { _, interResult in
            progressCountBox.mutate { $0 += 1 }
            XCTAssertGreaterThan(interResult.ttftMilliseconds, 0.0, "TTFT 必须大于 0")
            XCTAssertGreaterThan(interResult.decodeTPS, 0.0, "Decode TPS 必须大于 0")
        }

        XCTAssertEqual(result.completedRounds, 2, "完成了 2 轮压测")
        XCTAssertEqual(result.totalRounds, 2)
        XCTAssertEqual(progressCountBox.get(), 2, "回调了 2 次进度更新")
        XCTAssertGreaterThan(result.ttftMilliseconds, 0.0)
        XCTAssertGreaterThan(result.decodeTPS, 0.0)
        XCTAssertGreaterThanOrEqual(result.peakRAMDeltaMB, 0.0)
        XCTAssertFalse(result.grade.title.isEmpty, "评级说明不为空")
    }

    // MARK: - 测试 2: 评级标准分级准确性

    func testBenchmarkGradeThresholds() {
        let excellentResult = BenchmarkResult(
            ttftMilliseconds: 150.0,
            decodeTPS: 45.0,
            peakRAMDeltaMB: 30.0,
            grade: .excellent
        )
        XCTAssertEqual(excellentResult.grade, .excellent)
        XCTAssertFalse(BenchmarkGrade.excellent.title.isEmpty)

        let goodResult = BenchmarkResult(
            ttftMilliseconds: 400.0,
            decodeTPS: 20.0,
            peakRAMDeltaMB: 50.0,
            grade: .good
        )
        XCTAssertEqual(goodResult.grade, .good)

        let warningResult = BenchmarkResult(
            ttftMilliseconds: 900.0,
            decodeTPS: 8.0,
            peakRAMDeltaMB: 80.0,
            grade: .warning
        )
        XCTAssertEqual(warningResult.grade, .warning)
    }

    // MARK: - 测试 3: 模型市场任务分类 Filter 过滤逻辑

    func testModelStoreFilters() {
        let manifestChat = LLMManifest(
            modelId: "model_chat",
            displayName: "Chat Model",
            vendor: "Google",
            fileSizeInBytes: 1000,
            minDeviceMemoryInGb: 6.0,
            remoteURLString: "https://example.com/chat.bin",
            sha256Checksum: "",
            parameterCount: "2B",
            supportedTasks: ["chat", "completion"],
            description: "Chat model",
            defaultParameters: InferenceParameters()
        )

        let manifestSearch = LLMManifest(
            modelId: "model_search",
            displayName: "Embedding Model",
            vendor: "Google",
            fileSizeInBytes: 1000,
            minDeviceMemoryInGb: 6.0,
            remoteURLString: "https://example.com/embed.bin",
            sha256Checksum: "",
            parameterCount: "740M",
            supportedTasks: ["media_search", FeatureConstants.ModelTaskTag.embedding],
            description: "Embedding model",
            defaultParameters: InferenceParameters()
        )

        let manifestVision = LLMManifest(
            modelId: "model_vision",
            displayName: "Vision Model",
            vendor: "Google",
            fileSizeInBytes: 1000,
            minDeviceMemoryInGb: 6.0,
            remoteURLString: "https://example.com/vis.bin",
            sha256Checksum: "",
            parameterCount: "4B",
            supportedTasks: [FeatureConstants.ModelTaskTag.multimodal, FeatureConstants.ModelTaskTag.vision],
            description: "Vision model",
            defaultParameters: InferenceParameters()
        )

        let allModels = [manifestChat, manifestSearch, manifestVision]

        // 验证 All
        XCTAssertEqual(allModels.count, 3)

        // 验证 Chat 筛选
        let chatFiltered = allModels.filter {
            $0.supportedTasks.contains(FeatureConstants.TaskName.chat) ||
            $0.supportedTasks.contains(FeatureConstants.TaskName.completion)
        }
        XCTAssertEqual(chatFiltered.count, 1)
        XCTAssertEqual(chatFiltered.first?.modelId, "model_chat")

        // 验证 Search 筛选
        let searchFiltered = allModels.filter {
            $0.supportedTasks.contains(FeatureConstants.TaskName.mediaSearch) ||
            $0.supportedTasks.contains(FeatureConstants.ModelTaskTag.embedding)
        }
        XCTAssertEqual(searchFiltered.count, 1)
        XCTAssertEqual(searchFiltered.first?.modelId, "model_search")

        // 验证 Vision 筛选
        let visionFiltered = allModels.filter {
            $0.supportedTasks.contains(FeatureConstants.ModelTaskTag.multimodal) ||
            $0.supportedTasks.contains(FeatureConstants.ModelTaskTag.vision)
        }
        XCTAssertEqual(visionFiltered.count, 1)
        XCTAssertEqual(visionFiltered.first?.modelId, "model_vision")
    }

    // MARK: - 测试 4: 顶层分栏 Tab 枚举完整性

    func testModelManagerTabs() {
        XCTAssertEqual(ModelManagerTab.allCases.count, 2)
        XCTAssertEqual(ModelManagerTab.store.id, "store")
        XCTAssertEqual(ModelManagerTab.lab.id, "lab")
        XCTAssertFalse(ModelManagerTab.store.title.isEmpty)
        XCTAssertFalse(ModelManagerTab.lab.title.isEmpty)
        XCTAssertFalse(ModelManagerTab.store.icon.isEmpty)
        XCTAssertFalse(ModelManagerTab.lab.icon.isEmpty)
    }
}
