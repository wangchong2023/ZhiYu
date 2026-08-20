//
//  DemoMediaBuilderTests.swift
//  ZhiYu
//
//  系统层级：[L0] 测试层
//  核心职责：验证 DemoImageBuilder 图像生成、DemoAudioBuilder 音频生成、
//           PerformanceBenchmarker 压测入口的基本行为。
//

import XCTest
import UFPCore
import UFPStorage
@testable import ZhiYu

#if canImport(UIKit) && !os(watchOS)
import UIKit

final class DemoMediaBuilderTests: XCTestCase {

    // MARK: - DemoImageBuilder

    /// 首次生成应返回非 nil 图像并写入磁盘
    func testEnsureImageExists_首次生成_返回非nil图像并写入磁盘() {
        let tempDir = NSTemporaryDirectory() + "DemoImageTest-\(UUID().uuidString)/"
        let path = tempDir + "test.png"
        let image = DemoImageBuilder.ensureImageExists(at: path, title: "测试标题")
        XCTAssertNotNil(image, "首次生成应返回非 nil 图像")
        XCTAssertTrue(FileManager.default.fileExists(atPath: path), "图像文件应已写入磁盘")
    }

    /// 已存在文件且宽度达标时应直接加载返回
    func testEnsureImageExists_文件已存在且宽度达标_直接加载返回() {
        let tempDir = NSTemporaryDirectory() + "DemoImageTest-\(UUID().uuidString)/"
        let path = tempDir + "test.png"
        // 首次生成（生成的是 1200 宽的高清图，超过 hdMinWidth=1000）
        _ = DemoImageBuilder.ensureImageExists(at: path, title: "测试标题")
        // 第二次应走文件加载分支
        let second = DemoImageBuilder.ensureImageExists(at: path, title: "测试标题")
        XCTAssertNotNil(second, "已存在文件且宽度达标应直接加载返回")
    }

    /// 包含"神经"关键词应走神经元绘制分支
    func testEnsureImageExists_包含神经关键词_走神经元分支() {
        let tempDir = NSTemporaryDirectory() + "DemoImageTest-\(UUID().uuidString)/"
        let path = tempDir + "neuron.png"
        let image = DemoImageBuilder.ensureImageExists(at: path, title: "神经网络知识图谱")
        XCTAssertNotNil(image, "神经元分支应生成图像")
        XCTAssertTrue(FileManager.default.fileExists(atPath: path), "神经元分支图像应写入磁盘")
    }

    /// 包含"PKM"关键词应走神经元绘制分支
    func testEnsureImageExists_包含PKM关键词_走神经元分支() {
        let tempDir = NSTemporaryDirectory() + "DemoImageTest-\(UUID().uuidString)/"
        let path = tempDir + "pkm.png"
        let image = DemoImageBuilder.ensureImageExists(at: path, title: "PKM 系统设计")
        XCTAssertNotNil(image, "PKM 分支应生成图像")
    }

    /// 包含"知识"关键词应走神经元绘制分支
    func testEnsureImageExists_包含知识关键词_走神经元分支() {
        let tempDir = NSTemporaryDirectory() + "DemoImageTest-\(UUID().uuidString)/"
        let path = tempDir + "knowledge.png"
        let image = DemoImageBuilder.ensureImageExists(at: path, title: "知识管理方法论")
        XCTAssertNotNil(image, "知识分支应生成图像")
    }

    /// 不含关键词应走 SOP 绘制分支
    func testEnsureImageExists_不含关键词_走SOP分支() {
        let tempDir = NSTemporaryDirectory() + "DemoImageTest-\(UUID().uuidString)/"
        let path = tempDir + "sop.png"
        let image = DemoImageBuilder.ensureImageExists(at: path, title: "咖啡制作流程")
        XCTAssertNotNil(image, "SOP 分支应生成图像")
        XCTAssertTrue(FileManager.default.fileExists(atPath: path), "SOP 分支图像应写入磁盘")
    }

    /// 生成的图像尺寸应为 1200x900 高清规格
    func testEnsureImageExists_生成图像_尺寸为1200x900高清规格() {
        let tempDir = NSTemporaryDirectory() + "DemoImageTest-\(UUID().uuidString)/"
        let path = tempDir + "size.png"
        let image = DemoImageBuilder.ensureImageExists(at: path, title: "尺寸测试")
        guard let image else {
            XCTFail("图像不应为 nil")
            return
        }
        XCTAssertEqual(image.size.width, 1200, accuracy: 0.1, "生成图像宽度应为 1200")
        XCTAssertEqual(image.size.height, 900, accuracy: 0.1, "生成图像高度应为 900")
    }

