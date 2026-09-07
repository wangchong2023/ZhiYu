//
//  ContextRerankerPureLogicTests.swift
//  ZhiYu
//
//  Created by CodeFree on 2026/08/07.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 ContextReranker 二次语义重排序与 SSRFGuard SSRF 防护网关。
//

import XCTest
import Foundation
import UFPCore
@testable import ZhiYu

// MARK: - ContextReranker 二次语义重排序

final class ContextRerankerPureLogicTests: XCTestCase {

    let reranker = ContextReranker()

    /// 创建测试用 PageChunk
    private func makeChunk(
        id: String = "test-chunk",
        content: String = "test content",
        chunkType: ChunkType = .regular
    ) -> PageChunk {
        PageChunk(
            id: id,
            pageID: UUID(),
            chunkType: chunkType,
            content: content,
            index: 0,
            startIndex: 0
        )
    }

    // MARK: - 空候选

    func testRerankEmptyCandidates() {
        let result = reranker.rerank(query: "test", candidates: [])
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - 低分过滤

    func testRerankFilterLowScore() {
        let chunk = makeChunk(content: "some content")
        let candidates: [(chunk: PageChunk, score: Float)] = [(chunk, 0.1)]
        let result = reranker.rerank(query: "test", candidates: candidates, minScore: 0.35)
        XCTAssertTrue(result.isEmpty)
    }

    func testRerankAllBelowMinScore() {
        let chunk1 = makeChunk(id: "c1", content: "content one")
        let chunk2 = makeChunk(id: "c2", content: "content two")
        let candidates: [(chunk: PageChunk, score: Float)] = [
            (chunk1, 0.1),
            (chunk2, 0.2)
        ]
        let result = reranker.rerank(query: "test", candidates: candidates, minScore: 0.5)
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - 关键词加成

    func testRerankKeywordBonus() {
        let chunkWithKeyword = makeChunk(id: "c1", content: "machine learning model")
        let chunkWithoutKeyword = makeChunk(id: "c2", content: "weather forecast today")
        let candidates: [(chunk: PageChunk, score: Float)] = [
            (chunkWithoutKeyword, 0.8),
            (chunkWithKeyword, 0.8)
        ]
        let result = reranker.rerank(query: "machine learning", candidates: candidates)
        XCTAssertEqual(result.first?.chunk.id, "c1")
    }

    func testRerankEmptyQueryNoKeywordBonus() {
        let chunk = makeChunk(content: "some content")
        let candidates: [(chunk: PageChunk, score: Float)] = [(chunk, 0.5)]
        let result = reranker.rerank(query: "", candidates: candidates)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].score, 0.5)
    }

    // MARK: - 摘要类型权重

    func testRerankSummaryMultiplier() {
        let regularChunk = makeChunk(id: "regular", content: "test content", chunkType: .regular)
        let summaryChunk = makeChunk(id: "summary", content: "test content", chunkType: .summary)
        let candidates: [(chunk: PageChunk, score: Float)] = [
            (regularChunk, 0.5),
            (summaryChunk, 0.5)
        ]
        let result = reranker.rerank(query: "", candidates: candidates)
        XCTAssertEqual(result.first?.chunk.id, "summary")
    }

    // MARK: - TopK 截断

    func testRerankTopKTruncation() {
        var candidates: [(chunk: PageChunk, score: Float)] = []
        for i in 0..<10 {
            candidates.append((makeChunk(id: "c\(i)", content: "content \(i)"), Float(10 - i) / 10.0))
        }
        let result = reranker.rerank(query: "", candidates: candidates, topK: 3)
        XCTAssertEqual(result.count, 3)
        XCTAssertGreaterThanOrEqual(result[0].score, result[1].score)
        XCTAssertGreaterThanOrEqual(result[1].score, result[2].score)
    }

    func testRerankTopKLargerThanCandidates() {
        let chunk1 = makeChunk(id: "c1", content: "content one")
        let chunk2 = makeChunk(id: "c2", content: "content two")
        let candidates: [(chunk: PageChunk, score: Float)] = [
            (chunk1, 0.5),
            (chunk2, 0.6)
        ]
        let result = reranker.rerank(query: "", candidates: candidates, topK: 10)
        XCTAssertEqual(result.count, 2)
    }

    // MARK: - 排序正确性

    func testRerankSortedDescending() {
        var candidates: [(chunk: PageChunk, score: Float)] = []
        for i in 0..<5 {
            candidates.append((makeChunk(id: "c\(i)", content: "content \(i)"), Float(i) / 10.0 + 0.4))
        }
        let result = reranker.rerank(query: "", candidates: candidates)
        for i in 0..<result.count - 1 {
            XCTAssertGreaterThanOrEqual(result[i].score, result[i + 1].score)
        }
    }

    // MARK: - 常量验证

    func testConstantsDefaultValues() {
        XCTAssertEqual(ContextReranker.Constants.defaultTopK, 5)
        XCTAssertEqual(ContextReranker.Constants.defaultMinScore, 0.35)
        XCTAssertEqual(ContextReranker.Constants.keywordBonusWeight, 0.25)
        XCTAssertEqual(ContextReranker.Constants.summaryMultiplier, 1.1)
        XCTAssertEqual(ContextReranker.Constants.regularMultiplier, 1.0)
    }
}

