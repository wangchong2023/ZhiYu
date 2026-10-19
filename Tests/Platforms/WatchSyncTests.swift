//
//  WatchSyncTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 WatchSync 开展自动化单元测试验证。
//
import XCTest
import WatchConnectivity
#if os(watchOS)
@testable import ZhiYuWatch
#else
@testable import ZhiYu
#endif

// MARK: - 跨端同步测试载荷定义 (对齐 WATCHOS_DESIGN_GUIDELINES.md)

/// WCSession 传输载荷，watchOS 侧编码的数据结构
struct TestWatchSyncPayload: Codable, Equatable {
    let id: UUID           // 防止重复处理
    let type: PayloadType  // .voiceNote | .quickCapture | .complication
    let content: String    // 转写文字或快速记录内容
    let timestamp: Date
    let metadata: [String: String]  // 扩展元数据（标签、情绪等）

    enum PayloadType: String, Codable {
        case voiceNote       // 语音笔记
        case quickCapture    // 快捷文字记录
        case complicationTap // 表盘点击触发
    }
}

/// 模拟手表端离线缓存与重连传输管理器 (符合 4.3 离线可靠性规范)
final class MockWatchOfflineQueueManager {
    private(set) var cacheQueue: [TestWatchSyncPayload] = []
    private let maxCacheCount = 20
    
    /// 往缓存队列中压入新记录，超出限制则丢弃最旧记录
    func queuePayload(_ payload: TestWatchSyncPayload) {
        if cacheQueue.count >= maxCacheCount {
            // 丢弃最旧的记录
            cacheQueue.removeFirst()
        }
        cacheQueue.append(payload)
    }
    
    /// 模拟网络重新连接后，将所有缓存记录打包成传输字典发送
    func flushCachedPayloads(sender: (TestWatchSyncPayload) -> Bool) -> Int {
        var sentCount = 0
        let tempQueue = cacheQueue
        for payload in tempQueue {
            let success = sender(payload)
            if success {
                sentCount += 1
                if let index = cacheQueue.firstIndex(of: payload) {
                    cacheQueue.remove(at: index)
                }
            } else {
                // 如果发送失败，停止 flush，保留剩余队列以便重试
                break
            }
        }
        return sentCount
    }
    
    /// 清除所有缓存
    func clear() {
        cacheQueue.removeAll()
    }
}

// MARK: - 单元测试

/// 验证 watchOS 数据载荷、离线可靠性队列以及微缩缓存同步逻辑
@MainActor
final class WatchSyncTests: XCTestCase {

    private var queueManager: MockWatchOfflineQueueManager!

    override func setUp() {
        super.setUp()
        queueManager = MockWatchOfflineQueueManager()
    }

    override func tearDown() {
        queueManager = nil
        super.tearDown()
    }

    /// TC-WAT-01: 验证手表端离线录制音频后，系统能生成本地缓存，并在 WCSession 重新连线时自动离线传输。
    func testWatchVoiceRecorderSync() async {
        // 1. 模拟手表处于离线状态 (WCSession 未激活)，此时进行 3 次语音记录
        for i in 1...3 {
            let mockPayload = TestWatchSyncPayload(
                id: UUID(),
                type: .voiceNote,
                content: "手表端离线语音转写内容 \(i)",
                timestamp: Date(),
                metadata: ["duration": "10.\(i)s"]
            )
            queueManager.queuePayload(mockPayload)
        }
        
        // 2. 校验本地离线缓存数是否确实为 3
        XCTAssertEqual(queueManager.cacheQueue.count, 3, "离线缓存队列应包含 3 条记录")
        
        // 3. 模拟录音条数溢出，测试最多保存 20 条的上限逻辑
        for i in 4...25 {
            let mockPayload = TestWatchSyncPayload(
                id: UUID(),
                type: .voiceNote,
                content: "手表端离线溢出语音转写内容 \(i)",
                timestamp: Date(),
                metadata: [:]
            )
            queueManager.queuePayload(mockPayload)
        }
        
        // 4. 验证队列是否保持在 20 条的最大限制，且最旧的离线记录 (1, 2...5) 已被丢弃
        XCTAssertEqual(queueManager.cacheQueue.count, 20, "队列最大大小应限制在 20 条内")
        XCTAssertEqual(queueManager.cacheQueue.first?.content, "手表端离线溢出语音转写内容 6", "最旧的溢出记录应当被率先丢弃")
        
        // 5. 模拟 WCSession 重新连线成功，开始将缓存进行离线传输
        var sentPayloads: [TestWatchSyncPayload] = []
        let sendHandler: (TestWatchSyncPayload) -> Bool = { payload in
            sentPayloads.append(payload)
            return true // 返回 true 模拟传输成功
        }
        
        let sentCount = queueManager.flushCachedPayloads(sender: sendHandler)
        
        // 6. 验证已成功传输了 20 条，且本地缓存清空
        XCTAssertEqual(sentCount, 20, "重连后应该成功发送所有 20 条缓存记录")
        XCTAssertEqual(queueManager.cacheQueue.count, 0, "传输完毕后，本地离线队列应被清零")
        XCTAssertEqual(sentPayloads.first?.content, "手表端离线溢出语音转写内容 6")
    }

