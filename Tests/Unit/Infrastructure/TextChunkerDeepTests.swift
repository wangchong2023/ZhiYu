//
//  TextChunkerDeepTests.swift
//  ZhiYuTests
//
//  合并自 3 个碎片化测试文件：TextChunkerBoundaryTests.swift, TextChunkerFuzzTests.swift, TextChunkerMutationTests.swift
//

import XCTest
@testable import ZhiYu

final class TextChunkerDeepTests: XCTestCase {

    func testSplit_shortChunk_overlapWindowDoesNotCollapse() {
        let chunker = TextChunkerProcessor()
        let config = TextChunkerProcessor.Config(
            chunkSize: 20,
            chunkOverlap: 10,
            separators: ["\n"]
        )

        let line1 = String(repeating: "A", count: 25)
        let line2 = String(repeating: "B", count: 25)
        let text = line1 + "\n" + line2 + "\n"

        let chunks = chunker.split(text: text, config: config)

        XCTAssertGreaterThanOrEqual(chunks.count, 2, "应产生至少 2 个 chunk")

        for i in 1..<chunks.count {
            XCTAssertGreaterThan(
                chunks[i].startIndex,
                chunks[i-1].startIndex,
                "startIndex 应严格单调递增，重叠不应导致 startIndex 塌缩"
            )
        }
    }

    func testSplit_whitespaceText_startIndexWithinBounds() {
        let chunker = TextChunkerProcessor()
        let config = TextChunkerProcessor.Config(
            chunkSize: 15,
            chunkOverlap: 5,
            separators: ["\n"]
        )

        let text = String(repeating: "X", count: 50) + "\n" + String(repeating: "Y", count: 50) + "\n"
        let chunks = chunker.split(text: text, config: config)

        XCTAssertFalse(chunks.isEmpty, "应产生 chunk")
        for chunk in chunks {
            XCTAssertGreaterThanOrEqual(chunk.startIndex, 0, "startIndex 不应为负")
            XCTAssertLessThanOrEqual(
                chunk.startIndex,
                text.count,
                "startIndex 不应超出原文长度"
            )
        }
    }
}