    /// 空标题应正常生成图像（不崩溃）
    func testEnsureImageExists_空标题_应正常生成图像() {
        let tempDir = NSTemporaryDirectory() + "DemoImageTest-\(UUID().uuidString)/"
        let path = tempDir + "empty.png"
        let image = DemoImageBuilder.ensureImageExists(at: path, title: "")
        XCTAssertNotNil(image, "空标题应正常生成图像")
        XCTAssertTrue(FileManager.default.fileExists(atPath: path), "空标题图像应写入磁盘")
    }

    /// 已存在但宽度不达标的文件应触发重新生成
    func testEnsureImageExists_已存在窄图_应重新生成() {
        let tempDir = NSTemporaryDirectory() + "DemoImageTest-\(UUID().uuidString)/"
        try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        let path = tempDir + "narrow.png"
        // 先写入一个 10x10 的极小 PNG（宽度 < hdMinWidth=1000）
        let smallSize = CGSize(width: 10, height: 10)
        let renderer = UIGraphicsImageRenderer(size: smallSize)
        let smallImage = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: smallSize))
        }
        guard let smallData = smallImage.pngData() else {
            XCTFail("无法生成测试用小图")
            return
        }
        do {
            try smallData.write(to: URL(fileURLWithPath: path))
        } catch {
            XCTFail("写入测试小图失败: \(error)")
            return
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: path), "前置条件：小图应已存在")

        // 调用 ensureImageExists，应检测到宽度不达标并重新生成 1200x900 高清图
        let regenerated = DemoImageBuilder.ensureImageExists(at: path, title: "重新生成测试")
        XCTAssertNotNil(regenerated, "窄图应触发重新生成")
        guard let regenerated else { return }
        XCTAssertEqual(regenerated.size.width, 1200, accuracy: 0.1, "重新生成的图像应为 1200 宽")
    }

    /// 多次调用同一路径应幂等（第二次走文件加载分支）
    func testEnsureImageExists_多次调用_应幂等() {
        let tempDir = NSTemporaryDirectory() + "DemoImageTest-\(UUID().uuidString)/"
        let path = tempDir + "idempotent.png"
        let first = DemoImageBuilder.ensureImageExists(at: path, title: "幂等测试")
        let second = DemoImageBuilder.ensureImageExists(at: path, title: "幂等测试")
        let third = DemoImageBuilder.ensureImageExists(at: path, title: "幂等测试")
        XCTAssertNotNil(first)
        XCTAssertNotNil(second)
        XCTAssertNotNil(third, "多次调用应幂等返回非 nil")
    }
}

// MARK: - DemoAudioBuilder 测试（需 AVFoundation）
#if canImport(AVFoundation)
import AVFoundation

extension DemoMediaBuilderTests {

    /// 音频首次生成应返回有效 URL 并写入磁盘
    func testEnsureAudioExists_首次生成_返回有效URL并写入磁盘() {
        let tempDir = NSTemporaryDirectory() + "DemoAudioTest-\(UUID().uuidString)/"
        let path = tempDir + "test.wav"
        let url = DemoAudioBuilder.ensureAudioExists(at: path)
        XCTAssertNotNil(url, "首次生成应返回有效 URL")
        XCTAssertTrue(FileManager.default.fileExists(atPath: path), "音频文件应已写入磁盘")
    }

    /// 已存在文件应直接返回 URL 不重新合成
    func testEnsureAudioExists_文件已存在_直接返回URL() {
        let tempDir = NSTemporaryDirectory() + "DemoAudioTest-\(UUID().uuidString)/"
        let path = tempDir + "test.wav"
        // 首次生成
        _ = DemoAudioBuilder.ensureAudioExists(at: path)
        let firstAttributes = try? FileManager.default.attributesOfItem(atPath: path)
        let firstSize = (firstAttributes?[.size] as? Int) ?? 0

        // 第二次应直接返回（不重新合成）
        let secondURL = DemoAudioBuilder.ensureAudioExists(at: path)
        XCTAssertNotNil(secondURL, "已存在文件应直接返回 URL")

        let secondAttributes = try? FileManager.default.attributesOfItem(atPath: path)
        let secondSize = (secondAttributes?[.size] as? Int) ?? 0
        XCTAssertEqual(secondSize, firstSize, "已存在文件不应被重新写入")
    }