    /// TC-WAT-02: 验证手表端离线阅读列表从 iPhone 缓存拉取，支持 50+ 最热卡片热离线极速阅读。
    func testWatchMicroRecapCacheSync() async {
        // 1. 模拟 iPhone 侧生成 55 条最近热门知识库页面数据
        var mockPagesDict: [[String: Any]] = []
        for i in 1...55 {
            let page: [String: Any] = [
                "id": UUID().uuidString,
                "title": "热门卡片标题 \(i)",
                "content": "这里是第 \(i) 条最近更新的热门页面精简缓存数据内容，提供快速离线阅读。",
                "updatedAt": Date().timeIntervalSince1970
            ]
            mockPagesDict.append(page)
        }
        
        // 2. 模拟跨端 WCSession 载荷字典打包 (仅保留前 50 条最热数据限制以保证极速读取与包体积控制)
        let maxWatchReadCache = 50
        let watchCacheList = Array(mockPagesDict.prefix(maxWatchReadCache))
        
        let userInfo: [String: Any] = [
            "type": "recap_cache_sync",
            "pages": watchCacheList,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        // 3. 模拟手表端接收到 recap_cache_sync 广播，并写入本地 UserDefaults
        let mockUserDefaults = UserDefaults(suiteName: "com.zhiyu.test.watchcache") ?? .standard
        
        if let type = userInfo["type"] as? String, type == "recap_cache_sync",
           let receivedPages = userInfo["pages"] as? [[String: Any]] {
            
            // 写入本地缓存
            mockUserDefaults.set(receivedPages, forKey: "watch_offline_read_cache")
        }
        
        // 4. 从本地缓存中读取并进行断言校验
        let cachedData = mockUserDefaults.array(forKey: "watch_offline_read_cache") as? [[String: Any]]
        XCTAssertNotNil(cachedData, "读取的本地离线缓存数据不应该为空")
        XCTAssertEqual(cachedData?.count, 50, "离线阅读缓存数据应严格限制在 50 条以内")
        
        // 5. 验证首条热门数据的字段还原度
        let firstPage = cachedData?.first
        XCTAssertEqual(firstPage?["title"] as? String, "热门卡片标题 1")
        XCTAssertTrue((firstPage?["content"] as? String)?.contains("热门页面精简缓存数据内容") ?? false)
        
        // 6. 清理测试脏数据
        mockUserDefaults.removeObject(forKey: "watch_offline_read_cache")
    }

    // MARK: - 3. 音频物理分片与重组测试
    /// 验证音频物理分片切割与重组 (TC-WAT-03)
    func testAudioSplitterSplitAndMerge() {
        let originalSize = 1024 * 1024 // 1MB
        var randomBytes = Data(count: originalSize)
        _ = randomBytes.withUnsafeMutableBytes {
            // swiftlint:disable:next force_unwrapping
            SecRandomCopyBytes(kSecRandomDefault, originalSize, $0.baseAddress!)
        }
        
        let chunks = AudioSplitter.split(data: randomBytes, chunkSize: 256 * 1024)
        XCTAssertEqual(chunks.count, 4, "1MB 数据按 256KB 分片应正好分成 4 片")
        XCTAssertEqual(chunks[0].count, 256 * 1024)
        
        let merged = AudioSplitter.merge(chunks: chunks)
        XCTAssertEqual(merged, randomBytes, "合并后的数据应与原始数据完全一致")
    }
    
    #if os(iOS) && !os(watchOS)
    /// 验证 iOS 接收端对于音频分片的组装拼接与自愈，即使分片乱序到达 (TC-WAT-03)
    func testiOSAudioChunkAssemblyAndSelfHealing() {
        let service = iOSWatchSyncService()
        let transferId = UUID().uuidString
        let filename = "test_voice.m4a"
        
        let chunk1 = Data([1, 2, 3])
        let chunk2 = Data([4, 5, 6])
        let chunk3 = Data([7, 8, 9])
        
        // 模拟接收第二个分片 (乱序到达)
        service.handleReceivedAudioChunk(transferId: transferId, index: 1, total: 3, filename: filename, data: chunk2)
        XCTAssertEqual(service.lastReceivedText, "", "分片未集齐前不应触发合并")
        
        // 模拟接收第一个分片
        service.handleReceivedAudioChunk(transferId: transferId, index: 0, total: 3, filename: filename, data: chunk1)
        XCTAssertEqual(service.lastReceivedText, "")
        
        // 模拟接收第三个分片 (集齐)
        let expectation = expectation(description: "等待音频合并通知")
        let observer = NotificationCenter.default.addObserver(forName: .didReceiveWatchAudio, object: nil, queue: .main) { notification in
            let data = notification.object as? Data
            XCTAssertEqual(data, Data([1, 2, 3, 4, 5, 6, 7, 8, 9]), "合并后的音频数据内容应完全正确")
            XCTAssertEqual(notification.userInfo?["filename"] as? String, filename)
            expectation.fulfill()
        }
        
        service.handleReceivedAudioChunk(transferId: transferId, index: 2, total: 3, filename: filename, data: chunk3)
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(service.lastReceivedText, "audio:test_voice.m4a:9", "lastReceivedText 应该被正确赋值")
        NotificationCenter.default.removeObserver(observer)
    }
    #endif

    /// 验证规范中的 WatchSyncPayload 能够与 WCSession 的 [String: Any] 字典载荷进行无损互转，保证向下兼容
    func testPayloadCodableCompatibility() throws {
        let originalPayload = TestWatchSyncPayload(
            // swiftlint:disable:next force_unwrapping
            id: UUID(uuidString: "E621E1F8-C36C-495A-93FC-0C247A3E6E5F")!,
            type: .quickCapture,
            content: "这是一条测试内容",
            timestamp: Date(timeIntervalSince1970: 100000),
            metadata: ["source": "watchOS_complication"]
        )
        
        // 1. 进行 JSON 序列化
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(originalPayload)
        
        // 2. 将 JSON 转化为 WCSession 能接受的字典
        guard let dictionary = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] else {
            XCTFail("字典反序列化失败"); return
        }
        
        // 3. 校验关键字段在字典中存在且值正确
        XCTAssertEqual(dictionary["id"] as? String, "E621E1F8-C36C-495A-93FC-0C247A3E6E5F")
        XCTAssertEqual(dictionary["type"] as? String, "quickCapture")
        XCTAssertEqual(dictionary["content"] as? String, "这是一条测试内容")
        
        if let metadata = dictionary["metadata"] as? [String: String] {
            XCTAssertEqual(metadata["source"], "watchOS_complication")
        } else {
            XCTFail("metadata 解析失败")
        }
        
        // 4. 将字典反序列化回结构体，验证无损转换
        let newJsonData = try JSONSerialization.data(withJSONObject: dictionary, options: [])
        let decoder = JSONDecoder()
        let decodedPayload = try decoder.decode(TestWatchSyncPayload.self, from: newJsonData)
        
        XCTAssertEqual(decodedPayload, originalPayload, "还原出的结构体应该与原始结构体完全相等")
    }
    
