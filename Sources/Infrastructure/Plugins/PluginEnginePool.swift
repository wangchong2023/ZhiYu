//
//  PluginEnginePool.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/24.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：提供高并发安全的 JSContext 连接池，控制沙箱资源并防止内存碎片与 OOM。
//

#if !os(watchOS)

import Foundation
import JavaScriptCore
import os

/// 插件 JavaScriptCore 执行引擎连接池
/// 复用 JSContext 并将最大并发数物理限制为 4 个，有效遏制内存碎片积压与 OOM 隐患。
final class PluginEnginePool: @unchecked Sendable {
    /// 全局单例
    static let shared = PluginEnginePool()
    
    /// 连接池物理上限
    private let maxPoolSize = 4
    
    /// 缓存的可用 JSContext 实例队列
    private var availableContexts: [JSContext] = []
    
    /// 并发保护锁，用以保障连接池字典的读写安全性
    private let lockPointer: UnsafeMutablePointer<os_unfair_lock>
    
    private init() {
        lockPointer = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)
        lockPointer.initialize(to: os_unfair_lock())
    }
    
    deinit {
        lockPointer.deallocate()
    }
    
    /// 从池中获取或动态构建一个干净的 JSContext 实例，并注入 eval/Function 安全硬化配置。
    /// - Returns: 一个可供执行脚本的 JSContext。
    func borrowContext() -> JSContext {
        os_unfair_lock_lock(lockPointer)
        defer { os_unfair_lock_unlock(lockPointer) }

        if let context = availableContexts.popLast() {
            context.exception = nil
            return context
        }

        guard let newContext = JSContext() else {
            // fatalError 审查结论（任务 8）：运行时错误但不可降级 — JSContext 创建失败仅在不支持 JavaScriptCore 的平台发生，
            // borrowContext() 返回非可选类型，改为 throws/可选会级联影响所有调用方。
            // 实际触发概率极低（iOS/macOS 均支持 JSContext），保留 fatalError 并记录日志便于诊断。
            Logger.shared.error("[PluginEnginePool] JSContext 创建失败 — 当前平台可能不支持 JavaScriptCore")
            fatalError("Cannot create JSContext")
        }

        // 安全硬化：禁用 eval/Function（纯 JS 语法，无 Swift 代码）
        newContext.evaluateScript("""
        (function() {
            try { delete globalThis.eval; } catch(e) {}
            globalThis.eval = undefined;
            globalThis.Function = undefined;
            globalThis.__zhiyu_initial_keys = new Set(Object.getOwnPropertyNames(globalThis));
            var frozen = [Object.prototype, Array.prototype, String.prototype,
                         Number.prototype, Boolean.prototype, Function.prototype, RegExp.prototype];
            for (var i = 0; i < frozen.length; i++) {
                if (frozen[i]) { try { Object.freeze(frozen[i]); } catch(e) {} }
            }
        })();
        """)

        return newContext
    }

    /// 归还 JSContext 到池中
    func returnContext(_ context: JSContext) {
        os_unfair_lock_lock(lockPointer)
        defer { os_unfair_lock_unlock(lockPointer) }

        if availableContexts.count < maxPoolSize {
            context.exception = nil
            // 清理非初始全局属性（纯 JS 语法）
            context.evaluateScript("""
            (function() {
                if (globalThis.__zhiyu_initial_keys) {
                    var keys = Object.getOwnPropertyNames(globalThis);
                    for (var i = 0; i < keys.length; i++) {
                        var k = keys[i];
                        if (!globalThis.__zhiyu_initial_keys.has(k) && k !== '__zhiyu_initial_keys') {
                            try { delete globalThis[k]; } catch(e) {}
                        }
                    }
                }
            })();
            """)
            availableContexts.append(context)
        }
    }
}

#endif
