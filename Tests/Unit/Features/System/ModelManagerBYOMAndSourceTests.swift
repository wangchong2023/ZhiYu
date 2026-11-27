//
//  ModelManagerBYOMAndSourceTests.swift
//  ZhiYuTests
//
//  系统层级：[L3] 测试层
//  核心职责：以发现真实缺陷为目标，端到端验证 BYOM 持久化（跨重启不丢失）、坏/空文件强拦截与脏副本回滚、
//           魔搭/HuggingFace 双源路由与严格按域名隔离鉴权令牌（防跨域泄漏）、Thinking 流式边界解析及白名单防回归。
//

import XCTest
import Security
import UFPCore
@testable import ZhiYuUnitTestHost

@MainActor
final class ModelManagerBYOMAndSourceTests: XCTestCase {
    private var manager: GlobalModelManager!
    private var createdTempURLs: [URL] = []
    private var importedModelIds: [String] = []

    override func setUp() async throws {
        try await super.setUp()
        resetPersistentTestState()
        setupFullMockEnvironment()
        manager = GlobalModelManager()
        manager.clearHuggingFaceToken()
        manager.clearModelScopeToken()
        manager.downloadSourcePreference = .auto
    }

    override func tearDown() async throws {
        for modelId in importedModelIds {
            manager.clearModelCache(for: modelId)
        }
        for url in createdTempURLs {
            try? FileManager.default.removeItem(at: url)
        }
        manager.clearHuggingFaceToken()
        manager.clearModelScopeToken()
        manager.downloadSourcePreference = .auto
        importedModelIds.removeAll()
        createdTempURLs.removeAll()
        resetPersistentTestState()
        manager = nil
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - 1. BYOM 跨重启持久化与清理闭环（防重启后自定义模型消失）

    func testImportCustomModelPersistsAcrossManagerReloadAndRemovesCleanly() async throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PersistEdge_\(UUID().uuidString).gguf")
        var payload = Data("GGUF".utf8)
        payload.append(Data(repeating: 0xAB, count: 40_960))
        try payload.write(to: tempURL)
        createdTempURLs.append(tempURL)

        let manifest = try manager.importCustomModel(from: tempURL)
        importedModelIds.append(manifest.modelId)

        // 保留原始 .gguf 扩展名（不再强转为 .bin）
        let resolvedURL = try XCTUnwrap(manager.getLocalModelURL(for: manifest.modelId))
        XCTAssertEqual(resolvedURL.pathExtension.lowercased(), "gguf", "BYOM 导入必须保留原始 .gguf 扩展名")

        // 模拟 App 重启：重建 GlobalModelManager 并触发 reload()
        let restartedManager = GlobalModelManager()
        restartedManager.reset()
        await restartedManager.reload()

        XCTAssertTrue(
            restartedManager.remoteManifests.contains(where: { $0.modelId == manifest.modelId }),
            "BYOM 导入的模型必须在重启 reload 后依然保留在清单中"
        )
        XCTAssertTrue(restartedManager.isModelLocalReady(for: manifest.modelId))

        // 显式清理缓存后，物理文件、持久化清单与内存清单均应同步移除
        restartedManager.clearModelCache(for: manifest.modelId)
        let restartedAfterDelete = GlobalModelManager()
        restartedAfterDelete.reset()
        await restartedAfterDelete.reload()
        XCTAssertFalse(
            restartedAfterDelete.remoteManifests.contains(where: { $0.modelId == manifest.modelId }),
            "删除自定义模型后不应在重启时复活"
        )
        XCTAssertFalse(restartedAfterDelete.isModelLocalReady(for: manifest.modelId))
    }

    // MARK: - 2. BYOM 空文件与损坏文件强拦截（防脏副本残留与错误 .completed）

