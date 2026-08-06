//
//  AudioSplitterTests.swift
//  ZhiYu
//
//  系统层级：[L0] 测试层
//  核心职责：验证 AudioSplitter 音频分片切割与重组的正确性（空/边界/往返）。
//

import XCTest
@testable import ZhiYu

final class AudioSplitterTests: XCTestCase {

    // MARK: - split 等价类划分

    /// 空 Data → 空数组
    func testSplit_空数据_返回空数组() {
        let result = AudioSplitter.split(data: Data())
        XCTAssertTrue(result.isEmpty, "空数据应返回空数组")
    }

    /// 数据长度 < chunkSize → 单分片
    func testSplit_数据小于chunkSize_单分片() {
        let data = Data(repeating: 0xAB, count: 100)
        let result = AudioSplitter.split(data: data, chunkSize: 256)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0], data)
    }

    /// 数据长度 == chunkSize → 单分片
    func testSplit_数据等于chunkSize_单分片() {
        let data = Data(repeating: 0xAB, count: 256)
        let result = AudioSplitter.split(data: data, chunkSize: 256)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0], data)
    }

    /// 数据长度 == chunkSize * N → N 个分片
    func testSplit_数据整除chunkSize_N个分片() {
        let data = Data(repeating: 0xAB, count: 512)
        let result = AudioSplitter.split(data: data, chunkSize: 256)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].count, 256)
        XCTAssertEqual(result[1].count, 256)
    }

    /// 数据长度 == chunkSize * N + remainder → N+1 个分片，最后一个为 remainder
    func testSplit_数据非整除chunkSize_N加1个分片() {
        let data = Data(repeating: 0xAB, count: 300)
        let result = AudioSplitter.split(data: data, chunkSize: 256)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].count, 256)
        XCTAssertEqual(result[1].count, 44, "最后一个分片应为余数 44")
    }

    /// 自定义 chunkSize=1 → 每字节一个分片
    func testSplit_chunkSize为1_每字节一个分片() {
        let data = Data(repeating: 0xAB, count: 5)
        let result = AudioSplitter.split(data: data, chunkSize: 1)
        XCTAssertEqual(result.count, 5)
        for chunk in result {
            XCTAssertEqual(chunk.count, 1)
        }
    }

    /// 默认 chunkSize 为 256KB
    func testSplit_默认chunkSize_256KB() {
        let data = Data(repeating: 0xAB, count: 256 * 1024 + 1)
        let result = AudioSplitter.split(data: data)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].count, 256 * 1024)
        XCTAssertEqual(result[1].count, 1)
    }

    // MARK: - merge 测试

    /// 空数组 → 空 Data
    func testMerge_空数组_返回空Data() {
        let result = AudioSplitter.merge(chunks: [])
        XCTAssertTrue(result.isEmpty)
    }

    /// 单分片 → 原始 Data
    func testMerge_单分片_返回原始Data() {
        let original = Data(repeating: 0xCD, count: 100)
        let result = AudioSplitter.merge(chunks: [original])
        XCTAssertEqual(result, original)
    }

    // MARK: - 往返测试（split → merge 还原）

    /// split 后 merge 应还原原始数据
    func testRoundTrip_split后merge_还原原始数据() {
        let original = Data(repeating: 0xEF, count: 1000)
        let chunks = AudioSplitter.split(data: original, chunkSize: 256)
        let recovered = AudioSplitter.merge(chunks: chunks)
        XCTAssertEqual(recovered, original, "split→merge 应还原原始数据")
    }

    /// 大数据往返测试（默认 chunkSize）
    func testRoundTrip_大数据_默认chunkSize() {
        let original = Data(repeating: 0x12, count: 1024 * 1024)
        let chunks = AudioSplitter.split(data: original)
        let recovered = AudioSplitter.merge(chunks: chunks)
        XCTAssertEqual(recovered, original)
    }
}
