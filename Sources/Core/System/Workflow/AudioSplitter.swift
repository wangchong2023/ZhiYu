//
//  AudioSplitter.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/03.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0.5] 系统集成层
//  核心职责：提供音频文件/二进制数据的物理分片切割与重组拼接能力，保证传输吞吐量。
//

import Foundation
import UFPCore

/// 负责将大音频文件/数据进行物理切割成小分片，并在接收端进行组装与自愈 (TC-WAT-03)
final class AudioSplitter: Sendable {

    /// 分片切割默认参数常量
    private enum SplitDefaults {
        /// 默认分片大小（256KB，平衡传输吞吐量与内存占用）
        static let defaultChunkSizeKB: Int = 256
    }

    /// 将音频数据分割为指定大小的小分片
    /// - Parameters:
    ///   - data: 原始音频数据
    ///   - chunkSize: 每个分片的最大字节数（默认 256KB）
    /// - Returns: 切割后的数据分片数组
    static func split(data: Data, chunkSize: Int = SplitDefaults.defaultChunkSizeKB * Int(SystemConstants.bytesPerKB)) -> [Data] {
        guard !data.isEmpty else { return [] }
        var chunks: [Data] = []
        var offset = 0
        while offset < data.count {
            let length = min(chunkSize, data.count - offset)
            let chunk = data.subdata(in: offset..<(offset + length))
            chunks.append(chunk)
            offset += length
        }
        return chunks
    }
    
    /// 将多个分片重新拼接为完整的音频数据
    /// - Parameter chunks: 数据分片数组
    /// - Returns: 拼接后的完整数据
    static func merge(chunks: [Data]) -> Data {
        var mergedData = Data()
        for chunk in chunks {
            mergedData.append(chunk)
        }
        return mergedData
    }
}