    func testImportCustomModelRejectsEmptyAndCorruptedFilesWithoutLeavingOrphans() throws {
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

        // 2a. 0 字节空文件
        let emptyName = "EmptyBad_\(UUID().uuidString)"
        let emptyURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(emptyName).gguf")
        try Data().write(to: emptyURL)
        createdTempURLs.append(emptyURL)

        XCTAssertThrowsError(try manager.importCustomModel(from: emptyURL)) { error in
            XCTAssertEqual(error as? GlobalModelManager.BYOMImportError, .emptyFile)
        }
        let emptyDest = docDir.appendingPathComponent("custom-\(emptyName.lowercased()).bin")
        XCTAssertFalse(FileManager.default.fileExists(atPath: emptyDest.path), "导入空文件失败后不得残留孤儿 .bin")

        // 2b. 随机垃圾字节伪装为 .gguf
        let corruptName = "CorruptBad_\(UUID().uuidString)"
        let corruptURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(corruptName).gguf")
        try Data("NOT_A_VALID_MODEL_BINARY_HEADER_XXXX".utf8).write(to: corruptURL)
        createdTempURLs.append(corruptURL)

        let initialCount = manager.remoteManifests.count
        XCTAssertThrowsError(try manager.importCustomModel(from: corruptURL)) { error in
            guard case GlobalModelManager.BYOMImportError.corruptedFormat = error else {
                XCTFail("损坏文件应抛出 BYOMImportError.corruptedFormat，实际为 \(error)")
                return
            }
        }
        let corruptDest = docDir.appendingPathComponent("custom-\(corruptName.lowercased()).bin")
        XCTAssertFalse(FileManager.default.fileExists(atPath: corruptDest.path), "导入损坏文件失败后不得残留脏副本")
        XCTAssertEqual(manager.remoteManifests.count, initialCount, "导入失败不得污染 remoteManifests")
        XCTAssertFalse(manager.isModelLocalReady(for: "custom-\(corruptName.lowercased())"))
    }

    // MARK: - 3. 双源路由选择与严格域名隔离防 Token 跨域泄漏

    func testDownloadRouteSelectionAndStrictHostScopedTokenIsolation() throws {
        let manifest = LLMManifest(
            modelId: "gemma-4-e2b-it",
            displayName: "Gemma 4 E2B",
            vendor: "Google",
            fileSizeInBytes: 1024,
            minDeviceMemoryInGb: 4.0,
            remoteURLString: "https://huggingface.co/google/gemma-4-E2B-it/resolve/main/model.litertlm",
            sha256Checksum: "",
            parameterCount: "2B",
            supportedTasks: ["chat", "multimodal"],
            description: "test",
            defaultParameters: InferenceParameters(temperature: 0.7, topP: 0.9, topK: 40, maxTokens: 2048),
            huggingfaceURLString: "https://huggingface.co/google/gemma-4-E2B-it/resolve/main/model.litertlm",
            modelscopeURLString: "https://modelscope.cn/models/LLM-Research/gemma-4-E2B-it/resolve/master/model.litertlm"
        )

        // 自动模式：国内优先魔搭，海外优先 HuggingFace
        manager.downloadSourcePreference = .auto
        let cnRoute = try XCTUnwrap(manager.resolveDownloadRoute(for: manifest, isChinaRegionOverride: true))
        XCTAssertEqual(cnRoute.primaryURL.host, "modelscope.cn")
        XCTAssertEqual(cnRoute.fallbackURL?.host, "huggingface.co")

        let overseasRoute = try XCTUnwrap(manager.resolveDownloadRoute(for: manifest, isChinaRegionOverride: false))
        XCTAssertEqual(overseasRoute.primaryURL.host, "huggingface.co")
        XCTAssertEqual(overseasRoute.fallbackURL?.host, "modelscope.cn")

        // 强制覆盖模式
        manager.downloadSourcePreference = .modelscope
        let forcedMS = try XCTUnwrap(manager.resolveDownloadRoute(for: manifest, isChinaRegionOverride: false))
        XCTAssertEqual(forcedMS.primaryURL.host, "modelscope.cn")

        manager.downloadSourcePreference = .huggingface
        let forcedHF = try XCTUnwrap(manager.resolveDownloadRoute(for: manifest, isChinaRegionOverride: true))
        XCTAssertEqual(forcedHF.primaryURL.host, "huggingface.co")

        // 安全防泄漏：双令牌同时存在时，仅匹配域名才附带对应 Token，严禁跨域泄漏或被伪造子域名欺骗
        manager.saveModelScopeToken("  ms_secret_001  ")
        manager.saveHuggingFaceToken("  hf_secret_002  ")

        XCTAssertEqual(manager.authorizationHeader(for: cnRoute.primaryURL), "Bearer ms_secret_001")
        XCTAssertEqual(manager.authorizationHeader(for: overseasRoute.primaryURL), "Bearer hf_secret_002")

        let spoofedMS = try XCTUnwrap(URL(string: "https://modelscope.cn.evil.com/model.bin"))
        let spoofedHF = try XCTUnwrap(URL(string: "https://huggingface.co.attacker.io/model.bin"))
        let localFile = URL(fileURLWithPath: "/tmp/model.bin")
        XCTAssertNil(manager.authorizationHeader(for: spoofedMS), "伪造后缀域名绝不能拿到魔搭 Token")
        XCTAssertNil(manager.authorizationHeader(for: spoofedHF), "伪造后缀域名绝不能拿到 HF Token")
        XCTAssertNil(manager.authorizationHeader(for: localFile), "本地文件 URL 不得附带任何鉴权头")

        // 保存纯空白应自动清除而非写入空字符串
        manager.saveModelScopeToken("   \n  ")
        XCTAssertNil(manager.authorizationHeader(for: cnRoute.primaryURL))
        XCTAssertEqual(manager.authorizationHeader(for: overseasRoute.primaryURL), "Bearer hf_secret_002")
    }

