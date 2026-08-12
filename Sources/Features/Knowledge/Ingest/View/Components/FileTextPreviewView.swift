//
//  FileTextPreviewView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/20.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层组件
//  核心职责：用于导入文件的大文本高性能增量流式预览，基于 Swift 官方 AsyncSequence 及异步迭代器规范构建，规避主线程 I/O ANR 与大文本 SwiftUI 内存 OOM 崩溃。
//

import SwiftUI

/// 异步切片读取流序列，符合 Swift 官方 AsyncSequence 规范
public struct FileChunkSequence: AsyncSequence, Sendable {
    public typealias Element = String
    
    public let filePath: String
    public let chunkSize: Int
    
    public struct AsyncIterator: AsyncIteratorProtocol, Sendable {
        let filePath: String
        let chunkSize: Int
        
        // 迭代器状态通过 ReferenceBox 装箱（@unchecked Sendable），
        // 支持 mutating next() 方法跨 await 边界变异；AsyncIterator 实例单线程使用，无并发冲突。
        private let currentOffset = ReferenceBox<UInt64>(0)
        private let isEOF = ReferenceBox<Bool>(false)
        
        init(filePath: String, chunkSize: Int) {
            self.filePath = filePath
            self.chunkSize = chunkSize
        }
        
        public mutating func next() async throws -> String? {
            guard !isEOF.value else { return nil }
            
            let path = filePath
            let size = chunkSize
            let offset = currentOffset.value
            
            // 使用 Task.detached 后台异步读取，确保不阻塞主线程
            let (data, isEnd) = try await Task.detached(priority: .background) {
                guard let fileHandle = FileHandle(forReadingAtPath: path) else {
                    return (Data(), true)
                }
                defer { try? fileHandle.close() }
                
                try fileHandle.seek(toOffset: offset)
                if let readData = try fileHandle.read(upToCount: size) {
                    let end = readData.count < size
                    return (readData, end)
                }
                return (Data(), true)
            }.value
            
            if data.isEmpty {
                isEOF.value = true
                return nil
            }
            
            currentOffset.value += UInt64(data.count)
            isEOF.value = isEnd
            
            return String(bytes: data, encoding: .utf8) ?? ""
        }
    }
    
    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(filePath: filePath, chunkSize: chunkSize)
    }
}

/// 辅助引用装箱，便于在 mutating 迭代器方法中跨并发域线程变异
private final class ReferenceBox<T>: @unchecked Sendable {
    var value: T
    init(_ value: T) {
        self.value = value
    }
}

/// 高性能增量文本预览组件
@MainActor
public struct FileTextPreviewView: View {
    
    /// 本地文件路径
    public let filePath: String
    
    /// 单块流式读取的字节大小 (100KB)
    public let chunkSize: Int = 100_000
    
    /// 判定为大文件的字节阈值 (1MB)
    public let largeFileThreshold: Int = 1_000_000
    
    @State private var previewText: String = ""
    @State private var isLoading: Bool = false
    @State private var isEOF: Bool = false
    @State private var fileSize: UInt64 = 0
    @State private var isLargeFile: Bool = false
    
    // 异步序列迭代器状态
    @State private var iterator: FileChunkSequence.AsyncIterator?
    
    public init(filePath: String) {
        self.filePath = filePath
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.medium) {
            if isLargeFile && !isEOF {
                HStack(spacing: DesignSystem.small) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                    Text(L10n.Ingest.previewTruncated)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                .padding(.horizontal)
                .padding(.vertical, DesignSystem.tiny)
                .background(Color.theme.orange.opacity(DesignSystem.shadowOpacity))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.smallRadius))
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.medium) {
                    // 渲染已读取的纯文本
                    Text(previewText)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.appText)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                    
                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .padding()
                    } else if !isEOF {
                        // 增量加载更多按钮
                        Button(action: {
                            Task {
                                await loadNextChunk()
                            }
                        }) {
                            HStack {
                                Spacer()
                                Label(L10n.Ingest.previewLoadMore, systemImage: "arrow.clockwise.circle")
                                    .font(.subheadline.bold())
                                Spacer()
                            }
                            .padding()
                            .background(Color.appAccent.opacity(DesignSystem.subtleOpacity))
                            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cardRadius))
                        }
                        .padding(.horizontal)
                    } else if isLargeFile {
                        // 读完提示
                        HStack {
                            Spacer()
                            Text(L10n.Ingest.previewFinished)
                                .font(.caption2)
                                .foregroundStyle(.appSecondary)
                            Spacer()
                        }
                        .padding(.vertical)
                    }
                }
            }
        }
        .task {
            // 获取文件元数据并判断大小
            if let attributes = try? FileManager.default.attributesOfItem(atPath: filePath),
               let size = attributes[.size] as? UInt64 {
                self.fileSize = size
                self.isLargeFile = size >= UInt64(largeFileThreshold)
            }
            
            // 初始化迭代器
            self.iterator = FileChunkSequence(filePath: filePath, chunkSize: chunkSize).makeAsyncIterator()
            
            // 初始读取第一块
            await loadNextChunk()
        }
    }
    
    /// 流式异步背景读取文件切片
    private func loadNextChunk() async {
        guard !isLoading && !isEOF else { return }
        isLoading = true
        
        do {
            if var it = iterator {
                if let chunk = try await it.next() {
                    self.previewText.append(chunk)
                    // 更新迭代状态
                    self.iterator = it
                } else {
                    self.isEOF = true
                }
            } else {
                self.isEOF = true
            }
        } catch {
            self.isEOF = true
        }
        
        isLoading = false
    }
}