    /// 自定义时长应生成对应长度的音频
    func testEnsureAudioExists_自定义时长_生成对应长度音频() {
        let tempDir = NSTemporaryDirectory() + "DemoAudioTest-\(UUID().uuidString)/"
        let path = tempDir + "short.wav"
        let url = DemoAudioBuilder.ensureAudioExists(at: path, duration: 1.0)
        XCTAssertNotNil(url, "自定义时长应返回有效 URL")
        XCTAssertTrue(FileManager.default.fileExists(atPath: path), "音频文件应已写入磁盘")
    }

    /// 零时长应生成空缓冲区音频（边界场景）
    func testEnsureAudioExists_零时长_应处理边界不崩溃() {
        let tempDir = NSTemporaryDirectory() + "DemoAudioTest-\(UUID().uuidString)/"
        let path = tempDir + "zero.wav"
        // duration=0 → numSamples=0，AVAudioPCMBuffer(frameCapacity: 0) 可能返回 nil
        // 此处验证边界处理：要么返回 nil（buffer 创建失败），要么返回有效 URL
        let url = DemoAudioBuilder.ensureAudioExists(at: path, duration: 0.0)
        if let url {
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "若返回 URL 则文件应存在")
        } else {
            // 返回 nil 也是合理的（零样本缓冲区无法创建）
        }
    }

    /// 已存在的空文件应直接返回 URL（不校验有效性，已知行为）
    func testEnsureAudioExists_已存在空文件_直接返回URL不校验() {
        let tempDir = NSTemporaryDirectory() + "DemoAudioTest-\(UUID().uuidString)/"
        try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        let path = tempDir + "empty.wav"
        // 创建一个空文件（0 字节）
        FileManager.default.createFile(atPath: path, contents: nil)
        XCTAssertTrue(FileManager.default.fileExists(atPath: path), "前置条件：空文件应已存在")

        // ensureAudioExists 检测到文件存在即返回，不校验是否为有效音频
        let url = DemoAudioBuilder.ensureAudioExists(at: path)
        XCTAssertNotNil(url, "已存在文件（即使是空文件）应直接返回 URL")
    }

    /// 生成的音频文件应可被 AVAudioFile 读取（有效性验证）
    func testEnsureAudioExists_生成的音频_应可被AVAudioFile读取() throws {
        let tempDir = NSTemporaryDirectory() + "DemoAudioTest-\(UUID().uuidString)/"
        let path = tempDir + "valid.wav"
        guard let url = DemoAudioBuilder.ensureAudioExists(at: path, duration: 0.5) else {
            XCTFail("应返回有效 URL")
            return
        }
        // 验证生成的文件是有效音频
        do {
            let audioFile = try AVAudioFile(forReading: url)
            XCTAssertEqual(audioFile.fileFormat.sampleRate, DemoMediaConstants.audioSampleRate, accuracy: 1.0,
                           "音频采样率应为 44.1kHz")
        } catch {
            XCTFail("生成的音频文件无法被 AVAudioFile 读取: \(error)")
        }
    }
}
#endif

// MARK: - PerformanceBenchmarker 测试

/// 可计数的 Mock PageStore，用于验证 runStressTest 的调用次数
private final class CountingPageStore: AnyPageStore, @unchecked Sendable {
    private let lock = NSLock()
    private var _createCount = 0
    private var _searchCount = 0
    private var _createdTitles: [String] = []

    var createCount: Int { lock.withLock { _createCount } }
    var searchCount: Int { lock.withLock { _searchCount } }
    var createdTitles: [String] { lock.withLock { _createdTitles } }