    // MARK: - 4. Thinking Mode 流式与多标签边界解析

    func testThinkingContentParserHandlesThoughtTagsStreamingUnclosedAndMultipleBlocks() {
        // 4a. Gemma 4 <thought> 闭合标签
        let gemma = ThinkingContentParser.parse(rawText: "<thought>Step 1\nStep 2</thought>Final Answer")
        XCTAssertEqual(gemma.thinkingText, "Step 1\nStep 2")
        XCTAssertEqual(gemma.answerText, "Final Answer")

        // 4b. 流式半闭合（尚未收到 </thought>）
        let streaming = ThinkingContentParser.parse(rawText: "<thought>Analyzing...")
        XCTAssertEqual(streaming.thinkingText, "Analyzing...")
        XCTAssertEqual(streaming.answerText, "")

        // 4c. 仅空白内容的半闭合标签不应渲染空思考框
        let blankStreaming = ThinkingContentParser.parse(rawText: "<think>   \n  ")
        XCTAssertNil(blankStreaming.thinkingText)
        XCTAssertEqual(blankStreaming.answerText, "")

        // 4d. 空闭合标签应被剥离，保留干净正文
        let emptyClosed = ThinkingContentParser.parse(rawText: "<thought>  </thought>Clean body")
        XCTAssertNil(emptyClosed.thinkingText)
        XCTAssertEqual(emptyClosed.answerText, "Clean body")

        // 4e. 多段混合标签 + 前置正文不得丢失
        let multi = ThinkingContentParser.parse(rawText: "Intro <think>A</think> Mid <THOUGHT>B</THOUGHT> End")
        XCTAssertEqual(multi.thinkingText, "A\n\nB")
        XCTAssertEqual(multi.answerText, "Intro  Mid  End")
    }

    // MARK: - 5. 8 款模型白名单完整度与防链接错配回归

    func testAllowlistManifestsContainEightModelsWithoutMisconfiguredQwenLinks() async throws {
        let manifests = try await RemoteConfigService.shared.fetchLLMManifests()
        let ids = Set(manifests.map(\.modelId))

        XCTAssertGreaterThanOrEqual(manifests.count, 8, "白名单应包含 8 款全生态端侧模型")
        XCTAssertTrue(ids.contains("gemma-4-e2b-it"))
        XCTAssertTrue(ids.contains("gemma-4-e4b-it"))
        XCTAssertTrue(ids.contains("embeddinggemma-2-740m"))
        XCTAssertTrue(ids.contains("functiongemma-270m-it"))
        XCTAssertTrue(ids.contains("qwen2.5-1.5b-instruct"))
        XCTAssertTrue(ids.contains("smollm2-360m-instruct"))

        for manifest in manifests where manifest.modelId.hasPrefix("gemma-") {
            XCTAssertFalse(
                manifest.remoteURLString.contains("Qwen2.5-0.5B"),
                "\(manifest.modelId) 下载链接不得错指 Qwen2.5-0.5B"
            )
            XCTAssertTrue(
                manifest.supportedTasks.contains("multimodal"),
                "\(manifest.modelId) 应声明 multimodal 能力"
            )
        }
    }

