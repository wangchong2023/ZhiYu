//
//  CachedAsyncImage.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/28.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：封装支持内存/磁盘双重图像缓存的异步图片加载视图，提供流畅的网络图标懒加载性能。
//

import SwiftUI

/// 异步缓存图像加载组件
public struct CachedAsyncImage<Content: View>: View {
    private let url: URL?
    private let content: (AsyncImagePhase) -> Content

    @State private var phase: AsyncImagePhase = .empty

    public init(
        url: URL?,
        @ViewBuilder content: @escaping (AsyncImagePhase) -> Content
    ) {
        self.url = url
        self.content = content
    }

    public var body: some View {
        content(phase)
            .task(id: url) {
                await loadImage()
            }
    }

    private func loadImage() async {
        guard let url = url else {
            phase = .failure(URLError(.badURL))
            return
        }

        // 1. 优先使用缓存策略构建 Request 检查 URLCache 缓存
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 15.0)
        if let cachedResponse = URLCache.shared.cachedResponse(for: request),
           let image = AppImage(data: cachedResponse.data) {
            phase = .success(Image(appImage: image))
            return
        }

        phase = .empty

        // 2. 缓存未命中，发起异步网络请求
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // 3. 存储成功的网络响应 data 进入 URLCache
            let cachedResponse = CachedURLResponse(response: response, data: data)
            URLCache.shared.storeCachedResponse(cachedResponse, for: request)

            if let image = AppImage(data: data) {
                phase = .success(Image(appImage: image))
            } else {
                phase = .failure(URLError(.cannotDecodeContentData))
            }
        } catch {
            if !(error is CancellationError) {
                phase = .failure(error)
            }
        }
    }
}