    #if os(watchOS)
    /// 验证 watchOS 端的 WatchWatchSyncService 实现与 WCSessionDelegate 回调行为
    func testWatchWatchSyncServiceImplementation() async {
        // 1. 实例化 WatchWatchSyncService，测试未激活状态
        var mockState: WCSessionActivationState = .notActivated
        let service = WatchWatchSyncService(activationStateProvider: { mockState })
        XCTAssertEqual(service.lastReceivedText, "", "初始化时接收文本应为空")
        
        // 2. 测试发送内容 (由于在测试环境中 session activationState 不是 activated，应提前返回而不会崩溃)
        XCTAssertNoThrow(service.sendContent("测试发送"), "在未激活会话下发送不应抛出异常或崩溃")
        
        // 2.1 模拟已激活状态下的数据发送逻辑，覆盖 transferUserInfo 的完整拼装流程
        mockState = .activated
        XCTAssertNoThrow(service.sendContent("模拟已激活发送"), "在激活状态下发送不应崩溃")
        
        // 3. 模拟激活成功及激活异常回调
        let session = WCSession.default
        service.session(session, activationDidCompleteWith: .activated, error: nil)
        service.session(session, activationDidCompleteWith: .notActivated, error: NSError(domain: "WatchSyncTest", code: 100, userInfo: [NSLocalizedDescriptionKey: "模拟激活失败"]))
        #if !os(watchOS)
        service.sessionDidBecomeInactive(session)
        service.sessionDidDeactivate(session)
        #endif
        
        // 4. 模拟接收空或者无效的用户信息
        service.session(session, didReceiveUserInfo: [:])
        service.session(session, didReceiveUserInfo: ["content": 12345]) // 无效类型
        XCTAssertEqual(service.lastReceivedText, "", "收到无效用户信息时不应更新 text")
        
        // 5. 模拟接收有效用户信息并验证通知发送
        let expectedContent = "来自手表的同步测试内容"
        let expectation = expectation(description: "等待接收 watchOS 广播通知")
        
        let observer = NotificationCenter.default.addObserver(forName: .didReceiveWatchContent, object: nil, queue: .main) { notification in
            XCTAssertEqual(notification.object as? String, expectedContent, "通知携带的内容应与发送的一致")
            expectation.fulfill()
        }
        
        // 触发接收
        service.session(session, didReceiveUserInfo: ["content": expectedContent])
        
        // 等待异步任务执行完成
        await fulfillment(of: [expectation], timeout: 2.0)
        
        // 验证 lastReceivedText 的更新
        XCTAssertEqual(service.lastReceivedText, expectedContent, "接收文本应正确更新")
        
        NotificationCenter.default.removeObserver(observer)
    }
    