    // MARK: - 6. RemoteConfigService 白名单解析与损坏载荷容错

    func testRemoteConfigParsesAllowlistAndHandlesMalformedPayloadsSafely() {
        let service = RemoteConfigService()

        let validJSON = """
        {
          "models": [
            {
              "modelId": "gemma-4-e2b-it",
              "displayName": "Gemma 4 E2B",
              "vendor": "Google",
              "fileSizeInBytes": 1024,
              "minDeviceMemoryInGb": 4.0,
              "remoteURLString": "https://huggingface.co/google/gemma-4-E2B-it/resolve/main/model.litertlm"
            },
            {
              "displayName": "Missing ModelId Should Be Skipped"
            }
          ]
        }
        """
        let parsed = service.parseAllowlistManifests(from: Data(validJSON.utf8))
        XCTAssertEqual(parsed.count, 1, "缺必填字段的条目应被安全跳过，只保留合法模型")
        XCTAssertEqual(parsed.first?.modelId, "gemma-4-e2b-it")

        let corrupted = service.parseAllowlistManifests(from: Data("{not valid json".utf8))
        XCTAssertTrue(corrupted.isEmpty, "损坏 JSON 不得崩溃，应返回空数组触发本地兜底")
    }

    // MARK: - 7. ModelBenchmarkRunner 真实硬件压测路径（零模拟睡眠）

    func testBenchmarkRunnerHardwareExecutorMeasuresRealMetricsWithoutSimulation() async {
        actor InvocationCounter {
            private(set) var count: Int = 0
            func increment() { count += 1 }
        }
        let runner = ModelBenchmarkRunner()
        let counter = InvocationCounter()

        let result = await runner.runBenchmark(
            modelId: "gemma-4-e2b-it",
            rounds: 2,
            inferenceExecutor: { _ in
                await counter.increment()
                return String(repeating: "token ", count: 40)
            }
        )

        let totalCalls = await counter.count
        XCTAssertFalse(result.isSimulated, "传入真实推理执行器时 isSimulated 必须为 false")
        XCTAssertEqual(result.completedRounds, 2)
        XCTAssertEqual(result.totalRounds, 2)
        XCTAssertEqual(totalCalls, 2, "2 轮压测必须真实调用推理执行器 2 次")
        XCTAssertGreaterThan(result.decodeTPS, 0.0)
        XCTAssertGreaterThanOrEqual(result.ttftMilliseconds, 0.0)
    }

    // MARK: - 8. BYOM 同路径原地重复导入保护（防先删后拷自毁源文件）

    func testImportCustomModelSamePathInDocumentsDoesNotDestroySourceFile() throws {
        let fm = FileManager.default
        let docDir = fm.urls(for: .documentDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
        let modelId = "custom-samepath-\(UUID().uuidString.lowercased())"
        let inPlaceURL = docDir.appendingPathComponent("\(modelId).gguf")

        var payload = Data("GGUF".utf8)
        payload.append(Data(repeating: 0xCD, count: 40_960))
        try payload.write(to: inPlaceURL)
        createdTempURLs.append(inPlaceURL)
        importedModelIds.append(modelId)

        let manifest = try manager.importCustomModel(from: inPlaceURL)
        XCTAssertEqual(manifest.modelId, modelId)
        XCTAssertTrue(fm.fileExists(atPath: inPlaceURL.path), "原地重复导入不得删除源文件本身")
        XCTAssertEqual(try Data(contentsOf: inPlaceURL).count, payload.count, "原地重复导入后源文件内容必须完整保留")
    }
}