// MARK: - SSRFGuard SSRF 防护网关

final class SSRFGuardPureLogicTests: XCTestCase {

    // MARK: - 环回地址

    func testRejectLocalhost() {
        XCTAssertFalse(SSRFGuard.isSafeURL(URL(string: "http://localhost:8080")!))
    }

    func testRejectLoopbackIPv4() {
        XCTAssertFalse(SSRFGuard.isSafeURL(URL(string: "http://127.0.0.1")!))
    }

    func testRejectLoopbackIPv6() {
        XCTAssertFalse(SSRFGuard.isSafeURL(URL(string: "http://[::1]")!))
    }

    // MARK: - 链路本地地址

    func testRejectLinkLocal() {
        XCTAssertFalse(SSRFGuard.isSafeURL(URL(string: "http://169.254.169.254")!))
    }

    func testRejectLinkLocalIPv6() {
        XCTAssertFalse(SSRFGuard.isSafeURL(URL(string: "http://[fe80::1]")!))
    }

    // MARK: - 私有 IP 段

    func testRejectPrivate10() {
        XCTAssertFalse(SSRFGuard.isSafeURL(URL(string: "http://10.0.0.1")!))
    }

    func testRejectPrivate17216() {
        XCTAssertFalse(SSRFGuard.isSafeURL(URL(string: "http://172.16.0.1")!))
    }

    func testRejectPrivate17231() {
        XCTAssertFalse(SSRFGuard.isSafeURL(URL(string: "http://172.31.255.255")!))
    }

    func testAllowPublic17232() {
        XCTAssertTrue(SSRFGuard.isSafeURL(URL(string: "http://172.32.0.1")!))
    }

    func testRejectPrivate192168() {
        XCTAssertFalse(SSRFGuard.isSafeURL(URL(string: "http://192.168.1.1")!))
    }

    func testRejectZeroAddress() {
        XCTAssertFalse(SSRFGuard.isSafeURL(URL(string: "http://0.0.0.0")!))
    }

    func testRejectCGNAT() {
        XCTAssertFalse(SSRFGuard.isSafeURL(URL(string: "http://100.64.0.1")!))
    }

    // MARK: - IPv6 私有地址

    func testRejectPrivateIPv6FC() {
        XCTAssertFalse(SSRFGuard.isSafeURL(URL(string: "http://[fc00::1]")!))
    }

    func testRejectPrivateIPv6FD() {
        XCTAssertFalse(SSRFGuard.isSafeURL(URL(string: "http://[fd00::1]")!))
    }

    func testRejectLinkLocalIPv6FE9() {
        XCTAssertFalse(SSRFGuard.isSafeURL(URL(string: "http://[fe90::1]")!))
    }

    func testRejectLinkLocalIPv6FEA() {
        XCTAssertFalse(SSRFGuard.isSafeURL(URL(string: "http://[fea0::1]")!))
    }

    func testRejectLinkLocalIPv6FEB() {
        XCTAssertFalse(SSRFGuard.isSafeURL(URL(string: "http://[feb0::1]")!))
    }

    // MARK: - 本地域名

    func testRejectLocalDomain() {
        XCTAssertFalse(SSRFGuard.isSafeURL(URL(string: "http://service.local")!))
    }

    func testRejectInternalDomain() {
        XCTAssertFalse(SSRFGuard.isSafeURL(URL(string: "http://api.internal")!))
    }

    func testRejectLocalhostDomain() {
        XCTAssertFalse(SSRFGuard.isSafeURL(URL(string: "http://app.localhost")!))
    }

    // MARK: - DNS Rebinding 域名

    func testRejectRebindingDomain() {
        XCTAssertFalse(SSRFGuard.isSafeURL(URL(string: "http://subdomain.xip.io")!))
    }

    // MARK: - 合法公网地址

    func testAllowPublicDomain() {
        XCTAssertTrue(SSRFGuard.isSafeURL(URL(string: "https://example.com")!))
    }

    func testAllowPublicIP() {
        XCTAssertTrue(SSRFGuard.isSafeURL(URL(string: "https://8.8.8.8")!))
    }

    func testAllowFCDomain() {
        XCTAssertTrue(SSRFGuard.isSafeURL(URL(string: "https://fc-domain.com")!))
    }

    // MARK: - IP 编码绕过防护

    func testRejectDecimalIP() {
        XCTAssertFalse(SSRFGuard.isSafeURL(URL(string: "http://2130706433")!))
    }

    func testRejectOctalIP() {
        XCTAssertFalse(SSRFGuard.isSafeURL(URL(string: "http://0177.0.0.1")!))
    }

    func testRejectHexIP() {
        XCTAssertFalse(SSRFGuard.isSafeURL(URL(string: "http://0x7f.0.0.1")!))
    }

    func testRejectAbbreviatedIP() {
        XCTAssertFalse(SSRFGuard.isSafeURL(URL(string: "http://127.1")!))
    }

    // MARK: - 无 host 的 URL

    func testRejectNoHost() {
        XCTAssertFalse(SSRFGuard.isSafeURL(URL(string: "file:///path/to/file")!))
    }
}