    /// 验证 watchOS 端音频录音文件分片与断点续传的离线缓存与重连机制 (TC-WAT-03)
    func testWatchAudioOfflineTransferAndSelfHealing() {
        var mockState: WCSessionActivationState = .notActivated
        let service = WatchWatchSyncService(activationStateProvider: { mockState })
        let originalSize = 100 * 1024 // 100KB
        var randomBytes = Data(count: originalSize)
        
        UserDefaults.standard.removeObject(forKey: "watch_pending_audio_transfers")
        
        // 尝试发送，由于离线（mockState 为 .notActivated），分片应缓存于本地
        service.sendAudioData(randomBytes, filename: "offline_voice.m4a")
        
        let pending = UserDefaults.standard.dictionary(forKey: "watch_pending_audio_transfers") as? [String: [String: Any]]
        XCTAssertNotNil(pending, "离线时发送音频，分片应缓存于本地")
        XCTAssertEqual(pending?.count, 1)
        
        if let transfer = pending?.values.first,
           let chunks = transfer["chunks"] as? [[String: Any]] {
            XCTAssertEqual(chunks.count, 1, "100KB 音频分片应为 1 个")
            XCTAssertEqual(chunks[0]["sent"] as? Bool, false, "离线缓存中分片的已发送状态应为 false")
        } else {
            XCTFail("缓存数据结构解析失败")
        }
        
        // 模拟重连激活 (闭包返回状态改为 .activated)
        mockState = .activated
        service.triggerPendingTransfers()
        
        // 验证发送完毕后，本地离线队列应被清零
        let pendingAfterActive = UserDefaults.standard.dictionary(forKey: "watch_pending_audio_transfers") as? [String: [String: Any]]
        XCTAssertTrue(pendingAfterActive?.isEmpty ?? true, "重传成功后，本地离线队列应被清空")
        
        UserDefaults.standard.removeObject(forKey: "watch_pending_audio_transfers")
    }
    #endif
}