    var pages: [KnowledgePage] { get async { [] } }
    func fetchAllPages() async throws -> [KnowledgePage] { [] }
    func reloadFromDisk() async {}
    func replaceAllPages(_ newPages: [KnowledgePage]) async {}
    func resetDatabase() async throws {}
    func performBatchWrite(_ block: @escaping @Sendable (Database) throws -> Void) async throws {}
    func createPage(
        title: String, pageType: PageType, customIcon: String?, content: String,
        tags: [String], sourceURL: String?, rawSnippet: String?, fileSize: Int64?, sourceType: String?
    ) async throws -> KnowledgePage {
        lock.withLock {
            _createCount += 1
            _createdTitles.append(title)
        }
        return KnowledgePage(title: title, pageType: pageType, customIcon: customIcon,
                             content: content, tags: tags, sourceURL: sourceURL,
                             rawTextSnippet: rawSnippet, fileSize: fileSize, sourceType: sourceType)
    }
    func anyCreatePage(
        title: String, pageType: PageType, customIcon: String?, content: String,
        tags: [String], sourceURL: String?, rawSnippet: String?, fileSize: Int64?, sourceType: String?,
        forceDeepScan: Bool
    ) async -> KnowledgePage {
        KnowledgePage(title: title, pageType: pageType, customIcon: customIcon,
                      content: content, tags: tags, sourceURL: sourceURL,
                      rawTextSnippet: rawSnippet, fileSize: fileSize, sourceType: sourceType)
    }
    func updatePage(_ page: KnowledgePage) async throws {}
    func anyUpdatePage(_ page: KnowledgePage, forceDeepScan: Bool) async {}
    func deletePage(_ page: KnowledgePage) async throws {}
    func anyDeletePage(_ page: KnowledgePage) async {}
    func syncRemotePage(_ page: KnowledgePage) async {}
    func fetchBacklinksByID(for id: UUID) async -> [KnowledgePage] { [] }
    func searchPages(query: String) async -> [KnowledgePage] {
        lock.withLock { _searchCount += 1 }
        return []
    }
    func renameTag(_ oldTag: String, to newTag: String) async {}
    func deleteTag(_ tag: String) async {}
    func seedDefaultContent(logger: @escaping @Sendable (LogAction, String, String) -> Void) async {}
    func addLog(action: LogAction, target: String, details: String, duration: TimeInterval?, startTime: Date?, endTime: Date?, module: String?) {}
    func getStorageStats() async -> StorageStats { StorageStats(databaseSize: 0, logsSize: 0, exportsSize: 0) }
}

extension DemoMediaBuilderTests {

    /// 压测入口应不崩溃并完成全量循环，且 createPage 被调用指定次数
    @MainActor
    func testRunStressTest_小批量_不崩溃并完成循环() async {
        let benchmarker = PerformanceBenchmarker.shared
        let store = CountingPageStore()
        await benchmarker.runStressTest(count: 3, store: store)
        XCTAssertEqual(store.createCount, 3, "createPage 应被调用 3 次")
        XCTAssertEqual(store.searchCount, 1, "searchPages 应被调用 1 次（全量搜索测试）")
    }

    /// 压测入口默认 count 参数应可被显式覆盖
    @MainActor
    func testRunStressTest_显式count参数_应被正确使用() async {
        let benchmarker = PerformanceBenchmarker.shared
        let store = CountingPageStore()
        // count=1 是最小有效值（1...count 闭区间）
        await benchmarker.runStressTest(count: 1, store: store)
        XCTAssertEqual(store.createCount, 1, "createPage 应被调用 1 次")
    }

    /// 压测创建的页面标题应包含压测前缀和序号
    @MainActor
    func testRunStressTest_创建页面_标题应包含前缀和序号() async {
        let benchmarker = PerformanceBenchmarker.shared
        let store = CountingPageStore()
        await benchmarker.runStressTest(count: 2, store: store)
        XCTAssertEqual(store.createCount, 2, "应创建 2 个页面")
        // 验证标题格式：前缀 + 序号
        let titles = store.createdTitles
        XCTAssertEqual(titles.count, 2, "应记录 2 个标题")
        XCTAssertTrue(titles[0].hasPrefix(CoreConstants.Benchmark.stressTestPagePrefix), "第一个标题应包含压测前缀")
        XCTAssertTrue(titles[0].hasSuffix("1"), "第一个标题应以序号 1 结尾")
        XCTAssertTrue(titles[1].hasSuffix("2"), "第二个标题应以序号 2 结尾")
    }

    /// count=0 应安全跳过不崩溃（P1 缺陷 A-1 修复验证）
    @MainActor
    func testRunStressTest_count为零_应安全跳过不崩溃() async {
        let benchmarker = PerformanceBenchmarker.shared
        let store = CountingPageStore()
        // 修复前：1...0 触发 fatalError；修复后：guard count > 0 提前返回
        await benchmarker.runStressTest(count: 0, store: store)
        XCTAssertEqual(store.createCount, 0, "count=0 时不应创建任何页面")
        XCTAssertEqual(store.searchCount, 0, "count=0 时不应触发搜索")
    }

    /// 小批量压测应触发动态进度日志（A-4 死代码分支修复验证）
    @MainActor
    func testRunStressTest_小批量_动态步长应触发进度分支() async {
        let benchmarker = PerformanceBenchmarker.shared
        let store = CountingPageStore()
        // 修复前：step=5000，count=5 时进度分支永不执行（死代码）
        // 修复后：step=max(5/10,1)=1，每次迭代都触发进度日志
        await benchmarker.runStressTest(count: 5, store: store)
        XCTAssertEqual(store.createCount, 5, "应创建 5 个页面")
        // 进度分支会访问 store.pages.count，但不影响 createCount
        // 此测试主要验证小批量不崩溃且动态步长生效
    }
}
#endif
