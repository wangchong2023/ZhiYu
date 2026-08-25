//
//  iOSURLOpenerService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/20.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 平台适配层
//  核心职责：iOS 平台 URL 打开实现，封装 UIApplication.shared.open API。
//
//  D-35 修复：引入闭包注入模式，使 UIApplication.open 调用可被测试替换，
//  避免模拟器触发真实 Safari/系统进程阻塞单元测试。
//

#if os(iOS) && !os(watchOS)
import UIKit

/// iOS URL 打开器服务
@MainActor
// swiftlint:disable:next redundant_sendable
final class iOSURLOpenerService: URLOpenerProtocol, Sendable {
    /// 可注入的 URL 打开闭包（默认调用真实 UIApplication.shared.open）
    private let openHandler: @MainActor (URL) async -> Void

    /// 生产环境初始化（使用真实 UIApplication.shared.open）
    init() {
        self.openHandler = { url in
            await UIApplication.shared.open(url)
        }
    }

    /// 测试环境初始化（注入自定义闭包，避免触发真实 UIApplication.open）
    init(open: @escaping @MainActor (URL) async -> Void) {
        self.openHandler = open
    }

    func open(_ url: URL) async {
        await openHandler(url)
    }
}
#endif
